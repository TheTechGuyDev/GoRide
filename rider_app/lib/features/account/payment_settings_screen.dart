import 'package:flutter/material.dart';
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
              onSelected: (action) async {
                if (action == 'default') {
                  await ref
                      .read(paymentMethodsProvider.notifier)
                      .makeDefault(m.id);
                  return;
                }
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove card?'),
                    content: Text(
                      '${m.title.replaceAll(' (default)', '')} ${m.subtitle.split('  ').first} will be removed.',
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
                PopupMenuItem(
                  value: 'default',
                  child: Text('Use for card trips'),
                ),
                PopupMenuItem(value: 'remove', child: Text('Remove card')),
              ],
            ),
            _ => Text(
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
              color: AppColors.surface,
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
                        style: TextStyle(
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
            onPressed: () =>
                ref.read(paymentMethodsProvider.notifier).addCard(context),
          ),
        ),
      ),
    );
  }
}
