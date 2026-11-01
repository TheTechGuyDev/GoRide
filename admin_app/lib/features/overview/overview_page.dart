import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/ui.dart';
import '../../data/live.dart';
import '../../data/models.dart';
import '../../data/store.dart';

/// Scrollable page body with standard padding.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: EdgeInsets.all(narrow ? 16 : 28),
      children: children,
    );
  }
}

/// Two widgets side by side on wide screens, stacked on narrow ones.
class SplitRow extends StatelessWidget {
  const SplitRow({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 2,
    this.rightFlex = 1,
    this.breakpoint = 1000,
  });
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 16),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

const shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String dayLabel(DateTime d) => '${d.day} ${shortMonths[d.month - 1]}';

Color rideColor(String id) => switch (id) {
  'bike' => AC.orange,
  'keke' => AC.purple,
  'comfort' => AC.blue,
  'xl' => AC.teal,
  _ => AC.primary,
};

String rideName(String id) => rideTypes
    .firstWhere((r) => r.id == id, orElse: () => rideTypes[2])
    .name
    .replaceFirst('GoRide ', '');

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final live = ref.watch(liveProvider);
    final me = ref.watch(sessionProvider)!;
    final allowed = me.role.sections;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTrips = data.tripsOn(today);
    final yesterdayTrips = data
        .tripsOn(today.subtract(const Duration(days: 1)))
        .where(
          (t) =>
              t.date.hour < now.hour ||
              (t.date.hour == now.hour && t.date.minute <= now.minute),
        )
        .toList();
    final done = todayTrips
        .where((t) => t.status == TripStatus.completed)
        .toList();
    final commissionToday = done.fold(0, (a, t) => a + t.commission);
    final subsToday = data.subscriptions
        .where((s) => s.date.isAfter(today))
        .fold(0, (a, s) => a + s.amount);
    final revenueToday = commissionToday + subsToday;
    final online = data.drivers.where((d) => d.online).length;
    final activeDrivers = data.drivers
        .where((d) => d.status == DriverStatus.active)
        .length;
    final change = yesterdayTrips.isEmpty
        ? 0
        : ((todayTrips.length - yesterdayTrips.length) /
                  yesterdayTrips.length *
                  100)
              .round();

    // Last 14 days: bookings (fares) and GoRide revenue.
    final days = [
      for (var i = 13; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final bookings = <num>[];
    final revenue = <num>[];
    for (final d in days) {
      final t = data.tripsOn(d).where((t) => t.status == TripStatus.completed);
      bookings.add(t.fold(0, (a, x) => a + x.fare));
      revenue.add(
        t.fold(0, (a, x) => a + x.commission) +
            data.subscriptions
                .where(
                  (s) =>
                      s.date.year == d.year &&
                      s.date.month == d.month &&
                      s.date.day == d.day,
                )
                .fold(0, (a, s) => a + s.amount),
      );
    }

    // Trips by service (last 7 days)
    final week = data.trips.where(
      (t) => t.date.isAfter(today.subtract(const Duration(days: 7))),
    );
    final byType = <String, int>{};
    for (final t in week) {
      byType[t.rideTypeId] = (byType[t.rideTypeId] ?? 0) + 1;
    }

    final openSafety = data.safety
        .where((s) => s.status != SafetyStatus.resolved)
        .toList();

    return PageBody(
      children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B6B39), Color(0xFF0A3B22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 16,
            spacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${greeting()}, ${me.name.split(' ').first}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${live.trips.length} trips on the road, $online drivers online, ${data.pendingDrivers.length} applications waiting.',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (openSafety.isNotEmpty && allowed.contains(Section.safety))
                    InkWell(
                      onTap: () => context.go(R.safety),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AC.red.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sos,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${openSafety.length} safety alert${openSafety.length == 1 ? '' : 's'} open',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (allowed.contains(Section.applications))
                    FilledButton.icon(
                      onPressed: () => context.go(R.applications),
                      style: FilledButton.styleFrom(
                        backgroundColor: AC.lime,
                        foregroundColor: const Color(0xFF07140D),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.how_to_reg),
                      label: const Text(
                        'Review drivers',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ResponsiveGrid(
          minItemWidth: 230,
          children: [
            StatCard(
              icon: Icons.route,
              color: AC.primary,
              label: 'Trips today',
              value: '${todayTrips.length}',
              foot: '${change >= 0 ? '+' : ''}$change% vs this time yesterday',
              footColor: change >= 0 ? AC.primary : AC.red,
              onTap: allowed.contains(Section.trips)
                  ? () => context.go(R.trips)
                  : null,
            ),
            StatCard(
              icon: Icons.directions_car,
              color: AC.blue,
              label: 'Drivers online',
              value: '$online',
              foot: 'of $activeDrivers active drivers',
              onTap: allowed.contains(Section.liveMap)
                  ? () => context.go(R.live)
                  : null,
            ),
            StatCard(
              icon: Icons.show_chart,
              color: AC.purple,
              label: 'GoRide revenue today',
              value: naira(revenueToday),
              foot:
                  '${naira(commissionToday)} commission · ${naira(subsToday)} plans',
              onTap: allowed.contains(Section.revenue)
                  ? () => context.go(R.revenue)
                  : null,
            ),
            StatCard(
              icon: Icons.pending_actions,
              color: AC.orange,
              label: 'Waiting for you',
              value:
                  '${data.pendingDrivers.length + data.openTickets + data.pendingPayouts}',
              foot:
                  '${data.pendingDrivers.length} drivers · ${data.openTickets} tickets · ${data.pendingPayouts} payouts',
            ),
          ],
        ),
        const SizedBox(height: 16),
        SplitRow(
          left: Panel(
            title: 'Bookings and revenue',
            subtitle: 'Last 14 days. Green: fares paid by riders. Blue: GoRide\'s share',
            child: AreaChart(
              values: bookings,
              second: revenue,
              labels: [for (final d in days) dayLabel(d)],
            ),
          ),
          right: Panel(
            title: 'Trips by service',
            subtitle: 'Last 7 days',
            child: Center(
              child: Donut(
                centreValue: '${week.length}',
                centreLabel: 'trips',
                items: [
                  for (final t in rideTypes)
                    (
                      t.name.replaceFirst('GoRide ', ''),
                      byType[t.id] ?? 0,
                      rideColor(t.id),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SplitRow(
          left: Panel(
            title: 'Recent trips',
            subtitle: 'Latest across Lagos',
            flushBody: true,
            action: allowed.contains(Section.trips)
                ? TextButton(
                    onPressed: () => context.go(R.trips),
                    child: const Text(
                      'All trips',
                      style: TextStyle(
                        color: AC.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
            child: DataGrid(
              minWidth: 640,
              flex: const [3, 3, 2, 2],
              columns: const ['Route', 'Driver', 'Fare', 'Status'],
              rows: [
                for (final t in data.trips.take(6))
                  [
                    CellTitle(t.pickup, 'to ${t.dropoff}'),
                    CellTitle(
                      t.driverName,
                      '${rideName(t.rideTypeId)} · ${formatTime(t.date)}',
                    ),
                    Text(
                      t.fare == 0 ? '-' : naira(t.fare),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Pill(t.status.label, color: t.status.color),
                  ],
              ],
            ),
          ),
          right: Panel(
            title: 'Safety queue',
            subtitle: 'Open SOS and route alerts',
            action: allowed.contains(Section.safety)
                ? TextButton(
                    onPressed: () => context.go(R.safety),
                    child: const Text(
                      'Open queue',
                      style: TextStyle(
                        color: AC.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
            child: openSafety.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AC.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: AC.blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('No open alerts.'),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final s in openSafety)
                        InkWell(
                          onTap: allowed.contains(Section.safety)
                              ? () => context.go(R.safety)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: s.kind.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: s.kind.color.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(s.kind.icon, color: s.kind.color),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CellTitle(
                                    '${s.kind.label} · ${s.riderName}',
                                    '${s.place} · ${ago(s.time)}',
                                  ),
                                ),
                                Pill(s.status.label, color: s.status.color),
                              ],
                            ),
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
