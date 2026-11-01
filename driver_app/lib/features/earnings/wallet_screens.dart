import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../driving/driver_controller.dart';
import '../registration/registration_controller.dart';
import 'earnings_controller.dart';

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx});
  final WalletTx tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (positive ? AppColors.primary : AppColors.textSecondary)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          tx.type.icon,
          size: 20,
          color: positive ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
      title: Text(
        tx.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        tx.subtitle == null
            ? formatDateTimeShort(tx.date)
            : '${formatDateTimeShort(tx.date)}\n${tx.subtitle}',
        style: const TextStyle(fontSize: 12),
      ),
      isThreeLine: tx.subtitle != null,
      trailing: Text(
        '${positive ? '+' : ''}${naira(tx.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: positive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(earningsProvider);
    final bank = ref.watch(registrationProvider).bank;
    final balance = e.balance;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0CC25F), Color(0xFF079A4A)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance < 0 ? 'Amount owed' : 'Available balance',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  naira(balance.abs()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (balance < 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'From commission on cash trips. You can owe up to ${naira(DriverController.debtLimit)} before going online is paused.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: balance > 0
                            ? () => context.push(Routes.payout)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.white24,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.north_east, size: 18),
                        label: const Text(
                          'Cash out',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          Routes.settle,
                          extra: balance < 0 ? -balance : null,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          balance < 0 ? 'Settle' : 'Top up',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GoCard(
            onTap: () => context.push(Routes.bank),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payout account',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        bank == null
                            ? 'Add a bank account'
                            : '${bank.masked} · ${bank.accountName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          Row(
            children: [
              const Text(
                'Recent activity',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(Routes.transactions),
                child: const Text('See all'),
              ),
            ],
          ),
          if (e.txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No wallet activity yet. Earnings from card and wallet trips appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          for (final tx in e.txs.take(8)) TxTile(tx: tx),
        ],
      ),
    );
  }
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'All';

  static const _filters = {
    'All': null,
    'Trips': {TxType.tripEarning, TxType.cashCommission},
    'Payouts': {TxType.payout},
    'Tips & bonuses': {TxType.tip, TxType.bonus},
    'Plan & top ups': {TxType.subscription, TxType.topUp},
  };

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(earningsProvider).txs;
    final types = _filters[_filter];
    final list = types == null
        ? all
        : all.where((t) => types.contains(t.type)).toList();

    final children = <Widget>[];
    String? lastDay;
    for (final tx in list) {
      final day = formatDateTimeShort(tx.date).split(' · ').first;
      if (day != lastDay) {
        lastDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      }
      children.add(TxTile(tx: tx));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _filters.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _filter == f
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Nothing here yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: children,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Instant payout to the driver's bank.
class PayoutScreen extends ConsumerStatefulWidget {
  const PayoutScreen({super.key});

  @override
  ConsumerState<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends ConsumerState<PayoutScreen> {
  static const minimum = 1000;
  final _amount = TextEditingController();
  bool _busy = false;

  int get _value => int.tryParse(_amount.text) ?? 0;

  Future<void> _cashOut(BankDetails bank) async {
    setState(() => _busy = true);
    final amount = _value;
    await ref.read(earningsProvider.notifier).payout(amount, bank);
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.primary,
          size: 56,
        ),
        title: Text('${naira(amount)} sent'),
        content: Text(
          'It\'s on its way to your ${bank.bank} account (${bank.accountNumber}). Most transfers arrive within minutes.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(earningsProvider).balance;
    final bank = ref.watch(registrationProvider).bank;
    final valid = _value >= minimum && _value <= balance && bank != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash out')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            'Available: ${naira(balance)}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '₦ ',
              hintText: '0',
              errorText: _value > balance
                  ? 'More than your balance'
                  : _value > 0 && _value < minimum
                  ? 'Minimum is ${naira(minimum)}'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final v in [5000, 10000, 20000])
                if (v <= balance)
                  ActionChip(
                    label: Text(naira(v)),
                    onPressed: () => setState(() => _amount.text = '$v'),
                  ),
              if (balance >= minimum)
                ActionChip(
                  label: const Text('All'),
                  onPressed: () => setState(() => _amount.text = '$balance'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const FieldLabel('To'),
          GoCard(
            onTap: () => context.push(Routes.bank),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bank == null
                        ? 'Add a bank account'
                        : '${bank.bank}\n${bank.accountName} · ${bank.accountNumber}',
                    style: const TextStyle(height: 1.4),
                  ),
                ),
                const Text('Change'),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.bolt, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Instant and free. Sent with Paystack Transfers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _value > 0 ? 'Cash out ${naira(_value)}' : 'Cash out',
          loading: _busy,
          onPressed: valid ? () => _cashOut(bank) : null,
        ),
      ),
    );
  }
}

/// Add money to the wallet with Paystack (settle cash commission or fund a
/// subscription).
class SettleScreen extends ConsumerStatefulWidget {
  const SettleScreen({super.key, this.suggested});
  final int? suggested;

  @override
  ConsumerState<SettleScreen> createState() => _SettleScreenState();
}

class _SettleScreenState extends ConsumerState<SettleScreen> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.suggested?.toString() ?? '',
  );
  final _gateway = SimulatedPaystack();
  bool _busy = false;

  int get _value => int.tryParse(_amount.text) ?? 0;

  Future<void> _pay() async {
    setState(() => _busy = true);
    final res = await _gateway.chargeCard(amount: _value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(res.message ?? 'Payment failed')));
      return;
    }
    ref.read(earningsProvider.notifier).topUp(_value, res.reference!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${naira(_value)} added to your wallet')),
    );
    context.pop();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(earningsProvider).balance;
    return Scaffold(
      appBar: AppBar(
        title: Text(balance < 0 ? 'Settle balance' : 'Top up wallet'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          if (balance < 0)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'You owe ${naira(-balance)} in commission from cash trips.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(prefixText: '₦ ', hintText: '0'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final v in [2000, 5000, 10000, 20000])
                ActionChip(
                  label: Text(naira(v)),
                  onPressed: () => setState(() => _amount.text = '$v'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pay with card, bank transfer or USSD through Paystack. Test mode: no real money is charged.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: _value > 0 ? 'Pay ${naira(_value)}' : 'Pay',
          loading: _busy,
          onPressed: _value >= 100 ? _pay : null,
        ),
      ),
    );
  }
}
