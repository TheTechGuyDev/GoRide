import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/live.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../overview/overview_page.dart';

String paymentLabel(String p) => switch (p) {
  'cash' => 'Cash',
  'wallet' => 'Wallet',
  _ => 'Card',
};

TileLayer adminTiles() => TileLayer(
  urlTemplate: MapConfig.tileUrl,
  userAgentPackageName: 'com.goride.goride_admin',
  tileBuilder: AC.isDark ? darkModeTileBuilder : null,
);

// ---------------- Riders ----------------

class RidersPage extends ConsumerStatefulWidget {
  const RidersPage({super.key});

  @override
  ConsumerState<RidersPage> createState() => _RidersPageState();
}

class _RidersPageState extends ConsumerState<RidersPage> {
  String _filter = 'All';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(storeProvider).riders;
    final now = DateTime.now();
    final counts = {
      'All': all.length,
      'New this week': all
          .where((r) => now.difference(r.joinedAt).inDays < 7)
          .length,
      'Top riders': all.where((r) => r.trips >= 60).length,
      'No emergency contact': all.where((r) => r.emergencyContacts == 0).length,
      'Blocked': all.where((r) => r.blocked).length,
    };
    final q = _q.toLowerCase();
    final list = all.where((r) {
      final ok = switch (_filter) {
        'New this week' => now.difference(r.joinedAt).inDays < 7,
        'Top riders' => r.trips >= 60,
        'No emergency contact' => r.emergencyContacts == 0,
        'Blocked' => r.blocked,
        _ => true,
      };
      return ok &&
          (q.isEmpty ||
              r.name.toLowerCase().contains(q) ||
              r.id.toLowerCase().contains(q) ||
              r.email.toLowerCase().contains(q) ||
              r.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')));
    }).toList()..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));

    return PageBody(
      children: [
        PageHeader(
          title: 'Riders',
          subtitle:
              '${all.length} riders · ${counts['New this week']} joined this week',
          actions: [
            SearchBox(
              hint: 'Name, phone, email or ID',
              onChanged: (v) => setState(() => _q = v),
            ),
          ],
        ),
        FilterChips(
          options: counts.keys.toList(),
          value: _filter,
          counts: counts,
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 16),
        Panel(
          flushBody: true,
          child: DataGrid(
            minWidth: 900,
            flex: const [4, 3, 2, 2, 2, 2],
            columns: const [
              'Rider',
              'Phone',
              'Trips',
              'Spent',
              'Wallet',
              'Status',
            ],
            onRowTap: (i) => context.go(R.rider(list[i].id)),
            empty: 'No riders match',
            rows: [
              for (final r in list.take(100))
                [
                  CellTitle(
                    r.name,
                    '${r.id} · joined ${ago(r.joinedAt)}',
                    leading: Initials(r.name),
                  ),
                  Muted(r.phone),
                  Text('${r.trips}'),
                  Text(
                    naira(r.spent),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(naira(r.wallet)),
                  r.blocked
                      ? const Pill('Blocked', color: AC.red)
                      : const Pill('Active', color: AC.primary),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class RiderDetailPage extends ConsumerWidget {
  const RiderDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final r = data.rider(id);
    if (r == null)
      return PageBody(
        children: [PageHeader(title: 'Rider not found', subtitle: id)],
      );
    final store = ref.read(storeProvider.notifier);
    final trips = data.trips.where((t) => t.riderId == id).toList();
    final tickets = data.tickets.where((t) => t.fromName == r.name).toList();

    return PageBody(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(R.riders),
            icon: Icon(Icons.arrow_back, size: 18, color: AC.muted),
            label: Text('Riders', style: TextStyle(color: AC.muted)),
          ),
        ),
        const SizedBox(height: 8),
        Panel(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Initials(r.name, size: 64),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          r.blocked
                              ? const Pill('Blocked', color: AC.red)
                              : const Pill('Active', color: AC.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${r.id} · ${r.phone} · ${r.email}',
                        style: TextStyle(color: AC.muted),
                      ),
                    ],
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GhostButton(
                    label: 'Credit wallet',
                    icon: Icons.add_card,
                    onPressed: () async {
                      final res = await _amountDialog(
                        context,
                        'Credit ${r.name.split(' ').first}\'s wallet',
                        'Goodwill credit after a bad trip',
                      );
                      if (res != null) {
                        store.creditRider(r.id, res.$1, res.$2);
                        if (context.mounted)
                          toast(
                            context,
                            '${naira(res.$1)} credited to ${r.name}',
                          );
                      }
                    },
                  ),
                  r.blocked
                      ? PrimaryButton(
                          label: 'Unblock',
                          icon: Icons.lock_open,
                          onPressed: () {
                            store.setRiderBlocked(r.id, false);
                            toast(context, '${r.name} can book rides again');
                          },
                        )
                      : GhostButton(
                          label: 'Block rider',
                          icon: Icons.block,
                          color: AC.red,
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: 'Block ${r.name}?',
                              body: 'They won\'t be able to book rides until unblocked. Use this for abuse, fraud or safety issues.',
                              ok: 'Block',
                              danger: true,
                            );
                            if (ok) {
                              store.setRiderBlocked(r.id, true);
                              if (context.mounted)
                                toast(context, '${r.name} blocked');
                            }
                          },
                        ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(
              icon: Icons.route,
              color: AC.primary,
              label: 'Trips',
              value: '${r.trips}',
            ),
            StatCard(
              icon: Icons.payments_outlined,
              color: AC.blue,
              label: 'Total spent',
              value: naira(r.spent),
            ),
            StatCard(
              icon: Icons.account_balance_wallet_outlined,
              color: AC.purple,
              label: 'Wallet',
              value: naira(r.wallet),
            ),
            StatCard(
              icon: Icons.contacts_outlined,
              color: r.emergencyContacts == 0 ? AC.orange : AC.teal,
              label: 'Emergency contacts',
              value: '${r.emergencyContacts}',
              foot: r.emergencyContacts == 0
                  ? 'SOS can only reach GoRide'
                  : 'Alerted on SOS',
              footColor: r.emergencyContacts == 0 ? AC.orange : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SplitRow(
          left: Panel(
            title: 'Trips',
            flushBody: true,
            child: TripTable(trips: trips.take(12).toList(), showRider: false),
          ),
          right: Panel(
            title: 'Support tickets',
            child: tickets.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No tickets',
                      style: TextStyle(color: AC.muted),
                    ),
                  )
                : Column(
                    children: [
                      for (final t in tickets)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            t.subject,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${t.id} · ${ago(t.created)}'),
                          trailing: Pill(t.status.label, color: t.status.color),
                          onTap: () => context.go(R.support),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

Future<(int, String)?> _amountDialog(
  BuildContext context,
  String title,
  String hint,
) {
  final amount = TextEditingController();
  final reason = TextEditingController();
  return showDialog<(int, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₦ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: InputDecoration(labelText: 'Reason', hintText: hint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: TextStyle(color: AC.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AC.primary),
          onPressed: () {
            final v = int.tryParse(amount.text) ?? 0;
            if (v <= 0) return;
            Navigator.pop(ctx, (
              v,
              reason.text.trim().isEmpty ? hint : reason.text.trim(),
            ));
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

// ---------------- Trips ----------------

class TripTable extends ConsumerWidget {
  const TripTable({super.key, required this.trips, this.showRider = true});
  final List<Trip> trips;
  final bool showRider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataGrid(
      minWidth: showRider ? 1000 : 640,
      flex: showRider ? const [2, 2, 4, 3, 2, 2, 2] : const [2, 4, 2, 2],
      columns: showRider
          ? const [
              'Trip',
              'When',
              'Route',
              'Rider / driver',
              'Fare',
              'Payment',
              'Status',
            ]
          : const ['When', 'Route', 'Fare', 'Status'],
      empty: 'No trips',
      onRowTap: (i) => showTripDetails(context, trips[i].id),
      rows: [
        for (final t in trips)
          showRider
              ? [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.id,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.routeAlert) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'Off-route alert on this trip',
                          child: Icon(
                            Icons.alt_route,
                            size: 16,
                            color: AC.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Muted(formatDateTimeShort(t.date)),
                  CellTitle(t.pickup, 'to ${t.dropoff}'),
                  CellTitle(t.riderName, t.driverName),
                  Text(
                    t.fare == 0 ? '-' : naira(t.fare),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(paymentLabel(t.payment)),
                  Pill(
                    t.refunded > 0 ? 'Refunded' : t.status.label,
                    color: t.refunded > 0 ? AC.purple : t.status.color,
                  ),
                ]
              : [
                  Muted(formatDateTimeShort(t.date)),
                  CellTitle(t.pickup, 'to ${t.dropoff}'),
                  Text(
                    t.fare == 0 ? '-' : naira(t.fare),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Pill(t.status.label, color: t.status.color),
                ],
      ],
    );
  }
}

Future<void> showTripDetails(BuildContext context, String tripId) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TripDialog(tripId: tripId),
  );
}

class _TripDialog extends ConsumerWidget {
  const _TripDialog({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final t = data.trips.firstWhere((x) => x.id == tripId);
    final canRefund =
        ref.watch(sessionProvider)!.role.sections.contains(Section.revenue) ||
        ref.watch(sessionProvider)!.role.sections.contains(Section.support);
    final from = lagosPlaces.where((p) => p.name == t.pickup).firstOrNull;
    final to = lagosPlaces.where((p) => p.name == t.dropoff).firstOrNull;

    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: TextStyle(color: AC.muted)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
      title: Row(
        children: [
          Text(t.id, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Pill(t.status.label, color: t.status.color),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (from != null && to != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 190,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints([
                            from.position,
                            to.position,
                          ]),
                          padding: const EdgeInsets.all(40),
                        ),
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        adminTiles(),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [from.position, to.position],
                              color: AC.primary,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: from.position,
                              width: 18,
                              height: 18,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AC.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                            Marker(
                              point: to.position,
                              width: 18,
                              height: 18,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              kv('When', formatDateTimeShort(t.date)),
              kv('From', t.pickup),
              kv('To', t.dropoff),
              kv('Rider', t.riderName),
              kv('Driver', t.driverName),
              kv('Service', rideName(t.rideTypeId)),
              kv('Distance', '${t.km} km · ${t.minutes} min'),
              kv('Payment', paymentLabel(t.payment)),
              const Divider(height: 24),
              kv('Fare', t.fare == 0 ? '-' : naira(t.fare)),
              kv('Commission', naira(t.commission)),
              kv('Driver earned', naira(t.fare - t.commission)),
              if (t.refunded > 0) kv('Refunded', naira(t.refunded)),
              if (t.rating != null) kv('Rider rating', '${t.rating} of 5'),
              if (t.routeAlert)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AC.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.alt_route, color: AC.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The rider got an off-route alert on this trip. See Safety alerts for details.',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (canRefund && t.fare > 0 && t.payment != 'cash')
          TextButton.icon(
            onPressed: () async {
              final res = await _amountDialog(
                context,
                'Refund to ${t.riderName.split(' ').first}\'s wallet',
                'Overcharged',
              );
              if (res != null) {
                ref
                    .read(storeProvider.notifier)
                    .refundTrip(t.id, res.$1, res.$2);
                if (context.mounted)
                  toast(context, '${naira(res.$1)} refunded to ${t.riderName}');
              }
            },
            icon: const Icon(Icons.undo, color: AC.purple),
            label: const Text(
              'Refund',
              style: TextStyle(color: AC.purple, fontWeight: FontWeight.w700),
            ),
          ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.go(R.driver(t.driverId));
          },
          child: const Text('Open driver', style: TextStyle(color: AC.primary)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.go(R.rider(t.riderId));
          },
          child: const Text('Open rider', style: TextStyle(color: AC.primary)),
        ),
      ],
    );
  }
}

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  String _status = 'All';
  String _service = 'All';
  String _range = 'Today';
  late String _q = widget.initialQuery;
  int _shown = 50;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(storeProvider).trips;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final since = switch (_range) {
      'Today' => today,
      '7 days' => today.subtract(const Duration(days: 6)),
      '30 days' => today.subtract(const Duration(days: 29)),
      _ => DateTime(2000),
    };
    final q = _q.toLowerCase();
    final list = all.where((t) {
      if (t.date.isBefore(since) && q.isEmpty) return false;
      final s = switch (_status) {
        'Completed' => t.status == TripStatus.completed,
        'Cancelled' =>
          t.status == TripStatus.riderCancelled ||
              t.status == TripStatus.driverCancelled,
        'Route alerts' => t.routeAlert,
        'Refunded' => t.refunded > 0,
        _ => true,
      };
      final svc = _service == 'All' || rideName(t.rideTypeId) == _service;
      final match =
          q.isEmpty ||
          t.id.toLowerCase().contains(q) ||
          t.riderName.toLowerCase().contains(q) ||
          t.driverName.toLowerCase().contains(q) ||
          t.pickup.toLowerCase().contains(q) ||
          t.dropoff.toLowerCase().contains(q);
      return s && svc && match;
    }).toList();
    final done = list.where((t) => t.status == TripStatus.completed);
    final fares = done.fold(0, (a, t) => a + t.fare);
    final cancelled = list.length - done.length;

    return PageBody(
      children: [
        PageHeader(
          title: 'Trips',
          subtitle:
              '${list.length} trips · ${naira(fares)} in fares · ${list.isEmpty ? 0 : (cancelled / list.length * 100).round()}% cancelled',
          actions: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: TextEditingController(text: _q)
                  ..selection = TextSelection.collapsed(offset: _q.length),
                onChanged: (v) => setState(() {
                  _q = v;
                  _shown = 50;
                }),
                decoration: InputDecoration(
                  hintText: 'Trip ID, rider, driver or place',
                  prefixIcon: Icon(Icons.search, color: AC.muted, size: 20),
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            FilterChips(
              options: const ['Today', '7 days', '30 days', 'All time'],
              value: _range,
              onChanged: (v) => setState(() => _range = v),
            ),
            FilterChips(
              options: const [
                'All',
                'Completed',
                'Cancelled',
                'Route alerts',
                'Refunded',
              ],
              value: _status,
              onChanged: (v) => setState(() => _status = v),
            ),
            DropdownButton<String>(
              value: _service,
              underline: const SizedBox.shrink(),
              dropdownColor: AC.card,
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem(
                  value: 'All',
                  child: Text('All services'),
                ),
                for (final r in rideTypes)
                  DropdownMenuItem(
                    value: rideName(r.id),
                    child: Text(rideName(r.id)),
                  ),
              ],
              onChanged: (v) => setState(() => _service = v ?? 'All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          flushBody: true,
          child: TripTable(trips: list.take(_shown).toList()),
        ),
        if (list.length > _shown)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => _shown += 50),
                child: Text(
                  'Show more (${list.length - _shown} left)',
                  style: const TextStyle(
                    color: AC.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------- Live map ----------------

class LiveMapPage extends ConsumerStatefulWidget {
  const LiveMapPage({super.key});

  @override
  ConsumerState<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends ConsumerState<LiveMapPage> {
  final _map = MapController();
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveProvider);
    final data = ref.watch(storeProvider);
    final openSafety = data.safety
        .where((s) => s.status != SafetyStatus.resolved)
        .toList();
    final sel = live.trips.where((t) => t.id == _selected).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width > 1200;

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FlutterMap(
        mapController: _map,
        options: const MapOptions(
          initialCenter: LatLng(6.49, 3.40),
          initialZoom: 11.6,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          adminTiles(),
          if (sel != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: remainingPath(sel.path, sel.progress),
                  strokeWidth: 5,
                  color: sel.offRoute ? AC.orange : AC.primary,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final i in live.idle)
                Marker(
                  point: i.$2,
                  width: 14,
                  height: 14,
                  child: Tooltip(
                    message: '${i.$1} · waiting',
                    child: Container(
                      decoration: BoxDecoration(
                        color: AC.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              for (final s in openSafety)
                Marker(
                  point: s.position,
                  width: 120,
                  height: 120,
                  child: PulseRings(
                    size: 120,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AC.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sos,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              for (final t in live.trips)
                Marker(
                  point: t.at.point,
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = t.id),
                    child: Tooltip(
                      message: '${t.driverName} · ${t.plate}',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (t.offRoute ? AC.orange : AC.primary)
                              .withValues(
                                alpha: _selected == t.id ? 0.35 : 0.0,
                              ),
                        ),
                        child: VehicleMarker(
                          heading: t.at.heading,
                          type: t.rideTypeId == 'bike'
                              ? VehicleType.bike
                              : VehicleType.car,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SimpleAttributionWidget(source: Text(MapConfig.attribution)),
        ],
      ),
    );

    final side = Panel(
      title: 'On the road',
      subtitle:
          '${live.trips.length} trips · ${live.idle.length} drivers waiting',
      flushBody: true,
      child: Column(
        children: [
          for (final t in live.trips)
            InkWell(
              onTap: () {
                setState(() => _selected = t.id);
                _map.move(t.at.point, 14);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _selected == t.id ? AC.selected : null,
                  border: Border(top: BorderSide(color: AC.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.driverName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (t.offRoute)
                          const Pill('Off route', color: AC.orange)
                        else
                          Muted('${t.minutesLeft} min left', size: 12),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Muted('${t.from.name} to ${t.to.name}', size: 12.5),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: t.progress,
                        minHeight: 4,
                        color: t.offRoute ? AC.orange : AC.primary,
                        backgroundColor: AC.border,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return PageBody(
      children: [
        PageHeader(
          title: 'Live map',
          subtitle: 'Updates every second. Green cars are on trips, blue dots are waiting for requests, red is an open alert.',
          actions: [
            if (sel != null)
              GhostButton(
                label: 'Clear selection',
                icon: Icons.close,
                onPressed: () => setState(() => _selected = null),
              ),
          ],
        ),
        if (sel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Wrap(
                spacing: 28,
                runSpacing: 10,
                children: [
                  CellTitle(
                    sel.driverName,
                    '${sel.plate} · ${rideName(sel.rideTypeId)}',
                  ),
                  CellTitle('Rider', sel.riderName),
                  CellTitle('Route', '${sel.from.name} to ${sel.to.name}'),
                  CellTitle('Fare', naira(sel.fare)),
                  CellTitle('Arrives in', '${sel.minutesLeft} min'),
                ],
              ),
            ),
          ),
        if (wide)
          SizedBox(
            height: 640,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: map),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: SingleChildScrollView(child: side)),
              ],
            ),
          )
        else ...[
          SizedBox(height: 460, child: map),
          const SizedBox(height: 16),
          side,
        ],
      ],
    );
  }
}
