import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/routing_service.dart';
import '../activity/ride_history.dart';
import '../booking/booking_controller.dart';
import '../booking/payment_methods.dart';
import '../booking/ride_types.dart';
import '../location/location_controller.dart';
import 'path_utils.dart';
import 'trip_models.dart';

/// Runs a ride from "finding a driver" to drop-off.
///
/// Today this is a simulation so the whole flow can be tested in the preview.
/// With the backend, each phase change comes from Supabase Realtime instead:
/// the driver app accepts the ride, streams its GPS position, verifies the
/// PIN and ends the trip.
class TripController extends Notifier<TripState?> {
  final _rand = Random();
  Timer? _timer;
  Timer? _ticker;
  Timer? _alertTimer;

  // --- Route safety monitor ---
  /// How far from the agreed route counts as "off route".
  static const offRouteMetres = 300.0;

  /// How long the driver must stay off route before the rider is alerted.
  /// Production: 45s, so short detours and U-turns don't cause alarms.
  /// Preview: shorter so it can be tested quickly.
  static const offRouteConfirm = Duration(seconds: 6);

  /// Rider has this long to answer before SOS is sent automatically.
  static const alertTimeout = Duration(seconds: 60);

  /// After this long without an answer: loud alarm + final countdown.
  static const alertEscalateAfter = Duration(seconds: 45);

  // Preview speeds (real trips take as long as the road says).
  static const _searchTime = Duration(seconds: 5);
  static const _approachTime = Duration(seconds: 20);
  static const _waitAtPickup = Duration(seconds: 9);
  static const _tripTime = Duration(seconds: 35);
  static const _tick = Duration(milliseconds: 400);

  @override
  TripState? build() {
    ref.onDispose(_stopTimers);
    return null;
  }

  void _stopTimers() {
    _timer?.cancel();
    _ticker?.cancel();
    _alertTimer?.cancel();
  }

  /// Called from "Book" on the ride options screen.
  void start(RouteInfo route) {
    _stopTimers();
    final booking = ref.read(bookingControllerProvider);
    final pickupPoint =
        booking.pickup?.position ??
        ref.read(locationControllerProvider).position;
    final fare = booking.rideType.fareFor(route).total;
    final discount = booking.promo?.discountFor(booking.rideTypeId, fare) ?? 0;

    state = TripState(
      id: 'GR${DateTime.now().millisecondsSinceEpoch % 100000000}',
      phase: TripPhase.searching,
      pickup: pickupPoint,
      pickupName: booking.pickup?.name ?? 'Your location',
      destination: booking.destination!,
      pickupNote: booking.pickupNote,
      rideType: booking.rideType,
      paymentId: booking.paymentId,
      fare: fare,
      discount: discount,
      tripRoute: route.points.length >= 2
          ? route
          : RoutingService.estimate(pickupPoint, booking.destination!.position),
      pin: (1000 + _rand.nextInt(9000)).toString(),
    );

    _timer = Timer(_searchTime, _assignDriver);
  }

  Future<void> _assignDriver() async {
    final s = state;
    if (s == null || s.phase != TripPhase.searching) return;

    final driver = _pickDriver(s.rideType);
    final start = offsetPoint(
      s.pickup,
      700 + _rand.nextDouble() * 500,
      _rand.nextDouble() * 360,
    );
    final approach = await ref
        .read(routingServiceProvider)
        .route(start, s.pickup);
    if (state?.phase != TripPhase.searching) return;

    final first = positionAlong(approach.points, 0);
    state = s.copyWith(
      phase: TripPhase.driverEnRoute,
      driver: driver,
      approachRoute: approach,
      driverPosition: first.point,
      driverHeading: first.heading,
      progress: 0,
    );

    Timer(const Duration(seconds: 3), () {
      _driverSays(
        'Hello, I\'m ${driver.firstName}. I\'m on my way to your pickup. '
        'Please be ready in about ${state?.minutesLeft ?? 3} mins.',
      );
    });

    _runLeg(approach.points, _approachTime, onDone: _arrivedAtPickup);
  }

