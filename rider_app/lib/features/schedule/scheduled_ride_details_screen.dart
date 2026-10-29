import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../booking/payment_methods.dart';
import '../trip/trip_controller.dart';
import '../trip/widgets/trip_widgets.dart';
import 'scheduled_rides.dart';

/// Screens 53/55: a scheduled ride, before and after a driver accepts.
class ScheduledRideDetailsScreen extends ConsumerWidget {
  const ScheduledRideDetailsScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref
        .watch(scheduledRidesProvider)
        .where((e) => e.id == rideId)
        .firstOrNull;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This ride is no longer scheduled')),
      );
    }

    final methods = ref.watch(paymentMethodsProvider);
    final payment =
        methods.where((m) => m.id == r.paymentId).firstOrNull?.title ?? '';
    final freeCancel =
        r.pickupAt.difference(DateTime.now()) >
        ScheduledRidesController.freeCancelBefore;
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    BoxDecoration card() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    );
    Widget row(String a, Widget b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(a, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          b,
        ],
      ),
    );
    Widget val(String t, {bool bold = false}) => Text(
      t,
      style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
    );
    Widget copyable(String t) => InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: t));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$t copied')));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          val(t),
          const SizedBox(width: 6),
          const Icon(Icons.copy, size: 15, color: AppColors.textSecondary),
        ],
      ),
    );

    Future<void> cancel() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel scheduled ride?'),
          content: Text(
            freeCancel
                ? 'You won\'t be charged. Free cancellation applies up to 1 hour before pickup.'
                : 'Pickup is less than 1 hour away. In the live app a small cancellation fee may apply.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep ride'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Cancel ride',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
      ref
          .read(scheduledRidesProvider.notifier)
          .cancel(r.id, 'Canceled by rider');
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled ride canceled')),
        );
      }
    }

    void startNow() {
      final notifier = ref.read(scheduledRidesProvider.notifier);
      notifier.loadIntoBooking(r);
      notifier.remove(r.id);
      ref.read(tripControllerProvider.notifier).start(r.route);
      context.go(Routes.trip);
    }

    final shareText =
        'GoRide scheduled ride\n'
        '${days[r.pickupAt.weekday - 1]}, ${formatDate(r.pickupAt)} at ${formatTime(r.pickupAt)}\n'
        '${r.pickup.name} → ${r.destination.name}\n'
        '${r.rideType.name} · ${naira(r.total)}\n'
        'Booking ID: ${r.bookingId}';

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        backgroundColor: AppColors.fieldFill,
        title: const Text('Ride Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: card(),
            child: Column(
              children: [
                const Text(
                  'Your Scheduled Ride',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${days[r.pickupAt.weekday - 1]}, ${formatDate(r.pickupAt)} · ${formatTime(r.pickupAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (r.driver == null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'We\'ll notify you when a driver accepts',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: card(),
            child: Row(
              children: [
                Icon(r.rideType.icon, color: AppColors.primary, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    r.rideType.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  naira(r.total),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: card(),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: val(r.pickup.name)),
                  ],
                ),
                const Divider(height: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: val(r.destination.name)),
                  ],
                ),
                if (r.pickupNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.pickupNote,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (r.driver != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: card(),
              child: Row(
                children: [
                  DriverAvatar(driver: r.driver!, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r.driver!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: AppColors.star,
                            ),
                            Text(
                              ' ${r.driver!.rating.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.driver!.vehicleLine,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified, color: AppColors.primary),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: card(),
            child: Column(
              children: [
                row(
                  'Status',
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2196F3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.driver == null ? 'Scheduled' : 'Driver assigned',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ),
                row('Payment', val(payment)),
                row(
                  'Booked on',
                  val('${formatDate(r.bookedAt)} · ${formatTime(r.bookedAt)}'),
                ),
                row('Transaction ID', copyable(r.transactionId)),
                row('Booking ID', copyable(r.bookingId)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: card(),
            child: Column(
              children: [
                row('Trip Fare', val(naira(r.fare))),
                if (r.discount > 0)
                  row('Discount', val('-${naira(r.discount)}')),
                const Divider(height: 12),
                row('To pay after ride', val(naira(r.total), bold: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            freeCancel
                ? 'Free cancellation until ${formatTime(r.pickupAt.subtract(ScheduledRidesController.freeCancelBefore))} on ${formatDate(r.pickupAt)}.'
                : 'Pickup is less than 1 hour away.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Share Ride',
            variant: AppButtonVariant.outline,
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: () async {
              try {
                await SharePlus.instance.share(ShareParams(text: shareText));
              } catch (_) {
                await Clipboard.setData(ClipboardData(text: shareText));
              }
            },
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Cancel Ride',
            variant: AppButtonVariant.danger,
            onPressed: cancel,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: startNow,
            child: const Text(
              'Preview only: start this ride now',
              style: TextStyle(color: Color(0xFF6A1B9A)),
            ),
          ),
        ],
      ),
    );
  }
}
