import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../location/location_controller.dart';

enum VehicleType { car, bike, keke }

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

/// Mock nearby drivers that drift slowly around the rider.
/// Later this becomes a Supabase Realtime subscription on `driver_locations`.
class NearbyVehiclesController extends Notifier<List<NearbyVehicle>> {
  final _rand = Random(7);
  Timer? _timer;
  LatLng? _center;

  @override
  List<NearbyVehicle> build() {
    final loc = ref.watch(locationControllerProvider);
    ref.onDispose(() => _timer?.cancel());

    if (loc.status != LocationStatus.ready) return const [];

    _center = loc.position;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    return _spawn(loc.position);
  }

  List<NearbyVehicle> _spawn(LatLng c) {
    return List.generate(9, (i) {
      // Spread evenly around the rider, 200m to 800m away.
      final distance = 200 + _rand.nextDouble() * 600;
      final bearing = i * 40 + _rand.nextDouble() * 25;
      final base = NearbyVehicle(
        id: 'v$i',
        position: c,
        heading: bearing,
        type: i % 4 == 3 ? VehicleType.bike : VehicleType.car,
      ).moved(distance);
      return NearbyVehicle(
        id: base.id,
        position: base.position,
        heading: _rand.nextDouble() * 360,
        type: base.type,
      );
    });
  }

  void _tick() {
    final c = _center;
    if (c == null) return;
    const distance = Distance();
    state = state.map((v) {
      var next = v.moved(10 + _rand.nextDouble() * 10);
      // Turn around if drifting too far from the rider.
      if (distance(c, next.position) > 900) {
        next = NearbyVehicle(
          id: v.id,
          position: v.position,
          heading: (v.heading + 180) % 360,
          type: v.type,
        );
      } else if (_rand.nextDouble() < 0.1) {
        next = NearbyVehicle(
          id: next.id,
          position: next.position,
          heading: (next.heading + (_rand.nextBool() ? 90 : -90)) % 360,
          type: next.type,
        );
      }
      return next;
    }).toList();
  }
}

final nearbyVehiclesProvider =
    NotifierProvider<NearbyVehiclesController, List<NearbyVehicle>>(
      NearbyVehiclesController.new,
    );
