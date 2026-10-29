import 'package:flutter/material.dart';

import '../../core/services/routing_service.dart';
import '../../core/utils/money.dart';

enum VehicleKind { bike, keke, car }

/// A GoRide product with its Lagos pricing.
/// Later these rates come from a `ride_types` table so you can change prices
/// from the admin dashboard without an app update.
class RideType {
  const RideType({
    required this.id,
    required this.name,
    required this.kind,
    required this.passengers,
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
    required this.minimumFare,
    required this.etaMinutes,
    required this.description,
  });

  final String id;
  final String name;
  final VehicleKind kind;
  final int passengers;
  final double baseFare;
  final double perKm;
  final double perMinute;
  final double minimumFare;

  /// How far away the nearest driver of this type is (mock).
  final (int, int) etaMinutes;
  final String description;

  IconData get icon => switch (kind) {
    VehicleKind.bike => Icons.two_wheeler,
    VehicleKind.keke => Icons.electric_rickshaw,
    VehicleKind.car => Icons.directions_car_filled,
  };

  FareBreakdown fareFor(RouteInfo route) {
    final distance = route.km * perKm;
    final time = route.minutes * perMinute;
    final raw = baseFare + distance + time;
    final total = raw < minimumFare ? minimumFare : raw;
    return FareBreakdown(
      base: baseFare,
      distance: distance,
      time: time,
      minimumTopUp: total - raw,
      total: roundFare(total),
    );
  }
}

class FareBreakdown {
  const FareBreakdown({
    required this.base,
    required this.distance,
    required this.time,
    required this.minimumTopUp,
    required this.total,
  });

  final double base;
  final double distance;
  final double time;

  /// Extra added when the trip is below the minimum fare.
  final double minimumTopUp;
  final int total;
}

const rideTypes = [
  RideType(
    id: 'bike',
    name: 'GoRide Bike',
    kind: VehicleKind.bike,
    passengers: 1,
    baseFare: 300,
    perKm: 120,
    perMinute: 15,
    minimumFare: 700,
    etaMinutes: (2, 4),
    description: 'Fastest through traffic. Helmet provided.',
  ),
  RideType(
    id: 'keke',
    name: 'GoRide Keke',
    kind: VehicleKind.keke,
    passengers: 3,
    baseFare: 400,
    perKm: 150,
    perMinute: 20,
    minimumFare: 900,
    etaMinutes: (3, 5),
    description: 'Affordable rides for short trips.',
  ),
  RideType(
    id: 'car',
    name: 'GoRide Car',
    kind: VehicleKind.car,
    passengers: 4,
    baseFare: 700,
    perKm: 250,
    perMinute: 40,
    minimumFare: 1500,
    etaMinutes: (3, 6),
    description: 'Everyday rides in a clean, comfortable car.',
  ),
  RideType(
    id: 'comfort',
    name: 'GoRide Comfort',
    kind: VehicleKind.car,
    passengers: 4,
    baseFare: 900,
    perKm: 320,
    perMinute: 50,
    minimumFare: 2000,
    etaMinutes: (4, 7),
    description: 'Newer cars with AC and top-rated drivers.',
  ),
  RideType(
    id: 'xl',
    name: 'GoRide XL',
    kind: VehicleKind.car,
    passengers: 6,
    baseFare: 1200,
    perKm: 400,
    perMinute: 60,
    minimumFare: 2800,
    etaMinutes: (5, 9),
    description: 'SUVs and minivans for groups and luggage.',
  ),
];
