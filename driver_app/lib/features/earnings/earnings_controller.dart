import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/notifications/notification_service.dart';
import '../registration/plans.dart';
import '../registration/registration_controller.dart';

enum PaymentKind { cash, wallet, card }

extension PaymentKindX on PaymentKind {
  String get label => switch (this) {
    PaymentKind.cash => 'Cash',
    PaymentKind.wallet => 'GoRide Wallet',
    PaymentKind.card => 'Card',
  };

  IconData get icon => switch (this) {
    PaymentKind.cash => Icons.payments_outlined,
    PaymentKind.wallet => Icons.account_balance_wallet_outlined,
    PaymentKind.card => Icons.credit_card,
  };
}

/// A finished (or cancelled) trip. Later: the `trips` table.
class TripRecord {
  const TripRecord({
    required this.id,
    required this.date,
    required this.riderName,
    required this.pickup,
    required this.dropoff,
    required this.rideTypeId,
    required this.km,
    required this.minutes,
    required this.fare,
    required this.commission,
    required this.payment,
    this.tip = 0,
    this.waitingFee = 0,
    this.ratingFromRider,
    this.ratingGiven,
    this.riderComment,
    this.cancelled = false,
    this.cancelReason,
  });

  final String id;
  final DateTime date;
  final String riderName;
  final String pickup;
  final String dropoff;
  final String rideTypeId;
  final double km;
  final int minutes;

  /// What the rider paid, including any waiting fee.
  final int fare;
  final int commission;
  final PaymentKind payment;
  final int tip;
  final int waitingFee;

  /// Stars the rider gave the driver.
  final int? ratingFromRider;

  /// Stars the driver gave the rider.
  final int? ratingGiven;
  final String? riderComment;
  final bool cancelled;
  final String? cancelReason;

  int get net => cancelled ? 0 : fare - commission + tip;

  RideType get rideType => rideTypes.firstWhere((r) => r.id == rideTypeId);

  TripRecord copyWith({int? tip, int? ratingFromRider, String? riderComment}) =>
      TripRecord(
        id: id,
        date: date,
        riderName: riderName,
        pickup: pickup,
        dropoff: dropoff,
        rideTypeId: rideTypeId,
        km: km,
        minutes: minutes,
        fare: fare,
        commission: commission,
        payment: payment,
        tip: tip ?? this.tip,
        waitingFee: waitingFee,
        ratingFromRider: ratingFromRider ?? this.ratingFromRider,
        ratingGiven: ratingGiven,
        riderComment: riderComment ?? this.riderComment,
        cancelled: cancelled,
        cancelReason: cancelReason,
      );
}

enum TxType {
  tripEarning,
  cashCommission,
  tip,
  payout,
  subscription,
  bonus,
  topUp,
}

extension TxTypeX on TxType {
  IconData get icon => switch (this) {
    TxType.tripEarning => Icons.directions_car,
    TxType.cashCommission => Icons.percent,
    TxType.tip => Icons.volunteer_activism,
    TxType.payout => Icons.account_balance,
    TxType.subscription => Icons.workspace_premium,
    TxType.bonus => Icons.emoji_events,
    TxType.topUp => Icons.add_card,
  };
}

/// Wallet movement. Later: the `driver_wallet_transactions` table.
class WalletTx {
  const WalletTx({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.title,
    this.subtitle,
  });

  final String id;
  final TxType type;

  /// Positive = money in, negative = money out.
  final int amount;
  final DateTime date;
  final String title;
  final String? subtitle;
}

class Quest {
  const Quest({
    required this.title,
    required this.target,
    required this.done,
    required this.reward,
    required this.ends,
    this.todoText,
    this.doneText,
  });

  final String title;
  final String? todoText;
  final String? doneText;
  final int target;
  final int done;
  final int reward;
  final DateTime ends;

  double get progress => (done / target).clamp(0, 1);
  bool get completed => done >= target;
}

class EarningsState {
  const EarningsState({
    this.trips = const [],
    this.txs = const [],
    this.onlineMinutesByDay = const {},
    this.questPaid = false,
    this.power = const PowerConfig(),
  });

  /// Power Driver day rules from the server (app_settings).
  final PowerConfig power;

  /// Newest first.
  final List<TripRecord> trips;

  /// Newest first.
  final List<WalletTx> txs;

  /// Minutes online per day (key: yyyy-mm-dd), for the earnings chart.
  final Map<String, int> onlineMinutesByDay;
  final bool questPaid;

