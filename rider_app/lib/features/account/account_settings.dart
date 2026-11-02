import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:goride_core/goride_core.dart';

export 'package:goride_core/src/widgets/settings_widgets.dart';

/// Notification preferences (used for push notifications in Step 12).
class NotificationPref {
  const NotificationPref(
    this.id,
    this.title,
    this.subtitle, {
    this.locked = false,
  });
  final String id;
  final String title;
  final String subtitle;

  /// Safety alerts can't be turned off.
  final bool locked;
}

const notificationPrefs = [
  NotificationPref(
    'safety',
    'Safety and security alerts',
    'Route alerts, SOS and account security. Always on.',
    locked: true,
  ),
  NotificationPref(
    'ride_status',
    'Ride status updates',
    'Driver found, arriving, trip started and ended',
  ),
  NotificationPref(
    'messages',
    'Driver messages',
    'New chat messages from your driver',
  ),
  NotificationPref(
    'scheduled',
    'Scheduled ride reminders',
    'Reminders before a scheduled pickup',
  ),
  NotificationPref(
    'wallet',
    'Wallet and payments',
    'Top ups, ride payments and refunds',
  ),
  NotificationPref(
    'traffic',
    'Traffic and flooding alerts',
    'Major road closures near your saved places',
  ),
  NotificationPref('promos', 'Promos and offers', 'Discounts and promo codes'),
  NotificationPref(
    'ratings',
    'Rating reminders',
    'Reminders to rate finished trips',
  ),
  NotificationPref(
    'updates',
    'App updates and tips',
    'New features and how to use them',
  ),
];

final notificationSettingsProvider =
    NotifierProvider<ToggleSettings, Map<String, bool>>(
      () => ToggleSettings({
        'safety': true,
        'ride_status': true,
        'messages': true,
        'scheduled': true,
        'wallet': true,
        'traffic': true,
        'promos': false,
        'ratings': true,
        'updates': false,
      }),
    );

final securitySettingsProvider =
    NotifierProvider<ToggleSettings, Map<String, bool>>(
      () => ToggleSettings({
        'biometric': false,
        'two_step': true,
        'trip_pin': true,
        'hide_name': false,
      }),
    );

final linkedAccountsProvider =
    NotifierProvider<ToggleSettings, Map<String, bool>>(
      () => ToggleSettings({'google': true, 'apple': false}),
    );

final privacySettingsProvider =
    NotifierProvider<ToggleSettings, Map<String, bool>>(
      () => ToggleSettings({
        'analytics': true,
        'personalised': true,
        'crash_reports': true,
      }),
    );
