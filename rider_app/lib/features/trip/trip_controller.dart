import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart'
    show
        Backend,
        AuthService,
        tripColumns,
        Place,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel,
        parseTime,
        userIdProvider;
import 'package:latlong2/latlong.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router/app_router.dart';
import '../../core/router/routes.dart';
import '../../core/services/routing_service.dart';
import '../../core/utils/money.dart';
import '../activity/ride_history.dart';
import '../booking/booking_controller.dart';
import '../booking/payment_methods.dart';
import '../booking/ride_types.dart';
import '../location/location_controller.dart';
import 'path_utils.dart';
import 'trip_models.dart';

/// Runs a real ride from "finding a driver" to drop-off.
///
/// The trip lives in Supabase (`trips`). The rider app creates it with
/// `request_trip`, then follows it live: the driver app accepts, streams its
/// position (`driver_locations`), checks the PIN and ends the trip. Money
/// moves on the server when the trip completes.
class TripController extends Notifier<TripState?> {
  RealtimeChannel? _tripChannel;
  RealtimeChannel? _locationChannel;
  RealtimeChannel? _chatChannel;
  Timer? _poll;
  Timer? _searchTimeout;
  Timer? _ticker;
  Timer? _alertTimer;

  // --- Route safety monitor ---
  /// How far from the agreed route counts as "off route".
  static const offRouteMetres = 300.0;

  /// How long the driver must stay off route before the rider is alerted.
  static const offRouteConfirm = Duration(seconds: 30);

  /// Rider has this long to answer before SOS is sent automatically.
  static const alertTimeout = Duration(seconds: 60);

  /// After this long without an answer: loud alarm + final countdown.
  static const alertEscalateAfter = Duration(seconds: 45);

  /// No driver accepted in this time: the request is cancelled.
  static const searchLimit = Duration(minutes: 4);

  static const _tick = Duration(milliseconds: 400);

  bool _warnedArriving = false;
  double? _approachStartMetres;
  String? _status;

  void _notify(
    NotifyCategory c,
    String title,
    String body, {
    String route = Routes.trip,
    int? id = NotifyIds.rideStatus,
    bool urgent = false,
  }) {
    ref
        .read(notificationsProvider.notifier)
        .notify(c, title, body, route: route, id: id, urgent: urgent);
  }

  @override
  TripState? build() {
    final uid = ref.watch(userIdProvider);
    ref.onDispose(_stopAll);
    if (uid != null) Future.microtask(_resume);
    return null;
  }

  void _stopAll() {
    _poll?.cancel();
    _searchTimeout?.cancel();
    _ticker?.cancel();
    _alertTimer?.cancel();
    _tripChannel?.unsubscribe();
    _locationChannel?.unsubscribe();
    _chatChannel?.unsubscribe();
    _tripChannel = _locationChannel = _chatChannel = null;
  }

  // ---------------------------------------------------------------- booking

  /// Called from "Book" on the ride options screen.
  void start(RouteInfo route) {
    _stopAll();
    final booking = ref.read(bookingControllerProvider);
    final pickupPoint =
        booking.pickup?.position ??
        ref.read(locationControllerProvider).position;
    final fare = booking.rideType.fareFor(route).total;
    final discount = booking.promo?.discountFor(booking.rideTypeId, fare) ?? 0;
    final tripRoute = route.points.length >= 2
        ? route
        : RoutingService.estimate(pickupPoint, booking.destination!.position);

    // Show "finding a driver" straight away; the server confirms the price.
    state = TripState(
      id: '',
      phase: TripPhase.searching,
      pickup: pickupPoint,
      pickupName: booking.pickup?.name ?? 'Your location',
      destination: booking.destination!,
      pickupNote: booking.pickupNote,
      rideType: booking.rideType,
      paymentId: booking.paymentId,
      fare: fare,
      discount: discount,
      tripRoute: tripRoute,
      pin: '',
    );
    _request(booking, tripRoute);
  }

