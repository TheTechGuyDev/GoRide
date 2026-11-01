import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/notifications/notification_service.dart';
import '../driving/driver_controller.dart';
import '../earnings/earnings_controller.dart';
import '../registration/plans.dart';
import '../registration/registration_controller.dart';

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

/// The current trip, simulated along the OSRM route.
/// Later: each GPS fix is written to `trip_locations` so the rider sees the
/// car move, and the server checks the route (rider's off-route alert).
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
  final _rand = Random();
  String? _lastRouteCheck;

  @override
  ActiveTrip? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _waitTimer?.cancel();
    });
    return null;
  }

  NotificationsController get _notes =>
      ref.read(notificationsProvider.notifier);

  void start(RideRequest req) {
    final pos = ref.read(driverProvider).position;
    ref.read(driverProvider.notifier).pauseRequests();
    state = ActiveTrip(
      request: req,
      stage: TripStage.toPickup,
      position: pos,
      acceptedAt: DateTime.now(),
      messages: [
        if (req.pickupNote != null)
          ChatMessage(req.pickupNote!, fromDriver: false, time: DateTime.now()),
      ],
      unread: req.pickupNote != null ? 1 : 0,
    );
    _drive();
  }

  /// Seconds the simulation takes for a leg (kept short for the preview).
  double _legSeconds(RouteInfo r) => (r.minutes * 2.0).clamp(14, 32).toDouble();

  void _drive() {
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

      // Rider sometimes messages while the driver is on the way.
      final key = '${t.stage}-${(p * 10).floor()}';
      if (t.stage == TripStage.toPickup &&
          key == 'TripStage.toPickup-5' &&
          _lastRouteCheck != key) {
        _lastRouteCheck = key;
        if (_rand.nextBool()) _riderSays('Okay, I\'m coming out now');
      }
    });
  }

  /// Driver is at the pickup point.
  void arrived() {
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
    Future.delayed(const Duration(seconds: 6), () {
      if (state?.stage == TripStage.arrived) _riderSays('I see you, coming!');
    });
  }

  /// Returns true if the PIN matches and the trip has started.
  bool startTrip(String pin) {
    final t = state;
    if (t == null || t.stage != TripStage.arrived) return false;
    if (pin != t.request.pin) return false;
    _waitTimer?.cancel();
    state = t.copyWith(
      stage: TripStage.onTrip,
      progress: 0,
      startedAt: DateTime.now(),
    );
    _notes.notify(
      NotifyCategory.trips,
      'Trip started',
      'Heading to ${t.request.destination.name}. Drive safely.',
      route: '/trip',
      id: NotifyIds.trip,
    );
    _drive();
    return true;
  }

  /// Tell the rider the driver is taking a different route.
  /// Live: this sends the rider app a notice so the off-route alarm
  /// explains itself instead of just going off.
  void announceRouteChange(String reason) {
    final t = state;
    if (t == null) return;
    state = t.copyWith(routeChangeReason: reason);
    sendMessage('I\'m taking a different route: $reason', auto: true);
  }

  /// End the trip at (or near) the destination.
  void endTrip() {
    final t = state;
    if (t == null) return;
    if (t.stage != TripStage.onTrip && t.stage != TripStage.atDestination) {
      return;
    }
    _timer?.cancel();
    state = t.copyWith(stage: TripStage.completed, endedAt: DateTime.now());
  }

  void markCashCollected() => state = state?.copyWith(cashCollected: true);

  /// Finish: rate the rider, record earnings, go back online.
  void finish({required int riderRating}) {
    final t = state;
    if (t == null) return;
    final req = t.request;
    final plan = ref.read(registrationProvider).plan ?? const DriverPlan();
    final commission = plan.commissionOn(t.totalFare);
    final id = 'T${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final mins = t.startedAt == null
        ? req.trip.minutes
        : max(
            req.trip.minutes,
            DateTime.now().difference(t.startedAt!).inMinutes,
          );
    ref
        .read(earningsProvider.notifier)
        .recordTrip(
          TripRecord(
            id: id,
            date: DateTime.now(),
            riderName: req.riderName,
            pickup: req.pickup.name,
            dropoff: req.destination.name,
            rideTypeId: req.rideType.id,
            km: double.parse(req.trip.km.toStringAsFixed(1)),
            minutes: mins,
            fare: t.totalFare,
            commission: commission,
            payment: req.payment,
            waitingFee: t.waitingFee,
            ratingGiven: riderRating,
          ),
        );
    _clear();

    // The rider rates (and sometimes tips) a little later.
    Future.delayed(Duration(seconds: 6 + _rand.nextInt(5)), () {
      final stars = _rand.nextInt(8) == 0 ? 4 : 5;
      ref
          .read(earningsProvider.notifier)
          .rateFromRider(
            id,
            stars,
            stars == 5 ? 'Great driver, thank you!' : null,
          );
      if (_rand.nextInt(3) == 0) {
        ref
            .read(earningsProvider.notifier)
            .addTip(id, [200, 300, 500, 1000][_rand.nextInt(4)]);
      }
    });
  }

  /// Cancel before the trip starts.
  void cancel(String reason) {
    final t = state;
    if (t == null) return;
    final noShow =
        t.stage == TripStage.arrived &&
        t.arrivedAt != null &&
        DateTime.now().difference(t.arrivedAt!) >= noShowAfter &&
        reason == 'Rider didn\'t show up';
    final req = t.request;
    ref
        .read(earningsProvider.notifier)
        .recordTrip(
          TripRecord(
            id: 'T${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
            date: DateTime.now(),
            riderName: req.riderName,
            pickup: req.pickup.name,
            dropoff: req.destination.name,
            rideTypeId: req.rideType.id,
            km: 0,
            minutes: 0,
            fare: noShow ? noShowFee : 0,
            commission: 0,
            payment: noShow ? PaymentKind.wallet : req.payment,
            cancelled: !noShow,
            cancelReason: noShow ? 'Rider no-show (fee paid)' : reason,
          ),
        );
    _clear();
  }

  void _clear() {
    _timer?.cancel();
    _waitTimer?.cancel();
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
    if (auto) return;
    // Simulated rider reply.
    Future.delayed(Duration(seconds: 2 + _rand.nextInt(3)), () {
      const replies = [
        'Okay, thank you',
        'Alright, no problem',
        'I\'ll be there in a minute',
        'Thanks!',
      ];
      _riderSays(replies[_rand.nextInt(replies.length)]);
    });
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
