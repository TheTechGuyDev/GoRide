import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';

enum LocationStatus {
  /// Haven't asked yet; show the Enable Location dialog.
  notAsked,

  /// Permission granted, waiting for a GPS fix.
  searching,

  /// We have a position (real or the Lagos fallback).
  ready,
}

class LocationState {
  const LocationState({
    this.status = LocationStatus.notAsked,
    this.position = MapConfig.defaultCenter,
    this.isFallback = true,
  });

  final LocationStatus status;
  final LatLng position;

  /// True when we're showing the default Lagos point, not the real GPS fix.
  final bool isFallback;

  LocationState copyWith({
    LocationStatus? status,
    LatLng? position,
    bool? isFallback,
  }) {
    return LocationState(
      status: status ?? this.status,
      position: position ?? this.position,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}

class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  /// Called from "Grant Permission".
  Future<void> requestAndLocate() async {
    state = state.copyWith(status: LocationStatus.searching);
    final started = DateTime.now();

    LatLng? found;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );
          found = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {
      // Timeout or platform error: fall back to Lagos.
    }

    // Keep the "Searching your location..." screen up briefly so it doesn't flash.
    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 1800);
    if (elapsed < minShow) await Future.delayed(minShow - elapsed);

    state = LocationState(
      status: LocationStatus.ready,
      position: found ?? MapConfig.defaultCenter,
      isFallback: found == null,
    );
  }

  /// Called from "Maybe Later".
  void skip() {
    state = const LocationState(status: LocationStatus.ready);
  }

  /// Recenter button: refresh the fix if we have permission.
  Future<void> refresh() async {
    if (state.isFallback) return requestAndLocate();
    try {
      final pos = await Geolocator.getCurrentPosition();
      state = state.copyWith(position: LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);
