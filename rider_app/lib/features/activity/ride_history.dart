import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../booking/place.dart';
import '../booking/ride_types.dart';
import '../trip/trip_models.dart';

enum RideStatus { completed, canceled }

/// A finished or cancelled ride, as shown in the Activity tab.
/// Later: a row in the Supabase `rides` table.
class RideRecord {
  const RideRecord({
    required this.id,
    required this.bookingId,
    required this.transactionId,
    required this.status,
    required this.rideTypeId,
    required this.pickupName,
    required this.destination,
    required this.paymentId,
    required this.fare,
    required this.discount,
    required this.createdAt,
    required this.km,
    required this.minutes,
    this.driver,
    this.tip = 0,
    this.rating,
    this.feedback = const [],
    this.cancelReason,
  });

  final String id;
  final String bookingId;
  final String transactionId;
  final RideStatus status;
  final String rideTypeId;
  final String pickupName;
  final Place destination;
  final String paymentId;
  final int fare;
  final int discount;
  final DateTime createdAt;
  final double km;
  final int minutes;
  final Driver? driver;
  final int tip;
  final int? rating;
  final List<String> feedback;
  final String? cancelReason;

  RideType get rideType => rideTypes.firstWhere(
    (r) => r.id == rideTypeId,
    orElse: () => rideTypes[2],
  );

  /// What the rider paid in total (0 if cancelled).
  int get totalPaid =>
      status == RideStatus.canceled ? 0 : fare - discount + tip;

  RideRecord copyWith({int? tip, int? rating, List<String>? feedback}) {
    return RideRecord(
      id: id,
      bookingId: bookingId,
      transactionId: transactionId,
      status: status,
      rideTypeId: rideTypeId,
      pickupName: pickupName,
      destination: destination,
      paymentId: paymentId,
      fare: fare,
      discount: discount,
      createdAt: createdAt,
      km: km,
      minutes: minutes,
      driver: driver,
      tip: tip ?? this.tip,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      cancelReason: cancelReason,
    );
  }

  factory RideRecord.fromTrip(TripState t) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return RideRecord(
      id: t.id,
      bookingId: 'BKG${stamp % 1000000000}',
      transactionId: 'TRX${(stamp ~/ 7) % 1000000000}',
      status: t.phase == TripPhase.cancelled
          ? RideStatus.canceled
          : RideStatus.completed,
      rideTypeId: t.rideType.id,
      pickupName: t.pickupName,
      destination: t.destination,
      paymentId: t.paymentId,
      fare: t.fare,
      discount: t.discount,
      createdAt: t.startedAt ?? DateTime.now(),
      km: t.tripRoute.km,
      minutes: t.tripRoute.minutes,
      driver: t.driver,
      cancelReason: t.cancelReason,
    );
  }
}

class RideHistoryController extends Notifier<List<RideRecord>> {
  @override
  List<RideRecord> build() => _seed();

  void add(RideRecord r) {
    if (state.any((e) => e.id == r.id)) return;
    state = [r, ...state];
  }

  void update(String id, RideRecord Function(RideRecord) change) {
    state = [for (final r in state) r.id == id ? change(r) : r];
  }

  RideRecord? byId(String id) => state.where((r) => r.id == id).firstOrNull;
}

final rideHistoryProvider =
    NotifierProvider<RideHistoryController, List<RideRecord>>(
      RideHistoryController.new,
    );

