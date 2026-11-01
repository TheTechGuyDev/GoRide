import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../overview/overview_page.dart';
import '../trips/trips_pages.dart';

/// List + detail layout: side by side on wide screens, detail below on
/// narrow ones.
class MasterDetail extends StatelessWidget {
  const MasterDetail({super.key, required this.list, required this.detail});
  final Widget list;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detail != null) ...[detail!, const SizedBox(height: 16)],
              list,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 400, child: list),
            const SizedBox(width: 16),
            Expanded(
              child:
                  detail ??
                  Panel(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'Select an item',
                          style: TextStyle(color: AC.muted),
                        ),
                      ),
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------- Safety ----------------

class SafetyPage extends ConsumerStatefulWidget {
  const SafetyPage({super.key});

  @override
  ConsumerState<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends ConsumerState<SafetyPage> {
  String _filter = 'Open';
  String? _selected;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storeProvider);
    final store = ref.read(storeProvider.notifier);
    final all = data.safety;
    final list = all
        .where(
          (s) => switch (_filter) {
            'Open' => s.status != SafetyStatus.resolved,
            'Resolved' => s.status == SafetyStatus.resolved,
            'Route alerts' => s.kind == SafetyKind.routeDeviation,
            'SOS' => s.kind != SafetyKind.routeDeviation,
            _ => true,
          },
        )
        .toList();
    final sel = all
        .where(
          (s) => s.id == (_selected ?? (list.isEmpty ? null : list.first.id)),
        )
        .firstOrNull;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final settings = data.settings;

