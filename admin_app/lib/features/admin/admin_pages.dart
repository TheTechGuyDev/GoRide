import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../overview/overview_page.dart';

// ---------------- Staff & roles ----------------

class StaffPage extends ConsumerWidget {
  const StaffPage({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    StaffMember? m,
  ]) async {
    final name = TextEditingController(text: m?.name ?? '');
    final email = TextEditingController(text: m?.email ?? '');
    var role = m?.role ?? AdminRole.support;
    final result = await showDialog<StaffMember>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            m == null ? 'Invite staff member' : 'Change role',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  enabled: m == null,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  enabled: m == null,
                  decoration: const InputDecoration(labelText: 'Work email'),
                ),
                const SizedBox(height: 16),
                Text('Role', style: TextStyle(color: AC.muted)),
                const SizedBox(height: 6),
                for (final r in AdminRole.values)
                  RadioListTile<AdminRole>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: r,
                    // ignore: deprecated_member_use
                    groupValue: role,
                    activeColor: AC.primary,
                    // ignore: deprecated_member_use
                    onChanged: (v) => set(() => role = v!),
                    title: Text(
                      r.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      r.description,
                      style: TextStyle(fontSize: 12, color: AC.muted),
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
              style: FilledButton.styleFrom(backgroundColor: AC.primary),
              onPressed: () {
                if (name.text.trim().isEmpty || !email.text.contains('@'))
                  return;
                Navigator.pop(
                  ctx,
                  m?.copyWith(role: role) ??
                      StaffMember(
                        id: 'ST${DateTime.now().millisecondsSinceEpoch}',
                        name: name.text.trim(),
                        email: email.text.trim(),
                        role: role,
                      ),
                );
              },
              child: Text(m == null ? 'Send invite' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      ref.read(storeProvider.notifier).saveStaff(result);
      if (context.mounted) {
        toast(
          context,
          m == null
              ? 'Invite sent to ${result.email}'
              : '${result.name} is now ${result.role.label}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final me = ref.watch(sessionProvider)!;

    return PageBody(
      children: [
        PageHeader(
          title: 'Staff and roles',
          subtitle: 'Each role only sees the pages it needs',
          actions: [
            PrimaryButton(
              label: 'Invite staff',
              icon: Icons.person_add_alt,
              onPressed: () => _edit(context, ref),
            ),
          ],
        ),
        Panel(
          flushBody: true,
          child: DataGrid(
            minWidth: 820,
            flex: const [4, 2, 2, 2, 2],
            columns: const [
              'Staff member',
              'Role',
              'Last active',
              'Access',
              '',
            ],
            rows: [
              for (final s in data.staff)
                [
                  CellTitle(s.name, s.email, leading: Initials(s.name)),
                  Pill(
                    s.role.label,
                    color: s.role == AdminRole.superAdmin ? AC.lime : AC.blue,
                    dot: false,
                  ),
                  Muted(
                    s.lastActive == null ? 'Invite sent' : ago(s.lastActive!),
                  ),
                  s.active
                      ? const Pill('Active', color: AC.primary)
                      : const Pill('Removed', color: AC.red),
                  s.id == me.id
                      ? Muted('You')
                      : PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, color: AC.muted),
                          onSelected: (v) async {
                            if (v == 'role') return _edit(context, ref, s);
                            final ok = await confirm(
                              context,
                              title: s.active
                                  ? 'Remove ${s.name}\'s access?'
                                  : 'Restore ${s.name}\'s access?',
                              body: s.active
                                  ? 'They\'ll be signed out and can\'t sign in again.'
                                  : 'They can sign in again with the same role.',
                              danger: s.active,
                              ok: s.active ? 'Remove' : 'Restore',
                            );
                            if (ok)
                              ref
                                  .read(storeProvider.notifier)
                                  .setStaffActive(s.id, !s.active);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'role',
                              child: Text('Change role'),
                            ),
                            PopupMenuItem(
                              value: 'access',
                              child: Text(
                                s.active ? 'Remove access' : 'Restore access',
                              ),
                            ),
                          ],
                        ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'What each role can open',
          flushBody: true,
          child: DataGrid(
            minWidth: 900,
            flex: [3, for (final _ in AdminRole.values) 2],
            columns: ['Page', for (final r in AdminRole.values) r.label],
            rows: [
              for (final sec in Section.values)
                [
                  Row(
                    children: [
                      Icon(sec.icon, size: 18, color: AC.muted),
                      const SizedBox(width: 10),
                      Text(sec.label),
                    ],
                  ),
                  for (final r in AdminRole.values)
                    r.sections.contains(sec)
                        ? const Icon(
                            Icons.check_circle,
                            color: AC.primary,
                            size: 20,
                          )
                        : Icon(Icons.remove, color: AC.faint, size: 20),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Promo codes ----------------

class PromosPage extends ConsumerWidget {
  const PromosPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final desc = TextEditingController();
    final value = TextEditingController(text: '20');
    final cap = TextEditingController(text: '1500');
    final limit = TextEditingController(text: '1000');
    var percent = true;
    var newOnly = false;
    var days = 30;
    final promo = await showDialog<Promo>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text(
            'New promo code',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(14),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'e.g. EASTER25',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: desc,
                    decoration: const InputDecoration(
                      labelText: 'Description (shown to riders)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Percent off')),
                      ButtonSegment(value: false, label: Text('Naira off')),
                    ],
                    selected: {percent},
                    onSelectionChanged: (v) => set(() => percent = v.first),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: value,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: percent ? 'Percent' : 'Amount',
                            suffixText: percent ? '%' : null,
                            prefixText: percent ? null : '₦ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (percent)
                        Expanded(
                          child: TextField(
                            controller: cap,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Max discount',
                              prefixText: '₦ ',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: limit,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Total uses allowed',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: days,
                          dropdownColor: AC.card,
                          decoration: const InputDecoration(
                            labelText: 'Runs for',
                          ),
                          items: const [
                            DropdownMenuItem(value: 7, child: Text('7 days')),
                            DropdownMenuItem(value: 14, child: Text('14 days')),
                            DropdownMenuItem(value: 30, child: Text('30 days')),
                            DropdownMenuItem(value: 90, child: Text('90 days')),
                          ],
                          onChanged: (v) => set(() => days = v ?? 30),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: newOnly,
                    activeColor: AC.primary,
                    onChanged: (v) => set(() => newOnly = v ?? false),
                    title: const Text('New riders only (first trip)'),
                  ),
                ],
              ),
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
                final v = int.tryParse(value.text) ?? 0;
                if (code.text.length < 4 || v <= 0) return;
                Navigator.pop(
                  ctx,
                  Promo(
                    code: code.text.toUpperCase(),
                    description: desc.text.trim().isEmpty
                        ? (percent ? '$v% off' : '₦$v off')
                        : desc.text.trim(),
                    percent: percent,
                    value: v,
                    maxDiscount: percent ? int.tryParse(cap.text) ?? 0 : v,
                    uses: 0,
                    limit: int.tryParse(limit.text) ?? 1000,
                    expires: DateTime.now().add(Duration(days: days)),
                    newRidersOnly: newOnly,
                  ),
                );
              },
              child: const Text('Create code'),
            ),
          ],
        ),
      ),
    );
    if (promo != null) {
      final exists = ref
          .read(storeProvider)
          .promos
          .any((p) => p.code == promo.code);
      if (exists) {
        if (context.mounted) toast(context, '${promo.code} already exists');
        return;
      }
      ref.read(storeProvider.notifier).addPromo(promo);
      if (context.mounted)
        toast(context, '${promo.code} is live in the rider app');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promos = ref.watch(storeProvider).promos;
    final store = ref.read(storeProvider.notifier);
    return PageBody(
      children: [
        PageHeader(
          title: 'Promo codes',
          subtitle: 'Riders enter these on the Promos screen or when booking',
          actions: [
            PrimaryButton(
              label: 'New promo code',
              icon: Icons.add,
              onPressed: () => _create(context, ref),
            ),
          ],
        ),
        Panel(
          flushBody: true,
          child: DataGrid(
            minWidth: 900,
            flex: const [3, 2, 3, 2, 2, 1],
            columns: const ['Code', 'Offer', 'Used', 'Ends', 'Status', ''],
            rows: [
              for (final p in promos)
                [
                  CellTitle(p.code, p.description),
                  CellTitle(
                    p.offer,
                    p.percent
                        ? 'max ${naira(p.maxDiscount)}${p.newRidersOnly ? ' · new riders' : ''}'
                        : (p.newRidersOnly ? 'new riders' : null),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${p.uses} of ${p.limit}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 140,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (p.uses / p.limit).clamp(0, 1),
                            minHeight: 5,
                            color: AC.primary,
                            backgroundColor: AC.border,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Muted(formatDate(p.expires)),
                  p.expired
                      ? const Pill('Expired', color: Color(0xFF94A3B8))
                      : p.uses >= p.limit
                      ? const Pill('Used up', color: AC.orange)
                      : p.active
                      ? const Pill('Live', color: AC.primary)
                      : const Pill('Paused', color: AC.orange),
                  p.expired
                      ? const SizedBox.shrink()
                      : Switch(
                          value: p.active,
                          onChanged: (v) {
                            store.togglePromo(p.code, v);
                            toast(
                              context,
                              '${p.code} ${v ? 'is live' : 'paused'}',
                            );
                          },
                        ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- Notifications (broadcasts) ----------------

class BroadcastsPage extends ConsumerStatefulWidget {
  const BroadcastsPage({super.key});

  @override
  ConsumerState<BroadcastsPage> createState() => _BroadcastsPageState();
}

class _BroadcastsPageState extends ConsumerState<BroadcastsPage> {
  String _audience = 'Riders';
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(storeProvider);
    final reach = switch (_audience) {
      'Riders' => data.riders.length,
      'Drivers' =>
        data.drivers.where((d) => d.status == DriverStatus.active).length,
      _ => data.riders.length + data.drivers.length,
    };

    final composer = Panel(
      title: 'Send a notification',
      subtitle: 'Free push notification (Firebase Cloud Messaging) to phones, plus the in-app inbox',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterChips(
            options: const ['Riders', 'Drivers', 'Everyone'],
            value: _audience,
            onChanged: (v) => setState(() => _audience = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. 20% off this weekend',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            onChanged: (_) => setState(() {}),
            maxLength: 180,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 8),
          Text('Preview', style: TextStyle(color: AC.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AC.cardHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/images/logo_green.png', width: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title.text.isEmpty ? 'Title' : _title.text,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _body.text.isEmpty
                            ? 'Your message appears here'
                            : _body.text,
                        style: TextStyle(color: AC.muted),
                      ),
                    ],
                  ),
                ),
                Muted('now', size: 11),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              label:
                  'Send to $reach ${_audience == 'Everyone' ? 'people' : _audience.toLowerCase()}',
              icon: Icons.send,
              onPressed: _title.text.trim().isEmpty || _body.text.trim().isEmpty
                  ? null
                  : () async {
                      final ok = await confirm(
                        context,
                        title: 'Send to $reach people?',
                        body: 'This can\'t be unsent.',
                        ok: 'Send',
                      );
                      if (!ok) return;
                      ref
                          .read(storeProvider.notifier)
                          .sendBroadcast(
                            _audience,
                            _title.text.trim(),
                            _body.text.trim(),
                          );
                      _title.clear();
                      _body.clear();
                      setState(() {});
                      if (context.mounted) toast(context, 'Notification sent');
                    },
            ),
          ),
        ],
      ),
    );

    final history = Panel(
      title: 'Sent',
      flushBody: true,
      child: Column(
        children: [
          for (final b in data.broadcasts)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AC.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Pill(
                        b.audience,
                        color: b.audience == 'Drivers'
                            ? AC.blue
                            : b.audience == 'Riders'
                            ? AC.primary
                            : AC.purple,
                        dot: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(b.body, style: TextStyle(color: AC.muted)),
                  const SizedBox(height: 6),
                  Muted(
                    '${b.reach} people · ${b.sentBy} · ${ago(b.sentAt)}',
                    size: 12,
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return PageBody(
      children: [
        const PageHeader(
          title: 'Notifications',
          subtitle: 'Announcements, promos and service updates',
        ),
        SplitRow(left: composer, right: history, leftFlex: 3, rightFlex: 2),
      ],
    );
  }
}

// ---------------- Settings ----------------

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final s = data.settings;
    final store = ref.read(storeProvider.notifier);

    Widget number(
      String label,
      int value,
      String help,
      AppSettings Function(int) apply, {
      String? suffix,
      String? prefix,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                Text(help, style: TextStyle(fontSize: 12.5, color: AC.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: TextEditingController(text: '$value'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                suffixText: suffix,
                prefixText: prefix,
              ),
              onSubmitted: (v) {
                final n = int.tryParse(v);
                if (n == null || n == value) return;
                store.saveSettings(
                  apply(n),
                  'Changed $label to $n${suffix ?? ''}',
                );
                toast(context, '$label saved');
              },
            ),
          ),
        ],
      ),
    );

    return PageBody(
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Press Enter in a field to save it. Changes apply to both apps right away.',
        ),
        SplitRow(
          leftFlex: 1,
          rightFlex: 1,
          left: Panel(
            title: 'Route safety',
            subtitle: 'How the rider app\'s off-route alarm behaves',
            child: Column(
              children: [
                number(
                  'Off-route distance',
                  s.offRouteMetres,
                  'Alert when the car is this far from the planned route',
                  (v) => s.copyWith(offRouteMetres: v),
                  suffix: ' m',
                ),
                number(
                  'Rider response time',
                  s.routeAlertTimeoutSeconds,
                  'No answer in this time sends SOS automatically',
                  (v) => s.copyWith(routeAlertTimeoutSeconds: v),
                  suffix: ' s',
                ),
                number(
                  'Request timeout',
                  s.requestTimeoutSeconds,
                  'Seconds a driver has to accept a request',
                  (v) => s.copyWith(requestTimeoutSeconds: v),
                  suffix: ' s',
                ),
                number(
                  'Free waiting time',
                  s.freeWaitMinutes,
                  'Before the waiting fee starts',
                  (v) => s.copyWith(freeWaitMinutes: v),
                  suffix: ' min',
                ),
              ],
            ),
          ),
          right: Panel(
            title: 'Emergency alert channels',
            subtitle: 'How next of kin are told when SOS fires. Free channels are on; paid ones can be switched on later.',
            child: Column(
              children: [
                for (final c in data.channels)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Pill(
                                    c.free ? 'Free' : c.cost ?? 'Paid',
                                    color: c.free ? AC.primary : AC.orange,
                                    dot: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.description,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AC.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: c.enabled,
                          onChanged: c.id == 'safety_team'
                              ? null
                              : (v) async {
                                  if (v && !c.free) {
                                    final ok = await confirm(
                                      context,
                                      title: 'Turn on ${c.name}?',
                                      body:
                                          'This channel costs money (${c.cost}). It needs a funded account with the provider before it works.',
                                      ok: 'Turn on',
                                    );
                                    if (!ok) return;
                                  }
                                  store.toggleChannel(c.id, v);
                                  if (context.mounted)
                                    toast(
                                      context,
                                      '${c.name} ${v ? 'on' : 'off'}',
                                    );
                                },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SplitRow(
          leftFlex: 1,
          rightFlex: 1,
          left: Panel(
            title: 'Referrals',
            child: Column(
              children: [
                number(
                  'Rider referral reward',
                  s.referralRiderReward,
                  'Both riders get this when the friend takes a first ride',
                  (v) => s.copyWith(referralRiderReward: v),
                  prefix: '₦',
                ),
                number(
                  'Driver referral bonus',
                  s.referralDriverReward,
                  'When an invited driver completes 20 trips',
                  (v) => s.copyWith(referralDriverReward: v),
                  prefix: '₦',
                ),
              ],
            ),
          ),
          right: Panel(
            title: 'Service status',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.maintenanceMode,
              activeThumbColor: Colors.white,
              activeTrackColor: AC.red,
              onChanged: (v) async {
                final ok = await confirm(
                  context,
                  title: v ? 'Pause GoRide?' : 'Resume GoRide?',
                  body: v
                      ? 'Riders won\'t be able to book and drivers can\'t go online. Trips in progress continue. Use only for emergencies or planned maintenance.'
                      : 'Riders can book and drivers can go online again.',
                  danger: v,
                  ok: v ? 'Pause service' : 'Resume',
                );
                if (ok)
                  store.saveSettings(
                    s.copyWith(maintenanceMode: v),
                    v
                        ? 'Paused the service (maintenance mode)'
                        : 'Resumed the service',
                  );
              },
              title: const Text(
                'Maintenance mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                s.maintenanceMode
                    ? 'GoRide is paused for riders and drivers'
                    : 'GoRide is running normally',
                style: TextStyle(
                  color: s.maintenanceMode ? AC.red : AC.muted,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Testing',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: s.demoDriveAllowed,
            onChanged: (v) => store.saveSettings(
              s.copyWith(demoDriveAllowed: v),
              v ? 'Demo drive turned on for drivers' : 'Demo drive turned off',
            ),
            title: const Text(
              'Demo drive in the driver app',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              s.demoDriveAllowed
                  ? 'Drivers see a button that makes the car drive itself (for testing with one phone)'
                  : 'Hidden. Drivers always use real GPS',
              style: TextStyle(color: AC.muted, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- Audit log ----------------

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  String _cat = 'All';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(storeProvider).audit;
    final cats = [
      'All',
      ...{for (final a in all) a.category},
    ];
    final list = _cat == 'All'
        ? all
        : all.where((a) => a.category == _cat).toList();
    return PageBody(
      children: [
        const PageHeader(
          title: 'Audit log',
          subtitle:
              'Every change made by staff, newest first. It can\'t be edited.',
        ),
        FilterChips(
          options: cats,
          value: _cat,
          onChanged: (v) => setState(() => _cat = v),
        ),
        const SizedBox(height: 16),
        Panel(
          flushBody: true,
          child: DataGrid(
            minWidth: 760,
            flex: const [2, 3, 6, 2],
            columns: const ['When', 'Who', 'What', 'Area'],
            rows: [
              for (final a in list)
                [
                  Muted(formatDateTimeShort(a.time)),
                  CellTitle(a.who, null, leading: Initials(a.who, size: 28)),
                  Text(a.action, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Pill(a.category, color: AC.blue, dot: false),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
