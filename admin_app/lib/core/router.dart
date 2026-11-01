import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../features/auth/login_page.dart';
import '../features/shell/admin_shell.dart';
import '../features/pages.dart';

class R {
  static const login = '/login';
  static const overview = '/overview';
  static const live = '/live';
  static const drivers = '/drivers';
  static String driver(String id) => '/drivers/$id';
  static const applications = '/applications';
  static const riders = '/riders';
  static String rider(String id) => '/riders/$id';
  static const trips = '/trips';
  static const revenue = '/revenue';
  static const payouts = '/payouts';
  static const pricing = '/pricing';
  static const safety = '/safety';
  static const support = '/support';
  static const promos = '/promos';
  static const broadcasts = '/notifications';
  static const staff = '/staff';
  static const settings = '/settings';
  static const audit = '/audit';

  static String of(Section s) => switch (s) {
    Section.overview => overview,
    Section.liveMap => live,
    Section.drivers => drivers,
    Section.applications => applications,
    Section.riders => riders,
    Section.trips => trips,
    Section.revenue => revenue,
    Section.payouts => payouts,
    Section.pricing => pricing,
    Section.safety => safety,
    Section.support => support,
    Section.promos => promos,
    Section.broadcasts => broadcasts,
    Section.staff => staff,
    Section.settings => settings,
    Section.audit => audit,
  };

  static Section? sectionFor(String path) {
    for (final s in Section.values) {
      final p = of(s);
      if (path == p || path.startsWith('$p/')) return s;
    }
    return null;
  }
}

/// Re-runs redirects when the session changes.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable(ref);
  return GoRouter(
    initialLocation: R.overview,
    refreshListenable: refresh,
    redirect: (context, state) {
      final me = ref.read(sessionProvider);
      final path = state.uri.path;
      if (me == null) return path == R.login ? null : R.login;
      if (path == R.login) return R.overview;
      return null;
    },
    routes: [
      GoRoute(path: R.login, builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (_, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          for (final s in Section.values)
            GoRoute(
              path: R.of(s),
              pageBuilder: (_, _) => NoTransitionPage(
                child: Guard(section: s, child: pageFor(s)),
              ),
              routes: [
                if (s == Section.drivers)
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, st) => NoTransitionPage(
                      child: Guard(
                        section: s,
                        child: DriverDetailPage(id: st.pathParameters['id']!),
                      ),
                    ),
                  ),
                if (s == Section.riders)
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, st) => NoTransitionPage(
                      child: Guard(
                        section: s,
                        child: RiderDetailPage(id: st.pathParameters['id']!),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    ],
  );
});

/// Blocks pages the signed-in role can't access.
class Guard extends ConsumerWidget {
  const Guard({super.key, required this.section, required this.child});
  final Section section;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    if (me == null || me.role.sections.contains(section)) return child;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 14),
            Text(
              'No access to ${section.label}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Your role (${me.role.label}) can\'t open this page. Ask a Super Admin.',
            ),
          ],
        ),
      ),
    );
  }
}
