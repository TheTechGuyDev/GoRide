import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/platform/web_insets.dart';
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
          kIsWeb ? _WebPreviewFrame(child: child!) : child!,
    );
  }
}

/// Web preview (GitHub Pages) only:
/// - Phones: full screen, with the iPhone notch/home-bar safe areas applied
///   so top and bottom bars are never hidden.
/// - Laptops: the app is shown inside a phone-sized frame.
class _WebPreviewFrame extends StatelessWidget {
  const _WebPreviewFrame({required this.child});

  final Widget child;

  static const double _phoneWidth = 400;
  static const double _phoneHeight = 860;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;

    if (size.width <= 600) {
      final insets = readWebSafeInsets();
      EdgeInsets merge(EdgeInsets a) => EdgeInsets.only(
        left: a.left,
        right: a.right,
        top: a.top > insets.top ? a.top : insets.top,
        bottom: a.bottom > insets.bottom ? a.bottom : insets.bottom,
      );
      return MediaQuery(
        data: mq.copyWith(
          padding: merge(mq.padding),
          viewPadding: merge(mq.viewPadding),
        ),
        child: child,
      );
    }

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
            data: mq.copyWith(size: Size(_phoneWidth - 16, height - 16)),
            child: child,
          ),
        ),
      ),
    );
  }
}
