import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import 'trip_controller.dart';

/// Screen 34: dropped off. Rating, tip and receipt come in Step 7.
class TripArrivedScreen extends ConsumerStatefulWidget {
  const TripArrivedScreen({super.key});

  @override
  ConsumerState<TripArrivedScreen> createState() => _TripArrivedScreenState();
}

class _TripArrivedScreenState extends ConsumerState<TripArrivedScreen> {
  int? _mood;

  static const _moods = [
    Icons.sentiment_very_dissatisfied,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);
    if (trip == null) {
      return const Scaffold(body: Center(child: Text('No trip')));
    }

    // Real route numbers (the preview runs faster than real life).
    final km = trip.tripRoute.km;
    final mins = trip.tripRoute.minutes;
    final speed = mins == 0 ? 0 : (km / (mins / 60)).round();
    final cash = trip.paymentId == 'cash';

    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You have arrived!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const Divider(height: 40),
              Text(
                trip.destination.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                trip.destination.address,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    stat(Icons.schedule, '$mins mins', 'Duration'),
                    stat(
                      Icons.place_outlined,
                      '${km.toStringAsFixed(1)} km',
                      'Distance',
                    ),
                    stat(Icons.speed, '$speed km/h', 'Avg. Speed'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cash
                      ? const Color(0xFFFFF4E5)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      cash ? Icons.payments : Icons.check_circle,
                      color: cash ? AppColors.warning : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cash
                            ? 'Please pay ${naira(trip.total)} cash to your driver'
                            : '${naira(trip.total)} paid',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'How was your mood during this trip?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < _moods.length; i++)
                          IconButton(
                            onPressed: () => setState(() => _mood = i),
                            iconSize: 40,
                            icon: Icon(
                              _moods[i],
                              color: _mood == i
                                  ? AppColors.primary
                                  : const Color(0xFFBDBDBD),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: AppButton(
              label: 'Finish',
              onPressed: () => context.go(Routes.rateDriver),
            ),
          ),
        ),
      ),
    );
  }
}