  int get balance => txs.fold(0, (a, t) => a + t.amount);

  List<TripRecord> get completed => trips.where((t) => !t.cancelled).toList();

  List<TripRecord> tripsOn(DateTime day) => completed
      .where(
        (t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day,
      )
      .toList();

  int earnedOn(DateTime day) => tripsOn(day).fold(0, (a, t) => a + t.net);

  /// Monday of the week [weeksAgo] weeks back.
  static DateTime weekStart([int weeksAgo = 0]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1 + 7 * weeksAgo));
  }

  List<TripRecord> tripsInWeek([int weeksAgo = 0]) {
    final start = weekStart(weeksAgo);
    final end = start.add(const Duration(days: 7));
    return completed
        .where((t) => !t.date.isBefore(start) && t.date.isBefore(end))
        .toList();
  }

  Quest get weeklyQuest {
    final start = weekStart();
    return Quest(
      title: 'Complete 25 trips this week',
      target: 25,
      done: tripsInWeek().length,
      reward: 6000,
      ends: start.add(const Duration(days: 7)),
    );
  }

  /// Power Driver day: lower commission once today's target is reached.
  Quest get powerDay {
    final now = DateTime.now();
    final done = tripsOn(now).length;
    final left = power.trips - done;
    return Quest(
      title: 'Power Driver day',
      target: power.trips,
      done: done,
      reward: 0,
      ends: DateTime(now.year, now.month, now.day + 1),
      todoText:
          '$left more trip${left == 1 ? '' : 's'} today for ${power.rate}% commission all day',
      doneText: 'Power Driver day! ${power.rate}% commission for all of today',
    );
  }

  double get averageRating {
    final rated = trips.where((t) => t.ratingFromRider != null).take(100);
    if (rated.isEmpty) return 5;
    return rated.fold(0, (a, t) => a + t.ratingFromRider!) / rated.length;
  }

  double get acceptanceRate => trips.isEmpty ? 1 : 0.92;

  double get cancellationRate {
    final recent = trips.take(50).toList();
    if (recent.isEmpty) return 0;
    return recent.where((t) => t.cancelled).length / recent.length;
  }

  EarningsState copyWith({
    List<TripRecord>? trips,
    List<WalletTx>? txs,
    Map<String, int>? onlineMinutesByDay,
    bool? questPaid,
    PowerConfig? power,
  }) {
    return EarningsState(
      power: power ?? this.power,
      trips: trips ?? this.trips,
      txs: txs ?? this.txs,
      onlineMinutesByDay: onlineMinutesByDay ?? this.onlineMinutesByDay,
      questPaid: questPaid ?? this.questPaid,
    );
  }
}

class PowerConfig {
  const PowerConfig({this.enabled = true, this.trips = 20, this.rate = 7});
  final bool enabled;
  final int trips;
  final num rate;
}

String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Trips, wallet and payouts from Supabase. Money only moves on the
/// server: trip earnings, commission, tips, payouts and subscriptions.
class EarningsController extends Notifier<EarningsState> {
  RealtimeChannel? _channel;

  @override
  EarningsState build() {
    ref.onDispose(() => _channel?.unsubscribe());
    return const EarningsState();
  }

