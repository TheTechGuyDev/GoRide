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

/// Simulated live trips. Later: Supabase Realtime on `trip_locations` and
/// `driver_locations`.
class LiveController extends Notifier<LiveState> {
  final _r = Random(7);
  Timer? _timer;
  int _seq = 0;

  @override
  LiveState build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    final data = ref.read(storeProvider);
    final online = data.drivers.where((d) => d.online).toList();
    final trips = <LiveTrip>[];
    for (var i = 0; i < min(9, online.length); i++) {
      trips.add(
        _newTrip(online[i], progress: _r.nextDouble() * 0.8, offRoute: i == 0),
      );
    }
    final idle = [
      for (final d in online.skip(9))
        (
          d.name,
          offsetPoint(
            lagosPlaces[_r.nextInt(lagosPlaces.length)].position,
            200 + _r.nextDouble() * 1500,
            _r.nextDouble() * 360,
          ),
          d.rideTypeId,
        ),
    ];
    return LiveState(trips: trips, idle: idle);
  }

  LiveTrip _newTrip(Driver d, {double progress = 0, bool offRoute = false}) {
    final from = lagosPlaces[_r.nextInt(lagosPlaces.length)];
    var to = lagosPlaces[_r.nextInt(lagosPlaces.length)];
    if (to == from)
      to = lagosPlaces[(lagosPlaces.indexOf(from) + 5) % lagosPlaces.length];
    // A gently curved path between the two places.
    final mid = LatLng(
      (from.position.latitude + to.position.latitude) / 2 +
          (_r.nextDouble() - 0.5) * 0.02,
      (from.position.longitude + to.position.longitude) / 2 +
          (_r.nextDouble() - 0.5) * 0.02,
    );
    final path = <LatLng>[];
    for (var i = 0; i <= 24; i++) {
      final t = i / 24;
      final a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t;
      path.add(
        LatLng(
          a * from.position.latitude +
              b * mid.latitude +
              c * to.position.latitude,
          a * from.position.longitude +
              b * mid.longitude +
              c * to.position.longitude,
        ),
      );
    }
    final km = pathLength(path) / 1000;
    return LiveTrip(
      id: 'TRP-L${++_seq}',
      driverName: d.name,
      riderName: [
        'Adaeze O.',
        'Bola A.',
        'Chinedu E.',
        'Kemi A.',
        'Segun W.',
        'Zainab B.',
        'Tolu B.',
        'Grace N.',
      ][_r.nextInt(8)],
      plate: d.plate,
      rideTypeId: d.rideTypeId,
      from: from,
      to: to,
      path: path,
      progress: progress,
      fare: roundFare(700 + km * 260),
      offRoute: offRoute,
    );
  }

  void _tick() {
    final data = ref.read(storeProvider);
    final online = data.drivers.where((d) => d.online).toList();
    state = LiveState(
      idle: state.idle,
      trips: [
        for (final t in state.trips)
          t.progress >= 1
              ? _newTrip(online[_r.nextInt(online.length)])
              : t.copyWith(
                  progress: min(
                    1.0,
                    t.progress + 0.004 + _r.nextDouble() * 0.004,
                  ),
                ),
      ],
    );
  }
}

final liveProvider = NotifierProvider<LiveController, LiveState>(
  LiveController.new,
);
