import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart'
    show PaystackCheckout, paystackFee;

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../booking/payment_methods.dart';

class _Option {
  const _Option(this.id, this.title, this.subtitle, this.icon, this.color);
  final String id; // a saved card id, or 'paystack'
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

/// Screen 65: choose how to pay. A saved card is charged at once; anything
/// else opens Paystack's secure page (card, bank transfer or USSD). The
/// server credits the wallet once Paystack confirms.
class TopUpMethodScreen extends ConsumerStatefulWidget {
  const TopUpMethodScreen({super.key, required this.amount});

  final int amount;

  @override
  ConsumerState<TopUpMethodScreen> createState() => _TopUpMethodScreenState();
}

class _TopUpMethodScreenState extends ConsumerState<TopUpMethodScreen> {
  String? _selected;
  bool _busy = false;

  List<_Option> _options(List<PaymentMethod> cards) => [
    for (final c in cards)
      _Option(
        c.id,
        c.title.replaceAll(' (default)', ''),
        c.subtitle,
        Icons.credit_card,
        const Color(0xFF1A237E),
      ),
    const _Option(
      'paystack',
      'Card, bank transfer or USSD',
      'Pay on Paystack\'s secure page',
      Icons.lock_outline,
      Color(0xFF00897B),
    ),
  ];

  Future<void> _confirm(_Option o) async {
    setState(() => _busy = true);
    final reference = o.id == 'paystack'
        ? await PaystackCheckout.pay(context, amount: widget.amount)
        : await PaystackCheckout.chargeSaved(
            context,
            cardId: o.id,
            amount: widget.amount,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (reference == null) return;
    ref
        .read(walletBalanceProvider.notifier)
        .credit(widget.amount, method: o.title, reference: reference);
    // Paying on Paystack's page can save the card for next time.
    ref.read(paymentMethodsProvider.notifier).load();
    await _showSuccess();
    if (mounted) {
      context.pop();
      context.pop();
    }
  }

  Future<void> _showSuccess() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 22),
              const Text(
                'Top Up Successful!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'You\'ve successfully added ${naira(widget.amount)} to your GoRide Wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'OK', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(paymentMethodsProvider.notifier).cards;
    ref.watch(paymentMethodsProvider);
    final options = _options(cards);
    final selected = options.firstWhere(
      (o) => o.id == _selected,
      orElse: () => options.first,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Top Up Method')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final o in options) ...[
            Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected.id == o.id
                      ? AppColors.primary
                      : AppColors.border,
                  width: selected.id == o.id ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _busy ? null : () => setState(() => _selected = o.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: o.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(o.icon, color: o.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              o.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected.id == o.id)
                        const Icon(Icons.check, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _line('Added to your wallet', naira(widget.amount)),
                const SizedBox(height: 6),
                _line('Paystack fee', naira(paystackFee(widget.amount))),
                const Divider(height: 22),
                _line(
                  'You pay',
                  naira(widget.amount + paystackFee(widget.amount)),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Secured by Paystack. GoRide never sees your card number.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AppButton(
            label: 'Pay ${naira(widget.amount + paystackFee(widget.amount))}',
            loading: _busy,
            onPressed: () => _confirm(selected),
          ),
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Row(
    children: [
      Expanded(
        child: Text(
          a,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? null : AppColors.textSecondary,
          ),
        ),
      ),
      Text(
        b,
        style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
      ),
    ],
  );
}
