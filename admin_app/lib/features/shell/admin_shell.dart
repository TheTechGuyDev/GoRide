import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/models.dart';
import '../../data/store.dart';

const _groups = [
  ('Platform', [Section.overview, Section.liveMap]),
  ('People', [Section.drivers, Section.applications, Section.riders]),
  (
    'Rides and money',
    [Section.trips, Section.revenue, Section.payouts, Section.pricing],
  ),
  ('Safety and care', [Section.safety, Section.support]),
  ('Growth', [Section.promos, Section.broadcasts]),
  (
    'Admin',
    [Section.staff, Section.settings, Section.integrations, Section.audit],
  ),
];

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(storeErrorProvider, (_, e) {
      if (e == null) return;
      toast(context, e);
      ref.read(storeErrorProvider.notifier).set(null);
    });
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final sidebar = _Sidebar(location: location, closeOnTap: !wide);
    return Scaffold(
      drawer: wide
          ? null
          : Drawer(width: 280, backgroundColor: AC.sidebar, child: sidebar),
      body: Row(
        children: [
          if (wide) SizedBox(width: 268, child: sidebar),
          Expanded(
            child: Column(
              children: [
                _TopBar(showMenu: !wide),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.closeOnTap});
  final String location;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    final data = ref.watch(storeProvider);
    final allowed = me?.role.sections ?? const <Section>{};
    final current = R.sectionFor(location);
    final badges = {
      Section.applications: data.pendingDrivers.length,
      Section.safety: data.openSafety,
      Section.support: data.openTickets,
      Section.payouts: data.pendingPayouts,
    };

    return Container(
      decoration: BoxDecoration(
        color: AC.sidebar,
        border: Border(right: BorderSide(color: AC.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
              child: Row(
                children: [
                  Image.asset('assets/images/logo_green.png', width: 36),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GoRide',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Platform control',
                        style: TextStyle(fontSize: 12, color: AC.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final (title, items) in _groups)
                    if (items.any(allowed.contains)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AC.faint,
                          ),
                        ),
                      ),
                      for (final s in items)
                        if (allowed.contains(s))
                          _NavItem(
                            section: s,
                            selected: current == s,
                            badge: badges[s] ?? 0,
                            urgent: s == Section.safety,
                            onTap: () {
                              if (closeOnTap) Navigator.of(context).pop();
                              context.go(R.of(s));
                            },
                          ),
                    ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (allowed.contains(Section.applications))
              Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AC.border),
                  gradient: LinearGradient(
                    colors: [AC.primary.withValues(alpha: 0.18), AC.card],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_reg,
                          size: 20,
                          color: AC.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${data.pendingDrivers.length} drivers waiting',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        if (closeOnTap) Navigator.of(context).pop();
                        context.go(R.applications);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AC.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Review applications',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.badge,
    required this.onTap,
    this.urgent = false,
  });

  final Section section;
  final bool selected;
  final int badge;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AC.selected : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: const BorderSide(color: AC.primary, width: 3),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  section.icon,
                  size: 20,
                  color: selected ? AC.primary : AC.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AC.text : AC.muted,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: urgent
                          ? AC.red
                          : AC.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: urgent ? Colors.white : AC.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.showMenu});
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    final data = ref.watch(storeProvider);
    final dark = ref.watch(adminDarkProvider);
    final narrow = MediaQuery.sizeOf(context).width < 700;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AC.border)),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          if (!narrow) const SizedBox(width: 4, child: null),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: const _GlobalSearch(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: dark ? 'Light mode' : 'Dark mode',
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => ref.read(adminDarkProvider.notifier).toggle(),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Safety alerts',
                icon: const Icon(Icons.notifications_none),
                onPressed: () => context.go(R.safety),
              ),
              if (data.openSafety > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AC.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          if (me != null)
            PopupMenuButton<String>(
              tooltip: 'Account',
              offset: const Offset(0, 54),
              onSelected: (v) {
                if (v == 'out') ref.read(sessionProvider.notifier).signOut();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    '${me.email}\n${me.role.description}',
                    style: TextStyle(fontSize: 12, color: AC.muted),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'out', child: Text('Sign out')),
              ],
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AC.lime,
                      shape: BoxShape.circle,
                    ),
                    child: Initials(me.name, size: 38, color: AC.primaryDeep),
                  ),
                  if (!narrow) ...[
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          me.role.label,
                          style: TextStyle(fontSize: 12, color: AC.muted),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down, color: AC.muted),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Search drivers, riders and trips by name, ID, phone or plate.
class _GlobalSearch extends ConsumerWidget {
  const _GlobalSearch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(storeProvider);
    final allowed = ref.watch(sessionProvider)?.role.sections ?? const {};
    return SearchAnchor(
      viewBackgroundColor: AC.card,
      dividerColor: AC.border,
      viewHintText: 'Search drivers, riders, trip IDs, plates',
      builder: (context, controller) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: controller.openView,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AC.field,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AC.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: AC.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search drivers, riders, trip IDs, plates',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AC.faint),
                ),
              ),
            ],
          ),
        ),
      ),
      suggestionsBuilder: (context, controller) {
        final q = controller.text.trim().toLowerCase();
        if (q.length < 2) {
          return [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Type at least 2 characters',
                style: TextStyle(color: AC.muted),
              ),
            ),
          ];
        }
        final results = <Widget>[];
        if (allowed.contains(Section.drivers)) {
          for (final d
              in data.drivers
                  .where(
                    (d) =>
                        d.name.toLowerCase().contains(q) ||
                        d.id.toLowerCase().contains(q) ||
                        d.plate.toLowerCase().contains(q) ||
                        d.phone.replaceAll(' ', '').contains(q),
                  )
                  .take(5)) {
            results.add(
              ListTile(
                leading: Initials(d.name),
                title: Text(d.name),
                subtitle: Text('Driver · ${d.plate} · ${d.status.label}'),
                onTap: () {
                  controller.closeView('');
                  context.go(R.driver(d.id));
                },
              ),
            );
          }
        }
        if (allowed.contains(Section.riders)) {
          for (final r
              in data.riders
                  .where(
                    (r) =>
                        r.name.toLowerCase().contains(q) ||
                        r.id.toLowerCase().contains(q) ||
                        r.phone.replaceAll(' ', '').contains(q),
                  )
                  .take(5)) {
            results.add(
              ListTile(
                leading: Initials(r.name),
                title: Text(r.name),
                subtitle: Text('Rider · ${r.id}'),
                onTap: () {
                  controller.closeView('');
                  context.go(R.rider(r.id));
                },
              ),
            );
          }
        }
        if (allowed.contains(Section.trips)) {
          for (final t
              in data.trips
                  .where((t) => t.id.toLowerCase().contains(q))
                  .take(5)) {
            results.add(
              ListTile(
                leading: const Icon(Icons.route),
                title: Text(t.id),
                subtitle: Text(
                  '${t.pickup} to ${t.dropoff} · ${t.status.label}',
                ),
                onTap: () {
                  controller.closeView('');
                  context.go('${R.trips}?q=${t.id}');
                },
              ),
            );
          }
        }
        if (results.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No matches for "$q"',
                style: TextStyle(color: AC.muted),
              ),
            ),
          ];
        }
        return results;
      },
    );
  }
}
