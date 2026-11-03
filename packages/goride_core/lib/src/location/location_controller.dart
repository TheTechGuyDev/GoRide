import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/map_config.dart';

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
    this.accuracy,
  });

  final LocationStatus status;
  final LatLng position;

  /// True when we're showing the default Lagos point, not the real GPS fix.
  final bool isFallback;

  /// How precise the fix is, in metres (smaller is better).
  final double? accuracy;

  /// Good enough to use as a pickup point (within about one street).
  bool get isPrecise => !isFallback && (accuracy ?? 999) <= 50;

  LocationState copyWith({
    LocationStatus? status,
    LatLng? position,
    bool? isFallback,
    double? accuracy,
  }) {
    return LocationState(
      status: status ?? this.status,
      position: position ?? this.position,
      isFallback: isFallback ?? this.isFallback,
      accuracy: accuracy ?? this.accuracy,
    );
  }
}

/// The phone's location. Phones often give a rough Wi-Fi/network position
/// first (can be 1 km off), so we wait for a precise GPS fix and keep
/// improving the position while the app is open.
class LocationController extends Notifier<LocationState> {
  StreamSubscription<Position>? _watch;

  @override
  LocationState build() {
    ref.onDispose(() => _watch?.cancel());
    return const LocationState();
  }

  static const _precise = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  Future<bool> _allowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Called from "Grant Permission" (and when going online).
  Future<void> requestAndLocate() async {
    state = state.copyWith(status: LocationStatus.searching);
    final started = DateTime.now();
    Position? best;
    try {
      if (await _allowed()) best = await _bestFix();
    } catch (_) {}

    // Keep the "Searching your location..." screen up briefly so it doesn't flash.
    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 1800);
    if (elapsed < minShow) await Future.delayed(minShow - elapsed);

    state = best == null
        ? LocationState(
            status: LocationStatus.ready,
            position: state.isFallback
                ? MapConfig.defaultCenter
                : state.position,
            isFallback: state.isFallback,
            accuracy: state.accuracy,
          )
        : LocationState(
            status: LocationStatus.ready,
            position: LatLng(best.latitude, best.longitude),
            isFallback: false,
            accuracy: best.accuracy,
          );
    _keepImproving();
  }

  /// Listens for up to 12 seconds and keeps the most precise reading,
  /// stopping early once it is within 25 m.
  Future<Position?> _bestFix() async {
    Position? best;
    final done = Completer<void>();
    final sub = Geolocator.getPositionStream(locationSettings: _precise).listen(
      (p) {
        if (best == null || p.accuracy < best!.accuracy) {
          best = p;
          state = state.copyWith(
            position: LatLng(p.latitude, p.longitude),
            isFallback: false,
            accuracy: p.accuracy,
          );
        }
        if (p.accuracy <= 25 && !done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    await sub.cancel();
    if (best != null) return best;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// While the app is open, move to newer GPS readings that are precise, or
  /// more precise than what we have.
  void _keepImproving() {
    _watch?.cancel();
    try {
      _watch =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 10,
            ),
          ).listen((p) {
            final current = state.isFallback
                ? 9999.0
                : (state.accuracy ?? 9999);
            if (p.accuracy <= 50 || p.accuracy < current) {
              state = state.copyWith(
                position: LatLng(p.latitude, p.longitude),
                isFallback: false,
                accuracy: p.accuracy,
              );
            }
          }, onError: (_) {});
    } catch (_) {}
  }

  /// Called from "Maybe Later".
  void skip() {
    state = const LocationState(status: LocationStatus.ready);
  }

  /// Recenter button: get a fresh precise fix.
  Future<void> refresh() async {
    if (state.isFallback) return requestAndLocate();
    try {
      final p = await _bestFix();
      if (p != null) {
        state = state.copyWith(
          position: LatLng(p.latitude, p.longitude),
          accuracy: p.accuracy,
        );
      }
    } catch (_) {}
  }
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(LocationController.new);