    final listPanel = Panel(
      flushBody: true,
      child: Column(
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.verified_user, size: 44, color: AC.primary),
                  const SizedBox(height: 10),
                  Text('Nothing here', style: TextStyle(color: AC.muted)),
                ],
              ),
            ),
          for (final s in list)
            InkWell(
              onTap: () => setState(() => _selected = s.id),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel?.id == s.id ? AC.selected : null,
                  border: Border(
                    top: BorderSide(color: AC.border),
                    left: BorderSide(
                      color: s.status == SafetyStatus.open
                          ? AC.red
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: s.kind.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.kind.icon, color: s.kind.color, size: 20),
                    ),
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
    );

    Widget? detail;
    if (sel != null) {
      detail = Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(sel.kind.icon, color: sel.kind.color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${sel.kind.label} on ${sel.tripId}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Pill(sel.status.label, color: sel.status.color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${formatDateTimeShort(sel.time)} (${ago(sel.time)})',
              style: TextStyle(color: AC.muted),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 230,
                child: FlutterMap(
                  key: ValueKey(sel.id),
                  options: MapOptions(
                    initialCenter: sel.position,
                    initialZoom: 15,
                  ),
                  children: [
                    adminTiles(),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: sel.position,
                          width: 120,
                          height: 120,
                          child: PulseRings(
                            size: 120,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: sel.kind.color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                sel.kind.icon,
                                color: Colors.white,
                                size: 18,
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sel.kind.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel.kind.color.withValues(alpha: 0.3),
                ),
              ),
              child: Text(sel.detail, style: const TextStyle(height: 1.5)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                CellTitle('Rider', sel.riderName),
                CellTitle('Driver', '${sel.driverName} · ${sel.plate}'),
                CellTitle(
                  'Last location',
                  '${sel.place}\n${sel.position.latitude.toStringAsFixed(5)}, ${sel.position.longitude.toStringAsFixed(5)}',
                ),
                CellTitle(
                  'Emergency contacts alerted',
                  '${sel.contactsAlerted}',
                ),
                if (sel.handledBy != null)
                  CellTitle('Handled by', sel.handledBy!),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                GhostButton(
                  label: 'Call rider',
                  icon: Icons.call,
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: '+2348000000001')),
                ),
                GhostButton(
                  label: 'Call driver',
                  icon: Icons.call,
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: '+2348000000002')),
                ),
                GhostButton(
                  label: 'Police (112)',
                  icon: Icons.local_police_outlined,
                  color: AC.red,
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                ),
                GhostButton(
                  label: 'Open in Google Maps',
                  icon: Icons.map_outlined,
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps?q=${sel.position.latitude},${sel.position.longitude}',
                    ),
                  ),
                ),
                GhostButton(
                  label: 'Trip details',
                  icon: Icons.route,
                  onPressed: () => showTripDetails(context, sel.tripId),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: TextStyle(color: AC.muted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final n in sel.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: AC.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(n)),
                  ],
                ),
              ),
            if (sel.status != SafetyStatus.resolved) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What did you do? e.g. called rider, she is safe',
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (sel.status == SafetyStatus.open)
                    GhostButton(
                      label: 'I\'m handling this',
                      icon: Icons.front_hand_outlined,
                      color: AC.orange,
                      onPressed: () {
                        store.updateSafety(
                          sel.id,
                          SafetyStatus.acknowledged,
                          note: _note.text,
                        );
                        _note.clear();
                        toast(
                          context,
                          'Marked as handling. Others can see you\'re on it.',
                        );
                      },
                    ),
                  PrimaryButton(
                    label: 'Resolve: everyone safe',
                    icon: Icons.verified_user,
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: 'Resolve this alert?',
                        body: 'Only resolve once you\'ve confirmed the rider and driver are safe. Emergency contacts will be told it\'s resolved.',
                        ok: 'Resolve',
                      );
                      if (!ok) return;
                      store.updateSafety(
                        sel.id,
                        SafetyStatus.resolved,
                        note: _note.text.isEmpty
                            ? 'Confirmed safe'
                            : _note.text,
                      );
                      _note.clear();
                      if (context.mounted) toast(context, 'Alert resolved');
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return PageBody(
      children: [
        PageHeader(
          title: 'Safety alerts',
          subtitle: 'SOS presses, automatic SOS and off-route alerts from the rider app. Respond to open ones first.',
        ),
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            StatCard(
              icon: Icons.sos,
              color: AC.red,
              label: 'Open now',
              value:
                  '${all.where((s) => s.status == SafetyStatus.open).length}',
              foot:
                  '${all.where((s) => s.status == SafetyStatus.acknowledged).length} being handled',
            ),
            StatCard(
              icon: Icons.alt_route,
              color: AC.orange,
              label: 'Route alerts this week',
              value:
                  '${all.where((s) => s.kind == SafetyKind.routeDeviation && s.time.isAfter(weekAgo)).length}',
            ),
            StatCard(
              icon: Icons.timer_off_outlined,
              color: AC.purple,
              label: 'Automatic SOS',
              value: '${all.where((s) => s.kind == SafetyKind.autoSos).length}',
              foot:
                  'Rider didn\'t answer in ${settings.routeAlertTimeoutSeconds}s',
            ),
            StatCard(
              icon: Icons.tune,
              color: AC.blue,
              label: 'Off-route trigger',
              value: '${settings.offRouteMetres} m',
              foot: 'Change in Settings',
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilterChips(
          options: const ['Open', 'All', 'SOS', 'Route alerts', 'Resolved'],
          value: _filter,
          onChanged: (v) => setState(() {
            _filter = v;
            _selected = null;
          }),
        ),
        const SizedBox(height: 16),
        MasterDetail(list: listPanel, detail: detail),
      ],
    );
  }
}

// ---------------- Support ----------------

