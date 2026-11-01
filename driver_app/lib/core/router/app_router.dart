import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../features/account/account_details.dart';
import '../../features/account/account_tab.dart';
import '../../features/account/more_screens.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_screen.dart';
import '../../features/earnings/earnings_tab.dart';
import '../../features/earnings/wallet_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/home/trip_preferences_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/registration/application_status_screen.dart';
import '../../features/registration/bank_screen.dart';
import '../../features/registration/documents_screen.dart';
import '../../features/registration/personal_details_screen.dart';
import '../../features/registration/plan_screen.dart';
import '../../features/registration/registration_controller.dart';
import '../../features/registration/registration_hub_screen.dart';
import '../../features/registration/vehicle_screen.dart';
import '../../features/safety/emergency_contacts.dart';
import '../../features/safety/safety_screen.dart';
import '../../features/trip/trip_extras.dart';
import '../../features/trip/trip_screen.dart';
import '../../features/trips/trips_screens.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRoute _page(String path, Widget Function(GoRouterState s) build) => GoRoute(
  path: path,
  parentNavigatorKey: _rootKey,
  builder: (_, s) => build(s),
);

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: Routes.signUp,
      builder: (_, _) => const PhoneScreen(flow: AuthFlow.signUp),
    ),
    GoRoute(
      path: Routes.signIn,
      builder: (_, _) => const PhoneScreen(flow: AuthFlow.signIn),
    ),
    GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),

    // Registration
    GoRoute(
      path: Routes.registration,
      builder: (_, _) => const RegistrationHubScreen(),
    ),
    _page(Routes.regPersonal, (_) => const PersonalDetailsScreen()),
    _page(Routes.regVehicle, (_) => const VehicleScreen()),
    _page(Routes.regDocuments, (_) => const DocumentsScreen()),
    _page(
      Routes.regDocument,
      (s) => DocumentUploadScreen(
        type: DocType.values.byName(s.pathParameters['type']!),
      ),
    ),
    _page(Routes.regPlan, (_) => const PlanScreen()),
    _page(Routes.regBank, (_) => const BankScreen()),
    GoRoute(
      path: Routes.regStatus,
      builder: (_, _) => const ApplicationStatusScreen(),
    ),

    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => HomeShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.earnings,
              builder: (_, _) => const EarningsTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.trips, builder: (_, _) => const TripsTab()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.account,
              builder: (_, _) => const AccountTab(),
            ),
          ],
        ),
      ],
    ),

    // Driving
    _page(Routes.tripPreferences, (_) => const TripPreferencesScreen()),
    _page(Routes.trip, (_) => const TripScreen()),
    _page(Routes.tripChat, (_) => const TripChatScreen()),
    _page(Routes.cancelTrip, (_) => const CancelTripScreen()),
    _page(Routes.tripComplete, (_) => const TripCompleteScreen()),
    _page(
      Routes.tripDetails,
      (s) => TripDetailsScreen(id: s.pathParameters['id']!),
    ),

    // Money
    _page(Routes.wallet, (_) => const WalletScreen()),
    _page(Routes.payout, (_) => const PayoutScreen()),
    _page(Routes.settle, (s) => SettleScreen(suggested: s.extra as int?)),
    _page(Routes.transactions, (_) => const TransactionsScreen()),
    _page(Routes.plan, (_) => const PlanScreen(manage: true)),

    // Account
    _page(Routes.profile, (_) => const PersonalDetailsScreen(editing: true)),
    _page(Routes.vehicle, (_) => const VehicleInfoScreen()),
    _page(Routes.documents, (_) => const DocumentsScreen(fromAccount: true)),
    _page(Routes.bank, (_) => const BankScreen()),
    _page(Routes.ratings, (_) => const RatingsScreen()),
    _page(
      Routes.notificationSettings,
      (_) => const NotificationSettingsScreen(),
    ),
    _page(Routes.appearance, (_) => const AppearanceScreen()),
    _page(Routes.help, (_) => const HelpSupportScreen()),
    _page(Routes.referral, (_) => const ReferralScreen()),
    _page(Routes.privacyPolicy, (_) => const LegalScreen(terms: false)),
    _page(Routes.terms, (_) => const LegalScreen(terms: true)),
    _page(Routes.notifications, (_) => const NotificationsScreen()),

    // Safety
    _page(Routes.emergency, (_) => const SafetyScreen()),
    _page(Routes.emergencyContacts, (_) => const EmergencyContactsScreen()),
  ],
);
