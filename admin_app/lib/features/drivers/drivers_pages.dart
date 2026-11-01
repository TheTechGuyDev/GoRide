import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../overview/overview_page.dart';

class DriversPage extends ConsumerStatefulWidget {
  const DriversPage({super.key});

  @override
  ConsumerState<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends ConsumerState<DriversPage> {
  String _filter = 'All';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(storeProvider).drivers;
    final counts = {
      'All': all.length,
      'Online': all.where((d) => d.online).length,
      'Active': all.where((d) => d.status == DriverStatus.active).length,
      'In review': all.where((d) => d.status == DriverStatus.pending).length,
      'Suspended': all.where((d) => d.status == DriverStatus.suspended).length,
      'Documents expiring': all
          .where(
            (d) =>
                d.status == DriverStatus.active &&
                d.docs.any((x) => x.expiresSoon || x.expired),
          )
          .length,
      'Owe commission': all.where((d) => d.wallet < 0).length,
    };
    final q = _q.toLowerCase();
    final list = all.where((d) {
      final ok = switch (_filter) {
        'Online' => d.online,
        'Active' => d.status == DriverStatus.active,
        'In review' => d.status == DriverStatus.pending,
        'Suspended' => d.status == DriverStatus.suspended,
        'Documents expiring' =>
          d.status == DriverStatus.active &&
              d.docs.any((x) => x.expiresSoon || x.expired),
        'Owe commission' => d.wallet < 0,
        _ => true,
      };
      return ok &&
          (q.isEmpty ||
              d.name.toLowerCase().contains(q) ||
              d.plate.toLowerCase().contains(q) ||
              d.id.toLowerCase().contains(q) ||
              d.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')));
    }).toList();

    return PageBody(
      children: [
        PageHeader(
          title: 'Drivers',
          subtitle:
              '${counts['Active']} active · ${counts['Online']} online now',
          actions: [
            SearchBox(
              hint: 'Name, plate, phone or ID',
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
            minWidth: 980,
            flex: const [4, 3, 2, 2, 2, 2, 2],
            columns: const [
              'Driver',
              'Vehicle',
              'Service',
              'Plan',
              'Rating',
              'Wallet',
              'Status',
            ],
            onRowTap: (i) => context.go(R.driver(list[i].id)),
            empty: 'No drivers match',
            rows: [
              for (final d in list)
                [
                  CellTitle(
                    d.name,
                    '${d.id} · ${d.phone}',
                    leading: Stack(
                      children: [
                        Initials(d.name),
                        if (d.online)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: AC.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AC.card, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  CellTitle(d.plate, d.vehicle),
                  Text(rideName(d.rideTypeId)),
                  Text(d.plan),
                  d.rating == 0
                      ? const Text('-')
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AC.orange,
                            ),
                            const SizedBox(width: 3),
                            Text(d.rating.toStringAsFixed(2)),
                          ],
                        ),
                  Text(
                    naira(d.wallet),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: d.wallet < 0 ? AC.red : null,
                    ),
                  ),
                  Pill(d.status.label, color: d.status.color),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

/// New applications waiting for document review.
class ApplicationsPage extends ConsumerWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final pending = data.pendingDrivers
      ..sort((a, b) => a.appliedAt.compareTo(b.appliedAt));
    final recent = data.drivers
        .where(
          (d) =>
              d.status == DriverStatus.rejected ||
              (d.joinedAt != null &&
                  DateTime.now().difference(d.joinedAt!).inDays < 2),
        )
        .toList();

    return PageBody(
      children: [
        PageHeader(
          title: 'Driver applications',
          subtitle:
              '${pending.length} waiting · oldest first · aim to review within 24 hours',
        ),
        if (pending.isEmpty)
          Panel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.task_alt, size: 48, color: AC.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'All caught up',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'No applications waiting.',
                    style: TextStyle(color: AC.muted),
                  ),
                ],
              ),
            ),
          ),
        ResponsiveGrid(
          minItemWidth: 330,
          children: [for (final d in pending) _ApplicationCard(driver: d)],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 24),
          Panel(
            title: 'Recently decided',
            flushBody: true,
            child: DataGrid(
              minWidth: 640,
              flex: const [3, 3, 2, 3],
              columns: const ['Driver', 'Vehicle', 'Decision', 'Note'],
              onRowTap: (i) => context.go(R.driver(recent[i].id)),
              rows: [
                for (final d in recent)
                  [
                    CellTitle(d.name, d.id, leading: Initials(d.name)),
                    CellTitle(d.plate, d.vehicle),
                    Pill(
                      d.status == DriverStatus.rejected
                          ? 'Rejected'
                          : 'Approved',
                      color: d.status == DriverStatus.rejected
                          ? AC.red
                          : AC.primary,
                    ),
                    Muted(
                      d.suspendReason ??
                          (d.joinedAt == null
                              ? ''
                              : 'Approved ${ago(d.joinedAt!)}'),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.driver});
  final Driver driver;

  @override
  Widget build(BuildContext context) {
    final d = driver;
    final approved = d.docs.where((x) => x.state == DocState.approved).length;
    final waitingHours = DateTime.now().difference(d.appliedAt).inHours;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Initials(d.name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: CellTitle(
                  d.name,
                  '${d.city} · applied ${ago(d.appliedAt)}',
                ),
              ),
              if (waitingHours >= 24) const Pill('Over 24h', color: AC.red),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.directions_car_outlined, size: 18, color: AC.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${d.vehicle} · ${d.plate}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 18, color: AC.muted),
              const SizedBox(width: 8),
              Text('${rideName(d.rideTypeId)} · ${d.plan} plan'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Documents',
                style: TextStyle(color: AC.muted, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '$approved of ${d.docs.length} checked',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: approved / d.docs.length,
              minHeight: 7,
              color: AC.primary,
              backgroundColor: AC.border,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Review application',
              icon: Icons.fact_check_outlined,
              onPressed: () => context.go(R.driver(d.id)),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverDetailPage extends ConsumerWidget {
  const DriverDetailPage({super.key, required this.id});
  final String id;

  Future<String?> _askReason(
    BuildContext context,
    String title,
    List<String> presets,
  ) async {
    var reason = presets.first;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in presets)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: p,
                    // ignore: deprecated_member_use
                    groupValue: reason,
                    activeColor: AC.primary,
                    title: Text(p),
                    // ignore: deprecated_member_use
                    onChanged: (v) => set(() => reason = v!),
                  ),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Add a note for the driver (optional)',
                  ),
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
              style: FilledButton.styleFrom(backgroundColor: AC.red),
              onPressed: () => Navigator.pop(
                ctx,
                ctrl.text.trim().isEmpty
                    ? reason
                    : '$reason. ${ctrl.text.trim()}',
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final d = data.driver(id);
    final store = ref.read(storeProvider.notifier);
    if (d == null) {
      return PageBody(
        children: [PageHeader(title: 'Driver not found', subtitle: id)],
      );
    }
    final trips = data.trips.where((t) => t.driverId == d.id).toList();
    final completed = trips
        .where((t) => t.status == TripStatus.completed)
        .toList();
    final earned = completed.fold(0, (a, t) => a + t.fare - t.commission);
    final payouts = data.payouts.where((p) => p.driverId == d.id).toList();
    final allDocsOk = d.docs.every((x) => x.state == DocState.approved);
    final canManage = ref
        .watch(sessionProvider)!
        .role
        .sections
        .contains(Section.applications);

    final actions = <Widget>[
      if (d.status == DriverStatus.pending && canManage) ...[
        GhostButton(
          label: 'Reject application',
          icon: Icons.close,
          color: AC.red,
          onPressed: () async {
            final r = await _askReason(context, 'Reject ${d.name}?', const [
              'Vehicle does not meet requirements',
              'Documents could not be verified',
              'NIN does not match name',
              'Failed background check',
            ]);
            if (r != null) {
              store.rejectDriver(d.id, r);
              if (context.mounted)
                toast(context, '${d.name} rejected. They\'ve been told why.');
            }
          },
        ),
        PrimaryButton(
          label: allDocsOk ? 'Approve driver' : 'Approve all and activate',
          icon: Icons.verified,
          onPressed: () async {
            final ok = await confirm(
              context,
              title: 'Approve ${d.name}?',
              body:
                  'All documents will be marked approved and ${d.name.split(' ').first} can go online straight away. They get a notification.',
              ok: 'Approve',
            );
            if (ok) {
              store.approveDriver(d.id);
              if (context.mounted)
                toast(context, '${d.name} approved and notified');
            }
          },
        ),
      ],
      if (d.status == DriverStatus.active && canManage)
        GhostButton(
          label: 'Suspend',
          icon: Icons.block,
          color: AC.red,
          onPressed: () async {
            final r = await _askReason(context, 'Suspend ${d.name}?', const [
              'Rider complaint under review',
              'Rating below 4.2',
              'Expired documents',
              'Safety incident',
              'Fraud suspected',
            ]);
            if (r != null) {
              store.suspendDriver(d.id, r);
              if (context.mounted)
                toast(context, '${d.name} suspended and taken offline');
            }
          },
        ),
      if ((d.status == DriverStatus.suspended ||
              d.status == DriverStatus.rejected) &&
          canManage)
        PrimaryButton(
          label: 'Reactivate',
          icon: Icons.restart_alt,
          onPressed: () {
            store.reactivateDriver(d.id);
            toast(context, '${d.name} is active again');
          },
        ),
    ];

    return PageBody(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(
              d.status == DriverStatus.pending ? R.applications : R.drivers,
            ),
            icon: Icon(Icons.arrow_back, size: 18, color: AC.muted),
            label: Text(
              d.status == DriverStatus.pending ? 'Applications' : 'Drivers',
              style: TextStyle(color: AC.muted),
            ),
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
                  Initials(d.name, size: 64),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            d.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Pill(d.status.label, color: d.status.color),
                          if (d.online) ...[
                            const SizedBox(width: 6),
                            const Pill('Online', color: AC.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.id} · ${d.phone} · ${d.email}',
                        style: TextStyle(color: AC.muted),
                      ),
                      if (d.suspendReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Reason: ${d.suspendReason}',
                          style: const TextStyle(
                            color: AC.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 200,
          children: [
            StatCard(
              icon: Icons.star_rounded,
              color: AC.orange,
              label: 'Rating',
              value: d.rating == 0 ? '-' : d.rating.toStringAsFixed(2),
            ),
            StatCard(
              icon: Icons.route,
              color: AC.primary,
              label: 'Trips (all time)',
              value: '${d.trips}',
              foot: '${completed.length} in the last 45 days',
            ),
            StatCard(
              icon: Icons.payments_outlined,
              color: AC.blue,
              label: 'Earned (45 days)',
              value: naira(earned),
            ),
            StatCard(
              icon: Icons.account_balance_wallet_outlined,
              color: d.wallet < 0 ? AC.red : AC.purple,
              label: 'Wallet',
              value: naira(d.wallet),
              foot: d.wallet < 0
                  ? 'Owes cash commission'
                  : 'Available to cash out',
              footColor: d.wallet < 0 ? AC.red : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SplitRow(
          leftFlex: 3,
          rightFlex: 2,
          left: Panel(
            title: 'Documents',
            subtitle: d.status == DriverStatus.pending
                ? 'Check each document against the driver\'s details'
                : 'Expiry dates are checked daily',
            flushBody: true,
            child: Column(
              children: [
                for (var i = 0; i < d.docs.length; i++)
                  _DocRow(
                    doc: d.docs[i],
                    canReview: canManage,
                    onApprove: () =>
                        store.setDocState(d.id, i, DocState.approved),
                    onReject: () async {
                      final r = await _askReason(
                        context,
                        'Reject ${d.docs[i].title}?',
                        const [
                          'Photo is blurry',
                          'Document has expired',
                          'Name does not match',
                          'Wrong document uploaded',
                        ],
                      );
                      if (r != null)
                        store.setDocState(d.id, i, DocState.rejected, note: r);
                    },
                  ),
              ],
            ),
          ),
          right: Panel(
            title: 'Details',
            child: Column(
              children: [
                _KV('Service', rideName(d.rideTypeId)),
                _KV('Vehicle', d.vehicle),
                _KV('Plate', d.plate),
                _KV('City', d.city),
                _KV(
                  'NIN',
                  '${d.nin.substring(0, 3)}•••••${d.nin.substring(d.nin.length - 3)}',
                ),
                _KV(
                  'Plan',
                  d.subscription
                      ? 'Subscription${d.paidUntil == null
                            ? ''
                            : d.paidUntil!.isAfter(DateTime.now())
                            ? ' (paid to ${formatDate(d.paidUntil!)})'
                            : ' (expired)'}'
                      : 'Commission 15%',
                ),
                _KV('Applied', formatDate(d.appliedAt)),
                if (d.joinedAt != null)
                  _KV('Approved', formatDate(d.joinedAt!)),
                if (d.lastSeen != null) _KV('Last seen', ago(d.lastSeen!)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SplitRow(
          left: Panel(
            title: 'Recent trips',
            flushBody: true,
            child: DataGrid(
              minWidth: 620,
              flex: const [2, 4, 2, 2],
              columns: const ['When', 'Route', 'Fare', 'Status'],
              empty: 'No trips yet',
              rows: [
                for (final t in trips.take(8))
                  [
                    Muted(formatDateTimeShort(t.date)),
                    CellTitle(t.pickup, 'to ${t.dropoff} · ${t.riderName}'),
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
            title: 'Payouts',
            flushBody: true,
            child: DataGrid(
              minWidth: 360,
              flex: const [3, 2, 2],
              columns: const ['Date', 'Amount', 'Status'],
              empty: 'No payouts yet',
              rows: [
                for (final p in payouts.take(8))
                  [
                    Muted(formatDateTimeShort(p.date)),
                    Text(
                      naira(p.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Pill(p.status.label, color: p.status.color),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: TextStyle(color: AC.muted)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.doc,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });
  final DocReview doc;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final expiryColor = doc.expired
        ? AC.red
        : doc.expiresSoon
        ? AC.orange
        : AC.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AC.border)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(doc.title),
                content: Container(
                  width: 460,
                  height: 280,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AC.field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 56, color: AC.muted),
                      const SizedBox(height: 10),
                      Text(
                        'Uploaded photo appears here',
                        style: TextStyle(color: AC.muted),
                      ),
                      Text(
                        '(stored in Supabase Storage once connected)',
                        style: TextStyle(color: AC.faint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: Container(
              width: 52,
              height: 40,
              decoration: BoxDecoration(
                color: AC.field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AC.border),
              ),
              child: Icon(Icons.image_outlined, size: 20, color: AC.muted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (doc.number.isNotEmpty) doc.number,
                    if (doc.expiry != null)
                      '${doc.expired ? 'Expired' : 'Expires'} ${formatDate(doc.expiry!)}',
                    if (doc.note != null) doc.note!,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: doc.note != null ? AC.red : expiryColor,
                  ),
                ),
              ],
            ),
          ),
          Pill(doc.state.label, color: doc.state.color),
          if (canReview) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Approve',
              onPressed: doc.state == DocState.approved ? null : onApprove,
              icon: Icon(
                Icons.check_circle_outline,
                color: doc.state == DocState.approved ? AC.faint : AC.primary,
              ),
            ),
            IconButton(
              tooltip: 'Reject',
              onPressed: doc.state == DocState.rejected ? null : onReject,
              icon: Icon(
                Icons.cancel_outlined,
                color: doc.state == DocState.rejected ? AC.faint : AC.red,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