/// Sample Lagos trips so the Activity tab isn't empty in the preview.
List<RideRecord> _seed() {
  final now = DateTime.now();
  Driver d(
    String name,
    String car,
    String color,
    String plate,
    double rating,
  ) => Driver(
    id: 'seed-$plate',
    name: name,
    maskedPhone: '+234 *** *** ${plate.hashCode.abs() % 9000 + 1000}',
    rating: rating,
    trips: 3200,
    years: 3,
    memberSince: DateTime(now.year - 3, 4),
    carModel: car,
    carColor: color,
    plate: plate,
  );

  RideRecord r(
    int n,
    RideStatus status,
    String type,
    String name,
    String address,
    LatLng pos,
    int daysAgo,
    int hour,
    int fare,
    String payment, {
    int discount = 0,
    int tip = 0,
    int? rating,
    String? cancel,
    Driver? driver,
    double km = 8,
    int minutes = 25,
  }) {
    final when = DateTime(
      now.year,
      now.month,
      now.day - daysAgo,
      hour,
      10 + n * 4,
    );
    return RideRecord(
      id: 'GRSEED$n',
      bookingId: 'BKG92608$n',
      transactionId: 'TRX12212409$n',
      status: status,
      rideTypeId: type,
      pickupName: 'Home',
      destination: Place(
        id: 'seed-dest-$n',
        name: name,
        address: address,
        position: pos,
      ),
      paymentId: payment,
      fare: fare,
      discount: discount,
      createdAt: when,
      km: km,
      minutes: minutes,
      driver: driver,
      tip: tip,
      rating: rating,
      cancelReason: cancel,
    );
  }

  return [
    r(
      1,
      RideStatus.completed,
      'car',
      'Ikeja City Mall',
      'Obafemi Awolowo Way, Ikeja',
      const LatLng(6.6142, 3.3576),
      1,
      9,
      4350,
      'wallet',
      discount: 850,
      tip: 500,
      rating: 5,
      driver: d('Chinedu Okafor', 'Toyota Corolla', 'Silver', 'KJA-482GH', 4.8),
      km: 11.2,
      minutes: 38,
    ),
    r(
      2,
      RideStatus.completed,
      'bike',
      'Yaba Tech',
      'Herbert Macaulay Way, Yaba',
      const LatLng(6.5175, 3.3725),
      2,
      17,
      1450,
      'cash',
      rating: 4,
      driver: d('Ibrahim Musa', 'Bajaj Boxer', 'Red', 'LSR-219AK', 4.7),
      km: 5.1,
      minutes: 16,
    ),
    r(
      3,
      RideStatus.canceled,
      'car',
      'Eko Hotel & Suites',
      'Adetokunbo Ademola St, VI',
      const LatLng(6.4262, 3.4290),
      3,
      8,
      5200,
      'card-4679',
      cancel: 'Waiting for long time',
    ),
    r(
      4,
      RideStatus.completed,
      'comfort',
      'Murtala Muhammed Airport',
      'Airport Rd, Ikeja',
      const LatLng(6.5774, 3.3212),
      5,
      6,
      9800,
      'card-4679',
      tip: 1000,
      rating: 5,
      driver: d('Tunde Bakare', 'Honda Accord', 'Black', 'LND-731CS', 4.9),
      km: 22.4,
      minutes: 55,
    ),
    r(
      5,
      RideStatus.completed,
      'keke',
      'Balogun Market',
      'Lagos Island',
      const LatLng(6.4549, 3.3896),
      7,
      13,
      1800,
      'cash',
      rating: 4,
      driver: d('Emeka Nwosu', 'TVS King', 'Yellow', 'EKY-118TK', 4.6),
      km: 6.3,
      minutes: 24,
    ),
    r(
      6,
      RideStatus.canceled,
      'xl',
      'Landmark Beach',
      'Oniru, Victoria Island',
      const LatLng(6.4227, 3.4472),
      9,
      15,
      7400,
      'wallet',
      cancel: 'Change in plans',
    ),
    r(
      7,
      RideStatus.completed,
      'car',
      'University of Lagos',
      'Akoka, Yaba',
      const LatLng(6.5158, 3.3896),
      12,
      10,
      3900,
      'transfer',
      rating: 5,
      driver: d('Segun Adeyemi', 'Toyota Camry', 'Grey', 'AAA-905DQ', 4.8),
      km: 9.6,
      minutes: 31,
    ),
  ];
}
