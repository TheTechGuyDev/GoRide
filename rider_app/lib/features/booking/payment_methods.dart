import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Mock wallet balance in Naira. Later: `wallets` table + Paystack top-ups.
class WalletController extends Notifier<int> {
  @override
  int build() => 12500;

  /// Takes money out and records it in the wallet history.
  void debit(
    int amount, {
    WalletTxType type = WalletTxType.ridePayment,
    String title = 'Ride payment',
  }) {
    state = state - amount;
    _log(amount, type, title, 'GoRide Wallet');
  }

  /// Adds money (top-up or refund) and records it.
  void credit(
    int amount, {
    WalletTxType type = WalletTxType.topUp,
    String title = 'Top Up',
    String method = '',
    String? reference,
    String? id,
  }) {
    state = state + amount;
    _log(amount, type, title, method, reference: reference, id: id);
  }

  void _log(
    int amount,
    WalletTxType type,
    String title,
    String method, {
    String? reference,
    String? id,
  }) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    ref
        .read(walletTransactionsProvider.notifier)
        .add(
          WalletTx(
            id: id ?? 'TRX${stamp % 10000000000}',
            type: type,
            amount: amount,
            title: title,
            method: method,
            createdAt: DateTime.now(),
            reference: reference,
          ),
        );
  }
}

final walletBalanceProvider = NotifierProvider<WalletController, int>(
  WalletController.new,
);

/// Saved payment methods. Cards are added through Paystack: in the live app
/// Paystack charges ₦50 to verify the card, refunds it, and gives us a
/// reusable authorization code. We never store full card numbers.
class PaymentMethodsController extends Notifier<List<PaymentMethod>> {
  @override
  List<PaymentMethod> build() => const [
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
      id: 'card-4679',
      kind: PaymentKind.card,
      title: 'Mastercard',
      subtitle: '•••• •••• •••• 4679',
    ),
    PaymentMethod(
      id: 'transfer',
      kind: PaymentKind.transfer,
      title: 'Bank Transfer',
      subtitle: 'Pay to a one-time account number',
    ),
  ];

  void addCard({required String brand, required String last4}) {
    final card = PaymentMethod(
      id: 'card-$last4-${DateTime.now().millisecondsSinceEpoch % 10000}',
      kind: PaymentKind.card,
      title: brand,
      subtitle: '•••• •••• •••• $last4',
    );
    // Cards sit after Cash, before Bank Transfer.
    final i = state.lastIndexWhere((m) => m.kind != PaymentKind.transfer) + 1;
    state = [...state]..insert(i, card);
  }

  /// Only cards can be removed; wallet, cash and transfer are built in.
  void remove(String id) => state = state
      .where((m) => m.id != id || m.kind != PaymentKind.card)
      .toList();
}

final paymentMethodsProvider =
    NotifierProvider<PaymentMethodsController, List<PaymentMethod>>(
      PaymentMethodsController.new,
    );
