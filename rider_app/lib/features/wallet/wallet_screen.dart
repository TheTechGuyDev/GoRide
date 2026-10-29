import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../booking/payment_methods.dart';
import 'wallet_transactions.dart';

/// GoRide Wallet: balance, top up, and every movement of money.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider);
    final txs = ref.watch(walletTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GoRide Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          WalletBalanceCard(balance: balance),
          const SizedBox(height: 24),
          const Text(
            'Transactions',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (txs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          for (final t in txs) ...[
            WalletTxTile(tx: t),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({super.key, required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0CC25F), Color(0xFF079A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white70),
              const SizedBox(width: 8),
              const Text(
                'Available balance',
                style: TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Image.asset('assets/images/logo_white.png', width: 34),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            naira(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.topUp),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Top Up',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WalletTxTile extends StatelessWidget {
  const WalletTxTile({super.key, required this.tx});
  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tx.type == WalletTxType.topUp
          ? () => context.push(Routes.topUpDetailsFor(tx.id))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tx.isCredit
                    ? AppColors.primaryLight
                    : AppColors.fieldFill,
              ),
              child: Icon(
                tx.icon,
                color: tx.isCredit
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTimeShort(tx.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${tx.isCredit ? '+' : '-'}${naira(tx.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tx.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tx.method,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
