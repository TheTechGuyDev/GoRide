import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../backend/backend.dart';
import '../models/place.dart';
import '../config/map_config.dart';

/// Address search and reverse geocoding.
///
/// Provider order, best first:
///   1. Geoapify when `geoapify_key` is set in admin > Integrations. Free,
///      no card, 3,000 requests/day, with much better address search and
///      autocomplete for Nigeria than raw OpenStreetMap.
///   2. Mapbox when `mapbox_token` is set.
///   3. Free OpenStreetMap Nominatim (no key) as the always-on fallback, so
///      search keeps working out of the box and never goes dark on an error.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Nominatim usage policy: max 1 request/second (search is debounced in the UI).
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _mapboxBase = 'https://api.mapbox.com/search/geocode/v6';
  static const _geoapifyBase = 'https://api.geoapify.com/v1/geocode';

  /// The Geoapify API key from Integrations, or null to try the next provider.
  String? get _geoapifyKey {
    final k = Backend.config['geoapify_key']?.trim();
    return (k == null || k.isEmpty) ? null : k;
  }

  /// The Mapbox public token from Integrations, or null to use OpenStreetMap.
  String? get _mapboxToken {
    final t = Backend.config['mapbox_token']?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, String> get _nominatimHeaders => {
    // Browsers don't allow setting User-Agent; native apps must send one.
    if (!kIsWeb) 'User-Agent': '${MapConfig.userAgent} (GoRide app)',
    'Accept-Language': 'en',
  };

  /// Search places in Nigeria, biased towards [near].
  Future<List<Place>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final key = _geoapifyKey;
    if (key != null) return _geoapifySearch(q, key, near: near);
    final token = _mapboxToken;
    return token != null
        ? _mapboxSearch(q, token, near: near)
        : _nominatimSearch(q, near: near);
  }

  /// Address for a map point (used when dragging the pickup pin).
  Future<Place?> reverse(LatLng point) async {
    final key = _geoapifyKey;
    if (key != null) return _geoapifyReverse(point, key);
    final token = _mapboxToken;
    return token != null
        ? _mapboxReverse(point, token)
        : _nominatimReverse(point);
  }

  // ---------------- Geoapify (preferred, free, no card) ----------------

  Future<List<Place>> _geoapifySearch(
    String q,
    String key, {
    LatLng? near,
  }) async {
    // Autocomplete ranks partial, as-you-type queries better than plain search.
    final uri = Uri.parse('$_geoapifyBase/autocomplete').replace(
      queryParameters: {
        'text': q,
        'filter': 'countrycode:ng',
        'limit': '10',
        'lang': 'en',
        'format': 'json',
        if (near != null) 'bias': 'proximity:${near.longitude},${near.latitude}',
        'apiKey': key,
      },
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      // On any Geoapify error, fall back so search never goes dark.
      return _nominatimSearch(q, near: near);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>? ?? []);
    return results
        .map((r) => _fromGeoapify(r as Map<String, dynamic>))
        .whereType<Place>()
        .toList();
  }

  Future<Place?> _geoapifyReverse(LatLng point, String key) async {
    final uri = Uri.parse('$_geoapifyBase/reverse').replace(
      queryParameters: {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'lang': 'en',
        'limit': '1',
        'format': 'json',
        'apiKey': key,
      },
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) return _nominatimReverse(point);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List<dynamic>? ?? []);
    if (results.isEmpty) return null;
    final place = _fromGeoapify(results.first as Map<String, dynamic>);
    // Keep the exact pin position rather than the snapped address point.
    return place?.copyWith(position: point);
  }

  Place? _fromGeoapify(Map<String, dynamic> r) {
    final lat = (r['lat'] as num?)?.toDouble();
    final lon = (r['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    final house = (r['housenumber'] as String?)?.trim();
    final street = (r['street'] as String?)?.trim();
    final line1 = (r['address_line1'] as String?)?.trim() ?? '';
    final line2 = (r['address_line2'] as String?)?.trim() ?? '';
    final formatted = (r['formatted'] as String?)?.trim() ?? '';

    // Prefer a clean "27 Ajileye Street" when the parts are present.
    var name = (r['name'] as String?)?.trim() ?? '';
    if (name.isEmpty && street != null && street.isNotEmpty) {
      name = (house != null && house.isNotEmpty) ? '$house $street' : street;
    }
    if (name.isEmpty) name = line1.isEmpty ? formatted : line1;

    var address = line2.isNotEmpty ? line2 : formatted;
    if (address.startsWith('$name, ')) {
      address = address.substring(name.length + 2);
    }
    address = address.replaceAll(RegExp(r',?\s*Nigeria$'), '').trim();

    return Place(
      id: (r['place_id'] as String?) ?? '$lat,$lon',
      name: name.isEmpty ? (formatted.isEmpty ? 'Dropped pin' : formatted) : name,
      address: address.isEmpty ? formatted : address,
      position: LatLng(lat, lon),
    );
  }

  // ---------------- Mapbox (preferred) ----------------

  Future<List<Place>> _mapboxSearch(
    String q,
    String token, {
    LatLng? near,
  }) async {
    final uri = Uri.parse('$_mapboxBase/forward').replace(
      queryParameters: {
        'q': q,
        'access_token': token,
        'country': 'ng',
        'language': 'en',
        'limit': '10',
        'types': 'address,street,place,locality,neighborhood,postcode,poi',
        if (near != null) 'proximity': '${near.longitude},${near.latitude}',
      },
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      // On any Mapbox error, fall back so search never goes dark.
      return _nominatimSearch(q, near: near);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final feats = (body['features'] as List<dynamic>? ?? []);
    return feats
        .map((f) => _fromMapbox(f as Map<String, dynamic>))
        .whereType<Place>()
        .toList();
  }

  Future<Place?> _mapboxReverse(LatLng point, String token) async {
    final uri = Uri.parse('$_mapboxBase/reverse').replace(
      queryParameters: {
        'longitude': '${point.longitude}',
        'latitude': '${point.latitude}',
        'access_token': token,
        'language': 'en',
        'limit': '1',
      },
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) return _nominatimReverse(point);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final feats = (body['features'] as List<dynamic>? ?? []);
    if (feats.isEmpty) return null;
    final place = _fromMapbox(feats.first as Map<String, dynamic>);
    // Keep the exact pin position rather than the snapped address point.
    return place?.copyWith(position: point);
  }

  Place? _fromMapbox(Map<String, dynamic> f) {
    final props = (f['properties'] as Map<String, dynamic>?) ?? {};
    final coords = (props['coordinates'] as Map<String, dynamic>?) ?? {};
    var lat = (coords['latitude'] as num?)?.toDouble();
    var lng = (coords['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final g = (f['geometry'] as Map<String, dynamic>?)?['coordinates'];
      if (g is List && g.length >= 2) {
        lng = (g[0] as num?)?.toDouble();
        lat = (g[1] as num?)?.toDouble();
      }
    }
    if (lat == null || lng == null) return null;

    final name =
        (props['name'] as String?)?.trim().isNotEmpty == true
        ? (props['name'] as String).trim()
        : ((props['name_preferred'] as String?)?.trim() ?? '');
    final full = (props['place_formatted'] as String?)?.trim() ??
        (props['full_address'] as String?)?.trim() ??
        '';
    // Short address: drop the leading name and the country.
    var address = full;
    if (address.startsWith('$name, ')) {
      address = address.substring(name.length + 2);
    }
    address = address.replaceAll(RegExp(r',?\s*Nigeria$'), '').trim();

    return Place(
      id: (props['mapbox_id'] as String?) ?? '$lat,$lng',
      name: name.isEmpty ? (full.isEmpty ? 'Dropped pin' : full) : name,
      address: address.isEmpty ? full : address,
      position: LatLng(lat, lng),
    );
  }

  // ---------------- Nominatim (free fallback) ----------------

  Future<List<Place>> _nominatimSearch(String q, {LatLng? near}) async {
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

    final uri =
        Uri.parse('$_nominatimBase/search').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _nominatimHeaders);
    if (res.statusCode != 200) return [];

    final list = jsonDecode(res.body) as List<dynamic>;
    final places = list
        .map((e) => _fromNominatim(e as Map<String, dynamic>))
        .whereType<Place>()
        .toList();

    // OSM rarely has Nigerian house numbers, so "27, Ajileye" only matches
    // "Ajileye Street". Keep the number the rider typed on street results.
    final number = RegExp(r'^(\d+[A-Za-z]?)[,\s]+').firstMatch(q)?.group(1);
    if (number == null) return places;
    return places.map((p) {
      if (RegExp(r'^\d').hasMatch(p.name)) return p;
      return p.copyWith(name: '$number ${p.name}');
    }).toList();
  }

  Future<Place?> _nominatimReverse(LatLng point) async {
    final uri = Uri.parse('$_nominatimBase/reverse').replace(
      queryParameters: {
        'lat': '${point.latitude}',
        'lon': '${point.longitude}',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
      },
    );
    final res = await _client.get(uri, headers: _nominatimHeaders);
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
