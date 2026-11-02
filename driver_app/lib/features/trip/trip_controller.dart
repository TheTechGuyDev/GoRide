import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/notifications/notification_service.dart';
import '../driving/driver_controller.dart';
import '../earnings/earnings_controller.dart';

enum TripStage { toPickup, arrived, onTrip, atDestination, completed }

class ChatMessage {
  const ChatMessage(this.text, {required this.fromDriver, required this.time});
  final String text;
  final bool fromDriver;
  final DateTime time;
}

class ActiveTrip {
  const ActiveTrip({
    required this.request,
    required this.stage,
    required this.position,
    this.heading = 0,
    this.progress = 0,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.endedAt,
    this.messages = const [],
    this.unread = 0,
    this.routeChangeReason,
    this.cashCollected = false,
    this.riderRating,
    this.waitingFee = 0,
  });

  final RideRequest request;
  final TripStage stage;
  final LatLng position;
  final double heading;

  /// 0..1 along the current leg (to pickup, or to destination).
  final double progress;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<ChatMessage> messages;
  final int unread;

  /// Set when the driver told the rider they're taking another route.
  final String? routeChangeReason;
  final bool cashCollected;
  final int? riderRating;
  final int waitingFee;

  List<LatLng> get leg => switch (stage) {
    TripStage.toPickup || TripStage.arrived => request.toPickup.points,
    _ => request.trip.points,
  };

  List<LatLng> get remaining => remainingPath(leg, progress);

  double get remainingMetres => pathLength(remaining);

  int get remainingMinutes {
    final total = stage == TripStage.toPickup
        ? request.toPickup.minutes
        : request.trip.minutes;
    return max(1, (total * (1 - progress)).ceil());
  }

  /// Fare plus waiting time, what the rider pays.
  int get totalFare => request.fare + waitingFee;

  ActiveTrip copyWith({
    TripStage? stage,
    LatLng? position,
    double? heading,
    double? progress,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? endedAt,
    List<ChatMessage>? messages,
    int? unread,
    String? routeChangeReason,
    bool? cashCollected,
    int? riderRating,
    int? waitingFee,
  }) {
    return ActiveTrip(
      request: request,
      stage: stage ?? this.stage,
      position: position ?? this.position,
      heading: heading ?? this.heading,
      progress: progress ?? this.progress,
      acceptedAt: acceptedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      messages: messages ?? this.messages,
      unread: unread ?? this.unread,
      routeChangeReason: routeChangeReason ?? this.routeChangeReason,
      cashCollected: cashCollected ?? this.cashCollected,
      riderRating: riderRating ?? this.riderRating,
      waitingFee: waitingFee ?? this.waitingFee,
    );
  }
}

/// The current trip. Every step is confirmed on the server (`trips`):
/// arrive, start with the rider's PIN, complete (money moves), cancel.
/// The car's position is written to `driver_locations` so the rider sees it.
/// In the web preview the car drives itself along the route; on phones the
/// position comes from GPS.
class TripController extends Notifier<ActiveTrip?> {
  static const tick = Duration(milliseconds: 250);

  /// Waiting is free for this long, then [waitingFeePerMin] applies.
  static const freeWait = Duration(minutes: 3);
  static const waitingFeePerMin = 30;

  /// After this long at pickup, the driver may cancel as a no-show and
  /// still earn the cancellation fee.
  static const noShowAfter = Duration(minutes: 5);
  static const noShowFee = 500;

  Timer? _timer;
  Timer? _waitTimer;
  Timer? _poll;
  RealtimeChannel? _channel;

  @override
  ActiveTrip? build() {
    ref.onDispose(_stop);
    return null;
  }

  void _stop() {
    _timer?.cancel();
    _waitTimer?.cancel();
    _poll?.cancel();
    _channel?.unsubscribe();
    _channel = null;
  }

  NotificationsController get _notes =>
      ref.read(notificationsProvider.notifier);

  void start(RideRequest req) {
    final pos = ref.read(driverProvider).position;
    final driver = ref.read(driverProvider.notifier);
    driver.pauseRequests();
    driver.keepSharingLocation();
    state = ActiveTrip(
      request: req,
      stage: TripStage.toPickup,
      position: pos,
      acceptedAt: DateTime.now(),
    );
    _listen(req.id);
    _drive();
  }

