import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
    this.riderPhotoUrl,
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

  /// The rider's profile photo (public link), if they added one.
  final String? riderPhotoUrl;

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

/// Preview helper: the car drives itself along the route (for testing with
/// one device). Off = real GPS, which is how drivers use the app.
class DemoDriveController extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool on) => state = on;
}

final demoDriveProvider = NotifierProvider<DemoDriveController, bool>(
  DemoDriveController.new,
);

/// The admin decides (Admin > Settings) whether drivers see demo drive.
final demoDriveAllowedProvider = FutureProvider<bool>((ref) async {
  try {
    final r = await Backend.db
        .from('app_settings')
        .select('demo_drive_allowed')
        .eq('id', 1)
        .maybeSingle();
    return r?['demo_drive_allowed'] == true;
  } catch (_) {
    return false;
  }
});

class DriverController extends Notifier<DriverState> {
  static const requestSeconds = 15;

  /// Cash commission a driver may owe before they must settle.
  static const debtLimit = 5000;

  final _routing = RoutingService();
  Timer? _countdown;
  Timer? _publish;
  Timer? _poll;
  StreamSubscription<Position>? _gps;
  RealtimeChannel? _requests;
  AudioPlayer? _player;
  bool _paused = false;
  LatLng? _lastSent;
  DateTime? _lastSentAt;
  bool _sending = false;

  /// When the phone last gave us a GPS reading while online.
  DateTime? _lastFix;
  Timer? _gpsCheck;
  final _seen = <String>{};