const _canned = [
  'Thanks for reaching out. We\'re looking into this now.',
  'We\'ve refunded the amount to your GoRide wallet. It may take a few minutes to show.',
  'We\'ve contacted the driver and will update you shortly.',
  'Could you share the time of the trip and a screenshot?',
];

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  String _filter = 'Open';
  String? _selected;
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storeProvider);
    final store = ref.read(storeProvider.notifier);
    final all = data.tickets;
    final list = all
        .where(
          (t) => switch (_filter) {
            'Open' => t.status == TicketStatus.open,
            'Waiting on user' => t.status == TicketStatus.pending,
            'Resolved' => t.status == TicketStatus.resolved,
            'Drivers' => t.fromDriver,
            'Riders' => !t.fromDriver,
            _ => true,
          },
        )
        .toList();
    final sel = all
        .where(
          (t) => t.id == (_selected ?? (list.isEmpty ? null : list.first.id)),
        )
        .firstOrNull;

    Color prio(String p) => p == 'high'
        ? AC.red
        : p == 'low'
        ? AC.muted
        : AC.blue;

    final listPanel = Panel(
      flushBody: true,
      child: Column(
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text('No tickets here', style: TextStyle(color: AC.muted)),
            ),
          for (final t in list)
            InkWell(
              onTap: () => setState(() => _selected = t.id),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel?.id == t.id ? AC.selected : null,
                  border: Border(top: BorderSide(color: AC.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Initials(t.fromName, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Muted(ago(t.created), size: 12),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Muted(
                            '${t.fromName} · ${t.fromDriver ? 'Driver' : 'Rider'} · ${t.category}',
                            size: 12.5,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Pill(t.status.label, color: t.status.color),
                              const SizedBox(width: 6),
                              Pill(
                                t.priority,
                                color: prio(t.priority),
                                dot: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    Widget? detail;
    if (sel != null) {
      detail = Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sel.subject,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<TicketStatus>(
                  tooltip: 'Change status',
                  onSelected: (s) {
                    store.setTicketStatus(sel.id, s);
                    toast(context, 'Ticket marked ${s.label.toLowerCase()}');
                  },
                  itemBuilder: (_) => [
                    for (final s in TicketStatus.values)
                      PopupMenuItem(value: s, child: Text(s.label)),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Pill(sel.status.label, color: sel.status.color),
                      Icon(Icons.arrow_drop_down, color: AC.muted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${sel.id} · ${sel.fromName} (${sel.fromDriver ? 'driver' : 'rider'}) · ${sel.category}${sel.assignee == null ? '' : ' · assigned to ${sel.assignee}'}',
              style: TextStyle(color: AC.muted),
            ),
            if (sel.tripId != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: GhostButton(
                  label: 'Open trip ${sel.tripId}',
                  icon: Icons.route,
                  onPressed: () => showTripDetails(context, sel.tripId!),
                ),
              ),
            ],
            const SizedBox(height: 18),
            for (final m in sel.messages)
              Align(
                alignment: m.fromStaff
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: m.fromStaff
                        ? AC.primary.withValues(alpha: 0.16)
                        : AC.cardHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.text, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 6),
                      Muted(
                        '${m.fromStaff ? m.author : sel.fromName} · ${formatDateTimeShort(m.time)}',
                        size: 11.5,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _canned)
                  ActionChip(
                    label: Text(
                      c.length > 38 ? '${c.substring(0, 38)}...' : c,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => setState(() => _reply.text = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reply,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText:
                    'Reply to ${sel.fromName.split(' ').first}... (sent in-app and by email)',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                GhostButton(
                  label: 'Send and resolve',
                  icon: Icons.task_alt,
                  onPressed: () {
                    store.replyTicket(
                      sel.id,
                      _reply.text,
                      status: TicketStatus.resolved,
                    );
                    _reply.clear();
                    toast(context, 'Reply sent and ticket resolved');
                  },
                ),
                PrimaryButton(
                  label: 'Send reply',
                  icon: Icons.send,
                  onPressed: () {
                    if (_reply.text.trim().isEmpty) return;
                    store.replyTicket(sel.id, _reply.text);
                    _reply.clear();
                    toast(context, 'Reply sent');
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return PageBody(
      children: [
        PageHeader(
          title: 'Support',
          subtitle:
              '${all.where((t) => t.status == TicketStatus.open).length} open · from the Help pages in both apps',
        ),
        FilterChips(
          options: const [
            'Open',
            'Waiting on user',
            'Resolved',
            'Riders',
            'Drivers',
            'All',
          ],
          value: _filter,
          onChanged: (v) => setState(() {
            _filter = v;
            _selected = null;
          }),
        ),
        const SizedBox(height: 16),
        MasterDetail(list: listPanel, detail: detail),
      ],
    );
  }
}
