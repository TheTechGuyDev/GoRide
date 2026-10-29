import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/walkthrough_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: Routes.walkthrough,
      builder: (_, _) => const WalkthroughScreen(),
    ),
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    // Built in Step 2 (auth).
    GoRoute(
      path: Routes.signUp,
      builder: (_, _) => const _ComingNext(title: 'Sign up'),
    ),
    GoRoute(
      path: Routes.signIn,
      builder: (_, _) => const _ComingNext(title: 'Sign in'),
    ),
  ],
);

class _ComingNext extends StatelessWidget {
  const _ComingNext({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Coming in the next step')),
    );
  }
}
