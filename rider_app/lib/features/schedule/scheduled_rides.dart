import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/routing_service.dart';
import '../activity/ride_history.dart';
import '../booking/booking_controller.dart';
import '../booking/place.dart';
import '../booking/promos.dart';
import '../booking/ride_types.dart';
import '../trip/trip_models.dart';

/// A ride booked for later. The fare is locked when it's booked.
/// Later: `rides` row with status = 'scheduled'; a Supabase cron job
/// starts driver matching ~20 minutes before [pickupAt].
class ScheduledRide {
  const ScheduledRide({
    required this.id,
    required this.bookingId,
    required this.transactionId,
    required this.pickupAt,
    required this.bookedAt,
    required this.pickup,
    required this.destination,
    required this.pickupNote,
    required this.rideTypeId,
    required this.paymentId,
    required this.fare,
    required this.discount,
    required this.route,
    this.promo,
    this.driver,
  });

  final String id;
  final String bookingId;
  final String transactionId;
  final DateTime pickupAt;
  final DateTime bookedAt;
  final Place pickup;
  final Place destination;
  final String pickupNote;
  final String rideTypeId;
  final String paymentId;
  final int fare;
  final int discount;
  final RouteInfo route;
  final Promo? promo;

  /// Assigned ahead of time once a driver accepts.
  final Driver? driver;

  RideType get rideType => rideTypes.firstWhere(
    (r) => r.id == rideTypeId,
    orElse: () => rideTypes[2],
  );
  int get total => fare - discount;

  ScheduledRide withDriver(Driver d) => ScheduledRide(
    id: id,
    bookingId: bookingId,
    transactionId: transactionId,
    pickupAt: pickupAt,
    bookedAt: bookedAt,
    pickup: pickup,
    destination: destination,
    pickupNote: pickupNote,
    rideTypeId: rideTypeId,
    paymentId: paymentId,
    fare: fare,
    discount: discount,
    route: route,
    promo: promo,
    driver: d,
  );
}

class ScheduledRidesController extends Notifier<List<ScheduledRide>> {
  final _rand = Random();

  /// Rides can be booked from 30 minutes to 7 days ahead.
  static const minLead = Duration(minutes: 30);
  static const maxLead = Duration(days: 7);

  /// Free cancellation until this long before pickup.
  static const freeCancelBefore = Duration(hours: 1);

  @override
  List<ScheduledRide> build() => _seed();

  /// Books the current draft for [BookingState.scheduledAt].
  ScheduledRide schedule(RouteInfo route) {
    final b = ref.read(bookingControllerProvider);
    final pickup =
        b.pickup ??
        Place(
          id: 'current',
          name: 'Your location',
          address: '',
          position: route.points.first,
        );
    final fare = b.rideType.fareFor(route).total;
    final discount = b.promo?.discountFor(b.rideTypeId, fare) ?? 0;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ride = ScheduledRide(
      id: 'SCH$stamp',
      bookingId: 'BKG${stamp % 1000000000}',
      transactionId: 'TRX${(stamp ~/ 3) % 1000000000}',
      pickupAt: b.scheduledAt!,
      bookedAt: DateTime.now(),
      pickup: pickup,
      destination: b.destination!,
      pickupNote: b.pickupNote,
      rideTypeId: b.rideTypeId,
      paymentId: b.paymentId,
      fare: fare,
      discount: discount,
      route: route,
      promo: b.promo,
    );
    state = [...state, ride]..sort((a, c) => a.pickupAt.compareTo(c.pickupAt));

    // Preview: a driver accepts the booking shortly after.
    Timer(const Duration(seconds: 20), () => _assignDriver(ride.id));
    return ride;
  }

  void _assignDriver(String id) {
    final r = state.where((e) => e.id == id).firstOrNull;
    if (r == null || r.driver != null) return;
    const names = [
      'Kunle Ajayi',
      'Musa Abdullahi',
      'Obinna Eze',
      'Femi Ogunleye',
    ];
    const cars = [
      ('Toyota Corolla', 'White'),
      ('Toyota Camry', 'Black'),
      ('Honda Civic', 'Blue'),
    ];
    final car = cars[_rand.nextInt(cars.length)];
    final d = Driver(
      id: 'drv-sch-$id',
      name: names[_rand.nextInt(names.length)],
      maskedPhone: '+234 *** *** ${1000 + _rand.nextInt(9000)}',
      rating: 4.6 + _rand.nextInt(4) / 10,
      trips: 1500 + _rand.nextInt(6000),
      years: 2 + _rand.nextInt(4),
      memberSince: DateTime(DateTime.now().year - 3, 6),
      carModel: car.$1,
      carColor: car.$2,
      plate: 'KJA-${100 + _rand.nextInt(900)}XY',
    );
    state = [for (final e in state) e.id == id ? e.withDriver(d) : e];
  }

