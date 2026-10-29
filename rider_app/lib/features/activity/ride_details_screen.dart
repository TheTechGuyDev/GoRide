import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../booking/payment_methods.dart';
import '../trip/widgets/trip_widgets.dart';
import 'ride_history.dart';

/// Screen 57 (+58): ride details and receipt.
class RideDetailsScreen extends ConsumerWidget {
  const RideDetailsScreen({super.key, required this.rideId});

  final String rideId;

  String _receiptText(RideRecord r, String payment) {
    final lines = <String>[
      'GoRide receipt',
      '${formatDate(r.createdAt)} · ${formatTime(r.createdAt)}',
      '',
      '${r.rideType.name}: ${r.pickupName} → ${r.destination.name}',
      '${r.km.toStringAsFixed(1)} km · ${r.minutes} mins',
      if (r.driver != null) 'Driver: ${r.driver!.name} (${r.driver!.plate})',
      '',
      'Trip fare: ${naira(r.fare)}',
      if (r.discount > 0) 'Discount: -${naira(r.discount)}',
      if (r.tip > 0) 'Driver tip: ${naira(r.tip)}',
      'Total paid: ${naira(r.totalPaid)} ($payment)',
      '',
      'Booking ID: ${r.bookingId}',
      'Transaction ID: ${r.transactionId}',
    ];
    return lines.join('\n');
  }

  Future<void> _share(BuildContext context, String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt copied. Paste to share.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref
        .watch(rideHistoryProvider)
        .where((e) => e.id == rideId)
        .firstOrNull;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ride not found')),
      );
    }
    final methods = ref.watch(paymentMethodsProvider);
    final payment =
        methods.where((m) => m.id == r.paymentId).firstOrNull?.title ?? '';
    final canceled = r.status == RideStatus.canceled;

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
    Widget val(String t, {bool bold = false, Color? color}) => Text(
      t,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        color: color,
      ),
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

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        backgroundColor: AppColors.fieldFill,
        title: const Text('Ride Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  v == 'lost'
                      ? 'Lost item reports go to support once the backend is live'
                      : 'Ride issue reports go to support once the backend is live',
                ),
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lost', child: Text('Report a lost item')),
              PopupMenuItem(value: 'issue', child: Text('Report a problem')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: card(),
            child: Row(
              children: [
                Icon(r.rideType.icon, color: AppColors.primary, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.rideType.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${r.km.toStringAsFixed(1)} km · ${r.minutes} mins',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  naira(canceled ? r.fare : r.totalPaid),
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
                    Expanded(child: val(r.pickupName)),
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
                        Text(
                          r.driver!.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
                  if (r.rating != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.star,
                          size: 20,
                        ),
                        Text(
                          ' ${r.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
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
                      border: Border.all(
                        color: canceled ? AppColors.error : AppColors.primary,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      canceled ? 'Canceled' : 'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: canceled ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                if (canceled && r.cancelReason != null)
                  row('Reason', Flexible(child: val(r.cancelReason!))),
                row('Payment', val(payment)),
                row('Date', val(formatDate(r.createdAt))),
                row('Time', val(formatTime(r.createdAt))),
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
                  row(
                    'Discount',
                    val('-${naira(r.discount)}', color: AppColors.primary),
                  ),
                if (r.tip > 0) row('Driver Tip', val(naira(r.tip))),
                const Divider(height: 12),
                row(
                  canceled ? 'Charged' : 'Total Paid',
                  val(naira(r.totalPaid), bold: true),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: canceled
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AppButton(
                  label: 'Share Receipt',
                  variant: AppButtonVariant.outline,
                  icon: const Icon(Icons.ios_share, size: 20),
                  onPressed: () => _share(context, _receiptText(r, payment)),
                ),
              ),
            ),
    );
  }
}
