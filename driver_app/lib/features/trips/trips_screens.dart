import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../earnings/earnings_controller.dart';

class TripsTab extends ConsumerStatefulWidget {
  const TripsTab({super.key});

  @override
  ConsumerState<TripsTab> createState() => _TripsTabState();
}

class _TripsTabState extends ConsumerState<TripsTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(earningsProvider).trips;
    final list = switch (_filter) {
      'Completed' => all.where((t) => !t.cancelled).toList(),
      'Cancelled' => all.where((t) => t.cancelled).toList(),
      _ => all,
    };

    final children = <Widget>[];
    String? lastDay;
    for (final t in list) {
      final day = formatDateTimeShort(t.date).split(' · ').first;
      if (day != lastDay) {
        lastDay = day;
        final dayTrips = list.where(
          (x) => formatDateTimeShort(x.date).split(' · ').first == day,
        );
        final total = dayTrips.fold(0, (a, x) => a + x.net);
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Row(
              children: [
                Text(day, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  naira(total),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        );
      }
      children.add(_TripTile(trip: t));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Trips'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in ['All', 'Completed', 'Cancelled'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: _filter == f,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _filter == f
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No trips yet. Go online to get your first one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: children,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});
  final TripRecord trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    return GoCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(Routes.tripDetailsFor(t.id)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(t.rideType.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${formatTime(t.date)} · ${t.rideType.name}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (t.cancelled)
                const Text(
                  'Cancelled',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Text(
                  naira(t.net),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          RouteSummary(
            pickup: t.pickup,
            pickupSub: t.riderName,
            dropoff: t.dropoff,
            dropoffSub: t.cancelled
                ? (t.cancelReason ?? '')
                : '${t.km} km · ${t.minutes} min · ${t.payment.label}',
          ),
          if (t.ratingFromRider != null || t.tip > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (t.ratingFromRider != null) ...[
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.star,
                  ),
                  Text(
                    ' ${t.ratingFromRider}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                if (t.tip > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.volunteer_activism,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  Text(
                    ' ${naira(t.tip)} tip',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(earningsProvider).trips;
    final matches = trips.where((x) => x.id == id);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip not found')),
      );
    }
    final t = matches.first;

    Widget line(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? null : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: bold ? 17 : 15,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            formatDateTimeShort(t.date),
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            t.cancelled ? 'Cancelled trip' : naira(t.net),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          Text(
            'Trip ID ${t.id}',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 20),
          GoCard(
            child: RouteSummary(
              pickup: t.pickup,
              pickupSub: 'Pickup',
              dropoff: t.dropoff,
              dropoffSub: 'Drop-off',
            ),
          ),
          GoCard(
            child: Column(
              children: [
                line('Rider', t.riderName),
                line('Service', t.rideType.name),
                if (!t.cancelled) ...[
                  line('Distance', '${t.km} km'),
                  line('Duration', '${t.minutes} min'),
                ],
                line('Payment', t.payment.label),
                if (t.cancelled) line('Reason', t.cancelReason ?? '-'),
              ],
            ),
          ),
          if (!t.cancelled)
            GoCard(
              child: Column(
                children: [
                  line('Fare', naira(t.fare - t.waitingFee)),
                  if (t.waitingFee > 0)
                    line('Waiting fee', naira(t.waitingFee)),
                  line(
                    'Commission',
                    t.commission == 0 ? naira(0) : '-${naira(t.commission)}',
                  ),
                  if (t.tip > 0) line('Tip', naira(t.tip)),
                  const Divider(height: 20),
                  line('You earned', naira(t.net), bold: true),
                ],
              ),
            ),
          if (t.ratingFromRider != null || t.ratingGiven != null)
            GoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (t.ratingFromRider != null)
                    Row(
                      children: [
                        const Expanded(child: Text('Rider rated you')),
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= t.ratingFromRider!
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.star,
                            size: 20,
                          ),
                      ],
                    ),
                  if (t.riderComment != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"${t.riderComment}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (t.ratingGiven != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(child: Text('You rated the rider')),
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= t.ratingGiven!
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: AppColors.star,
                            size: 20,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          GoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.report_problem_outlined),
                  title: const Text('Report a problem with this trip'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.help),
                ),
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: const Text('Rider left something in my car'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Thanks. Support will connect you with the rider to return it.',
                      ),
                    ),
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
