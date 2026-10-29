import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';

class Promo {
  const Promo({
    required this.code,
    required this.title,
    required this.percentOff,
    required this.maxDiscount,
    required this.minSpend,
    required this.validUntil,
    this.rideTypeIds,
  });

  final String code;
  final String title;
  final int percentOff;
  final int maxDiscount;
  final int minSpend;
  final DateTime validUntil;

  /// Null = all ride types.
  final Set<String>? rideTypeIds;

  String get terms {
    final parts = <String>[
      code,
      minSpend > 0 ? 'Min. spend ${naira(minSpend)}' : 'No min. spend',
      'Max ${naira(maxDiscount)} off',
      'Valid till ${validUntil.day}/${validUntil.month}/${validUntil.year}',
    ];
    return parts.join(' · ');
  }

  bool appliesTo(String rideTypeId) =>
      rideTypeIds == null || rideTypeIds!.contains(rideTypeId);

  /// Discount in Naira for a fare, or 0 if the promo doesn't apply.
  int discountFor(String rideTypeId, int fare) {
    if (!appliesTo(rideTypeId) || fare < minSpend) return 0;
    final d = (fare * percentOff / 100).round();
    return roundFare((d > maxDiscount ? maxDiscount : d).toDouble());
  }
}

/// Mock promos. Later: `promos` table managed from the admin dashboard.
final promosProvider = Provider<List<Promo>>((ref) {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month + 2, 0);
  return [
    Promo(
      code: 'GORIDE20',
      title: 'Best Deal: 20% OFF',
      percentOff: 20,
      maxDiscount: 1000,
      minSpend: 0,
      validUntil: end,
    ),
    Promo(
      code: 'NEWRIDER',
      title: '15% OFF: New Rider Promotion',
      percentOff: 15,
      maxDiscount: 1500,
      minSpend: 2000,
      validUntil: end,
    ),
    Promo(
      code: 'KEKE10',
      title: '10% OFF all Keke rides',
      percentOff: 10,
      maxDiscount: 300,
      minSpend: 0,
      validUntil: end,
      rideTypeIds: const {'keke'},
    ),
    Promo(
      code: 'COMFY25',
      title: '25% OFF GoRide Comfort',
      percentOff: 25,
      maxDiscount: 2000,
      minSpend: 3000,
      validUntil: end,
      rideTypeIds: const {'comfort'},
    ),
  ];
});
