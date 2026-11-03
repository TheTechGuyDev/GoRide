
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Rides can be booked from 30 minutes to 7 days ahead.
  static const minLead = Duration(minutes: 30);
  static const maxLead = Duration(days: 7);

  /// Free cancellation until this long before pickup.
  static const freeCancelBefore = Duration(hours: 1);

  @override
  List<ScheduledRide> build() => const [];

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

    return ride;
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
}

final scheduledRidesProvider =
    NotifierProvider<ScheduledRidesController, List<ScheduledRide>>(
      ScheduledRidesController.new,
    );
