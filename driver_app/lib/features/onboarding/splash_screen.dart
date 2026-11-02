import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../auth/auth_controller.dart';

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

  /// A saved session (including coming back from Google) goes straight in.
  Future<void> _route() async {
    final wait = Future.delayed(const Duration(milliseconds: 1500));
    String? next;
    try {
      next = await ref.read(authControllerProvider.notifier).enter();
    } catch (_) {
      // Offline or session expired: show the welcome screen.
    }
    await wait;
    if (mounted) context.go(next ?? Routes.welcome);
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
                      const Text(
                        'GoRide',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'DRIVER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
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
