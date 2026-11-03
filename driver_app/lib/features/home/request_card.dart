import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/widgets/rider_avatar.dart';

import '../../core/widgets/common.dart';
import '../driving/driver_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/router/routes.dart';
import '../../core/notifications/notification_service.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';
import '../trip/trip_controller.dart';

/// Incoming ride request with a countdown ring.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.commission,
    required this.onAccept,
    required this.onDecline,
  });

  final RideRequest request;
  final int secondsLeft;
  final int totalSeconds;
  final int commission;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Container(
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.rideType.icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      r.rideType.name,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (r.surge > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${r.surge}x busy',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: secondsLeft / totalSeconds,
                        strokeWidth: 4,
                        color: secondsLeft <= 5
                            ? AppColors.error
                            : AppColors.primary,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                    Text(
                      '$secondsLeft',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                naira(r.fare),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      r.payment.icon,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r.payment.label,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            commission > 0
                ? 'You earn ${naira(r.fare - commission)} after ${naira(commission)} commission'
                : 'You keep the full fare (no commission)',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RiderAvatar(request: r, radius: 18),
              const SizedBox(width: 10),
              Text(
                r.riderFirstName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, color: AppColors.star, size: 18),
              Text(r.riderRating.toStringAsFixed(1)),
              Text(
                '  ·  ${r.riderTrips} trips',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RouteSummary(
            pickup: r.pickup.name,
            pickupSub:
                '${r.toPickup.minutes} min · ${formatDistance(r.toPickup.distanceMetres)} away',
            dropoff: r.destination.name,
            dropoffSub:
                '${r.trip.minutes} min · ${formatDistance(r.trip.distanceMetres)} trip',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Icon(Icons.close, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(label: 'Accept', onPressed: onAccept),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows an incoming request over whichever tab the driver is on.
class RequestOverlay extends ConsumerWidget {
  const RequestOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(driverProvider);
    final req = d.request;
    if (req == null) return const SizedBox.shrink();
    final plan = ref.watch(registrationProvider).plan;
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.35),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: RequestCard(
                request: req,
                secondsLeft: d.secondsLeft,
                totalSeconds: DriverController.requestSeconds,
                commission: plan?.commissionOn(req.fare) ?? 0,
                onAccept: () async {
                  final (accepted, error) = await ref
                      .read(driverProvider.notifier)
                      .accept();
                  if (accepted == null) {
                    if (error != null) {
                      ref
                          .read(notificationsProvider.notifier)
                          .notify(
                            NotifyCategory.requests,
                            'Request no longer available',
                            error,
                          );
                    }
                    return;
                  }
                  ref.read(tripProvider.notifier).start(accepted);
                  appRouter.push(Routes.trip);
                },
                onDecline: () => ref.read(driverProvider.notifier).decline(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
