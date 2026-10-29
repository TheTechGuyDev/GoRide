import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/routing_service.dart';
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
    _runLeg(s.tripRoute.points, _tripTime, onDone: _complete);
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
  }

  void cancel(String reason) {
    _stopTimers();
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: TripPhase.cancelled, cancelReason: reason);
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
