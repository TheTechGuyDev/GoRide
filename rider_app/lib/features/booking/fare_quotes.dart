import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart' show Backend;

import '../../core/services/routing_service.dart';
import '../location/location_controller.dart';
import 'booking_controller.dart';
import 'ride_types.dart';

/// A price worked out by the server: city rates, rush hour, busy areas,
/// airport fee and long-pickup fee. The app shows exactly what will be
/// charged.
class FareQuote {
  const FareQuote(this.fare, this.surge, this.breakdown, [this.unavailable]);
  final int fare;

  /// Why this ride type can't be booked here right now (e.g. "Available
  /// 5:30am to 10:30pm"), or null when it can.
  final String? unavailable;
  final double surge;
  final Map<String, dynamic> breakdown;

  num _n(String k) => (breakdown[k] as num?) ?? 0;
  String get city => (breakdown['city'] as String?) ?? '';
  num get base => _n('base');
  num get perKm => _n('per_km');
  num get perMinute => _n('per_minute');
  num get minutes => _n('minutes');
  bool get rushHour => breakdown['rush_hour'] == true;
  int get ride => _n('ride').toInt();
  int get airportFee => _n('airport_fee').toInt();
  String? get airport => breakdown['airport'] as String?;
  int get pickupFee => _n('pickup_fee').toInt();
  num get pickupKm => _n('pickup_km');
}

typedef QuoteArgs = ({
  double km,
  int minutes,
  double lat,
  double lng,
  double dropLat,
  double dropLng,
});

final fareQuotesProvider =
    FutureProvider.family<Map<String, FareQuote>, QuoteArgs>((ref, a) async {
      final j = await Backend.db.rpc(
        'quote_all',
        params: {
          'p_km': double.parse(a.km.toStringAsFixed(2)),
          'p_minutes': a.minutes,
          'p_lat': a.lat,
          'p_lng': a.lng,
          'p_drop_lat': a.dropLat,
          'p_drop_lng': a.dropLng,
        },
      );
      return {
        for (final e in (j as Map).entries)
          e.key as String: FareQuote(
            ((e.value as Map)['fare'] as num).toInt(),
            ((e.value as Map)['surge'] as num).toDouble(),
            Map<String, dynamic>.from(e.value['breakdown'] as Map),
            (e.value as Map)['unavailable'] as String?,
          ),
      };
    });

/// Server prices for this route (empty until loaded, or if offline).
Map<String, FareQuote> quotesFor(WidgetRef ref, RouteInfo route) {
  final b = ref.watch(bookingControllerProvider);
  final dest = b.destination;
  if (dest == null) return const {};
  final pickup =
      b.pickup?.position ?? ref.watch(locationControllerProvider).position;
  return ref
          .watch(
            fareQuotesProvider((
              km: route.km,
              minutes: route.minutes,
              lat: pickup.latitude,
              lng: pickup.longitude,
              dropLat: dest.position.latitude,
              dropLng: dest.position.longitude,
            )),
          )
          .value ??
      const {};
}

/// The fare to show: the server's price, or the local estimate while loading.
int fareOf(Map<String, FareQuote> quotes, RideType type, RouteInfo route) =>
    quotes[type.id]?.fare ?? type.fareFor(route).total;