  /// Loads trips and wallet history, and reloads when money moves.
  Future<void> load() async {
    final uid = Backend.user?.id;
    if (uid == null) return;
    try {
      final results = await Future.wait(<Future<dynamic>>[
        Backend.db.rpc('my_driver_trips'),
        Backend.db
            .from('wallet_transactions')
            .select()
            .order('created_at', ascending: false)
            .limit(1000),
        Backend.db
            .from('app_settings')
            .select(
              'power_driver_enabled, power_driver_trips, power_driver_rate',
            )
            .eq('id', 1)
            .maybeSingle(),
      ]);
      final ps = results[2] as Map<String, dynamic>?;
      final trips = [
        for (final t in results[0] as List)
          _trip(Map<String, dynamic>.from(t as Map)),
      ];
      final txs = [
        for (final r in results[1] as List)
          _tx(Map<String, dynamic>.from(r as Map)),
      ];
      state = state.copyWith(
        trips: trips,
        txs: txs,
        power: ps == null
            ? null
            : PowerConfig(
                enabled: ps['power_driver_enabled'] == true,
                trips: (ps['power_driver_trips'] as num).toInt(),
                rate: ps['power_driver_rate'] as num,
              ),
      );
    } catch (_) {}
    _channel ??= Backend.db
        .channel('driver-wallet-$uid')
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
            final r = p.newRecord;
            if (r['kind'] == 'tip') {
              ref
                  .read(notificationsProvider.notifier)
                  .notify(
                    NotifyCategory.earnings,
                    'You got a tip',
                    '${naira((r['amount'] as num).toInt())} from your rider. Thank you for great service!',
                    route: '/wallet',
                  );
            }
            load();
          },
        )
        .subscribe();
  }

  static TripRecord _trip(Map<String, dynamic> t) {
    final cancelled = t['status'] == 'cancelled';
    return TripRecord(
      id: t['id'] as String,
      date:
          parseTime(
            t['completed_at'] ?? t['cancelled_at'] ?? t['requested_at'],
          ) ??
          DateTime.now(),
      riderName: ((t['rider_name'] as String?) ?? '').trim().isEmpty
          ? 'Rider'
          : t['rider_name'] as String,
      pickup: t['pickup_address'] as String,
      dropoff: t['dropoff_address'] as String,
      rideTypeId: t['ride_type_id'] as String,
      km: (t['distance_km'] as num).toDouble(),
      minutes: (t['duration_min'] as num).round(),
      fare:
          (t['fare'] as num).toInt() +
          ((t['waiting_fee'] as num?)?.toInt() ?? 0),
      commission: (t['commission'] as num?)?.toInt() ?? 0,
      payment: t['payment'] == 'cash' ? PaymentKind.cash : PaymentKind.wallet,
      tip: (t['tip'] as num?)?.toInt() ?? 0,
      waitingFee: (t['waiting_fee'] as num?)?.toInt() ?? 0,
      ratingFromRider: (t['rider_stars'] as num?)?.toInt(),
      ratingGiven: (t['driver_stars'] as num?)?.toInt(),
      riderComment: t['rider_comment'] as String?,
      cancelled: cancelled,
      cancelReason: t['cancel_reason'] as String?,
    );
  }

  static WalletTx _tx(Map<String, dynamic> r) {
    final amount = (r['amount'] as num).toInt();
    return WalletTx(
      id: r['id'] as String,
      type: switch (r['kind'] as String) {
        'trip_earning' => TxType.tripEarning,
        'commission' => TxType.cashCommission,
        'tip' => TxType.tip,
        'payout' => TxType.payout,
        'subscription' => TxType.subscription,
        'bonus' || 'referral' => TxType.bonus,
        _ => amount < 0 ? TxType.cashCommission : TxType.topUp,
      },
      amount: amount,
      date: parseTime(r['created_at']) ?? DateTime.now(),
      title: r['title'] as String,
    );
  }

  /// After a trip ends the server has already paid the driver; reload.
  void recordTrip(TripRecord trip) => load();

  void addOnlineMinutes(int minutes) {
    final key = dayKey(DateTime.now());
    state = state.copyWith(
      onlineMinutesByDay: {
        ...state.onlineMinutesByDay,
        key: (state.onlineMinutesByDay[key] ?? 0) + minutes,
      },
    );
  }

  /// Asks for a payout. The money leaves the wallet straight away and the
  /// GoRide finance team (later: Paystack Transfers) sends it to the bank.
  Future<String> payout(int amount, BankDetails bank) async {
    final p = await Backend.db.rpc(
      'request_payout',
      params: {'p_amount': amount},
    );
    await load();
    ref
        .read(notificationsProvider.notifier)
        .notify(
          NotifyCategory.earnings,
          'Payout requested',
          '${naira(amount)} to your ${bank.bank} account. We will tell you when it is sent.',
          route: '/wallet',
        );
    return ((p as Map)['id'] as String).substring(0, 8).toUpperCase();
  }

  /// Paystack top-ups are credited by the server; just reload.
  void topUp(int amount, String reference) => load();

  /// Pays a subscription from the wallet on the server.
  /// Returns false if the wallet is short.
  Future<bool> paySubscription(int amount, SubscriptionPeriod period) async {
    if (state.balance < amount) return false;
    try {
      await Backend.db.rpc(
        'pay_subscription',
        params: {'p_period': period.name},
      );
    } catch (_) {
      return false;
    }
    await load();
    await ref.read(registrationProvider.notifier).load();
    return true;
  }

  void seedDemo() => load();

  void reset() {
    _channel?.unsubscribe();
    _channel = null;
    state = const EarningsState();
  }
}

final earningsProvider = NotifierProvider<EarningsController, EarningsState>(
  EarningsController.new,
);
