import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'store.dart';

/// A trip happening right now, shown moving on the live map.
class LiveTrip {
  const LiveTrip({
    required this.id,
    required this.driverName,
    required this.riderName,
    required this.plate,
    required this.rideTypeId,
    required this.from,
    required this.to,
    required this.path,
    required this.progress,
    required this.fare,
    this.offRoute = false,
  });

  final String id;
  final String driverName;
  final String riderName;
  final String plate;
  final String rideTypeId;
  final Place from;
  final Place to;
  final List<LatLng> path;
  final double progress;
  final int fare;
  final bool offRoute;

  PathPosition get at => positionAlong(path, progress);
  int get minutesLeft =>
      max(1, ((1 - progress) * pathLength(path) / 1000 * 3).round());

  LiveTrip copyWith({double? progress}) => LiveTrip(
    id: id,
    driverName: driverName,
    riderName: riderName,
    plate: plate,
    rideTypeId: rideTypeId,
    from: from,
    to: to,
    path: path,
    progress: progress ?? this.progress,
    fare: fare,
    offRoute: offRoute,
  );
}

class LiveState {
  const LiveState({required this.trips, required this.idle});
  final List<LiveTrip> trips;

  /// Online drivers waiting for a request.
  final List<(String name, LatLng pos, String type)> idle;
}

/// Live map from Supabase: online drivers (`driver_locations`) and trips in
/// progress, refreshed every few seconds.
class LiveController extends Notifier<LiveState> {
  Timer? _timer;

  @override
  LiveState build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
    Future.microtask(_load);
    return const LiveState(trips: [], idle: []);
  }

  Future<void> _load() async {
    if (ref.read(sessionProvider) == null) return;
    try {
      final results = await Future.wait(<Future<dynamic>>[
        Backend.db
            .from('driver_locations')
            .select('driver_id, lat, lng, ride_type_id, on_trip, updated_at')
            .eq('online', true),
        Backend.db.from('trips').select(tripColumns).inFilter('status', [
          'accepted',
          'arrived',
          'on_trip',
        ]),
      ]);
      final data = ref.read(storeProvider);
      final locs = {
        for (final r in results[0] as List)
          if (r['lat'] != null)
            r['driver_id'] as String: LatLng(
              (r['lat'] as num).toDouble(),
              (r['lng'] as num).toDouble(),
            ),
      };
      final types = {
        for (final r in results[0] as List)
          r['driver_id'] as String: (r['ride_type_id'] as String?) ?? 'car',
      };
      final busy = <String>{};
      final trips = <LiveTrip>[];
      for (final t in results[1] as List) {
        final driverId = t['driver_id'] as String?;
        if (driverId == null) continue;
        busy.add(driverId);
        final from = Place(
          id: 'from',
          name: t['pickup_address'] as String,
          address: t['pickup_address'] as String,
          position: LatLng(
            (t['pickup_lat'] as num).toDouble(),
            (t['pickup_lng'] as num).toDouble(),
          ),
        );
        final to = Place(
          id: 'to',
          name: t['dropoff_address'] as String,
          address: t['dropoff_address'] as String,
          position: LatLng(
            (t['dropoff_lat'] as num).toDouble(),
            (t['dropoff_lng'] as num).toDouble(),
          ),
        );
        final car = locs[driverId] ?? from.position;
        final target = t['status'] == 'on_trip' ? to.position : from.position;
        final driver = data.driver(driverId);
        final rider = data.rider(t['rider_id'] as String);
        trips.add(
          LiveTrip(
            id: t['code'] as String,
            driverName: driver?.name ?? 'Driver',
            riderName: rider?.name ?? 'Rider',
            plate: driver?.plate ?? '',
            rideTypeId: t['ride_type_id'] as String,
            from: from,
            to: to,
            path: [car, target],
            progress: 0,
            fare: (t['fare'] as num).toInt(),
            offRoute: data.safety.any(
              (e) => e.tripId == t['code'] && e.status != SafetyStatus.resolved,
            ),
          ),
        );
      }
      state = LiveState(
        trips: trips,
        idle: [
          for (final e in locs.entries)
            if (!busy.contains(e.key))
              (
                data.driver(e.key)?.name ?? 'Driver',
                e.value,
                types[e.key] ?? 'car',
              ),
        ],
      );
    } catch (_) {}
  }
}

final liveProvider = NotifierProvider<LiveController, LiveState>(
  LiveController.new,
);
