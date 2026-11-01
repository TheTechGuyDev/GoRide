import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';

class VehicleInfoScreen extends ConsumerWidget {
  const VehicleInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(registrationProvider).vehicle;
    Widget row(String l, String r) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(l, style: TextStyle(color: AppColors.textSecondary)),
          ),
          Text(r, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle')),
      body: v == null
          ? const Center(child: Text('No vehicle added'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                GoCard(
                  child: Column(
                    children: [
                      Icon(v.rideType.icon, size: 64, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        '${v.make} ${v.model}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          v.plate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GoCard(
                  child: Column(
                    children: [
                      row('Service', v.rideType.name),
                      row(
                        'Also eligible for',
                        v.eligibleTypes
                            .map((e) => e.name.replaceFirst('GoRide ', ''))
                            .join(', '),
                      ),
                      row('Year', '${v.year}'),
                      row('Colour', v.color),
                      row('Seats', '${v.seats}'),
                    ],
                  ),
                ),
                Text(
                  'Changing your vehicle sends it for review again. You can keep driving the approved vehicle until then.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Change vehicle',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(Routes.regVehicle),
                ),
              ],
            ),
    );
  }
}

class RatingsScreen extends ConsumerWidget {
  const RatingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(earningsProvider);
    final rated = e.trips
        .where((t) => t.ratingFromRider != null)
        .take(100)
        .toList();
    final counts = List.filled(6, 0);
    for (final t in rated) {
      counts[t.ratingFromRider!]++;
    }
    final maxCount = max(1, counts.reduce(max));
    final comments = e.trips
        .where((t) => t.riderComment != null)
        .take(10)
        .toList();
    final tipped = e.completed.where((t) => t.tip > 0).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Ratings and feedback')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          GoCard(
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      e.averageRating.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= e.averageRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.star,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rated.length} ratings',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      for (var s = 5; s >= 1; s--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('$s', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: counts[s] / maxCount,
                                    minHeight: 7,
                                    color: AppColors.star,
                                    backgroundColor: AppColors.border,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GoCard(
            child: Row(
              children: [
                StatTile(
                  value: '${(e.acceptanceRate * 100).round()}%',
                  label: 'Acceptance',
                ),
                StatTile(
                  value: '${(e.cancellationRate * 100).round()}%',
                  label: 'Cancellation',
                ),
                StatTile(value: '$tipped', label: 'Tips received'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Keep your rating above 4.6 and cancellations below 10% to stay in good standing. Your rating is the average of your last 100 rated trips.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            'What riders said',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No comments yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          for (final t in comments)
            GoCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= (t.ratingFromRider ?? 5)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.star,
                          size: 16,
                        ),
                      const Spacer(),
                      Text(
                        formatDateTimeShort(t.date).split(' · ').first,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('"${t.riderComment}"'),
                  const SizedBox(height: 4),
                  Text(
                    t.riderName.split(' ').first,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(notificationSettingsProvider);
    final ctrl = ref.read(notificationSettingsProvider.notifier);
    return SettingsPage(
      title: 'Notifications',
      children: [
        SettingsGroup(
          children: [
            for (final p in notificationPrefs)
              SettingsSwitchTile(
                title: p.title,
                subtitle: p.subtitle,
                value: values[p.id] ?? true,
                locked: p.locked,
                onChanged: (v) => ctrl.set(p.id, v),
              ),
          ],
        ),
        Text(
          'Ride requests also play a sound and vibrate while you are online.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