  Future<void> _request(BookingState booking, RouteInfo route) async {
    final s = state!;
    final payment = switch (booking.paymentId) {
      'wallet' => 'wallet',
      'cash' => 'cash',
      final id when id.length == 36 => 'card',
      _ => null,
    };
    // The chosen card becomes the one the server charges.
    if (payment == 'card') {
      try {
        await Backend.db.rpc(
          'set_default_card',
          params: {'p_card': booking.paymentId},
        );
      } catch (_) {}
    }
    if (payment == null) {
      return _bookingFailed(
        'Bank transfer tops up your wallet. Top up, then pay with your wallet, a saved card or cash.',
      );
    }
    try {
      final row = await Backend.db.rpc(
        'request_trip',
        params: {
          'p_ride_type': booking.rideTypeId,
          'p_pickup_address': s.pickupName,
          'p_pickup_lat': s.pickup.latitude,
          'p_pickup_lng': s.pickup.longitude,
          'p_dropoff_address': s.destination.name,
          'p_dropoff_lat': s.destination.position.latitude,
          'p_dropoff_lng': s.destination.position.longitude,
          'p_km': double.parse(route.km.toStringAsFixed(2)),
          'p_minutes': route.minutes,
          'p_payment': payment,
          'p_promo': booking.promo?.code,
          'p_route': [
            for (final p in route.points) [p.latitude, p.longitude],
          ],
        },
      );
      final t = Map<String, dynamic>.from(row as Map);
      final pin = await Backend.db.rpc('trip_pin', params: {'p_trip': t['id']});
      state = _withServer(state!, t, pin: pin as String?);
      _follow(t['id'] as String);
      _searchTimeout = Timer(searchLimit, () {
        if (state?.phase == TripPhase.searching) {
          cancel('No driver accepted the request', byTimeout: true);
        }
      });
    } catch (e) {
      _bookingFailed(AuthService.message(e));
    }
  }

  void _bookingFailed(String message) {
    _stopAll();
    state = null;
    _notify(NotifyCategory.updates, 'Could not book your ride', message);
    if (appRouter.canPop()) {
      appRouter.pop();
    } else {
      appRouter.go(Routes.home);
    }
  }

  /// Copies the server's id, prices and PIN into the local trip.
  TripState _withServer(TripState s, Map<String, dynamic> t, {String? pin}) {
    return TripState(
      id: t['id'] as String,
      phase: s.phase,
      pickup: s.pickup,
      pickupName: s.pickupName,
      destination: s.destination,
      pickupNote: s.pickupNote,
      rideType: s.rideType,
      paymentId: s.paymentId,
      fare: (t['fare'] as num).toInt(),
      discount: (t['discount'] as num).toInt(),
      tripRoute: s.tripRoute,
      pin: pin ?? s.pin,
      driver: s.driver,
      approachRoute: s.approachRoute,
      driverPosition: s.driverPosition,
      driverHeading: s.driverHeading,
      progress: s.progress,
      messages: s.messages,
      unreadMessages: s.unreadMessages,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      cancelReason: s.cancelReason,
    );
  }

  /// Picks up a trip still running after the app was closed.
  Future<void> _resume() async {
    if (state != null) return;
    try {
      final row = await Backend.db.rpc('my_active_trip');
      if (row == null || state != null) return;
      final t = Map<String, dynamic>.from(row as Map);
      final pickup = LatLng(
        (t['pickup_lat'] as num).toDouble(),
        (t['pickup_lng'] as num).toDouble(),
      );
      final dest = LatLng(
        (t['dropoff_lat'] as num).toDouble(),
        (t['dropoff_lng'] as num).toDouble(),
      );
      final type = rideTypes.firstWhere(
        (r) => r.id == t['ride_type_id'],
        orElse: () => rideTypes.first,
      );
      state = TripState(
        id: t['id'] as String,
        phase: TripPhase.searching,
        pickup: pickup,
        pickupName: t['pickup_address'] as String,
        destination: Place(
          id: 'dest',
          name: t['dropoff_address'] as String,
          address: t['dropoff_address'] as String,
          position: dest,
        ),
        pickupNote: '',
        rideType: type,
        paymentId: t['payment'] == 'cash' ? 'cash' : 'wallet',
        fare: (t['fare'] as num).toInt(),
        discount: (t['discount'] as num).toInt(),
        tripRoute: RoutingService.estimate(pickup, dest),
        pin: (t['pin'] as String?) ?? '',
      );
      _follow(t['id'] as String);
      await _apply(t);
    } catch (_) {}
  }

