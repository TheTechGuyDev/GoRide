import 'dart:math';

import 'package:latlong2/latlong.dart';

const _distance = Distance();

/// A point along a polyline plus the direction of travel there.
class PathPosition {
  const PathPosition(this.point, this.heading);
  final LatLng point;

  /// Degrees, 0 = north.
  final double heading;
}

double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * pi / 180, lat2 = b.latitude * pi / 180;
  final dLng = (b.longitude - a.longitude) * pi / 180;
  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

double pathLength(List<LatLng> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += _distance(pts[i - 1], pts[i]);
  }
  return total;
}

/// Position at [progress] (0..1) of the way along [pts], by distance.
PathPosition positionAlong(List<LatLng> pts, double progress) {
  if (pts.length < 2) return PathPosition(pts.first, 0);
  final target = pathLength(pts) * progress.clamp(0.0, 1.0);
  var walked = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final seg = _distance(pts[i - 1], pts[i]);
    if (walked + seg >= target || i == pts.length - 1) {
      final t = seg == 0 ? 0.0 : ((target - walked) / seg).clamp(0.0, 1.0);
      final a = pts[i - 1], b = pts[i];
      return PathPosition(
        LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ),
        bearingBetween(a, b),
      );
    }
    walked += seg;
  }
  return PathPosition(pts.last, 0);
}

/// The part of [pts] still ahead after [progress].
List<LatLng> remainingPath(List<LatLng> pts, double progress) {
  if (pts.length < 2) return pts;
  final total = pathLength(pts);
  final target = total * progress.clamp(0.0, 1.0);
  var walked = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final seg = _distance(pts[i - 1], pts[i]);
    if (walked + seg >= target) {
      return [positionAlong(pts, progress).point, ...pts.sublist(i)];
    }
    walked += seg;
  }
  return [pts.last];
}

/// Move [from] by [metres] towards [bearingDeg].
LatLng offsetPoint(LatLng from, double metres, double bearingDeg) {
  return _distance.offset(from, metres, bearingDeg);
}
