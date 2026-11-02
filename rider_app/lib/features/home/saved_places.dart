import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart' show Backend, userIdProvider;
import 'package:latlong2/latlong.dart';

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.position,
    this.details = '',
  });

  final String id;

  /// What the rider calls it: Home, Office, Mum's House...
  final String label;
  final String address;
  final LatLng position;

  /// Extra directions: floor, flat number, gate colour.
  final String details;

  IconData get icon {
    final l = label.toLowerCase();
    if (l.contains('home') || l.contains('house')) return Icons.home_outlined;
    if (l.contains('office') || l.contains('work')) return Icons.work_outline;
    if (l.contains('school') || l.contains('uni')) return Icons.school_outlined;
    if (l.contains('gym')) return Icons.fitness_center;
    return Icons.place_outlined;
  }

  SavedPlace copyWith({
    String? label,
    String? address,
    LatLng? position,
    String? details,
  }) {
    return SavedPlace(
      id: id,
      label: label ?? this.label,
      address: address ?? this.address,
      position: position ?? this.position,
      details: details ?? this.details,
    );
  }
}

/// Saved addresses, stored in Supabase (`saved_places`).
class SavedPlacesController extends Notifier<List<SavedPlace>> {
  static const maxPlaces = 10;

  @override
  List<SavedPlace> build() {
    final uid = ref.watch(userIdProvider);
    if (uid == null) return const [];
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      final rows = await Backend.db
          .from('saved_places')
          .select()
          .order('created_at');
      state = [
        for (final r in rows)
          SavedPlace(
            id: r['id'] as String,
            label: r['label'] as String,
            address: r['address'] as String,
            position: LatLng(
              (r['lat'] as num).toDouble(),
              (r['lng'] as num).toDouble(),
            ),
            details: (r['details'] as String?) ?? '',
          ),
      ];
    } catch (_) {}
  }

  Future<void> save(SavedPlace p) async {
    final i = state.indexWhere((e) => e.id == p.id);
    if (i == -1 && state.length >= maxPlaces) return;
    final row = {
      'user_id': Backend.user!.id,
      'label': p.label,
      'address': p.address,
      'lat': p.position.latitude,
      'lng': p.position.longitude,
      'details': p.details,
    };
    // Optimistic update so the list changes immediately.
    state = i == -1 ? [...state, p] : ([...state]..[i] = p);
    try {
      if (i == -1 || !_isUuid(p.id)) {
        await Backend.db.from('saved_places').insert(row);
      } else {
        await Backend.db.from('saved_places').update(row).eq('id', p.id);
      }
    } finally {
      await _load();
    }
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    if (_isUuid(id)) {
      await Backend.db.from('saved_places').delete().eq('id', id);
    }
  }
}

bool _isUuid(String id) => id.length == 36 && id.contains('-');

final savedPlacesProvider =
    NotifierProvider<SavedPlacesController, List<SavedPlace>>(
      SavedPlacesController.new,
    );
