import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/theme/admin_theme.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../overview/overview_page.dart';
import 'engine_panel.dart';

// ---------------- Revenue ----------------

class RevenuePage extends ConsumerStatefulWidget {
  const RevenuePage({super.key});

  @override
  ConsumerState<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends ConsumerState<RevenuePage> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storeProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: _days - 1));
    final prevStart = start.subtract(Duration(days: _days));

    bool inRange(DateTime d, DateTime a, DateTime b) =>
        !d.isBefore(a) && d.isBefore(b);
    final trips = data.trips
        .where(
          (t) => t.status == TripStatus.completed && !t.date.isBefore(start),
        )
        .toList();
    final prevTrips = data.trips
        .where(
          (t) =>
              t.status == TripStatus.completed &&
              inRange(t.date, prevStart, start),
        )
        .toList();
    final subs = data.subscriptions
        .where((s) => !s.date.isBefore(start))
        .toList();

    final gross = trips.fold(0, (a, t) => a + t.fare);
    final commission = trips.fold(0, (a, t) => a + t.commission);
    final subRevenue = subs.fold(0, (a, s) => a + s.amount);
    final refunds = data.trips
        .where((t) => !t.date.isBefore(start))
        .fold(0, (a, t) => a + t.refunded);
    final revenue = commission + subRevenue - refunds;
    final prevRevenue = prevTrips.fold(0, (a, t) => a + t.commission);
    final growth = prevRevenue == 0
        ? 0
        : ((commission - prevRevenue) / prevRevenue * 100).round();
    final cash = trips
        .where((t) => t.payment == 'cash')
        .fold(0, (a, t) => a + t.fare);
    final owed = data.drivers
        .where((d) => d.wallet < 0)
        .fold(0, (a, d) => a - d.wallet);

    final days = [
      for (var i = _days - 1; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final dailyCommission = <num>[];
    final dailySubs = <num>[];
    for (final d in days) {
      bool same(DateTime x) =>
          x.year == d.year && x.month == d.month && x.day == d.day;
      dailyCommission.add(
        trips.where((t) => same(t.date)).fold(0, (a, t) => a + t.commission),
      );
      dailySubs.add(
        subs.where((s) => same(s.date)).fold(0, (a, s) => a + s.amount),
      );
    }
    final daily = [
      for (var i = 0; i < days.length; i++) dailyCommission[i] + dailySubs[i],
    ];

    final byService = {
      for (final r in rideTypes)
        r.id: trips
            .where((t) => t.rideTypeId == r.id)
            .fold(0, (a, t) => a + t.fare),
    };

    // Busiest hours
    final hours = List<num>.filled(24, 0);
    for (final t in trips) {
      hours[t.date.hour]++;
    }

    return PageBody(
      children: [
        PageHeader(
          title: 'Revenue',
          subtitle: 'GoRide earns from commission on trips and from driver subscriptions',
          actions: [
            FilterChips(
              options: const ['7 days', '30 days', '45 days'],
              value: '$_days days',
              onChanged: (v) =>
                  setState(() => _days = int.parse(v.split(' ').first)),
            ),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(
              icon: Icons.receipt_long,
              color: AC.blue,
              label: 'Gross bookings',
              value: naira(gross),
              foot: '${trips.length} completed trips',
            ),
            StatCard(
              icon: Icons.trending_up,
              color: AC.primary,
              label: 'GoRide revenue',
              value: naira(revenue),
              foot:
                  '${growth >= 0 ? '+' : ''}$growth% commission vs previous $_days days',
              footColor: growth >= 0 ? AC.primary : AC.red,
            ),
            StatCard(
              icon: Icons.workspace_premium,
              color: AC.purple,
              label: 'Subscriptions',
              value: naira(subRevenue),
              foot: '${subs.length} payments',
            ),
            StatCard(
              icon: Icons.payments,
              color: AC.orange,
              label: 'Paid in cash',
              value: '${gross == 0 ? 0 : (cash / gross * 100).round()}%',
              foot: '${naira(owed)} commission owed by drivers',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Daily revenue',
          subtitle: 'Green: commission + subscriptions. Blue dashed: subscriptions only',
          child: AreaChart(
            values: daily,
            second: dailySubs,
            labels: [for (final d in days) dayLabel(d)],
            height: 280,
          ),
        ),
        const SizedBox(height: 16),
        SplitRow(
          leftFlex: 1,
          rightFlex: 1,
          left: Panel(
            title: 'Bookings by service',
            child: Column(
              children: [
                for (final r in rideTypes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: rideColor(r.id),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rideName(r.id),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              naira(byService[r.id]!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: gross == 0 ? 0 : byService[r.id]! / gross,
                            minHeight: 7,
                            color: rideColor(r.id),
                            backgroundColor: AC.border,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          right: Panel(
            title: 'Busiest hours',
            subtitle: 'Completed trips by hour of day',
            child: Bars(
              values: hours,
              labels: [for (var h = 0; h < 24; h++) '${h}h'],
              color: AC.blue,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Subscription payments',
          subtitle: 'Drivers paying a flat fee instead of commission',
          flushBody: true,
          child: DataGrid(
            minWidth: 560,
            flex: const [3, 2, 2, 2],
            columns: const ['Driver', 'Plan', 'Amount', 'Date'],
            rows: [
              for (final s in subs.take(10))
                [
                  CellTitle(
                    s.driverName,
                    null,
                    leading: Initials(s.driverName, size: 30),
                  ),
                  Text(s.period),
                  Text(
                    naira(s.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Muted(formatDateTimeShort(s.date)),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Payouts ----------------

class PayoutsPage extends ConsumerStatefulWidget {
  const PayoutsPage({super.key});

  @override
  ConsumerState<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends ConsumerState<PayoutsPage> {
  String _filter = 'All';
  bool _paying = false;
  final _retrying = <String>{};

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storeProvider);
    final store = ref.read(storeProvider.notifier);
    final all = data.payouts;
    final pending = all.where((p) => p.status == PayoutStatus.pending).toList();
    final failed = all.where((p) => p.status == PayoutStatus.failed).toList();
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final paidWeek = all
        .where(
          (p) => p.status == PayoutStatus.completed && p.date.isAfter(weekAgo),
        )
        .fold(0, (a, p) => a + p.amount);
    final list = switch (_filter) {
      'Pending' => pending,
      'Failed' => failed,
      'Paid' => all.where((p) => p.status == PayoutStatus.completed).toList(),
      _ => all,
    };
    final driverBalances = data.drivers
        .where((d) => d.wallet > 0)
        .fold(0, (a, d) => a + d.wallet);

    return PageBody(
      children: [
        PageHeader(
          title: 'Payouts',
          subtitle: 'Drivers request payouts from the app. Send the money from your bank or Paystack, then mark it paid.',
          actions: [
            PrimaryButton(
              label: 'Mark all paid (${pending.length})',
              icon: Icons.send,
              busy: _paying,
              onPressed: pending.isEmpty
                  ? null
                  : () async {
                      final total = pending.fold(0, (a, p) => a + p.amount);
                      final ok = await confirm(
                        context,
                        title: 'Mark ${pending.length} payouts as paid?',
                        body:
                            'Only do this after you have sent ${naira(total)} to the drivers\' bank accounts.',
                        ok: 'Mark paid',
                      );
                      if (!ok) return;
                      setState(() => _paying = true);
                      final n = await store.payAllPending();
                      if (!mounted) return;
                      setState(() => _paying = false);
                      if (context.mounted)
                        toast(context, '$n payouts marked paid');
                    },
            ),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(
              icon: Icons.schedule,
              color: AC.orange,
              label: 'Pending',
              value: naira(pending.fold(0, (a, p) => a + p.amount)),
              foot: '${pending.length} requests',
            ),
            StatCard(
              icon: Icons.error_outline,
              color: AC.red,
              label: 'Failed',
              value: '${failed.length}',
              foot: 'Retry or contact the driver',
            ),
            StatCard(
              icon: Icons.check_circle_outline,
              color: AC.primary,
              label: 'Paid in last 7 days',
              value: naira(paidWeek),
            ),
            StatCard(
              icon: Icons.account_balance_wallet_outlined,
              color: AC.blue,
              label: 'Held in driver wallets',
              value: naira(driverBalances),
              foot: 'Not yet cashed out',
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilterChips(
          options: const ['All', 'Pending', 'Failed', 'Paid'],
          value: _filter,
          counts: {
            'All': all.length,
            'Pending': pending.length,
            'Failed': failed.length,
            'Paid': all.length - pending.length - failed.length,
          },
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 16),
        Panel(
          flushBody: true,
          child: DataGrid(
            minWidth: 900,
            flex: const [2, 3, 2, 3, 2, 2],
            columns: const ['ID', 'Driver', 'Amount', 'Bank', 'Status', ''],
            empty: 'No payouts here',
            rows: [
              for (final p in list.take(60))
                [
                  CellTitle(p.id, formatDateTimeShort(p.date)),
                  CellTitle(
                    p.driverName,
                    p.driverId,
                    leading: Initials(p.driverName, size: 30),
                  ),
                  Text(
                    naira(p.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  CellTitle(
                    p.bank,
                    p.failReason ?? (p.reference.isEmpty ? null : p.reference),
                  ),
                  Pill(p.status.label, color: p.status.color),
                  p.status != PayoutStatus.pending
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _retrying.contains(p.id)
                              ? null
                              : () async {
                                  setState(() => _retrying.add(p.id));
                                  await store.retryPayout(p.id);
                                  if (!mounted) return;
                                  setState(() => _retrying.remove(p.id));
                                  if (context.mounted)
                                    toast(
                                      context,
                                      '${naira(p.amount)} to ${p.driverName} marked paid',
                                    );
                                },
                          child: Text(
                            _retrying.contains(p.id)
                                ? 'Saving...'
                                : 'Mark paid',
                            style: const TextStyle(
                              color: AC.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Pricing & plans ----------------

class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final s = data.settings;
    final store = ref.read(storeProvider.notifier);
    final cityRates = ref.watch(cityRatesProvider);
    final city = ref.watch(pricingCityProvider);
    final overrides = city == null
        ? const <String, RidePricing>{}
        : (cityRates.rates[city] ?? const {});
    final shown = [for (final p in data.pricing) overrides[p.id] ?? p];

    return PageBody(
      children: [
        const PageHeader(
          title: 'Pricing and plans',
          subtitle: 'Changes reach the rider and driver apps immediately, no app update needed',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Default (launch cities)'),
              selected: city == null,
              onSelected: (_) =>
                  ref.read(pricingCityProvider.notifier).set(null),
            ),
            for (final c in cityRates.cities)
              ChoiceChip(
                label: Text(
                  cityRates.rates.containsKey(c) ? '$c (own prices)' : c,
                ),
                selected: city == c,
                onSelected: (_) =>
                    ref.read(pricingCityProvider.notifier).set(c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Panel(
          title: city == null ? 'Fares' : 'Fares in $city',
          subtitle: city == null
              ? 'Used in every city without its own prices. Fare = base + (per km x distance) + (per minute x time), never below the minimum. Rush hour adds traffic time, busy areas up to 1.3x, plus airport and long-pickup fees. Example: 8 km, 25 min'
              : 'Edit a service to give $city its own price. Services without their own price use the default. Example: 8 km, 25 min',
          flushBody: true,
          child: DataGrid(
            minWidth: 900,
            flex: const [3, 2, 2, 2, 2, 2, 1],
            columns: const [
              'Service',
              'Base',
              'Per km',
              'Per min',
              'Minimum',
              'Example',
              '',
            ],
            rows: [
              for (final p in shown)
                [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: rideColor(p.id),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!p.active) ...[
                        const SizedBox(width: 8),
                        const Pill('Off', color: AC.red, dot: false),
                      ],
                    ],
                  ),
                  Text(naira(p.baseFare)),
                  Text(naira(p.perKm)),
                  Text(naira(p.perMinute)),
                  Text(naira(p.minimumFare)),
                  Text(
                    naira(
                      roundFare(
                        [
                          p.minimumFare,
                          p.baseFare + p.perKm * 8 + p.perMinute * 25,
                        ].reduce((a, b) => a > b ? a : b),
                      ),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AC.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    icon: Icon(Icons.edit_outlined, color: AC.muted, size: 20),
                    onPressed: () async {
                      final updated = await showDialog<RidePricing>(
                        context: context,
                        builder: (_) => _PricingDialog(p: p),
                      );
                      if (updated != null) {
                        if (city == null) {
                          store.savePricing(updated);
                        } else {
                          store.saveCityPricing(city, updated);
                        }
                        if (context.mounted)
                          toast(
                            context,
                            '${p.name} prices updated${city == null ? '' : ' in $city'}',
                          );
                      }
                    },
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SplitRow(
          leftFlex: 3,
          rightFlex: 2,
          left: Panel(
            title: 'Driver subscription prices',
            subtitle:
                'Drivers on a subscription pay this and keep 100% of fares',
            flushBody: true,
            child: DataGrid(
              minWidth: 520,
              flex: const [2, 2, 2, 2, 1],
              columns: const ['Vehicle', 'Daily', 'Weekly', 'Monthly', ''],
              rows: [
                for (final p in data.planPrices)
                  [
                    Text(
                      p.kind,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(naira(p.daily)),
                    Text(naira(p.weekly)),
                    Text(naira(p.monthly)),
                    IconButton(
                      tooltip: 'Edit',
                      icon: Icon(
                        Icons.edit_outlined,
                        color: AC.muted,
                        size: 20,
                      ),
                      onPressed: () async {
                        final updated = await showDialog<PlanPrice>(
                          context: context,
                          builder: (_) => _PlanDialog(p: p),
                        );
                        if (updated != null) {
                          store.savePlanPrice(updated);
                          if (context.mounted)
                            toast(
                              context,
                              '${p.kind} subscription prices updated',
                            );
                        }
                      },
                    ),
                  ],
              ],
            ),
          ),
          right: Panel(
            title: 'Commission and fees',
            child: Column(
              children: [
                _NumberSetting(
                  label: 'Commission per trip',
                  suffix: '%',
                  value: s.commissionRate,
                  onSave: (v) => store.saveSettings(
                    s.copyWith(commissionRate: v),
                    'Changed commission to $v%',
                  ),
                ),
                _NumberSetting(
                  label: 'Cash commission limit',
                  prefix: '₦',
                  value: s.debtLimit,
                  help: 'Drivers must settle before going online',
                  onSave: (v) => store.saveSettings(
                    s.copyWith(debtLimit: v),
                    'Changed cash commission limit to ${naira(v)}',
                  ),
                ),
                _NumberSetting(
                  label: 'Waiting fee per minute',
                  prefix: '₦',
                  value: s.waitingFeePerMin,
                  help: 'After ${s.freeWaitMinutes} free minutes',
                  onSave: (v) => store.saveSettings(
                    s.copyWith(waitingFeePerMin: v),
                    'Changed waiting fee to ${naira(v)}/min',
                  ),
                ),
                _NumberSetting(
                  label: 'No-show fee',
                  prefix: '₦',
                  value: s.noShowFee,
                  onSave: (v) => store.saveSettings(
                    s.copyWith(noShowFee: v),
                    'Changed no-show fee to ${naira(v)}',
                  ),
                ),
                _NumberSetting(
                  label: 'Minimum payout',
                  prefix: '₦',
                  value: s.minPayout,
                  onSave: (v) => store.saveSettings(
                    s.copyWith(minPayout: v),
                    'Changed minimum payout to ${naira(v)}',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.surgeEnabled,
                  onChanged: (v) => store.saveSettings(
                    s.copyWith(surgeEnabled: v),
                    '${v ? 'Enabled' : 'Disabled'} busy-area pricing',
                  ),
                  title: const Text(
                    'Busy-area pricing',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Up to ${s.maxSurge}x in high-demand zones',
                    style: TextStyle(color: AC.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const EnginePanel(),
      ],
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.onSave,
    this.prefix,
    this.suffix,
    this.help,
  });

  final String label;
  final int value;
  final ValueChanged<int> onSave;
  final String? prefix;
  final String? suffix;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (help != null)
                  Text(help!, style: TextStyle(fontSize: 12, color: AC.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: TextEditingController(text: '$value'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                prefixText: prefix,
                suffixText: suffix,
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v);
                if (n != null && n != value) {
                  onSave(n);
                  toast(context, '$label saved');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingDialog extends StatefulWidget {
  const _PricingDialog({required this.p});
  final RidePricing p;

  @override
  State<_PricingDialog> createState() => _PricingDialogState();
}

class _PricingDialogState extends State<_PricingDialog> {
  late final _base = TextEditingController(
    text: widget.p.baseFare.round().toString(),
  );
  late final _km = TextEditingController(
    text: widget.p.perKm.round().toString(),
  );
  late final _min = TextEditingController(
    text: widget.p.perMinute.round().toString(),
  );
  late final _minimum = TextEditingController(
    text: widget.p.minimumFare.round().toString(),
  );
  late bool _active = widget.p.active;

  double _v(TextEditingController c) => double.tryParse(c.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final example = roundFare(
      [
        _v(_minimum),
        _v(_base) + _v(_km) * 8 + _v(_min) * 25,
      ].reduce((a, b) => a > b ? a : b),
    );
    Widget field(String label, TextEditingController c) => Expanded(
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, prefixText: '₦ '),
      ),
    );

    return AlertDialog(
      title: Text(
        'Edit ${widget.p.name}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                field('Base fare', _base),
                const SizedBox(width: 12),
                field('Minimum fare', _minimum),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                field('Per km', _km),
                const SizedBox(width: 12),
                field('Per minute', _min),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Available to riders'),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AC.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '8 km, 25 min trip: ${naira(example)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AC.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AC.primary),
          onPressed: () => Navigator.pop(
            context,
            widget.p.copyWith(
              baseFare: _v(_base),
              perKm: _v(_km),
              perMinute: _v(_min),
              minimumFare: _v(_minimum),
              active: _active,
            ),
          ),
          child: const Text('Save prices'),
        ),
      ],
    );
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({required this.p});
  final PlanPrice p;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late final _d = TextEditingController(text: '${widget.p.daily}');
  late final _w = TextEditingController(text: '${widget.p.weekly}');
  late final _m = TextEditingController(text: '${widget.p.monthly}');

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, prefixText: '₦ '),
      ),
    );
    return AlertDialog(
      title: Text(
        '${widget.p.kind} subscription',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field('Daily', _d),
            field('Weekly', _w),
            field('Monthly', _m),
            Text(
              'Drivers already paid keep their current period at the old price.',
              style: TextStyle(fontSize: 12.5, color: AC.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AC.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AC.primary),
          onPressed: () => Navigator.pop(
            context,
            widget.p.copyWith(
              daily: int.tryParse(_d.text),
              weekly: int.tryParse(_w.text),
              monthly: int.tryParse(_m.text),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
