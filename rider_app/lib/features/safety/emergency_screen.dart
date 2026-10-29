import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_controller.dart';
import '../trip/trip_controller.dart';
import '../trip/trip_models.dart';
import '../trip/widgets/trip_widgets.dart';
import 'emergency_contacts.dart';

/// The alert text sent to next of kin (email / push / WhatsApp).
String emergencyMessage(TripState trip, String riderName) {
  final who = riderName.isEmpty ? 'A GoRide rider' : riderName;
  final how = trip.emergency?.automatic == true
      ? 'did not respond after their driver left the planned route'
      : 'pressed SOS';
  return 'EMERGENCY from GoRide: $who $how. ${tripShareText(trip)}';
}

/// Shown while emergency mode is on.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripControllerProvider);
    final contacts = ref.watch(emergencyContactsProvider);
    final riderName = ref.watch(authControllerProvider).profile.fullName;
    final e = trip?.emergency;

    if (trip == null || e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No active emergency')),
      );
    }

    final message = emergencyMessage(trip, riderName);
    final t = e.triggeredAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        title: const Text(
          'EMERGENCY MODE',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.automatic ? 'Automatic SOS at $time' : 'SOS sent at $time',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(e.reason, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 8),
                const Text(
                  'Your live location keeps updating for the people below and the GoRide safety team until you mark yourself safe.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Call emergency services (112)',
            icon: const Icon(Icons.call, color: Colors.white, size: 20),
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
          ),
          const SizedBox(height: 20),
          const Text(
            'Who has been alerted',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const _AlertedRow(
            icon: Icons.support_agent,
            title: 'GoRide Safety Team',
            subtitle: 'Trip, driver and live location',
          ),
          if (contacts.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('You have no emergency contacts yet.'),
                  ),
                  TextButton(
                    onPressed: () => context.push(Routes.emergencyContacts),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          for (final c in contacts)
            _AlertedRow(
              icon: Icons.person,
              title: '${c.name} (${c.relationship})',
              subtitle: [
                if (c.email.isNotEmpty) 'Email',
                'App notification',
                'Live location link',
              ].join(' · '),
              trailing: IconButton(
                tooltip: 'Send on WhatsApp',
                icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                onPressed: () => _whatsApp(c.phone, message),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Preview: email and app alerts send for real once the backend (Supabase) is connected. WhatsApp works now.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Share my location with anyone',
            variant: AppButtonVariant.secondary,
            onPressed: () => shareTrip(context, trip),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AppButton(
            label: 'I\'m safe',
            variant: AppButtonVariant.outline,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Are you safe?'),
                  content: const Text(
                    'This ends emergency mode and tells your contacts you are safe.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Yes, I\'m safe'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                ref.read(tripControllerProvider.notifier).markSafe();
                if (context.mounted) context.pop();
              }
            },
          ),
        ),
      ),
    );
  }

  static Future<void> _whatsApp(String phone, String text) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '234${digits.substring(1)}';
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(text)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AlertedRow extends StatelessWidget {
  const _AlertedRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Row(
          children: [
            const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(subtitle, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}
