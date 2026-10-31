import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

/// On/off settings keyed by id. Later: a `rider_settings` row in Supabase,
/// so preferences follow the rider to a new phone.
class ToggleSettings extends Notifier<Map<String, bool>> {
  ToggleSettings(this._defaults);
  final Map<String, bool> _defaults;

  @override
  Map<String, bool> build() => Map.of(_defaults);

  bool get(String id) => state[id] ?? false;
  void set(String id, bool value) => state = {...state, id: value};
}

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

/// Grey page background with white rounded groups, like the kit.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.locked = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      value: value,
      onChanged: locked ? null : onChanged,
      activeTrackColor: AppColors.primary,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12)),
    );
  }
}

class SettingsLinkTile extends StatelessWidget {
  const SettingsLinkTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.danger = false,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool danger;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
      leading: icon == null ? null : Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: color),
    );
  }
}

/// Shared scaffold for settings pages.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
  });

  final String title;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(title: Text(title), backgroundColor: AppColors.fieldFill),
      body: ListView(padding: const EdgeInsets.all(20), children: children),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
            ),
    );
  }
}
