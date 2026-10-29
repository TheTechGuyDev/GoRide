import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../features/booking/place.dart';
import '../config/map_config.dart';

/// Free geocoding via OpenStreetMap Nominatim (no API key).
/// Usage policy: max 1 request/second, so search is debounced in the UI.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://nominatim.openstreetmap.org';

  Map<String, String> get _headers => {
    // Browsers don't allow setting User-Agent; native apps must send one.
    if (!kIsWeb) 'User-Agent': '${MapConfig.userAgent} (GoRide app)',
    'Accept-Language': 'en',
  };

  /// Search places in Nigeria, biased towards [near].
  Future<List<Place>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final params = {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'ng',
      'limit': '10',
      if (near != null)
        // ~50km box around the rider, not strict, just preferred.
        'viewbox':
            '${near.longitude - 0.45},${near.latitude + 0.45},${near.longitude + 0.45},${near.latitude - 0.45}',
    };

    final uri = Uri.parse('$_base/search').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => _fromNominatim(e as Map<String, dynamic>))
        .whereType<Place>()
        .toList();
  }

  /// Address for a map point (used when dragging the pickup pin).
  Future<Place?> reverse(LatLng point) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
      },
    );
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    final place = _fromNominatim(jsonDecode(res.body) as Map<String, dynamic>);
    // Keep the exact pin position rather than the snapped address point.
    return place?.copyWith(position: point);
  }

  Place? _fromNominatim(Map<String, dynamic> j) {
    final lat = double.tryParse('${j['lat']}');
    final lon = double.tryParse('${j['lon']}');
    final display = (j['display_name'] as String?) ?? '';
    if (lat == null || lon == null || display.isEmpty) return null;

    final addr = (j['address'] as Map<String, dynamic>?) ?? {};
    final parts = display.split(', ');

    var name = (j['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      final road = addr['road'] as String?;
      final house = addr['house_number'] as String?;
      name = road != null
          ? (house != null ? '$house $road' : road)
          : parts.first;
    }

    // Short address: drop the name itself, the country and postcode.
    final rest = parts
        .where(
          (p) =>
              p != 'Nigeria' &&
              !name.contains(p) &&
              !RegExp(r'^[\d\s-]+$').hasMatch(p),
        )
        .take(3)
        .join(', ');

    return Place(
      id: '${j['osm_type'] ?? ''}${j['osm_id'] ?? '$lat,$lon'}',
      name: name,
      address: rest.isEmpty ? display : rest,
      position: LatLng(lat, lon),
    );
  }
}
