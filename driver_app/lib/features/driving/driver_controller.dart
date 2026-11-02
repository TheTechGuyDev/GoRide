import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/notifications/notification_service.dart';
import '../earnings/earnings_controller.dart';
import '../registration/plans.dart';
import '../registration/registration_controller.dart';

/// A ride offered to this driver. Later: a row in `ride_requests`,
/// delivered over Supabase Realtime.
class RideRequest {
  const RideRequest({
    required this.id,
    required this.riderName,
    required this.riderRating,
    required this.riderTrips,
    required this.pickup,
    required this.destination,
    required this.rideType,
    required this.payment,
    required this.toPickup,
    required this.trip,
    required this.fare,
    required this.pin,
    this.surge = 1.0,
    this.pickupNote,
  });

  final String id;
  final String riderName;
  final double riderRating;
  final int riderTrips;
  final Place pickup;
  final Place destination;
  final RideType rideType;
  final PaymentKind payment;
  final RouteInfo toPickup;
  final RouteInfo trip;
  final int fare;

  /// 4-digit code the rider reads out before the trip can start.
  final String pin;
  final double surge;
  final String? pickupNote;

  String get riderFirstName => riderName.split(' ').first;
}

class TripPreferences {
  const TripPreferences({
    this.acceptCash = true,
    this.rideTypes = const {},
    this.maxPickupKm = 5,
    this.destination,
  });

  final bool acceptCash;

  /// Services to receive requests for. Empty = all the vehicle allows.
  final Set<String> rideTypes;
  final double maxPickupKm;

  /// "Heading home" mode: only trips going this way.
  final Place? destination;

  TripPreferences copyWith({
    bool? acceptCash,
    Set<String>? rideTypes,
    double? maxPickupKm,
    Place? destination,
    bool clearDestination = false,
  }) {
    return TripPreferences(
      acceptCash: acceptCash ?? this.acceptCash,
      rideTypes: rideTypes ?? this.rideTypes,
      maxPickupKm: maxPickupKm ?? this.maxPickupKm,
      destination: clearDestination ? null : destination ?? this.destination,
    );
  }
}

class DriverState {
  const DriverState({
    this.online = false,
    this.onlineSince,
    this.request,
    this.secondsLeft = 0,
    this.offered = 0,
    this.accepted = 0,
    this.position = MapConfig.defaultCenter,
    this.heading = 0,
    this.prefs = const TripPreferences(),
    this.searching = false,
  });

  final bool online;
  final DateTime? onlineSince;
  final RideRequest? request;
  final int secondsLeft;

  /// Today's requests offered/accepted (acceptance rate).
  final int offered;
  final int accepted;
  final LatLng position;
  final double heading;
  final TripPreferences prefs;

  /// Busy preparing the next request (routing).
  final bool searching;

  double get acceptanceRate => offered == 0 ? 1 : accepted / offered;

  DriverState copyWith({
    bool? online,
    DateTime? onlineSince,
    RideRequest? request,
    bool clearRequest = false,
    int? secondsLeft,
    int? offered,
    int? accepted,
    LatLng? position,
    double? heading,
    TripPreferences? prefs,
    bool? searching,
  }) {
    return DriverState(
      online: online ?? this.online,
      onlineSince: onlineSince ?? this.onlineSince,
      request: clearRequest ? null : request ?? this.request,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      offered: offered ?? this.offered,
      accepted: accepted ?? this.accepted,
      position: position ?? this.position,
      heading: heading ?? this.heading,
      prefs: prefs ?? this.prefs,
      searching: searching ?? this.searching,
    );
  }
}

/// Busy area shown on the map while online.
class DemandZone {
  const DemandZone(this.centre, this.radiusM, this.multiplier, this.name);
  final LatLng centre;
  final double radiusM;
  final double multiplier;
  final String name;
}

const demandZones = [
  DemandZone(LatLng(6.4300, 3.4250), 900, 1.3, 'Victoria Island'),
  DemandZone(LatLng(6.4390, 3.4560), 1100, 1.2, 'Lekki Phase 1'),
  DemandZone(LatLng(6.4510, 3.3950), 800, 1.3, 'Lagos Island'),
  DemandZone(LatLng(6.6080, 3.3550), 1200, 1.2, 'Ikeja'),
  DemandZone(LatLng(6.5170, 3.3850), 900, 1.1, 'Yaba'),
];

/// Online/offline and incoming requests. Mock now: requests are generated
/// near the driver. Later: driver location is written to `driver_locations`
/// and requests arrive over Supabase Realtime.
class DriverController extends Notifier<DriverState> {
  static const requestSeconds = 15;

