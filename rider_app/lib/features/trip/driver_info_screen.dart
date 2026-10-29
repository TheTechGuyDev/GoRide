import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import 'trip_controller.dart';
import 'widgets/trip_widgets.dart';

/// Screen 29.
class DriverInfoScreen extends ConsumerWidget {
  const DriverInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(tripControllerProvider)?.driver;
    if (d == null) {
      return const Scaffold(body: Center(child: Text('No driver assigned')));
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(a, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    BoxDecoration card() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        title: const Text('Driver Information'),
        backgroundColor: AppColors.fieldFill,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: card(),
            child: Column(
              children: [
                DriverAvatar(driver: d, radius: 46),
                const SizedBox(height: 16),
                Text(
                  d.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d.maskedPhone,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calls and chats are routed through GoRide to protect both numbers',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: card(),
            child: Row(
              children: [
                stat(Icons.star_border, d.rating.toStringAsFixed(1), 'Rating'),
                stat(Icons.directions_car_outlined, '${d.trips}', 'Rides'),
                stat(Icons.schedule, '${d.years}', 'Years'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: card(),
            child: Column(
              children: [
                row(
                  'Member Since',
                  '${months[d.memberSince.month - 1]} ${d.memberSince.year}',
                ),
                row('Vehicle', d.carModel),
                row('Color', d.carColor),
                row('Plate Number', d.plate),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Call',
                  variant: AppButtonVariant.secondary,
                  icon: const Icon(
                    Icons.call,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () => context.push(Routes.call),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Chat',
                  icon: const Icon(
                    Icons.chat_bubble,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => context.push(Routes.chat),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
