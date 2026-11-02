import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart'
    show Backend, parseTime, userIdProvider;
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
  /// Past trips from Supabase (`my_rides`).
  @override
  List<RideRecord> build() {
    final uid = ref.watch(userIdProvider);
    if (uid == null) return const [];
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    try {
      final rows = await Backend.db.rpc('my_rides');
      state = [
        for (final r in (rows as List))
          _fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (_) {}
  }

  static RideRecord _fromRow(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final code = t['code'] as String;
    final driver = t['driver'] == null
        ? null
        : Driver.fromJson(Map<String, dynamic>.from(t['driver'] as Map));
    return RideRecord(
      id: id,
      bookingId: code,
      transactionId: 'TRX${code.substring(2)}',
      status: t['status'] == 'completed'
          ? RideStatus.completed
          : RideStatus.canceled,
      rideTypeId: t['ride_type_id'] as String,
      pickupName: t['pickup_address'] as String,
      destination: Place(
        id: 'dest-$id',
        name: t['dropoff_address'] as String,
        address: t['dropoff_address'] as String,
        position: LatLng(
          (t['dropoff_lat'] as num).toDouble(),
          (t['dropoff_lng'] as num).toDouble(),
        ),
      ),
      paymentId: t['payment'] == 'cash' ? 'cash' : 'wallet',
      fare:
          (t['fare'] as num).toInt() +
          ((t['waiting_fee'] as num?)?.toInt() ?? 0),
      discount: (t['discount'] as num).toInt(),
      createdAt: parseTime(t['requested_at']) ?? DateTime.now(),
      km: (t['distance_km'] as num).toDouble(),
      minutes: (t['duration_min'] as num).round(),
      driver: driver,
      tip: (t['my_tip'] as num?)?.toInt() ?? 0,
      rating: (t['my_rating'] as num?)?.toInt(),
      feedback: [
        for (final f in (t['my_tags'] as List?) ?? const []) f as String,
      ],
      cancelReason: t['cancel_reason'] as String?,
    );
  }

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
