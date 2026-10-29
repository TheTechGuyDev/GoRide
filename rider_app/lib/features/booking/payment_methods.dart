import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void debit(int amount) => state = state - amount;
  void credit(int amount) => state = state + amount;
}

final walletBalanceProvider = NotifierProvider<WalletController, int>(
  WalletController.new,
);

/// Mock saved methods. Cards are added through Paystack (free test mode).
final paymentMethodsProvider = Provider<List<PaymentMethod>>((ref) {
  return const [
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
});
