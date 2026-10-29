import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/personal_info_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/home/home_placeholder_screen.dart';
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
    GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
    GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
    GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),
    GoRoute(
      path: Routes.personalInfo,
      builder: (_, _) => const PersonalInfoScreen(),
    ),
    GoRoute(
      path: Routes.home,
      builder: (_, _) => const HomePlaceholderScreen(),
    ),
  ],
);
