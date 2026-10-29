import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../trip_models.dart';

/// Initials avatar (no stock photos of real people).
class DriverAvatar extends StatelessWidget {
  const DriverAvatar({super.key, required this.driver, this.radius = 24});

  final Driver driver;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDCE7FF),
      child: Text(
        driver.initials,
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3F51B5),
        ),
      ),
    );
  }
}

/// Driver row with chat + call buttons (screens 27, 33).
class DriverRow extends StatelessWidget {
  const DriverRow({
    super.key,
    required this.driver,
    required this.onTap,
    required this.onChat,
    required this.onCall,
    this.unread = 0,
  });

  final Driver driver;
  final VoidCallback onTap;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            DriverAvatar(driver: driver),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(
                        driver.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          driver.maskedPhone,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _RoundIcon(
              icon: Icons.chat_bubble_outline,
              onTap: onChat,
              badge: unread,
            ),
            const SizedBox(width: 10),
            _RoundIcon(icon: Icons.call_outlined, onTap: onCall),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: AppColors.error,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}

/// Text to send when the rider shares their trip.
String tripShareText(TripState trip) {
  final d = trip.driver;
  final buf = StringBuffer('I\'m on a GoRide trip')
    ..write(' to ${trip.destination.name}.');
  if (d != null) {
    buf.write(' Driver: ${d.name}, ${d.carColor} ${d.carModel} (${d.plate}).');
  }
  buf.write(' Trip ID: ${trip.id}.');
  if (trip.driverPosition != null) {
    final p = trip.driverPosition!;
    buf.write(
      ' Live position: https://www.openstreetmap.org/?mlat=${p.latitude.toStringAsFixed(5)}&mlon=${p.longitude.toStringAsFixed(5)}#map=17/${p.latitude.toStringAsFixed(5)}/${p.longitude.toStringAsFixed(5)}',
    );
  }
  return buf.toString();
}

Future<void> shareTrip(BuildContext context, TripState trip) async {
  final text = tripShareText(trip);
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip details copied. Paste to share.')),
      );
    }
  }
}

/// SOS / safety tools sheet.
Future<void> showSafetySheet(BuildContext context, TripState trip) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Safety tools',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              trip.driver == null
                  ? 'Trip ${trip.id}'
                  : '${trip.driver!.name} · ${trip.driver!.plate} · Trip ${trip.id}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _SafetyTile(
              icon: Icons.sos,
              color: AppColors.error,
              title: 'Call emergency services (112)',
              subtitle: 'Nigeria\'s free emergency number',
              onTap: () => launchUrl(Uri(scheme: 'tel', path: '112')),
            ),
            _SafetyTile(
              icon: Icons.share_location,
              color: AppColors.primary,
              title: 'Share trip status',
              subtitle: 'Send driver, car and live position to someone',
              onTap: () {
                Navigator.pop(ctx);
                shareTrip(context, trip);
              },
            ),
            _SafetyTile(
              icon: Icons.report_outlined,
              color: AppColors.warning,
              title: 'Report a safety issue',
              subtitle: 'Our safety team reviews every report',
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Safety reports go to the GoRide team once the backend is live',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _SafetyTile extends StatelessWidget {
  const _SafetyTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
