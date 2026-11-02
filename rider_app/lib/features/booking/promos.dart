import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart'
    show Backend, parseTime, userIdProvider;

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

/// Active promo codes from Supabase (`promos`), managed in the admin.
class PromosController extends Notifier<List<Promo>> {
  @override
  List<Promo> build() {
    final uid = ref.watch(userIdProvider);
    if (uid == null) return const [];
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      final rows = await Backend.db
          .from('promos')
          .select()
          .eq('active', true)
          .order('percent_off', ascending: false);
      final now = DateTime.now();
      state = [
        for (final r in rows)
          if (parseTime(r['ends_at'])?.isAfter(now) ?? true)
            Promo(
              code: r['code'] as String,
              title: r['title'] as String,
              percentOff: r['percent_off'] as int,
              maxDiscount: r['max_off'] as int,
              minSpend: r['min_spend'] as int,
              validUntil:
                  parseTime(r['ends_at']) ?? now.add(const Duration(days: 365)),
              rideTypeIds: r['ride_type_id'] == null
                  ? null
                  : {r['ride_type_id'] as String},
            ),
      ];
    } catch (_) {}
  }
}

final promosProvider = NotifierProvider<PromosController, List<Promo>>(
  PromosController.new,
);
