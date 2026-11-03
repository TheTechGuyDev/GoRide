import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../driving/driver_controller.dart';
import '../registration/registration_controller.dart';
import '../trip/trip_controller.dart';
import 'emergency_contacts.dart';

/// When the driver's SOS was sent (null = no emergency).
/// Later: an `sos_events` row; the server alerts the safety team and
/// texts emergency contacts with a live-location link.
class SosController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Alerts the GoRide safety team (admin Safety page) with the driver's
  /// position and current trip.
  void trigger() {
    state = DateTime.now();
    final pos = ref.read(driverProvider).position;
    Backend.db
        .rpc(
          'raise_sos',
          params: {
            'p_trip': ref.read(tripProvider)?.request.id,
            'p_kind': 'sos',
            'p_lat': pos.latitude,
            'p_lng': pos.longitude,
            'p_details': 'Driver pressed SOS',
          },
        )
        .then((_) {}, onError: (_) {});
    ref
        .read(notificationsProvider.notifier)
        .notify(
          NotifyCategory.safety,
          'SOS sent',
          'GoRide safety team and your emergency contacts have your live location.',
          route: Routes.emergency,
          id: NotifyIds.sos,
          urgent: true,
        );
  }

  void markSafe() => state = null;
}

final sosProvider = NotifierProvider<SosController, DateTime?>(
  SosController.new,
);

String _locationLink(double lat, double lng) =>
    'https://www.google.com/maps?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  String _message(WidgetRef ref) {
    final d = ref.read(driverProvider);
    final reg = ref.read(registrationProvider);
    final trip = ref.read(tripProvider);
    final name = reg.personal.fullName.isEmpty
        ? 'A GoRide driver'
        : reg.personal.fullName;
    final buf = StringBuffer(
      'EMERGENCY: $name needs help. Live location: ${_locationLink(d.position.latitude, d.position.longitude)}',
    );
    if (reg.vehicle != null) {
      buf.write('. Vehicle: ${reg.vehicle!.title}, ${reg.vehicle!.plate}');
    }
    if (trip != null) {
      buf.write(
        '. On a GoRide trip from ${trip.request.pickup.name} to ${trip.request.destination.name}',
      );
    }
    buf.write('. Sent from GoRide Driver.');
    return buf.toString();
  }

  Future<void> _confirmSos(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sos, color: AppColors.error, size: 48),
        title: const Text('Send SOS?'),
        content: const Text(
          'GoRide\'s safety team and your emergency contacts will get your live location and vehicle details.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.heavyImpact();
      ref.read(sosProvider.notifier).trigger();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sos = ref.watch(sosProvider);
    final contacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: sos != null
          ? AppColors.error.withValues(alpha: 0.06)
          : null,
      appBar: AppBar(
        title: Text(sos != null ? 'SOS active' : 'Safety toolkit'),
        backgroundColor: sos != null ? AppColors.error : null,
        foregroundColor: sos != null ? Colors.white : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          if (sos == null)
            Center(
              child: GestureDetector(
                onTap: () => _confirmSos(context, ref),
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, color: Colors.white, size: 56),
                      Text(
                        'Tap for SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            GoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOS sent at ${formatTime(sos)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your live location is shared with the GoRide safety team${contacts.isEmpty ? '' : ' and ${contacts.length} emergency contact${contacts.length == 1 ? '' : 's'}'} until you mark yourself safe.',
                    style: TextStyle(
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final c in contacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${c.name} (${c.relationship})'),
                          ),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri(
                                scheme: 'sms',
                                path: c.phone,
                                queryParameters: {'body': _message(ref)},
                              ),
                            ),
                            child: const Text('Text'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'I\'m safe now',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      ref.read(sosProvider.notifier).markSafe();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Glad you\'re safe. We\'ve let everyone know.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          GoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.local_police_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Call emergency services',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('112 (free, any network)'),
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.emergency_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Lagos emergency line',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('767'),
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: '767')),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.share_location,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Share my location',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Send a live map link to anyone'),
                  onTap: () async {
                    final msg = _message(ref);
                    try {
                      await SharePlus.instance.share(ShareParams(text: msg));
                    } catch (_) {
                      await Clipboard.setData(ClipboardData(text: msg));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.contacts_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Emergency contacts',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    contacts.isEmpty
                        ? 'Add up to 3 people'
                        : '${contacts.length} added',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.emergencyContacts),
                ),
              ],
            ),
          ),
          const Text(
            'Safety tips',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final tip in const [
            'Always check the rider PIN before starting a trip.',
            'Keep pickups in well-lit, busy places at night.',
            'If a rider makes you uncomfortable, end the trip somewhere safe and contact support.',
            'Never share your personal number. Calls go through GoRide.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tip, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