  /// Picks up a trip still running after the app was closed or reloaded.
  /// Returns true if there is one.
  Future<bool> resume() async {
    final uid = Backend.user?.id;
    if (uid == null || state != null) return state != null;
    final row = await Backend.db
        .from('trips')
        .select(tripColumns)
        .eq('driver_id', uid)
        .inFilter('status', ['accepted', 'arrived', 'on_trip'])
        .order('accepted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return false;
    final driver = ref.read(driverProvider.notifier);
    final req = await driver.buildRequest(row);
    if (req == null) return false;
    final stage = switch (row['status']) {
      'arrived' => TripStage.arrived,
      'on_trip' => TripStage.onTrip,
      _ => TripStage.toPickup,
    };
    final pos = stage == TripStage.toPickup
        ? ref.read(driverProvider).position
        : req.pickup.position;
    driver.pauseRequests();
    state = ActiveTrip(
      request: req,
      stage: stage,
      position: pos,
      progress: stage == TripStage.arrived ? 1 : 0,
      acceptedAt: parseTime(row['accepted_at']),
      arrivedAt: parseTime(row['arrived_at']),
      startedAt: parseTime(row['started_at']),
    );
    await driver.goOnline();
    driver.pauseRequests();
    _listen(req.id);
    if (stage != TripStage.arrived) _drive();
    return true;
  }

  /// Rider messages and rider cancellation arrive live.
  void _listen(String tripId) {
    _channel = Backend.db
        .channel('drv-trip-$tripId')
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
              _riderSays(r['body'] as String);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tripId,
          ),
          callback: (p) => _onTripRow(p.newRecord),
        )
        .subscribe();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final r = await Backend.db
            .from('trips')
            .select('id, status, cancelled_by')
            .eq('id', tripId)
            .maybeSingle();
        if (r != null) _onTripRow(r);
      } catch (_) {}
    });
  }

  void _onTripRow(Map<String, dynamic> r) {
    final t = state;
    if (t == null || r['id'] != t.request.id) return;
    if (r['status'] == 'cancelled' && r['cancelled_by'] == 'rider') {
      _notes.notify(
        NotifyCategory.trips,
        'Rider cancelled the trip',
        'You are back online for new requests.',
        route: '/home',
        id: NotifyIds.trip,
      );
      ref.read(earningsProvider.notifier).load();
      _clear();
    }
  }

  /// Seconds the simulation takes for a leg (kept short for the preview).
  double _legSeconds(RouteInfo r) => (r.minutes * 2.0).clamp(14, 32).toDouble();

  /// Real trips follow the phone's GPS; demo drive moves the car by itself.
  void _drive() {
    if (ref.read(demoDriveProvider)) return _demoDrive();
    _timer?.cancel();
    final startLeg = state;
    if (startLeg == null) return;
    const dist = Distance();
    LatLng target(ActiveTrip t) => t.stage == TripStage.toPickup
        ? t.request.pickup.position
        : t.request.destination.position;
    final legStart = startLeg.position;
    final legMetres = max(200.0, dist(legStart, target(startLeg)));
    var warned = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final t = state;
      if (t == null) return;
      if (t.stage != TripStage.toPickup && t.stage != TripStage.onTrip) return;
      final pos = ref.read(driverProvider).position;
      final left = dist(pos, target(t));
      // Close enough counts as arrived (GPS is never perfect).
      final arrived = left <= (t.stage == TripStage.toPickup ? 200 : 300);
      final progress = arrived ? 1.0 : (1 - left / legMetres).clamp(0.0, 0.84);
      state = t.copyWith(
        progress: progress,
        position: pos,
        heading: ref.read(driverProvider).heading,
      );
      if (arrived && !warned) {
        warned = true;
        if (t.stage == TripStage.toPickup) {
          _notes.notify(
            NotifyCategory.trips,
            'You\'ve reached the pickup',
            'Tap "I\'ve arrived" to let ${t.request.riderFirstName} know.',
            route: '/trip',
            id: NotifyIds.trip,
          );
        } else {
          _timer?.cancel();
          state = state!.copyWith(stage: TripStage.atDestination);
          _notes.notify(
            NotifyCategory.trips,
            'Destination reached',
            'End the trip to see the fare.',
            route: '/trip',
            id: NotifyIds.trip,
          );
        }
      }
    });
  }

  void _demoDrive() {
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) {
      final t = state;
      if (t == null) return;
      if (t.stage != TripStage.toPickup && t.stage != TripStage.onTrip) return;
      final route = t.stage == TripStage.toPickup
          ? t.request.toPickup
          : t.request.trip;
      final step = tick.inMilliseconds / 1000 / _legSeconds(route);
      final p = min(1.0, t.progress + step);
      final at = positionAlong(t.leg, p);
      state = t.copyWith(progress: p, position: at.point, heading: at.heading);
      ref
          .read(driverProvider.notifier)
          .setPosition(at.point, heading: at.heading);

      if (p >= 1) {
        _timer?.cancel();
        if (t.stage == TripStage.toPickup) {
          _notes.notify(
            NotifyCategory.trips,
            'You\'ve reached the pickup',
            'Tap "I\'ve arrived" to let ${t.request.riderFirstName} know.',
            route: '/trip',
            id: NotifyIds.trip,
          );
        } else {
          state = state!.copyWith(stage: TripStage.atDestination);
          _notes.notify(
            NotifyCategory.trips,
            'Destination reached',
            'End the trip to see the fare.',
            route: '/trip',
            id: NotifyIds.trip,
          );
        }
      }
    });
  }

  /// Driver is at the pickup point; the rider is told.
  Future<void> arrived() async {
    final t = state;
    if (t == null || t.stage != TripStage.toPickup) return;
    _timer?.cancel();
    final end = positionAlong(t.leg, 1);
    state = t.copyWith(
      stage: TripStage.arrived,
      arrivedAt: DateTime.now(),
      progress: 1,
      position: end.point,
    );
    ref.read(driverProvider.notifier).setPosition(end.point);
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s == null || s.stage != TripStage.arrived) return;
      final waited = DateTime.now().difference(s.arrivedAt!);
      final extra = waited - freeWait;
      final fee = extra.isNegative
          ? 0
          : (extra.inMinutes + 1) * waitingFeePerMin;
      if (fee != s.waitingFee) state = s.copyWith(waitingFee: fee);
    });
    try {
      await Backend.db.rpc('driver_arrived', params: {'p_trip': t.request.id});
    } catch (_) {}
  }

  /// Returns null if the PIN matched and the trip started, else a message.
  Future<String?> startTrip(String pin) async {
    final t = state;
    if (t == null || t.stage != TripStage.arrived) return 'Trip not ready';
    try {
      final row = await Backend.db.rpc(
        'start_trip',
        params: {'p_trip': t.request.id, 'p_pin': pin},
      );
      final fee = ((row as Map)['waiting_fee'] as num?)?.toInt() ?? 0;
      _waitTimer?.cancel();
      state = state!.copyWith(
        stage: TripStage.onTrip,
        progress: 0,
        startedAt: DateTime.now(),
        waitingFee: fee,
      );
    } catch (e) {
      return AuthService.message(e);
    }
    _notes.notify(
      NotifyCategory.trips,
      'Trip started',
      'Heading to ${t.request.destination.name}. Drive safely.',
      route: '/trip',
      id: NotifyIds.trip,
    );
    _drive();
    return null;
  }

  /// Tell the rider the driver is taking a different route, so the rider's
  /// off-route alarm explains itself.
  void announceRouteChange(String reason) {
    final t = state;
    if (t == null) return;
    state = t.copyWith(routeChangeReason: reason);
    sendMessage('I\'m taking a different route: $reason');
  }

  /// End the trip: the server charges the rider and pays the driver.
  Future<void> endTrip() async {
    final t = state;
    if (t == null) return;
    if (t.stage != TripStage.onTrip && t.stage != TripStage.atDestination) {
      return;
    }
    _timer?.cancel();
    state = t.copyWith(stage: TripStage.completed, endedAt: DateTime.now());
    try {
      final row = await Backend.db.rpc(
        'complete_trip',
        params: {'p_trip': t.request.id},
      );
      final fee = ((row as Map)['waiting_fee'] as num?)?.toInt();
      if (fee != null) state = state?.copyWith(waitingFee: fee);
    } catch (e) {
      _notes.notify(
        NotifyCategory.trips,
        'Could not end the trip',
        AuthService.message(e),
        route: '/trip',
      );
    }
    ref.read(earningsProvider.notifier).load();
  }

  void markCashCollected() => state = state?.copyWith(cashCollected: true);

  /// Finish: rate the rider and go back online.
  Future<void> finish({required int riderRating}) async {
    final t = state;
    if (t == null) return;
    try {
      await Backend.db.rpc(
        'rate_trip',
        params: {'p_trip': t.request.id, 'p_stars': riderRating},
      );
    } catch (_) {}
    _clear();
    ref.read(earningsProvider.notifier).load();
  }

  /// Cancel before the trip starts (no-show fee is decided by the server).
  Future<void> cancel(String reason) async {
    final t = state;
    if (t == null) return;
    final id = t.request.id;
    _clear();
    try {
      await Backend.db.rpc(
        'cancel_trip',
        params: {'p_trip': id, 'p_reason': reason},
      );
    } catch (_) {}
    ref.read(earningsProvider.notifier).load();
  }

  void _clear() {
    _stop();
    state = null;
    ref.read(driverProvider.notifier).resumeAfterTrip();
  }

  // ---- Chat ----

  void sendMessage(String text, {bool auto = false}) {
    final t = state;
    if (t == null || text.trim().isEmpty) return;
    state = t.copyWith(
      messages: [
        ...t.messages,
        ChatMessage(text.trim(), fromDriver: true, time: DateTime.now()),
      ],
    );
    Backend.db
        .from('trip_messages')
        .insert({
          'trip_id': t.request.id,
          'sender_id': Backend.user!.id,
          'body': text.trim(),
        })
        .then((_) {}, onError: (_) {});
  }

  void _riderSays(String text) {
    final t = state;
    if (t == null) return;
    state = t.copyWith(
      messages: [
        ...t.messages,
        ChatMessage(text, fromDriver: false, time: DateTime.now()),
      ],
      unread: t.unread + 1,
    );
    if (!_onChatScreen) {
      _notes.notify(
        NotifyCategory.messages,
        t.request.riderFirstName,
        text,
        route: '/trip/chat',
      );
    }
  }

  bool _onChatScreen = false;
  void chatOpened(bool open) {
    _onChatScreen = open;
    if (open) state = state?.copyWith(unread: 0);
  }
}

final tripProvider = NotifierProvider<TripController, ActiveTrip?>(
  TripController.new,
);
