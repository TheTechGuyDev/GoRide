import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:goride_core/goride_core.dart';

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
  RealtimeChannel? _channel;

  @override
  List<WalletTx> build() {
    final uid = ref.watch(userIdProvider);
    ref.onDispose(() => _channel?.unsubscribe());
    if (uid == null) return const [];
    Future.microtask(refresh);
    // New rows (trip payments, refunds, top-ups) appear straight away.
    _channel = Backend.db
        .channel('wallet-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'wallet_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => refresh(),
        )
        .subscribe();
    return const [];
  }

  Future<void> refresh() async {
    if (Backend.user == null) return;
    try {
      final rows = await Backend.db
          .from('wallet_transactions')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      state = [for (final r in rows) _fromRow(r)];
      ref.invalidate(walletBalanceSyncProvider);
    } catch (_) {}
  }

  /// Kept for the preview top-up screens; real money comes from the server.
  void add(WalletTx tx) => state = [tx, ...state];

  static WalletTx _fromRow(Map<String, dynamic> r) {
    final amount = r['amount'] as int;
    final type = switch (r['kind'] as String) {
      'top_up' || 'adjustment' when amount > 0 => WalletTxType.topUp,
      'refund' => WalletTxType.refund,
      'tip' => WalletTxType.tip,
      _ => amount > 0 ? WalletTxType.refund : WalletTxType.ridePayment,
    };
    return WalletTx(
      id:
          (r['reference'] as String?) ??
          (r['id'] as String).substring(0, 8).toUpperCase(),
      type: type,
      amount: amount.abs(),
      title: r['title'] as String,
      method: 'GoRide Wallet',
      createdAt: parseTime(r['created_at']) ?? DateTime.now(),
      reference: r['reference'] as String?,
    );
  }
}

/// Bumped whenever the transaction list reloads, so the balance reloads too.
final walletBalanceSyncProvider = Provider<int>((ref) => 0);

final walletTransactionsProvider =
    NotifierProvider<WalletTransactionsController, List<WalletTx>>(
      WalletTransactionsController.new,
    );
