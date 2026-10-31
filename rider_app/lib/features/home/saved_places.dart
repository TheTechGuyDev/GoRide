import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Saved addresses (Lagos samples). Later: `saved_places` table in Supabase.
class SavedPlacesController extends Notifier<List<SavedPlace>> {
  static const maxPlaces = 10;

  @override
  List<SavedPlace> build() => const [
    SavedPlace(
      id: 'home',
      label: 'Home',
      address: '12 Admiralty Way, Lekki Phase 1, Lagos',
      position: LatLng(6.4474, 3.4720),
      details: 'Estate gate 2, Block C',
    ),
    SavedPlace(
      id: 'office',
      label: 'Office',
      address: '1 Adeola Odeku St, Victoria Island, Lagos',
      position: LatLng(6.4310, 3.4215),
    ),
    SavedPlace(
      id: 'mum',
      label: 'Mum\'s House',
      address: '5 Allen Avenue, Ikeja, Lagos',
      position: LatLng(6.6018, 3.3515),
    ),
  ];

  void save(SavedPlace p) {
    final i = state.indexWhere((e) => e.id == p.id);
    if (i == -1) {
      if (state.length >= maxPlaces) return;
      state = [...state, p];
    } else {
      state = [...state]..[i] = p;
    }
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();
}

final savedPlacesProvider =
    NotifierProvider<SavedPlacesController, List<SavedPlace>>(
      SavedPlacesController.new,
    );
