import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart' show Backend, userIdProvider;
import 'package:latlong2/latlong.dart';

import '../location/location_controller.dart';
import 'widgets/map_markers.dart';

export 'widgets/map_markers.dart' show VehicleType;

class NearbyVehicle {
  const NearbyVehicle({
    required this.id,
    required this.position,
    required this.heading,
    required this.type,
  });

  final String id;
  final LatLng position;

  /// Degrees, 0 = north.
  final double heading;
  final VehicleType type;

  NearbyVehicle moved(double metres) {
    final rad = heading * pi / 180;
    const metresPerDegree = 111320.0;
    final dLat = metres * cos(rad) / metresPerDegree;
    final dLng =
        metres *
        sin(rad) /
        (metresPerDegree * cos(position.latitude * pi / 180));
    return NearbyVehicle(
      id: id,
      position: LatLng(position.latitude + dLat, position.longitude + dLng),
      heading: heading,
      type: type,
    );
  }
}

/// Real online drivers near the rider (`driver_locations`), refreshed
/// every few seconds. Only free drivers within 5 km are shown.
class NearbyVehiclesController extends Notifier<List<NearbyVehicle>> {
  Timer? _timer;
  LatLng? _center;

  static const _radiusMetres = 5000.0;

  @override
  List<NearbyVehicle> build() {
    final loc = ref.watch(locationControllerProvider);
    final uid = ref.watch(userIdProvider);
    ref.onDispose(() => _timer?.cancel());
    if (loc.status != LocationStatus.ready || uid == null) return const [];

    _center = loc.position;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final c = _center;
    if (c == null) return;
    // Rough box first (cheap), then exact distance.
    const dLat = 0.05;
    final dLng = 0.05 / cos(c.latitude * pi / 180);
    try {
      final rows = await Backend.db
          .from('driver_locations')
          .select('driver_id, lat, lng, heading, ride_type_id, on_trip')
          .eq('online', true)
          .eq('on_trip', false)
          .gte('lat', c.latitude - dLat)
          .lte('lat', c.latitude + dLat)
          .gte('lng', c.longitude - dLng)
          .lte('lng', c.longitude + dLng)
          .limit(30);
      const distance = Distance();
      state = [
        for (final r in rows)
          if (r['lat'] != null && r['lng'] != null)
            if (distance(
                  c,
                  LatLng(
                    (r['lat'] as num).toDouble(),
                    (r['lng'] as num).toDouble(),
                  ),
                ) <=
                _radiusMetres)
              NearbyVehicle(
                id: r['driver_id'] as String,
                position: LatLng(
                  (r['lat'] as num).toDouble(),
                  (r['lng'] as num).toDouble(),
                ),
                heading: (r['heading'] as num?)?.toDouble() ?? 0,
                type: switch (r['ride_type_id']) {
                  'bike' => VehicleType.bike,
                  'keke' => VehicleType.keke,
                  _ => VehicleType.car,
                },
              ),
      ];
    } catch (_) {}
  }
}

final nearbyVehiclesProvider =
    NotifierProvider<NearbyVehiclesController, List<NearbyVehicle>>(
      NearbyVehiclesController.new,
    );
