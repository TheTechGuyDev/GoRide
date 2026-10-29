import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GoRideApp()));
}

class GoRideApp extends StatelessWidget {
  const GoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoRide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      builder: (context, child) =>
          kIsWeb ? _WebPhoneFrame(child: child!) : child!,
    );
  }
}

/// On the web preview (GitHub Pages), wide screens show the app inside a
/// phone-sized frame so it looks like the real mobile app. Phones get full width.
class _WebPhoneFrame extends StatelessWidget {
  const _WebPhoneFrame({required this.child});

  final Widget child;

  static const double _phoneWidth = 400;
  static const double _phoneHeight = 860;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 600) return child;

    final height = size.height < _phoneHeight + 40
        ? size.height - 40
        : _phoneHeight;

    return ColoredBox(
      color: const Color(0xFFEFF3F1),
      child: Center(
        child: Container(
          width: _phoneWidth,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFF1F1F1F), width: 8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(size: Size(_phoneWidth - 16, height - 16)),
            child: child,
          ),
        ),
      ),
    );
  }
}
