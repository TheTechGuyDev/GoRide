import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    _route();
  }

  /// Signed in (including coming back from Google) goes straight in.
  Future<void> _route() async {
    final wait = Future.delayed(const Duration(milliseconds: 1600));
    var next = Routes.walkthrough;
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (await auth.loadProfile()) {
        next = ref.read(authControllerProvider).profile.complete
            ? Routes.home
            : Routes.personalInfo;
      }
    } catch (_) {
      // Offline or session expired: show the normal start screens.
    }
    await wait;
    if (mounted) context.go(next);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      Image.asset('assets/images/logo_white.png', width: 110),
                      const SizedBox(height: 28),
                      Text(
                        'GoRide',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                const SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