  void _runLeg(
    List<LatLng> points,
    Duration duration, {
    required void Function() onDone,
    void Function(LatLng position)? onMove,
  }) {
    _ticker?.cancel();
    final steps = duration.inMilliseconds / _tick.inMilliseconds;
    _ticker = Timer.periodic(_tick, (t) {
      final s = state;
      if (s == null) return t.cancel();
      final next = (s.progress + 1 / steps).clamp(0.0, 1.0);
      final pos = positionAlong(points, next);
      state = s.copyWith(
        progress: next,
        driverPosition: pos.point,
        driverHeading: pos.heading,
      );
      onMove?.call(pos.point);
      if (next >= 1) {
        t.cancel();
        onDone();
      }
    });
  }

  void _arrivedAtPickup() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: TripPhase.driverArrived, progress: 1);
    _driverSays(
      'I\'m at the pickup point. ${s.pickupNote.isNotEmpty ? 'Close to: ${s.pickupNote}.' : ''}',
    );
    // Simulates the driver entering the rider's PIN.
    _timer = Timer(_waitAtPickup, startTrip);
  }

  /// Driver entered the correct PIN.
  void startTrip() {
    final s = state;
    if (s == null || s.phase != TripPhase.driverArrived) return;
    _timer?.cancel();
    final first = positionAlong(s.tripRoute.points, 0);
    state = s.copyWith(
      phase: TripPhase.onTrip,
      progress: 0,
      startedAt: DateTime.now(),
      driverPosition: first.point,
      driverHeading: first.heading,
    );
    _runLeg(
      s.tripRoute.points,
      _tripTime,
      onDone: _complete,
      onMove: _checkRoute,
    );
  }

  // --- Route safety monitor ---

  /// Runs on every driver position update during the ride.
  /// With the backend this check also runs on the server, so an alert still
  /// fires if the rider's phone is off, stolen or out of data.
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
    if (DateTime.now().difference(since) >= offRouteConfirm) _raiseRouteAlert();
  }

  void _raiseRouteAlert() {
    final s = state;
    if (s == null) return;
    final now = DateTime.now();
    state = s.copyWith(
      routeAlert: RouteAlert(startedAt: now, deadline: now.add(alertTimeout)),
    );
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
      }
    });
  }

  /// "I know this route": accept the driver's new route and keep going.
  Future<void> acceptNewRoute() async {
    final s = state;
    if (s == null || s.driverPosition == null) return;
    _alertTimer?.cancel();
    state = s.copyWith(clearRouteAlert: true, clearOffRoute: true);

    final newRoute = await ref
        .read(routingServiceProvider)
        .route(s.driverPosition!, s.destination.position);
    final now = state;
    if (now == null || now.phase != TripPhase.onTrip) return;
    state = now.copyWith(
      tripRoute: newRoute,
      clearDrivePath: true,
      progress: 0,
      reroutedCount: now.reroutedCount + 1,
    );
    _runLeg(
      newRoute.points,
      _tripTime * 0.6,
      onDone: _complete,
      onMove: _checkRoute,
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
      messages: [
        ...s.messages,
        ChatMessage(
          text: 'Why are we going a different way from the route on my app?',
          fromRider: true,
          time: DateTime.now(),
        ),
      ],
    );
    Timer(const Duration(seconds: 3), () {
      _driverSays(
        'Sorry, the main road is blocked with heavy traffic. '
        "I'm taking another way, we'll still get there.",
      );
    });
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
  }

  /// Rider confirms they are safe; ends emergency mode.
  void markSafe() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(clearEmergency: true, clearOffRoute: true);
    // Continue to the destination from wherever the car is now.
    if (s.drivePath != null && s.phase == TripPhase.onTrip) acceptNewRoute();
  }

  /// Preview only: make the driver take a wrong turn to test the alert.
  void simulateWrongTurn() {
    final s = state;
    final pos = s?.driverPosition;
    if (s == null || pos == null || s.phase != TripPhase.onTrip) return;
    if (s.routeAlert != null || s.emergency != null) return;

    // Turn sideways (not backwards along the same road) so it's clearly off route.
    final away = (bearingBetween(pos, s.destination.position) + 100) % 360;
    final p1 = offsetPoint(pos, 150, (away + 60) % 360);
    final p2 = offsetPoint(p1, 900, away);
    final p3 = offsetPoint(p2, 1400, (away + 25) % 360);
    final path = [pos, p1, p2, p3];
    state = s.copyWith(drivePath: path, progress: 0);
    _runLeg(
      path,
      const Duration(seconds: 70),
      onDone: () {},
      onMove: _checkRoute,
    );
  }

  void _complete() {
    final s = state;
    if (s == null) return;
    if (s.paymentId == 'wallet') {
      ref.read(walletBalanceProvider.notifier).debit(s.total);
    }
    state = s.copyWith(
      phase: TripPhase.completed,
      progress: 1,
      endedAt: DateTime.now(),
    );
    ref.read(rideHistoryProvider.notifier).add(RideRecord.fromTrip(state!));
  }

  void cancel(String reason) {
    _stopTimers();
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: TripPhase.cancelled, cancelReason: reason);
    ref.read(rideHistoryProvider.notifier).add(RideRecord.fromTrip(state!));
  }

  /// Clears the finished/cancelled trip and the booking draft.
  void clear() {
    _stopTimers();
    state = null;
    ref.read(bookingControllerProvider.notifier).reset();
  }

  // --- Chat (mock driver replies) ---

  void sendMessage(String text) {
    final s = state;
    if (s == null || text.trim().isEmpty) return;
    state = s.copyWith(
      messages: [
        ...s.messages,
        ChatMessage(text: text.trim(), fromRider: true, time: DateTime.now()),
      ],
    );
    Timer(const Duration(seconds: 2), () => _driverSays(_replyTo(text)));
  }

  void markMessagesRead() {
    final s = state;
    if (s != null && s.unreadMessages > 0) {
      state = s.copyWith(unreadMessages: 0);
    }
  }

  void _driverSays(String text) {
    final s = state;
    if (s == null || s.driver == null) return;
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
  }

  String _replyTo(String text) {
    final t = text.toLowerCase();
    if (t.contains('where') || t.contains('how long')) {
      return 'I\'m about ${state?.minutesLeft ?? 2} mins away.';
    }
    if (t.contains('call')) return 'Okay, I\'ll call you when I get there.';
    if (t.contains('gate') || t.contains('waiting') || t.contains('here')) {
      return 'Alright, I\'m coming. Thank you!';
    }
    return 'Okay, noted 👍';
  }

  Driver _pickDriver(RideType type) {
    final vehicles = switch (type.kind) {
      VehicleKind.bike => [('Bajaj Boxer', 'Red'), ('Honda CG125', 'Black')],
      VehicleKind.keke => [('TVS King', 'Yellow'), ('Bajaj RE', 'Green')],
      VehicleKind.car =>
        type.id == 'xl'
            ? [('Toyota Sienna', 'Silver'), ('Toyota Highlander', 'Black')]
            : [
                ('Toyota Corolla', 'Silver'),
                ('Honda Accord', 'Black'),
                ('Toyota Camry', 'Grey'),
              ],
    };
    const names = [
      'Chinedu Okafor',
      'Tunde Bakare',
      'Ibrahim Musa',
      'Emeka Nwosu',
      'Segun Adeyemi',
    ];
    const plateLetters = ['KJA', 'LND', 'EKY', 'AAA', 'KTU', 'LSR'];
    final v = vehicles[_rand.nextInt(vehicles.length)];
    final name = names[_rand.nextInt(names.length)];
    final years = 1 + _rand.nextInt(5);
    return Driver(
      id: 'drv-${_rand.nextInt(99999)}',
      name: name,
      maskedPhone: '+234 *** *** ${1000 + _rand.nextInt(9000)}',
      rating: 4.5 + _rand.nextInt(5) / 10,
      trips: 800 + _rand.nextInt(9000),
      years: years,
      memberSince: DateTime(DateTime.now().year - years, 1 + _rand.nextInt(12)),
      carModel: v.$1,
      carColor: v.$2,
      plate:
          '${plateLetters[_rand.nextInt(plateLetters.length)]}-${100 + _rand.nextInt(900)}${String.fromCharCode(65 + _rand.nextInt(26))}${String.fromCharCode(65 + _rand.nextInt(26))}',
    );
  }
}

final tripControllerProvider = NotifierProvider<TripController, TripState?>(
  TripController.new,
);
