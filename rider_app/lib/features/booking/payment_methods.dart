import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart'
    show
        Backend,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel,
        PaystackCheckout,
        userIdProvider;

import '../../core/notifications/notification_service.dart';
import '../../core/router/routes.dart';
import '../../core/utils/money.dart';
import '../wallet/wallet_transactions.dart';

enum PaymentKind { wallet, cash, card, transfer }

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final PaymentKind kind;
  final String title;
  final String subtitle;

  IconData get icon => switch (kind) {
    PaymentKind.wallet => Icons.account_balance_wallet,
    PaymentKind.cash => Icons.payments,
    PaymentKind.card => Icons.credit_card,
    PaymentKind.transfer => Icons.account_balance,
  };

  Color get color => switch (kind) {
    PaymentKind.wallet => const Color(0xFF0CC25F),
    PaymentKind.cash => const Color(0xFF2E7D32),
    PaymentKind.card => const Color(0xFF1A237E),
    PaymentKind.transfer => const Color(0xFF6A1B9A),
  };
}

/// Wallet balance in Naira, from the server (sum of wallet transactions).
/// Money only moves on the server: trips, tips, refunds and Paystack top-ups.
class WalletController extends Notifier<int> {
  RealtimeChannel? _channel;
  Timer? _timer;

  @override
  int build() {
    final uid = ref.watch(userIdProvider);
    ref.watch(walletBalanceSyncProvider);
    ref.onDispose(() {
      _channel?.unsubscribe();
      _timer?.cancel();
    });
    if (uid == null) return 0;
    Future.microtask(refresh);
    // Money added by GoRide (refunds, credits, top-ups) shows straight away.
    _channel = Backend.db
        .channel('balance-$uid-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'wallet_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (p) {
            refresh();
            ref.read(walletTransactionsProvider.notifier).refresh();
            final amount = (p.newRecord['amount'] as num?)?.toInt() ?? 0;
            if (amount > 0 && p.newRecord['kind'] != 'trip_earning') {
              ref
                  .read(notificationsProvider.notifier)
                  .notify(
                    NotifyCategory.wallet,
                    '${naira(amount)} added to your wallet',
                    (p.newRecord['title'] as String?) ?? 'Wallet credit',
                    route: Routes.wallet,
                  );
            }
          },
        )
        .subscribe();
    // Backup in case a live update is missed.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    return stateOrNull ?? 0;
  }

  Future<void> refresh() async {
    if (Backend.user == null) return;
    try {
      final v = await Backend.db.rpc('my_balance');
      state = (v as num).toInt();
    } catch (_) {}
  }

  /// The server already took the money; just reload.
  void debit(
    int amount, {
    WalletTxType type = WalletTxType.ridePayment,
    String title = 'Ride payment',
  }) => ref.read(walletTransactionsProvider.notifier).refresh();

  /// Top-ups are credited by the server after Paystack confirms the payment.
  void credit(
    int amount, {
    WalletTxType type = WalletTxType.topUp,
    String title = 'Top Up',
    String method = '',
    String? reference,
    String? id,
  }) {
    ref.read(walletTransactionsProvider.notifier).refresh();
    if (type == WalletTxType.topUp) {
      ref
          .read(notificationsProvider.notifier)
          .notify(
            NotifyCategory.wallet,
            'Wallet top-up',
            'We are confirming your payment of ${naira(amount)}.',
            route: Routes.wallet,
          );
    }
  }
}

final walletBalanceProvider = NotifierProvider<WalletController, int>(
  WalletController.new,
);

/// Payment methods: wallet, cash, bank transfer and the rider's saved cards.
/// A card is saved by Paystack after a card payment (we keep only the last 4
/// digits; Paystack holds the card). We never see full card numbers.
class PaymentMethodsController extends Notifier<List<PaymentMethod>> {
  static const _builtIn = [
    PaymentMethod(
      id: 'wallet',
      kind: PaymentKind.wallet,
      title: 'GoRide Wallet',
      subtitle: 'Available balance',
    ),
    PaymentMethod(
      id: 'cash',
      kind: PaymentKind.cash,
      title: 'Cash',
      subtitle: 'Pay your driver directly',
    ),
    PaymentMethod(
      id: 'transfer',
      kind: PaymentKind.transfer,
      title: 'Bank Transfer',
      subtitle: 'Top up your wallet by transfer',
    ),
  ];

  @override
  List<PaymentMethod> build() {
    final uid = ref.watch(userIdProvider);
    if (uid != null) Future.microtask(load);
    return _builtIn;
  }

  List<PaymentMethod> get cards =>
      state.where((m) => m.kind == PaymentKind.card).toList();

  Future<void> load() async {
    try {
      final rows = await Backend.db
          .from('payment_cards')
          .select('id, brand, last4, exp, bank, is_default, created_at')
          .order('is_default', ascending: false)
          .order('created_at');
      state = [
        _builtIn[0],
        _builtIn[1],
        for (final r in rows)
          PaymentMethod(
            id: r['id'] as String,
            kind: PaymentKind.card,
            title:
                '${r['brand']}${r['is_default'] == true ? ' (default)' : ''}',
            subtitle: '•••• •••• •••• ${r['last4']}  ·  ${r['exp']}',
          ),
        _builtIn[2],
      ];
    } catch (_) {}
  }

  /// Pays ₦100 with Paystack to save a card. The ₦100 stays in the wallet.
  Future<bool> addCard(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a card'),
        content: const Text(
          'Paystack will charge your card 100 naira to save it securely. '
          'The 100 naira goes into your GoRide wallet, so you lose nothing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
    final before = cards.length;
    final ref0 = await PaystackCheckout.pay(
      context,
      amount: 100,
      purpose: 'add_card',
    );
    if (ref0 == null) return false;
    await load();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cards.length > before
                ? 'Card saved. 100 naira added to your wallet.'
                : '100 naira added to your wallet. This card type cannot be saved for later; try a Visa, Mastercard or Verve debit card.',
          ),
        ),
      );
    }
    return cards.length > before;
  }

  /// Trips paid by card use this card.
  Future<void> makeDefault(String id) async {
    await Backend.db.rpc('set_default_card', params: {'p_card': id});
    await load();
  }

  Future<void> remove(String id) async {
    state = state.where((m) => m.id != id).toList();
    await Backend.db.from('payment_cards').delete().eq('id', id);
    await load();
  }
}

final paymentMethodsProvider =
    NotifierProvider<PaymentMethodsController, List<PaymentMethod>>(
      PaymentMethodsController.new,
    );
