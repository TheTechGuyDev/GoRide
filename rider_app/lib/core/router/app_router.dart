import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/personal_info_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/booking/payment_method_screen.dart';
import '../../features/booking/promos_screen.dart';
import '../../features/booking/ride_options_screen.dart';
import '../../features/booking/set_pickup_screen.dart';
import '../../features/booking/where_to_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/trip/call_screen.dart';
import '../../features/trip/cancel_ride_screen.dart';
import '../../features/trip/chat_screen.dart';
import '../../features/trip/driver_info_screen.dart';
import '../../features/trip/trip_arrived_screen.dart';
import '../../features/trip/trip_screen.dart';
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
              builder: (_, _) => const PromosScreen(),
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

    GoRoute(
      path: Routes.whereTo,
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          WhereToScreen(savedPlaceId: state.extra as String?),
    ),
    GoRoute(
      path: Routes.setPickup,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const SetPickupScreen(),
    ),
    GoRoute(
      path: Routes.rideOptions,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const RideOptionsScreen(),
    ),
    GoRoute(
      path: Routes.paymentMethod,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const PaymentMethodScreen(),
    ),
    GoRoute(
      path: Routes.applyPromo,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const PromosScreen(applying: true),
    ),
    GoRoute(
      path: Routes.trip,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const TripScreen(),
      routes: [
        GoRoute(
          path: 'driver',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => const DriverInfoScreen(),
        ),
        GoRoute(
          path: 'chat',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => const ChatScreen(),
        ),
        GoRoute(
          path: 'call',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => const CallScreen(),
        ),
        GoRoute(
          path: 'cancel',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => const CancelRideScreen(),
        ),
      ],
    ),
    GoRoute(
      path: Routes.rideCanceled,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const RideCanceledScreen(),
    ),
    GoRoute(
      path: Routes.tripArrived,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const TripArrivedScreen(),
    ),
    // Built in Step 7 (rating, tip & receipt).
    GoRoute(
      path: Routes.rateDriver,
      parentNavigatorKey: _rootKey,
      builder: (_, _) => const RateDriverPlaceholder(),
    ),
  ],
);