  // ---------------------------------------------------------- live updates

  void _follow(String tripId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: tripId,
    );
    _tripChannel = Backend.db
        .channel('trip-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: filter,
          callback: (p) => _apply(p.newRecord),
        )
        .subscribe();
    _chatChannel = Backend.db
        .channel('chat-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (p) {
            final r = p.newRecord;
            if (r['sender_id'] != Backend.user?.id) {
              _driverSays(r['body'] as String);
            }
          },
        )
        .subscribe();
    // Backup in case a live update is missed on a weak network.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) async {
      final id = state?.id;
      if (id == null || id.isEmpty) return;
      try {
        final row = await Backend.db
            .from('trips')
            .select(tripColumns)
            .eq('id', id)
            .maybeSingle();
        if (row != null) await _apply(row);
      } catch (_) {}
    });
  }

  Future<void> _apply(Map<String, dynamic> t) async {
    final s = state;
    if (s == null || t['id'] != s.id) return;
    final status = t['status'] as String;
    if (status == _status) return;
    _status = status;

    switch (status) {
      case 'accepted':
        _searchTimeout?.cancel();
        await _driverAssigned(t['driver_id'] as String);
      case 'arrived':
        if (s.driver == null) await _driverAssigned(t['driver_id'] as String);
        state = state!.copyWith(phase: TripPhase.driverArrived, progress: 1);
        _notify(
          NotifyCategory.rideStatus,
          'Your driver has arrived',
          'Check the plate ${state!.driver?.plate ?? ''}, then share your ride PIN: ${state!.pin}',
        );
      case 'on_trip':
        if (s.driver == null) await _driverAssigned(t['driver_id'] as String);
        state = state!.copyWith(
          phase: TripPhase.onTrip,
          progress: 0,
          startedAt: parseTime(t['started_at']) ?? DateTime.now(),
        );
        _notify(
          NotifyCategory.rideStatus,
          'Trip started',
          'Heading to ${s.destination.name}. GoRide is watching your route.',
        );
      case 'completed':
        _complete(t);
      case 'cancelled':
        _cancelled(t);
    }
  }

  Future<void> _driverAssigned(String driverId) async {
    final s = state;
    if (s == null) return;
    Driver? driver;
    try {
      final j = await Backend.db.rpc('trip_driver', params: {'p_trip': s.id});
      if (j != null) driver = Driver.fromJson(Map<String, dynamic>.from(j));
    } catch (_) {}
    if (state == null) return;
    state = state!.copyWith(
      phase: TripPhase.driverEnRoute,
      driver: driver,
      progress: 0,
    );
    _warnedArriving = false;
    _approachStartMetres = null;
    if (driver != null) {
      _notify(
        NotifyCategory.rideStatus,
        'Driver found: ${driver.name}',
        '${driver.carColor} ${driver.carModel} · ${driver.plate}. On the way to you.',
      );
    }
    _watchDriver(driverId);
  }

  void _watchDriver(String driverId) {
    _locationChannel?.unsubscribe();
    _locationChannel = Backend.db
        .channel('driver-loc-$driverId-${state?.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (p) => _onDriverRow(p.newRecord),
        )
        .subscribe();
    Backend.db
        .from('driver_locations')
        .select()
        .eq('driver_id', driverId)
        .maybeSingle()
        .then((r) {
          if (r != null) _onDriverRow(r);
        }, onError: (_) {});
  }

  Future<void> _onDriverRow(Map<String, dynamic> r) async {
    final lat = r['lat'] as num?;
    final lng = r['lng'] as num?;
    if (lat == null || lng == null) return;
    final pos = LatLng(lat.toDouble(), lng.toDouble());
    final heading = (r['heading'] as num?)?.toDouble();
    final s = state;
    if (s == null) return;
    // While the wrong-turn preview is running, it drives the car.
    if (s.drivePath != null) return;

    const dist = Distance();
    if (s.phase == TripPhase.driverEnRoute) {
      final left = dist(pos, s.pickup);
      _approachStartMetres ??= left < 200 ? 200 : left;
      if (s.approachRoute == null) {
        final approach = await ref
            .read(routingServiceProvider)
            .route(pos, s.pickup);
        if (state?.phase == TripPhase.driverEnRoute) {
          state = state!.copyWith(approachRoute: approach);
        }
      }
      final progress = (1 - left / _approachStartMetres!).clamp(0.0, 1.0);
      state = state!.copyWith(
        driverPosition: pos,
        driverHeading: heading ?? s.driverHeading,
        progress: progress,
      );
      if (!_warnedArriving && left < 400) {
        _warnedArriving = true;
        _notify(
          NotifyCategory.rideStatus,
          '${s.driver?.firstName ?? 'Your driver'} is almost there',
          'Arriving in about 1 min. Please head to your pickup point.',
        );
      }
    } else if (s.phase == TripPhase.onTrip) {
      final total = dist(s.pickup, s.destination.position);
      final left = dist(pos, s.destination.position);
      state = s.copyWith(
        driverPosition: pos,
        driverHeading: heading ?? s.driverHeading,
        progress: total <= 0 ? 0 : (1 - left / total).clamp(0.0, 1.0),
      );
      _checkRoute(pos);
    } else {
      state = s.copyWith(
        driverPosition: pos,
        driverHeading: heading ?? s.driverHeading,
      );
    }
  }

  void _complete(Map<String, dynamic> t) {
    final s = state;
    if (s == null) return;
    _stopAll();
    final total = (t['total_fare'] as num?)?.toInt() ?? s.total;
    state = s.copyWith(
      phase: TripPhase.completed,
      progress: 1,
      endedAt: parseTime(t['completed_at']) ?? DateTime.now(),
    );
    ref.read(walletBalanceProvider.notifier).debit(total);
    ref.read(rideHistoryProvider.notifier).refresh();
    _notify(
      NotifyCategory.rideStatus,
      'You have arrived at ${s.destination.name}',
      s.paymentId == 'cash'
          ? 'Please pay ${naira(total)} cash to your driver. Tap to rate your trip.'
          : '${naira(total)} paid from your wallet. Tap to rate your trip.',
      route: Routes.tripArrived,
    );
    if (appRouter.routerDelegate.currentConfiguration.uri.path == Routes.trip) {
      appRouter.go(Routes.tripArrived);
    }
  }

  void _cancelled(Map<String, dynamic> t) {
    final s = state;
    if (s == null) return;
    _stopAll();
    final byDriver = t['cancelled_by'] == 'driver';
    state = s.copyWith(
      phase: TripPhase.cancelled,
      cancelReason: (t['cancel_reason'] as String?) ?? 'Cancelled',
    );
    ref.read(rideHistoryProvider.notifier).refresh();
    if (byDriver) {
      _notify(
        NotifyCategory.rideStatus,
        'Your driver cancelled',
        'Sorry about that. Please book again and we\'ll find you another driver.',
        route: Routes.home,
      );
    }
  }

  // ------------------------------------------------------------ rider actions

  Future<void> cancel(String reason, {bool byTimeout = false}) async {
    final s = state;
    if (s == null) return;
    _stopAll();
    state = s.copyWith(phase: TripPhase.cancelled, cancelReason: reason);
    if (s.id.isEmpty) return;
    try {
      await Backend.db.rpc(
        'cancel_trip',
        params: {'p_trip': s.id, 'p_reason': reason},
      );
    } catch (_) {}
    ref.read(rideHistoryProvider.notifier).refresh();
    ref.read(walletBalanceProvider.notifier).debit(0);
    if (byTimeout) {
      _notify(
        NotifyCategory.rideStatus,
        'No driver available',
        'All drivers near you are busy. Please try again in a few minutes.',
        route: Routes.home,
      );
    }
  }

  /// Clears the finished/cancelled trip and the booking draft.
  void clear() {
    _stopAll();
    _status = null;
    state = null;
    ref.read(bookingControllerProvider.notifier).reset();
  }

  // ---------------------------------------------------- route safety monitor

  /// Runs on every driver position update during the ride. The same check
  /// should also run on the server so an alert fires if the rider's phone is
  /// off or out of data.
  void _checkRoute(LatLng position) {
    final s = state;
    if (s == null || s.phase != TripPhase.onTrip) return;
    if (s.routeAlert != null || s.emergency != null) return;

    final off = distanceToPath(position, s.tripRoute.points) > offRouteMetres;
    if (!off) {
      if (s.offRouteSince != null) state = s.copyWith(clearOffRoute: true);
      return;
    }
    final since = s.offRouteSince ?? DateTime.now();
    if (s.offRouteSince == null) state = s.copyWith(offRouteSince: since);
    final confirm = s.drivePath != null
        ? const Duration(seconds: 6)
        : offRouteConfirm;
    if (DateTime.now().difference(since) >= confirm) _raiseRouteAlert();
  }

  void _raiseRouteAlert() {
    final s = state;
    if (s == null) return;
    final now = DateTime.now();
    state = s.copyWith(
      routeAlert: RouteAlert(startedAt: now, deadline: now.add(alertTimeout)),
    );
    _notify(
      NotifyCategory.safety,
      'Your driver has left the route',
      'Open GoRide now to confirm the route. SOS is sent automatically in 60 seconds.',
      id: NotifyIds.routeAlert,
      urgent: true,
    );
    _report('route_deviation', 'Driver left the planned route');
    _alertTimer?.cancel();
    _alertTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final a = state?.routeAlert;
      if (a == null) return _alertTimer?.cancel();
      final now = DateTime.now();
      if (!now.isBefore(a.deadline)) {
        triggerSos(
          automatic: true,
          reason: 'Driver left the route and the rider did not respond',
        );
        return;
      }
      final escalateAt = a.deadline.subtract(alertTimeout - alertEscalateAfter);
      if (a.stage == RouteAlertStage.asking && !now.isBefore(escalateAt)) {
        state = state!.copyWith(
          routeAlert: a.copyWith(stage: RouteAlertStage.escalated),
        );
        _notify(
          NotifyCategory.safety,
          'Sending SOS in 15 seconds',
          'Your driver is still off route. Tap to respond.',
          id: NotifyIds.routeAlert,
          urgent: true,
        );
      }
    });
  }

  /// "I know this route": accept the driver's new route and keep going.
  Future<void> acceptNewRoute() async {
    final s = state;
    if (s == null || s.driverPosition == null) return;
    _alertTimer?.cancel();
    _ticker?.cancel();
    state = s.copyWith(
      clearRouteAlert: true,
      clearOffRoute: true,
      clearDrivePath: true,
    );
    final newRoute = await ref
        .read(routingServiceProvider)
        .route(s.driverPosition!, s.destination.position);
    final now = state;
    if (now == null || now.phase != TripPhase.onTrip) return;
    state = now.copyWith(
      tripRoute: newRoute,
      reroutedCount: now.reroutedCount + 1,
    );
  }

  /// "Ask driver": message the driver and get one more minute to decide.
  void askDriverAboutRoute() {
    final s = state;
    final a = s?.routeAlert;
    if (s == null || a == null) return;
    state = s.copyWith(
      routeAlert: a.copyWith(
        askedDriver: true,
        stage: RouteAlertStage.asking,
        deadline: DateTime.now().add(alertTimeout),
      ),
    );
    sendMessage('Why are we going a different way from the route on my app?');
  }

  /// SOS: alert next of kin + GoRide safety team with live location.
  void triggerSos({required bool automatic, required String reason}) {
    final s = state;
    if (s == null || s.emergency != null) return;
    _alertTimer?.cancel();
    state = s.copyWith(
      clearRouteAlert: true,
      emergency: Emergency(
        triggeredAt: DateTime.now(),
        automatic: automatic,
        reason: reason,
      ),
    );
    _report(automatic ? 'auto_sos' : 'sos', reason);
    _notify(
      NotifyCategory.safety,
      'Emergency mode on',
      'Your emergency contacts and the GoRide safety team have your live location.',
      route: Routes.emergency,
      id: NotifyIds.sos,
      urgent: true,
    );
  }

  /// Sends the alert to the GoRide safety team (admin Safety page).
  void _report(String kind, String details) {
    final s = state;
    if (s == null || s.id.isEmpty) return;
    final at =
        s.driverPosition ?? ref.read(locationControllerProvider).position;
    Backend.db
        .rpc(
          'raise_sos',
          params: {
            'p_trip': s.id,
            'p_kind': kind,
            'p_lat': at.latitude,
            'p_lng': at.longitude,
            'p_details': details,
          },
        )
        .then((_) {}, onError: (_) {});
  }

  /// Rider confirms they are safe; ends emergency mode.
  void markSafe() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(clearEmergency: true, clearOffRoute: true);
    if (s.drivePath != null && s.phase == TripPhase.onTrip) acceptNewRoute();
  }

  /// Preview only: make the car on the map take a wrong turn to test the alert.
  void simulateWrongTurn() {
    final s = state;
    final pos = s?.driverPosition;
    if (s == null || pos == null || s.phase != TripPhase.onTrip) return;
    if (s.routeAlert != null || s.emergency != null) return;

    final away = (bearingBetween(pos, s.destination.position) + 100) % 360;
    final p1 = offsetPoint(pos, 150, (away + 60) % 360);
    final p2 = offsetPoint(p1, 900, away);
    final p3 = offsetPoint(p2, 1400, (away + 25) % 360);
    final path = [pos, p1, p2, p3];
    state = s.copyWith(drivePath: path, progress: 0);
    _ticker?.cancel();
    const total = Duration(seconds: 70);
    final steps = total.inMilliseconds / _tick.inMilliseconds;
    var progress = 0.0;
    _ticker = Timer.periodic(_tick, (t) {
      final now = state;
      if (now == null || now.drivePath == null) return t.cancel();
      progress = (progress + 1 / steps).clamp(0.0, 1.0);
      final p = positionAlong(path, progress);
      state = now.copyWith(driverPosition: p.point, driverHeading: p.heading);
      _checkRoute(p.point);
      if (progress >= 1) t.cancel();
    });
  }

  // --------------------------------------------------------------------- chat

  void sendMessage(String text) {
    final s = state;
    if (s == null || text.trim().isEmpty) return;
    state = s.copyWith(
      messages: [
        ...s.messages,
        ChatMessage(text: text.trim(), fromRider: true, time: DateTime.now()),
      ],
    );
    if (s.id.isEmpty) return;
    Backend.db
        .from('trip_messages')
        .insert({
          'trip_id': s.id,
          'sender_id': Backend.user!.id,
          'body': text.trim(),
        })
        .then((_) {}, onError: (_) {});
  }

  void markMessagesRead() {
    final s = state;
    if (s != null && s.unreadMessages > 0) {
      state = s.copyWith(unreadMessages: 0);
    }
  }

  void _driverSays(String text) {
    final s = state;
    if (s == null) return;
    if (s.phase == TripPhase.cancelled || s.phase == TripPhase.completed) {
      return;
    }
    state = s.copyWith(
      messages: [
        ...s.messages,
        ChatMessage(text: text, fromRider: false, time: DateTime.now()),
      ],
      unreadMessages: s.unreadMessages + 1,
    );
    final onChat =
        appRouter.routerDelegate.currentConfiguration.uri.path == Routes.chat;
    if (!onChat) {
      _notify(
        NotifyCategory.messages,
        s.driver?.firstName ?? 'Your driver',
        text,
        route: Routes.chat,
        id: null,
      );
    }
  }
}

final tripControllerProvider = NotifierProvider<TripController, TripState?>(
  TripController.new,
);
