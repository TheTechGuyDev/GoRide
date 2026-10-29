import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import 'booking_controller.dart';
import 'promos.dart';
import 'ride_types.dart';

/// Screen 22 (apply during booking) and the Promos tab (browse only).
class PromosScreen extends ConsumerStatefulWidget {
  const PromosScreen({super.key, this.applying = false});

  /// True when opened from ride options: selecting a promo applies it.
  final bool applying;

  @override
  ConsumerState<PromosScreen> createState() => _PromosScreenState();
}

class _PromosScreenState extends ConsumerState<PromosScreen> {
  final _code = TextEditingController();
  late String? _selected = ref.read(bookingControllerProvider).promo?.code;
  String? _error;

  /// Returns an error message, or null if [promo] can be used now.
  String? _check(Promo promo) {
    if (!widget.applying) return null;
    final rideTypeId = ref.read(bookingControllerProvider).rideTypeId;
    if (!promo.appliesTo(rideTypeId)) {
      final names = rideTypes
          .where((r) => promo.rideTypeIds!.contains(r.id))
          .map((r) => r.name)
          .join(', ');
      return '${promo.code} only works on $names';
    }
    return null;
  }

  void _redeem() {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final promo = ref
        .read(promosProvider)
        .where((p) => p.code == code)
        .firstOrNull;
    if (promo == null) {
      setState(() => _error = 'Invalid promo code');
      return;
    }
    final problem = _check(promo);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _selected = promo.code;
      _error = null;
    });
    if (widget.applying) _apply();
  }

  void _apply() {
    final booking = ref.read(bookingControllerProvider.notifier);
    final promo = ref
        .read(promosProvider)
        .where((p) => p.code == _selected)
        .firstOrNull;
    if (promo == null) {
      booking.removePromo();
    } else {
      booking.applyPromo(promo);
    }
    context.pop();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promos = ref.watch(promosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promos / Vouchers'),
        automaticallyImplyLeading: widget.applying,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have a Promo Code?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _redeem(),
                        decoration: InputDecoration(
                          hintText: 'Enter code here',
                          errorText: _error,
                          errorMaxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: AppButton(
                        label: 'Redeem',
                        height: 52,
                        onPressed: _redeem,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final p in promos) ...[
            _PromoTile(
              promo: p,
              selected: widget.applying && p.code == _selected,
              disabledReason: _check(p),
              onTap: () {
                if (!widget.applying) {
                  Clipboard.setData(ClipboardData(text: p.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${p.code} copied. Apply it when booking a ride.',
                      ),
                    ),
                  );
                  return;
                }
                final problem = _check(p);
                if (problem != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(problem)));
                  return;
                }
                setState(() => _selected = _selected == p.code ? null : p.code);
              },
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
      bottomNavigationBar: widget.applying
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: AppButton(label: 'OK', onPressed: _apply),
              ),
            )
          : null,
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({
    required this.promo,
    required this.selected,
    required this.onTap,
    this.disabledReason,
  });

  final Promo promo;
  final bool selected;
  final VoidCallback onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final disabled = disabledReason != null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9800),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.percent, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disabledReason ?? promo.terms,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
