import 'package:latlong2/latlong.dart';

/// Free map configuration. No API keys needed.
class MapConfig {
  MapConfig._();

  /// OpenStreetMap tiles (free, community-run).
  /// For production traffic, switch to a self-hosted or other free tile
  /// server here; nothing else in the app needs to change.
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'com.goride.goride_rider';
  static const attribution = 'OpenStreetMap contributors';

  /// Fallback when location is off: Victoria Island, Lagos.
  static const defaultCenter = LatLng(6.4281, 3.4219);
  static const defaultZoom = 15.5;
}