  /// Cash commission a driver may owe before they must settle.
  static const debtLimit = 5000;

  final _rand = Random();
  final _routing = RoutingService();
  Timer? _nextTimer;
  Timer? _countdown;
  AudioPlayer? _player;

  @override
  DriverState build() {
    ref.onDispose(() {
      _nextTimer?.cancel();
      _countdown?.cancel();
      _player?.dispose();
    });
    final loc = ref.read(locationControllerProvider);
    return DriverState(position: loc.position);
  }

  /// Why the driver can't go online, or null if they can.
  String? blockingReason() {
    final reg = ref.read(registrationProvider);
    if (reg.status != ApprovalStatus.approved) {
      return 'Your account is still being reviewed.';
    }
    final expired = reg.requiredDocs.map(reg.doc).where((d) => d.isExpired);
    if (expired.isNotEmpty) {
      return 'Your ${expired.first.type.title.toLowerCase()} has expired. Upload a new one in Account > Documents.';
    }
    final plan = reg.plan ?? const DriverPlan();
    if (plan.isSubscription && !plan.subscriptionActive) {
      return 'Your subscription has ended. Renew it in My plan to go online.';
    }
    final balance = ref.read(earningsProvider).balance;
    if (balance <= -debtLimit) {
      return 'You owe ${naira(-balance)} in cash trip commission. Settle it in your wallet to go online.';
    }
    return null;
  }

  void setPosition(LatLng p, {double? heading}) =>
      state = state.copyWith(position: p, heading: heading);

  void syncLocation() {
    final loc = ref.read(locationControllerProvider);
    if (state.online || state.request != null) return;
    state = state.copyWith(position: loc.position);
  }

  void goOnline() {
    if (state.online) return;
    state = state.copyWith(online: true, onlineSince: DateTime.now());
    _scheduleNext(first: true);
  }

  void goOffline() {
    _nextTimer?.cancel();
    _countdown?.cancel();
    final since = state.onlineSince;
    if (since != null) {
      ref
          .read(earningsProvider.notifier)
          .addOnlineMinutes(DateTime.now().difference(since).inMinutes);
    }
    state = DriverState(
      position: state.position,
      heading: state.heading,
      prefs: state.prefs,
      offered: state.offered,
      accepted: state.accepted,
    );
  }

  void updatePrefs(TripPreferences p) => state = state.copyWith(prefs: p);

  /// Called when a trip ends so new requests start coming again.
  void resumeAfterTrip() {
    if (state.online) _scheduleNext();
  }

  /// Pause requests while on a trip.
  void pauseRequests() {
    _nextTimer?.cancel();
    _countdown?.cancel();
  }

  void _scheduleNext({bool first = false}) {
    _nextTimer?.cancel();
    final wait = first ? 5 + _rand.nextInt(4) : 9 + _rand.nextInt(10);
    _nextTimer = Timer(Duration(seconds: wait), _offerRequest);
  }

  /// Preview button: get a request right now.
  void requestNow() {
    if (!state.online || state.request != null || state.searching) return;
    _nextTimer?.cancel();
    _offerRequest();
  }

