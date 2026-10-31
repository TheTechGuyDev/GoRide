import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../booking/payment_methods.dart';

/// Screen 78: manage payment methods.
class PaymentSettingsScreen extends ConsumerWidget {
  const PaymentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final balance = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        title: const Text('Payment Methods'),
        backgroundColor: AppColors.fieldFill,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: methods.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final m = methods[i];
          final trailing = switch (m.kind) {
            PaymentKind.wallet => TextButton(
              onPressed: () => context.push(Routes.topUp),
              child: const Text(
                'Top up',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PaymentKind.card => PopupMenuButton<String>(
              onSelected: (_) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove card?'),
                    content: Text(
                      '${m.title} ${m.subtitle.substring(m.subtitle.length - 4)} will be removed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  ref.read(paymentMethodsProvider.notifier).remove(m.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('Remove card')),
              ],
            ),
            _ => const Text(
              'Available',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          };
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: m.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(m.icon, color: m.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m.kind == PaymentKind.wallet
                            ? 'Balance: ${naira(balance)}'
                            : m.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AppButton(
            label: 'Add New Card',
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddCardScreen())),
          ),
        ),
      ),
    );
  }
}

/// Screen 79: add a debit card (verified through Paystack in the live app).
class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  bool _saving = false;

  String get _digits => _number.text.replaceAll(RegExp(r'\D'), '');

  /// Nigerian cards: Verve (506, 650), Visa (4), Mastercard (51-55, 2221-2720).
  String get _brand {
    final d = _digits;
    if (d.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5061|5062|5063|6500|6501|507)').hasMatch(d)) return 'Verve';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(d)) return 'Mastercard';
    return 'Card';
  }

  bool _luhn(String d) {
    var sum = 0;
    for (var i = 0; i < d.length; i++) {
      var n = int.parse(d[d.length - 1 - i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    return d.length >= 13 && sum % 10 == 0;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    ref
        .read(paymentMethodsProvider.notifier)
        .addCard(brand: _brand, last4: _digits.substring(_digits.length - 4));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.primary,
          size: 56,
        ),
        title: const Text('Card added'),
        content: Text(
          '$_brand •••• ${_digits.substring(_digits.length - 4)} is ready to use for rides and top ups.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Card'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Card Number',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _number,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
              ],
              decoration: InputDecoration(
                hintText: '0000 0000 0000 0000',
                suffixText: _digits.isEmpty ? null : _brand,
              ),
              validator: (_) =>
                  _luhn(_digits) ? null : 'Enter a valid card number',
            ),
            const SizedBox(height: 18),
            const Text(
              'Name on Card',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Enter the name on the card'
                  : null,
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expiry',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _expiry,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'MM/YY'),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
                          LengthLimitingTextInputFormatter(5),
                        ],
                        validator: (v) {
                          final m = RegExp(r'^(\d{2})/(\d{2})$')
                              .firstMatch(v ?? '');
                          if (m == null) return 'MM/YY';
                          final month = int.parse(m.group(1)!);
                          final year = 2000 + int.parse(m.group(2)!);
                          final now = DateTime.now();
                          if (month < 1 || month > 12) return 'Invalid month';
                          if (DateTime(year, month + 1).isBefore(now)) {
                            return 'Card expired';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CVV',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cvv,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        validator: (v) =>
                            (v == null || v.length < 3) ? '3 digits' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            const Text(
              'Supported cards',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Verve')),
                Chip(label: Text('Mastercard')),
                Chip(label: Text('Visa')),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Paystack checks your card with a ₦50 charge that is refunded immediately. '
              'GoRide never stores your full card number. Preview: try 4084 0840 8408 4081.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AppButton(
            label: 'Save Card',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}
