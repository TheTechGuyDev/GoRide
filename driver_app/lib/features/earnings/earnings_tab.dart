import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../driving/driver_controller.dart';
import '../registration/plans.dart';
import '../registration/registration_controller.dart';
import 'earnings_controller.dart';

class EarningsTab extends ConsumerStatefulWidget {
  const EarningsTab({super.key});

  @override
  ConsumerState<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends ConsumerState<EarningsTab> {
  int _weeksAgo = 0;

  /// null = default (today this week), -1 = whole week, 0 = Monday.
  int? _day;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(earningsProvider);
    final reg = ref.watch(registrationProvider);
    final start = EarningsState.weekStart(_weeksAgo);
    final now = DateTime.now();
    final todayIndex = _weeksAgo == 0 ? now.weekday - 1 : null;
    final selectedDay = _day == -1 ? null : (_day ?? todayIndex);

    final perDay = [
      for (var i = 0; i < 7; i++) e.earnedOn(start.add(Duration(days: i))),
    ];
    final trips = selectedDay == null
        ? e.tripsInWeek(_weeksAgo)
        : e.tripsOn(start.add(Duration(days: selectedDay)));
    final total = selectedDay == null
        ? perDay.fold(0, (a, b) => a + b)
        : perDay[selectedDay];
    final fares = trips.fold(0, (a, t) => a + t.fare);
    final commission = trips.fold(0, (a, t) => a + t.commission);
    final tips = trips.fold(0, (a, t) => a + t.tip);
    final onlineMins = selectedDay == null
        ? [
            for (var i = 0; i < 7; i++)
              e.onlineMinutesByDay[dayKey(start.add(Duration(days: i)))] ?? 0,
          ].fold(0, (a, b) => a + b)
        : e.onlineMinutesByDay[dayKey(
                start.add(Duration(days: selectedDay)),
              )] ??
              0;
    final weekBonus = e.txs
        .where(
          (t) =>
              t.type == TxType.bonus &&
              !t.date.isBefore(start) &&
              t.date.isBefore(start.add(const Duration(days: 7))),
        )
        .fold(0, (a, t) => a + t.amount);
    final balance = e.balance;
    final plan = reg.plan ?? const DriverPlan();
    final quest = e.weeklyQuest;

    final periodLabel = selectedDay == null
        ? '${formatDate(start).split(',').first} - ${formatDate(start.add(const Duration(days: 6))).split(',').first}'
        : selectedDay == todayIndex
        ? 'Today'
        : '${_days[selectedDay]}, ${formatDate(start.add(Duration(days: selectedDay))).split(',').first}';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Earnings'),
        actions: [
          IconButton(
            tooltip: 'All transactions',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(Routes.transactions),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Week selector
          Row(
            children: [
              IconButton(
                onPressed: _weeksAgo >= 2
                    ? null
                    : () => setState(() {
                        _weeksAgo++;
                        _day = null;
                      }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _weeksAgo == 0
                      ? 'This week'
                      : _weeksAgo == 1
                      ? 'Last week'
                      : '2 weeks ago',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _weeksAgo == 0
                    ? null
                    : () => setState(() {
                        _weeksAgo--;
                        _day = null;
                      }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          GoCard(
            child: Column(
              children: [
                Text(
                  periodLabel,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  naira(total),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: _WeekBars(
                    values: perDay,
                    labels: _days,
                    selected: selectedDay,
                    today: todayIndex,
                    onTap: (i) =>
                        setState(() => _day = selectedDay == i ? -1 : i),
                  ),
                ),
                if (selectedDay != null)
                  TextButton(
                    onPressed: () => setState(() => _day = -1),
                    child: const Text('Show whole week'),
                  ),
                const Divider(height: 24),
                Row(
                  children: [
                    StatTile(value: '${trips.length}', label: 'Trips'),
                    StatTile(
                      value: formatDuration(Duration(minutes: onlineMins)),
                      label: 'Online',
                    ),
                    StatTile(
                      value: trips.isEmpty ? '-' : naira(total / trips.length),
                      label: 'Per trip',
                    ),
                  ],
                ),
              ],
            ),
          ),
          GoCard(
            child: Column(
              children: [
                _Row('Fares', naira(fares)),
                _Row(
                  plan.isSubscription && commission == 0
                      ? 'Commission (subscription)'
                      : 'GoRide commission',
                  commission == 0 ? naira(0) : '-${naira(commission)}',
                ),
                _Row('Tips', naira(tips)),
                if (selectedDay == null) _Row('Bonuses', naira(weekBonus)),
                const Divider(height: 20),
                _Row(
                  'Total earnings',
                  naira(total + (selectedDay == null ? weekBonus : 0)),
                  bold: true,
                ),
              ],
            ),
          ),
          if (_weeksAgo == 0)
            GoCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quest.completed
                              ? 'Done! ${naira(quest.reward)} added to your wallet'
                              : '${quest.done} of ${quest.target} · ${naira(quest.reward)} bonus · ends Sunday',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: quest.progress,
                            minHeight: 7,
                            color: AppColors.warning,
                            backgroundColor: AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Wallet
          GoCard(
            onTap: () => context.push(Routes.wallet),
            color: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'GoRide wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  balance < 0 ? 'You owe ${naira(-balance)}' : naira(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balance < 0
                      ? 'Commission from cash trips. Settle before it reaches ${naira(DriverController.debtLimit)}.'
                      : 'Available to cash out',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => balance < 0
                        ? context.push(Routes.settle, extra: -balance)
                        : context.push(Routes.payout),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      balance < 0 ? 'Settle balance' : 'Cash out',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GoCard(
            onTap: () => context.push(Routes.plan),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        plan.isSubscription
                            ? (plan.subscriptionActive
                                  ? 'Active until ${formatDate(plan.paidUntil!)}'
                                  : 'Expired. Renew to go online')
                            : 'Driving full-time? A subscription could save you money',
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
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? null : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: bold ? 17 : 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({
    required this.values,
    required this.labels,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final List<int> values;
  final List<String> labels;
  final int? selected;
  final int? today;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final maxV = max(1, values.reduce(max));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (selected == i && values[i] > 0)
                    FittedBox(
                      child: Text(
                        naira(values[i]),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: max(4, 100 * values[i] / maxV),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: selected == null || selected == i
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: today == i
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: today == i
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
