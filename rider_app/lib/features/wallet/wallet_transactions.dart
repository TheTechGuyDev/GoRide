import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

enum WalletTxType { topUp, ridePayment, tip, refund }

enum WalletTxStatus { completed, pending, failed }

/// One movement of money in or out of the GoRide Wallet.
/// Later: `wallet_transactions` table, written only by the backend after
/// Paystack confirms a payment (never trusted from the app).
class WalletTx {
  const WalletTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    required this.method,
    required this.createdAt,
    this.status = WalletTxStatus.completed,
    this.reference,
  });

  final String id;
  final WalletTxType type;

  /// Always positive; [isCredit] says the direction.
  final int amount;
  final String title;

  /// e.g. "Mastercard •••• 4679", "Bank Transfer", "GoRide Wallet".
  final String method;
  final DateTime createdAt;
  final WalletTxStatus status;

  /// Paystack reference for top-ups.
  final String? reference;

  bool get isCredit =>
      type == WalletTxType.topUp || type == WalletTxType.refund;

  IconData get icon => switch (type) {
    WalletTxType.topUp => Icons.add,
    WalletTxType.ridePayment => Icons.directions_car_outlined,
    WalletTxType.tip => Icons.volunteer_activism_outlined,
    WalletTxType.refund => Icons.undo,
  };

  Color get color => isCredit ? AppColors.primary : AppColors.textPrimary;
}

class WalletTransactionsController extends Notifier<List<WalletTx>> {
  @override
  List<WalletTx> build() => _seed();

  void add(WalletTx tx) => state = [tx, ...state];

  List<WalletTx> _seed() {
    final now = DateTime.now();
    WalletTx t(int n, int daysAgo, int hour, int amount, String method) =>
        WalletTx(
          id: 'TRX12182420$n',
          type: WalletTxType.topUp,
          amount: amount,
          title: 'Top Up',
          method: method,
          createdAt: DateTime(
            now.year,
            now.month,
            now.day - daysAgo,
            hour,
            12 + n,
          ),
          reference: 'PSK_TEST_${8820 + n}',
        );
    return [
      t(1, 2, 20, 10000, 'Mastercard •••• 4679'),
      t(2, 6, 10, 5000, 'Bank Transfer'),
      t(3, 11, 18, 2500, 'USSD'),
    ];
  }
}

final walletTransactionsProvider =
    NotifierProvider<WalletTransactionsController, List<WalletTx>>(
      WalletTransactionsController.new,
    );
