import 'package:latlong2/latlong.dart';

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
  });

  final String id;
  final String name;
  final String address;
  final LatLng position;

  Place copyWith({String? name, String? address, LatLng? position}) {
    return Place(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// "1.2 km" / "850 m"
String formatDistance(double metres) {
  if (metres < 1000) return '${(metres / 10).round() * 10} m';
  final km = metres / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}
