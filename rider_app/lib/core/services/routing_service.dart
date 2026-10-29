import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteInfo {
  const RouteInfo({
    required this.points,
    required this.distanceMetres,
    required this.durationSeconds,
    this.isEstimate = false,
  });

  final List<LatLng> points;
  final double distanceMetres;

  /// Includes the Lagos traffic factor.
  final double durationSeconds;

  /// True when OSRM was unreachable and we fell back to a straight line.
  final bool isEstimate;

  double get km => distanceMetres / 1000;
  int get minutes => (durationSeconds / 60).ceil();
}

/// Free driving routes from the public OSRM server (no API key).
/// For production, self-host OSRM (free, open source) and change [_base].
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://router.project-osrm.org';

  /// OSRM assumes free-flowing roads; Lagos traffic is much slower.
  static const trafficFactor = 1.7;

  Future<RouteInfo> route(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        '$_base/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = j['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords =
              (r['geometry'] as Map<String, dynamic>)['coordinates'] as List;
          return RouteInfo(
            points: coords
                .map(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList(),
            distanceMetres: (r['distance'] as num).toDouble(),
            durationSeconds: (r['duration'] as num).toDouble() * trafficFactor,
          );
        }
      }
    } catch (_) {
      // Fall through to the estimate below.
    }
    return estimate(from, to);
  }

  /// Straight line x 1.35 for road bends, at ~18 km/h Lagos average.
  static RouteInfo estimate(LatLng from, LatLng to) {
    final straight = const Distance()(from, to);
    final metres = straight * 1.35;
    return RouteInfo(
      points: [from, to],
      distanceMetres: metres,
      durationSeconds: metres / (18000 / 3600),
      isEstimate: true,
    );
  }
}
