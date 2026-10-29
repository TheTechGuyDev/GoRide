import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/app_button.dart';
import '../booking/booking_controller.dart';
import 'scheduled_rides.dart';

/// Screens 41-42: "Scheduling your ride..." then "Ride scheduled!".
class SchedulingScreen extends ConsumerStatefulWidget {
  const SchedulingScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends ConsumerState<SchedulingScreen> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref
        .watch(scheduledRidesProvider)
        .where((r) => r.id == widget.rideId)
        .firstOrNull;
    final when = ride?.pickupAt;
    final day = when == null
        ? ''
        : '${const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][when.weekday - 1]}, '
              '${formatDate(when).split(',').first} · ${formatTime(when)}';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [
                  ...previous,
                  ?current,
                ].map((w) => SizedBox.expand(child: w)).toList(),
              ),
              child: !_done
                  ? const Column(
                      key: ValueKey('busy'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 4,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Scheduling your ride...',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('done'),
                      children: [
                        const Spacer(),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.event_available,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Ride scheduled!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Divider(height: 40),
                        Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your fare is locked in. We\'ll notify you when a driver accepts, '
                          'and again when they\'re on the way. You can see scheduled rides in Activity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const Spacer(),
                        AppButton(
                          label: 'Got It',
                          onPressed: () {
                            ref
                                .read(bookingControllerProvider.notifier)
                                .reset();
                            context.go(Routes.home);
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
