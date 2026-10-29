import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import 'wallet_transactions.dart';

/// Screen 62.
class TopUpDetailsScreen extends ConsumerWidget {
  const TopUpDetailsScreen({super.key, required this.txId});

  final String txId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref
        .watch(walletTransactionsProvider)
        .where((e) => e.id == txId)
        .firstOrNull;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    Widget row(String a, Widget b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(a, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          b,
        ],
      ),
    );
    Widget val(String s) =>
        Text(s, style: const TextStyle(fontWeight: FontWeight.w600));
    Widget copyable(String s) => InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: s));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$s copied')));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          val(s),
          const SizedBox(width: 6),
          const Icon(Icons.copy, size: 15, color: AppColors.textSecondary),
        ],
      ),
    );

    final receipt =
        'GoRide Wallet top up\n'
        '${naira(t.amount)} from ${t.method}\n'
        '${formatDate(t.createdAt)} · ${formatTime(t.createdAt)}\n'
        'Transaction ID: ${t.id}'
        '${t.reference != null ? '\nPaystack ref: ${t.reference}' : ''}';

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        backgroundColor: AppColors.fieldFill,
        title: const Text('Top Up Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  naira(t.amount),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'GoRide Wallet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${t.method}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                row(
                  'Status',
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                row('Payment', val(t.method)),
                row('Date', val(formatDate(t.createdAt))),
                row('Time', val(formatTime(t.createdAt))),
                row('Transaction ID', copyable(t.id)),
                if (t.reference != null)
                  row('Paystack ref', copyable(t.reference!)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AppButton(
            label: 'Share Receipt',
            variant: AppButtonVariant.outline,
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: () async {
              try {
                await SharePlus.instance.share(ShareParams(text: receipt));
              } catch (_) {
                await Clipboard.setData(ClipboardData(text: receipt));
              }
            },
          ),
        ),
      ),
    );
  }
}
