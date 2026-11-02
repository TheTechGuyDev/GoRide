import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'package:goride_core/goride_core.dart' show WebPreviewFrame, Backend;
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  runApp(const ProviderScope(child: GoRideApp()));
}

class GoRideApp extends ConsumerWidget {
  const GoRideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GoRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: appRouter,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        AppColors.useDark(dark);
        // Rebuild every screen when light/dark changes so all colours update.
        Widget app = KeyedSubtree(
          key: ValueKey(dark),
          child: InAppNotificationHost(child: child!),
        );
        if (kIsWeb) app = WebPreviewFrame(child: app);
        return app;
      },
    );
  }
}

