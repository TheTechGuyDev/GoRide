import 'dart:math';

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
  });

  final String title;
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
  });

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
  }) {
    return EarningsState(
      trips: trips ?? this.trips,
      txs: txs ?? this.txs,
      onlineMinutesByDay: onlineMinutesByDay ?? this.onlineMinutesByDay,
      questPaid: questPaid ?? this.questPaid,
    );
  }
}

String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Trips, wallet and payouts. Mock now; Supabase tables later.
class EarningsController extends Notifier<EarningsState> {
  int _seq = 0;
  String _id(String p) => '$p${DateTime.now().millisecondsSinceEpoch}${_seq++}';

  @override
  EarningsState build() => const EarningsState();

  void _notify(NotifyCategory c, String title, String body, {String? route}) {
    ref
        .read(notificationsProvider.notifier)
        .notify(c, title, body, route: route);
  }

  /// A trip just finished: record it and move money.
  void recordTrip(TripRecord trip) {
    final txs = <WalletTx>[];
    if (!trip.cancelled) {
      if (trip.payment == PaymentKind.cash) {
        if (trip.commission > 0) {
          txs.add(
            WalletTx(
              id: _id('tx'),
              type: TxType.cashCommission,
              amount: -trip.commission,
              date: trip.date,
              title: 'Commission on cash trip',
              subtitle: 'You collected ${naira(trip.fare)} cash',
            ),
          );
        }
      } else {
        txs.add(
          WalletTx(
            id: _id('tx'),
            type: TxType.tripEarning,
            amount: trip.fare - trip.commission,
            date: trip.date,
            title: 'Trip with ${trip.riderName}',
            subtitle: trip.commission > 0
                ? '${naira(trip.fare)} fare, ${naira(trip.commission)} commission'
                : '${naira(trip.fare)} fare, no commission (subscription)',
          ),
        );
      }
    }
    state = state.copyWith(
      trips: [trip, ...state.trips],
      txs: [...txs.reversed, ...state.txs],
    );
    _checkQuest();
  }

  /// Rider added a tip after the trip.
  void addTip(String tripId, int amount) {
    state = state.copyWith(
      trips: [
        for (final t in state.trips)
          t.id == tripId ? t.copyWith(tip: t.tip + amount) : t,
      ],
      txs: [
        WalletTx(
          id: _id('tx'),
          type: TxType.tip,
          amount: amount,
          date: DateTime.now(),
          title: 'Tip from rider',
        ),
        ...state.txs,
      ],
    );
    _notify(
      NotifyCategory.earnings,
      'You got a ${naira(amount)} tip',
      'Your rider appreciated the trip. It\'s in your wallet.',
      route: '/wallet',
    );
  }

  void rateFromRider(String tripId, int stars, String? comment) {
    state = state.copyWith(
      trips: [
        for (final t in state.trips)
          t.id == tripId
              ? t.copyWith(ratingFromRider: stars, riderComment: comment)
              : t,
      ],
    );
  }

  void _checkQuest() {
    final q = state.weeklyQuest;
    if (q.completed && !state.questPaid) {
      state = state.copyWith(
        questPaid: true,
        txs: [
          WalletTx(
            id: _id('tx'),
            type: TxType.bonus,
            amount: q.reward,
            date: DateTime.now(),
            title: 'Weekly quest bonus',
            subtitle: q.title,
          ),
          ...state.txs,
        ],
      );
      _notify(
        NotifyCategory.incentives,
        'Quest complete: ${naira(q.reward)} bonus',
        'You finished ${q.target} trips this week. The bonus is in your wallet.',
        route: '/wallet',
      );
    }
  }

  void addOnlineMinutes(int minutes) {
    final k = dayKey(DateTime.now());
    state = state.copyWith(
      onlineMinutesByDay: {
        ...state.onlineMinutesByDay,
        k: (state.onlineMinutesByDay[k] ?? 0) + minutes,
      },
    );
  }

