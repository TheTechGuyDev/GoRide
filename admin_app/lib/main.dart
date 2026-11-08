import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart' show Backend;

import 'core/router.dart';
import 'core/theme/admin_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init(sessionKey: 'sb-goride-admin-auth');
  runApp(const ProviderScope(child: GoRideAdminApp()));
}

class GoRideAdminApp extends ConsumerWidget {
  const GoRideAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(adminDarkProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GoRide Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.build(false),
      darkTheme: AdminTheme.build(true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        AC.useDark(dark);
        // Rebuild every page when the theme flips so all colours update.
        return KeyedSubtree(key: ValueKey(dark), child: child!);
      },
    );
  }
}