  /// Cancels and records it under Activity > Canceled.
  void cancel(String id, String reason) {
    final r = state.where((e) => e.id == id).firstOrNull;
    if (r == null) return;
    state = state.where((e) => e.id != id).toList();
    ref
        .read(rideHistoryProvider.notifier)
        .add(
          RideRecord(
            id: r.id,
            bookingId: r.bookingId,
            transactionId: r.transactionId,
            status: RideStatus.canceled,
            rideTypeId: r.rideTypeId,
            pickupName: r.pickup.name,
            destination: r.destination,
            paymentId: r.paymentId,
            fare: r.fare,
            discount: r.discount,
            createdAt: r.pickupAt,
            km: r.route.km,
            minutes: r.route.minutes,
            driver: r.driver,
            cancelReason: reason,
          ),
        );
  }

  /// Removes it from the list when the trip starts.
  void remove(String id) => state = state.where((e) => e.id != id).toList();

  /// Puts the ride back into the booking draft so the trip can start.
  void loadIntoBooking(ScheduledRide r) {
    ref
        .read(bookingControllerProvider.notifier)
        .load(
          BookingState(
            pickup: r.pickup,
            destination: r.destination,
            pickupNote: r.pickupNote,
            rideTypeId: r.rideTypeId,
            paymentId: r.paymentId,
            promo: r.promo,
          ),
        );
  }

  List<ScheduledRide> _seed() {
    final now = DateTime.now();
    final tomorrow9 = DateTime(now.year, now.month, now.day + 1, 9, 0);
    final in3days = DateTime(now.year, now.month, now.day + 3, 6, 30);
    const home = Place(
      id: 'saved-home',
      name: 'Home',
      address: '12 Admiralty Way, Lekki Phase 1',
      position: LatLng(6.4474, 3.4720),
    );
    RouteInfo est(LatLng a, LatLng b) => RoutingService.estimate(a, b);

    final office = ScheduledRide(
      id: 'SCHSEED1',
      bookingId: 'BKG720469',
      transactionId: 'TRX1222240941',
      pickupAt: tomorrow9,
      bookedAt: now.subtract(const Duration(hours: 5)),
      pickup: home,
      destination: const Place(
        id: 'saved-office',
        name: 'Office',
        address: '1 Adeola Odeku St, Victoria Island',
        position: LatLng(6.4310, 3.4215),
      ),
      pickupNote: 'Estate gate 2',
      rideTypeId: 'car',
      paymentId: 'wallet',
      fare: 3600,
      discount: 0,
      route: est(home.position, const LatLng(6.4310, 3.4215)),
      driver: Driver(
        id: 'drv-seed-sch',
        name: 'Michael Okon',
        maskedPhone: '+234 *** *** 4412',
        rating: 4.7,
        trips: 4210,
        years: 4,
        memberSince: DateTime(now.year - 4, 2),
        carModel: 'Toyota Camry',
        carColor: 'Black',
        plate: 'LND-901FK',
      ),
    );
    final airport = ScheduledRide(
      id: 'SCHSEED2',
      bookingId: 'BKG720512',
      transactionId: 'TRX1222241077',
      pickupAt: in3days,
      bookedAt: now.subtract(const Duration(hours: 2)),
      pickup: home,
      destination: const Place(
        id: 'seed-mma',
        name: 'Murtala Muhammed Airport',
        address: 'Airport Rd, Ikeja',
        position: LatLng(6.5774, 3.3212),
      ),
      pickupNote: '',
      rideTypeId: 'comfort',
      paymentId: 'card-4679',
      fare: 12400,
      discount: 1000,
      route: est(home.position, const LatLng(6.5774, 3.3212)),
    );
    return [office, airport];
  }
}

final scheduledRidesProvider =
    NotifierProvider<ScheduledRidesController, List<ScheduledRide>>(
      ScheduledRidesController.new,
    );
