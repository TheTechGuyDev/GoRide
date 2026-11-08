import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:goride_core/goride_core.dart';

import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'features/home/request_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init(sessionKey: 'sb-goride-driver-auth');
  runApp(const ProviderScope(child: GoRideDriverApp()));
}

class GoRideDriverApp extends ConsumerWidget {
  const GoRideDriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GoRide Driver',
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
          child: InAppNotificationHost(
            child: Stack(children: [child!, const RequestOverlay()]),
          ),
        );
        if (kIsWeb) app = WebPreviewFrame(child: app);
        return app;
      },
    );
  }
}
