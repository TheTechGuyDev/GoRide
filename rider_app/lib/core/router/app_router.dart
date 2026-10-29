import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/personal_info_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/home/home_tab.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/walkthrough_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(
      path: Routes.walkthrough,
      builder: (_, _) => const WalkthroughScreen(),
    ),
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
    GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
    GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),
    GoRoute(
      path: Routes.personalInfo,
      builder: (_, _) => const PersonalInfoScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => HomeShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.promos,
              builder: (_, _) =>
                  const ComingSoonTab(title: 'Promos', icon: Icons.local_offer),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.activity,
              builder: (_, _) => const ComingSoonTab(
                title: 'Activity',
                icon: Icons.receipt_long,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.account,
              builder: (_, _) =>
                  const ComingSoonTab(title: 'Account', icon: Icons.person),
            ),
          ],
        ),
      ],
    ),

    // Built in Step 4 (destination search).
    GoRoute(
      path: Routes.whereTo,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const ComingSoonTab(
        title: 'Where do you want to go?',
        icon: Icons.search,
      ),
    ),
  ],
);