  /// Instant payout to the driver's bank (later: Paystack Transfers API,
  /// started from a Supabase Edge Function).
  Future<String> payout(int amount, BankDetails bank) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    final ref0 = 'TRF_${DateTime.now().millisecondsSinceEpoch % 100000000}';
    state = state.copyWith(
      txs: [
        WalletTx(
          id: _id('tx'),
          type: TxType.payout,
          amount: -amount,
          date: DateTime.now(),
          title: 'Payout to ${bank.bank}',
          subtitle: '${bank.accountName} · ${bank.accountNumber}',
        ),
        ...state.txs,
      ],
    );
    _notify(
      NotifyCategory.earnings,
      'Payout sent',
      '${naira(amount)} is on its way to your ${bank.bank} account.',
      route: '/wallet',
    );
    return ref0;
  }

  /// Funds added with Paystack, e.g. to clear cash commission owed.
  void topUp(int amount, String reference) {
    state = state.copyWith(
      txs: [
        WalletTx(
          id: _id('tx'),
          type: TxType.topUp,
          amount: amount,
          date: DateTime.now(),
          title: 'Wallet top up',
          subtitle: 'Ref $reference',
        ),
        ...state.txs,
      ],
    );
  }

  /// Pay a subscription from the wallet. Returns false if funds are short.
  bool paySubscription(int amount, SubscriptionPeriod period) {
    if (state.balance < amount) return false;
    state = state.copyWith(
      txs: [
        WalletTx(
          id: _id('tx'),
          type: TxType.subscription,
          amount: -amount,
          date: DateTime.now(),
          title: '${period.label} subscription',
          subtitle: 'Keep 100% of every fare',
        ),
        ...state.txs,
      ],
    );
    return true;
  }

  /// Preview: realistic history for the demo driver.
  void seedDemo() {
    final rand = Random(7);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trips = <TripRecord>[];
    final txs = <WalletTx>[];
    final online = <String, int>{};
    var balance = 0;

    for (var d = 20; d >= 0; d--) {
      final day = today.subtract(Duration(days: d));
      // Today: only a few trips so far, done earlier in the morning.
      final count = d == 0 ? 3 : 3 + rand.nextInt(7);
      var minute = 6 * 60 + 30 + rand.nextInt(60);
      online[dayKey(day)] = d == 0 ? 95 : 180 + rand.nextInt(300);

      for (var i = 0; i < count; i++) {
        final from = _demoPlaces[rand.nextInt(_demoPlaces.length)];
        var to = _demoPlaces[rand.nextInt(_demoPlaces.length)];
        if (to == from) {
          to =
              _demoPlaces[(_demoPlaces.indexOf(from) + 3) % _demoPlaces.length];
        }
        final km = 3 + rand.nextDouble() * 18;
        final mins = (km * 3.2 + rand.nextInt(15)).round();
        final type = rand.nextInt(4) == 0 ? 'comfort' : 'car';
        final rt = rideTypes.firstWhere((r) => r.id == type);
        final fare = roundFare(
          max(
            rt.minimumFare,
            rt.baseFare + rt.perKm * km + rt.perMinute * mins,
          ),
        );
        final payment = switch (rand.nextInt(10)) {
          < 5 => PaymentKind.cash,
          < 8 => PaymentKind.wallet,
          _ => PaymentKind.card,
        };
        final cancelled = rand.nextInt(18) == 0;
        final commission = (fare * PlanPricing.commissionRate).round();
        final tip = !cancelled && rand.nextInt(6) == 0
            ? [200, 300, 500, 1000][rand.nextInt(4)]
            : 0;
        final rating = cancelled ? null : (rand.nextInt(9) == 0 ? 4 : 5);
        minute += 20 + rand.nextInt(55);
        final date = day.add(Duration(minutes: minute));
        if (date.isAfter(now)) break;
        final t = TripRecord(
          id: 'T${date.millisecondsSinceEpoch ~/ 1000}',
          date: date,
          riderName: _demoRiders[rand.nextInt(_demoRiders.length)],
          pickup: from,
          dropoff: to,
          rideTypeId: type,
          km: double.parse(km.toStringAsFixed(1)),
          minutes: mins,
          fare: fare,
          commission: commission,
          payment: payment,
          tip: tip,
          ratingFromRider: rating,
          ratingGiven: cancelled ? null : 5,
          riderComment: rating != null && rand.nextInt(5) == 0
              ? _demoComments[rand.nextInt(_demoComments.length)]
              : null,
          cancelled: cancelled,
          cancelReason: cancelled ? 'Rider cancelled' : null,
        );
        trips.add(t);
        if (!cancelled) {
          if (payment == PaymentKind.cash) {
            txs.add(
              WalletTx(
                id: 'c${t.id}',
                type: TxType.cashCommission,
                amount: -commission,
                date: date,
                title: 'Commission on cash trip',
                subtitle: 'You collected ${naira(fare)} cash',
              ),
            );
            balance -= commission;
          } else {
            txs.add(
              WalletTx(
                id: 'e${t.id}',
                type: TxType.tripEarning,
                amount: fare - commission,
                date: date,
                title: 'Trip with ${t.riderName}',
                subtitle:
                    '${naira(fare)} fare, ${naira(commission)} commission',
              ),
            );
            balance += fare - commission;
          }
          if (tip > 0) {
            txs.add(
              WalletTx(
                id: 'p${t.id}',
                type: TxType.tip,
                amount: tip,
                date: date.add(const Duration(minutes: 5)),
                title: 'Tip from ${t.riderName.split(' ').first}',
              ),
            );
            balance += tip;
          }
        }
      }
      // Payout every 3 days, keeping a little in the wallet.
      if (d % 3 == 1 && balance > 8000) {
        final amount = ((balance - 3000) / 1000).floor() * 1000;
        txs.add(
          WalletTx(
            id: 'po$d',
            type: TxType.payout,
            amount: -amount,
            date: day.add(const Duration(hours: 21)),
            title: 'Payout to GTBank',
            subtitle: 'TUNDE BAKARE · 0123456789',
          ),
        );
        balance -= amount;
      }
    }
    // No trips yet today (e.g. early morning): no online time either.
    if (!trips.any((t) => dayKey(t.date) == dayKey(today))) {
      online[dayKey(today)] = 0;
    }
    trips.sort((a, b) => b.date.compareTo(a.date));
    txs.sort((a, b) => b.date.compareTo(a.date));
    state = EarningsState(trips: trips, txs: txs, onlineMinutesByDay: online);
    // Pay this week's quest bonus if the seeded trips already completed it.
    final q = state.weeklyQuest;
    if (q.completed) {
      state = state.copyWith(
        questPaid: true,
        txs: [
          WalletTx(
            id: 'quest',
            type: TxType.bonus,
            amount: q.reward,
            date: trips.firstWhere((t) => !t.cancelled).date,
            title: 'Weekly quest bonus',
            subtitle: q.title,
          ),
          ...state.txs,
        ],
      );
    }
  }

  void reset() => state = const EarningsState();
}

final earningsProvider = NotifierProvider<EarningsController, EarningsState>(
  EarningsController.new,
);

const _demoPlaces = [
  'Ikeja City Mall',
  'Yaba Tech',
  'Lekki Phase 1',
  'Victoria Island',
  'Murtala Muhammed Airport',
  'Surulere',
  'Ajah',
  'Maryland Mall',
  'Ikoyi',
  'Unilag',
  'Obalende',
  'Gbagada',
  'Festac Town',
  'Allen Avenue',
  'Oshodi',
];

const _demoRiders = [
  'Adaeze Okafor',
  'Bola Adeyemi',
  'Chinedu Eze',
  'Damilola Ojo',
  'Emeka Nwosu',
  'Funke Akindele',
  'Ibrahim Musa',
  'Kemi Adebayo',
  'Ngozi Obi',
  'Segun Williams',
  'Tolu Bankole',
  'Yemi Alade',
  'Zainab Bello',
];

const _demoComments = [
  'Very polite and the car was clean.',
  'Smooth driving, thank you!',
  'Knew the route well, avoided traffic.',
  'Great music and AC was working.',
  'On time and professional.',
];