  Future<void> _offerRequest() async {
    if (!state.online || state.request != null) return;
    state = state.copyWith(searching: true);
    final req = await _buildRequest();
    if (!state.online) return;
    state = state.copyWith(
      request: req,
      secondsLeft: requestSeconds,
      offered: state.offered + 1,
      searching: false,
    );
    _ping();
    ref
        .read(notificationsProvider.notifier)
        .notify(
          NotifyCategory.requests,
          'New ${req.rideType.name} request · ${naira(req.fare)}',
          '${req.toPickup.minutes} min away · ${req.pickup.name} to ${req.destination.name}',
          route: '/home',
          id: NotifyIds.request,
          // The request card is already on screen.
          banner: false,
        );
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.secondsLeft <= 1) {
        t.cancel();
        decline(missed: true);
      } else {
        state = state.copyWith(secondsLeft: state.secondsLeft - 1);
      }
    });
  }

  Future<void> _ping() async {
    HapticFeedback.heavyImpact();
    try {
      _player ??= AudioPlayer();
      await _player!.play(AssetSource('sounds/ride_request.wav'));
    } catch (_) {
      // Browsers may block sound until the user has tapped the page.
    }
  }

  /// Returns the accepted request (caller starts the trip).
  RideRequest? accept() {
    final req = state.request;
    if (req == null) return null;
    _countdown?.cancel();
    _nextTimer?.cancel();
    state = state.copyWith(clearRequest: true, accepted: state.accepted + 1);
    return req;
  }

  void decline({bool missed = false}) {
    _countdown?.cancel();
    state = state.copyWith(clearRequest: true);
    if (missed) {
      ref
          .read(notificationsProvider.notifier)
          .notify(
            NotifyCategory.requests,
            'You missed a request',
            'Requests last $requestSeconds seconds. Keep the app open while online.',
          );
    }
    _scheduleNext();
  }

  Future<RideRequest> _buildRequest() async {
    final reg = ref.read(registrationProvider);
    final vehicle = reg.vehicle;
    final allowed = vehicle?.eligibleTypes ?? [rideTypes[2]];
    final chosen = state.prefs.rideTypes.isEmpty
        ? allowed
        : allowed.where((r) => state.prefs.rideTypes.contains(r.id)).toList();
    final rideType = (chosen.isEmpty
        ? allowed
        : chosen)[_rand.nextInt((chosen.isEmpty ? allowed : chosen).length)];

    final pos = state.position;
    const dist = Distance();
    final byDistance = [...lagosPlaces]
      ..sort((a, b) => dist(pos, a.position).compareTo(dist(pos, b.position)));

    Place pickup;
    if (dist(pos, byDistance.first.position) < 6000) {
      pickup = byDistance[_rand.nextInt(3)];
    } else {
      // Driver is outside central Lagos: make a pickup nearby.
      final p = offsetPoint(
        pos,
        600 + _rand.nextDouble() * 1200,
        _rand.nextDouble() * 360,
      );
      pickup = Place(
        id: 'near',
        name: 'Pickup near you',
        address: 'Pin on map',
        position: p,
      );
    }

    Place destination;
    final dest = state.prefs.destination;
    if (dest != null) {
      destination = dest;
    } else if (pickup.id == 'near') {
      final p = offsetPoint(
        pickup.position,
        3000 + _rand.nextDouble() * 6000,
        _rand.nextDouble() * 360,
      );
      destination = Place(
        id: 'drop',
        name: 'Drop-off point',
        address: 'Pin on map',
        position: p,
      );
    } else {
      final candidates = lagosPlaces
          .where((p) => p != pickup && dist(pickup.position, p.position) > 2500)
          .toList();
      destination = candidates[_rand.nextInt(candidates.length)];
    }

    final results = await Future.wait([
      _routing.route(pos, pickup.position),
      _routing.route(pickup.position, destination.position),
    ]);
    final surge = _surgeAt(pickup.position);
    final fare = roundFare(rideType.fareFor(results[1]).total * surge);
    var payment = switch (_rand.nextInt(10)) {
      < 5 => PaymentKind.cash,
      < 8 => PaymentKind.wallet,
      _ => PaymentKind.card,
    };
    if (!state.prefs.acceptCash && payment == PaymentKind.cash) {
      payment = PaymentKind.wallet;
    }
    const riders = [
      'Adaeze Okafor',
      'Bola Adeyemi',
      'Chinedu Eze',
      'Damilola Ojo',
      'Emeka Nwosu',
      'Funmi Lawal',
      'Ibrahim Musa',
      'Kemi Adebayo',
      'Ngozi Obi',
      'Segun Williams',
      'Tolu Bankole',
      'Zainab Bello',
    ];
    const notes = [
      'I\'m at the main gate',
      'Call me when you arrive',
      'Blue gate opposite the pharmacy',
      null,
      null,
      null,
    ];
    return RideRequest(
      id: 'R${DateTime.now().millisecondsSinceEpoch}',
      riderName: riders[_rand.nextInt(riders.length)],
      riderRating: 4.5 + _rand.nextInt(5) / 10,
      riderTrips: 3 + _rand.nextInt(180),
      pickup: pickup,
      destination: destination,
      rideType: rideType,
      payment: payment,
      toPickup: results[0],
      trip: results[1],
      fare: fare,
      pin: (1000 + _rand.nextInt(9000)).toString(),
      surge: surge,
      pickupNote: notes[_rand.nextInt(notes.length)],
    );
  }

  double _surgeAt(LatLng p) {
    const dist = Distance();
    for (final z in demandZones) {
      if (dist(p, z.centre) <= z.radiusM) {
        return z.multiplier > maxSurge ? maxSurge : z.multiplier;
      }
    }
    return 1.0;
  }
}

final driverProvider = NotifierProvider<DriverController, DriverState>(
  DriverController.new,
);