  @override
  DriverState build() {
    ref.onDispose(() {
      _countdown?.cancel();
      _publish?.cancel();
      _poll?.cancel();
      _gps?.cancel();
      _requests?.unsubscribe();
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

  String? get _uid => Backend.user?.id;

  /// Online: the driver appears on riders' maps and receives requests.
  /// Returns a message when the driver can't go online (no GPS).
  Future<String?> goOnline() async {
    if (state.online) return null;
    final uid = _uid;
    if (uid == null) return 'Please sign in again.';
    // Riders are matched by distance, so a real GPS position is required.
    final loc = ref.read(locationControllerProvider.notifier);
    if (ref.read(locationControllerProvider).isFallback) {
      await loc.requestAndLocate();
    }
    if (ref.read(locationControllerProvider).isFallback) {
      return 'We could not find your location. Turn on Location (GPS) for GoRide Driver in your phone settings, then try again.';
    }
    // City rules, e.g. no okada at night in Oyo State.
    try {
      final here = ref.read(locationControllerProvider).position;
      final why = await Backend.db.rpc(
        'my_ride_type_block',
        params: {'p_lat': here.latitude, 'p_lng': here.longitude},
      );
      if (why is String && why.isNotEmpty) {
        return 'Your vehicle type cannot take trips here right now. $why.';
      }
    } catch (_) {}
    syncLocation();
    state = state.copyWith(online: true, onlineSince: DateTime.now());
    _paused = false;
    _startGps();
    await _sendLocation(force: true, online: true);
    _publish?.cancel();
    _publish = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sendLocation(),
    );
    _listen();
    return null;
  }

  void _onFix(Position p) {
    _lastFix = DateTime.now();
    // In demo drive the trip moves the car instead.
    if (ref.read(demoDriveProvider) && _paused) return;
    setPosition(
      LatLng(p.latitude, p.longitude),
      heading: p.heading > 0 ? p.heading : state.heading,
    );
  }

  /// Follows the phone's real GPS while online. If the background GPS
  /// service can't start on this phone, it falls back to normal GPS, and a
  /// check every 10 seconds asks the phone directly if readings stop.
  void _startGps({bool background = true}) {
    _gps?.cancel();
    try {
      _gps =
          Geolocator.getPositionStream(
            locationSettings: background
                ? _gpsSettings()
                : const LocationSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: 2,
                  ),
          ).listen(
            _onFix,
            onError: (_) {
              if (background) _startGps(background: false);
            },
          );
    } catch (_) {
      if (background) _startGps(background: false);
    }
    _gpsCheck?.cancel();
    _gpsCheck = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!state.online) return;
      if (_lastFix != null &&
          DateTime.now().difference(_lastFix!) < const Duration(seconds: 15)) {
        return;
      }
      try {
        _onFix(
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 8),
            ),
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> goOffline() async {
    _gps?.cancel();
    _gps = null;
    _gpsCheck?.cancel();
    _countdown?.cancel();
    _publish?.cancel();
    _poll?.cancel();
    _requests?.unsubscribe();
    _requests = null;
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
    final uid = _uid;
    if (uid != null) {
      try {
        await Backend.db
            .from('driver_locations')
            .update({
              'online': false,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('driver_id', uid);
      } catch (_) {}
    }
  }

  /// Writes the driver's position so riders see the car move.
  Future<void> _sendLocation({bool force = false, bool? online}) async {
    final uid = _uid;
    if (uid == null) return;
    // On a slow network, don't pile up requests: skip until the last one lands.
    if (_sending && !force) return;
    final p = state.position;
    const dist = Distance();
    // Send when the car moves, and at least every 20 seconds while parked so
    // the server knows the driver is still online and nearby.
    final recent =
        _lastSentAt != null &&
        DateTime.now().difference(_lastSentAt!) < const Duration(seconds: 20);
    if (!force && _lastSent != null && dist(_lastSent!, p) < 2 && recent) {
      return;
    }
    _lastSent = p;
    _lastSentAt = DateTime.now();
    final reg = ref.read(registrationProvider);
    try {
      _sending = true;
      await Backend.db.from('driver_locations').upsert({
        'driver_id': uid,
        'lat': p.latitude,
        'lng': p.longitude,
        'heading': state.heading,
        'online': ?online,
        'ride_type_id': ?reg.vehicle?.rideTypeId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
    } finally {
      _sending = false;
    }
  }

  /// Keeps sharing the position during a trip even if requests are paused.
  void keepSharingLocation() {
    if (_publish == null || !_publish!.isActive) {
      _publish = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _sendLocation(),
      );
    }
  }

  void updatePrefs(TripPreferences p) => state = state.copyWith(prefs: p);

  /// Called when a trip ends so new requests start coming again.
  void resumeAfterTrip() {
    _paused = false;
    if (state.online) _checkOpenRequests();
  }

  /// Pause requests while on a trip.
  void pauseRequests() {
    _paused = true;
    _countdown?.cancel();
  }

  /// New ride requests arrive live; a poll catches anything missed.
  void _listen() {
    _requests?.unsubscribe();
    _requests = Backend.db
        .channel('requests-${_uid ?? ''}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trips',
          callback: (_) => _checkOpenRequests(),
        )
        .subscribe();
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _checkOpenRequests(),
    );
    _checkOpenRequests();
  }

  /// Preview button: look for a request right now.
  void requestNow() => _checkOpenRequests();

  Future<void> _checkOpenRequests() async {
    if (!state.online || _paused || state.request != null || state.searching) {
      return;
    }
    final reg = ref.read(registrationProvider);
    final allowed = (reg.vehicle?.eligibleTypes ?? const <RideType>[])
        .map((r) => r.id)
        .where(
          (id) =>
              state.prefs.rideTypes.isEmpty ||
              state.prefs.rideTypes.contains(id),
        )
        .toList();
    if (allowed.isEmpty) return;
    try {
      final rows = await Backend.db
          .from('trips')
          .select(tripColumns)
          .eq('status', 'requested')
          .isFilter('driver_id', null)
          .inFilter('ride_type_id', allowed)
          .order('requested_at')
          .limit(10);
      const dist = Distance();
      final pos = state.position;
      final maxMetres = state.prefs.maxPickupKm * 1000;
      for (final r in rows) {
        final id = r['id'] as String;
        if (_seen.contains(id)) continue;
        if (!state.prefs.acceptCash && r['payment'] == 'cash') continue;
        final pickup = LatLng(
          (r['pickup_lat'] as num).toDouble(),
          (r['pickup_lng'] as num).toDouble(),
        );
        if (dist(pos, pickup) > maxMetres) continue;
        _seen.add(id);
        await _offer(r);
        return;
      }
    } catch (_) {}
  }

  Future<void> _offer(Map<String, dynamic> r) async {
    if (!state.online || _paused || state.request != null) return;
    state = state.copyWith(searching: true);
    final req = await _buildRequest(r);
    if (!state.online || _paused || req == null) {
      state = state.copyWith(searching: false);
      return;
    }
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

  /// Takes the request on the server. Returns null (with a message) if
  /// another driver got it first or the rider cancelled.
  Future<(RideRequest?, String?)> accept() async {
    final req = state.request;
    if (req == null) return (null, null);
    _countdown?.cancel();
    state = state.copyWith(clearRequest: true);
    try {
      await Backend.db.rpc('accept_trip', params: {'p_trip': req.id});
    } catch (e) {
      _checkOpenRequests();
      return (null, AuthService.message(e));
    }
    state = state.copyWith(accepted: state.accepted + 1);
    return (req, null);
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
    Future.delayed(const Duration(seconds: 2), _checkOpenRequests);
  }

  Future<RideRequest?> buildRequest(Map<String, dynamic> r) => _buildRequest(r);

  Future<RideRequest?> _buildRequest(Map<String, dynamic> r) async {
    final type = rideTypes.where((t) => t.id == r['ride_type_id']).firstOrNull;
    if (type == null) return null;
    final pickup = Place(
      id: 'pickup',
      name: r['pickup_address'] as String,
      address: r['pickup_address'] as String,
      position: LatLng(
        (r['pickup_lat'] as num).toDouble(),
        (r['pickup_lng'] as num).toDouble(),
      ),
    );
    final destination = Place(
      id: 'drop',
      name: r['dropoff_address'] as String,
      address: r['dropoff_address'] as String,
      position: LatLng(
        (r['dropoff_lat'] as num).toDouble(),
        (r['dropoff_lng'] as num).toDouble(),
      ),
    );
    Map<String, dynamic>? rider;
    try {
      final j = await Backend.db.rpc('trip_rider', params: {'p_trip': r['id']});
      if (j != null) rider = Map<String, dynamic>.from(j as Map);
    } catch (_) {}
    final results = await Future.wait([
      _routing.route(state.position, pickup.position),
      _routing.route(pickup.position, destination.position),
    ]);
    final name = (rider?['name'] as String?)?.trim();
    return RideRequest(
      id: r['id'] as String,
      riderName: name == null || name.isEmpty ? 'GoRide rider' : name,
      riderRating: (rider?['rating'] as num?)?.toDouble() ?? 5,
      riderTrips: (rider?['trips'] as num?)?.toInt() ?? 0,
      pickup: pickup,
      destination: destination,
      rideType: type,
      payment: r['payment'] == 'cash' ? PaymentKind.cash : PaymentKind.wallet,
      toPickup: results[0],
      trip: results[1],
      fare: (r['fare'] as num).toInt(),
      pin: '',
      surge: (r['surge'] as num?)?.toDouble() ?? 1,
      riderPhotoUrl: rider?['avatar_url'] as String?,
    );
  }
}

final driverProvider = NotifierProvider<DriverController, DriverState>(
  DriverController.new,
);

/// On Android phones GPS keeps running when the app is in the background or
/// the screen is off (a "GoRide Driver is online" notification shows).
LocationSettings _gpsSettings() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'GoRide Driver is online',
        notificationText: 'Sharing your location so riders can find you',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 2,
  );
}
