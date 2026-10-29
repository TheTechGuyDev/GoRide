import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.position,
    this.icon = Icons.place_outlined,
  });

  final String id;
  final String label;
  final String address;
  final LatLng position;
  final IconData icon;
}

/// Mock saved places (Lagos). Later: `saved_places` table in Supabase.
class SavedPlacesController extends Notifier<List<SavedPlace>> {
  @override
  List<SavedPlace> build() => const [
    SavedPlace(
      id: 'home',
      label: 'Home',
      address: '12 Admiralty Way, Lekki Phase 1, Lagos',
      position: LatLng(6.4474, 3.4720),
      icon: Icons.home_outlined,
    ),
    SavedPlace(
      id: 'office',
      label: 'Office',
      address: '1 Adeola Odeku St, Victoria Island, Lagos',
      position: LatLng(6.4310, 3.4215),
      icon: Icons.work_outline,
    ),
    SavedPlace(
      id: 'mum',
      label: 'Mum\'s House',
      address: '5 Allen Avenue, Ikeja, Lagos',
      position: LatLng(6.6018, 3.3515),
      icon: Icons.favorite_border,
    ),
  ];
}

final savedPlacesProvider =
    NotifierProvider<SavedPlacesController, List<SavedPlace>>(
      SavedPlacesController.new,
    );
