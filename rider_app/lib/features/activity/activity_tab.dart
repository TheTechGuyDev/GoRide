import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../booking/payment_methods.dart';
import '../trip/trip_controller.dart';
import '../trip/trip_models.dart';
import 'ride_history.dart';

enum _Filter { ongoing, completed, canceled }

/// Screens 51, 56, 59: ride history.
class ActivityTab extends ConsumerStatefulWidget {
  const ActivityTab({super.key});

  @override
  ConsumerState<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<ActivityTab> {
  _Filter? _filter;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);
    final ongoing =
        trip != null &&
            trip.phase != TripPhase.completed &&
            trip.phase != TripPhase.cancelled
        ? trip
        : null;
    final filter =
        _filter ?? (ongoing != null ? _Filter.ongoing : _Filter.completed);
    final history = ref.watch(rideHistoryProvider);
    final list = history
        .where(
          (r) => filter == _Filter.completed
              ? r.status == RideStatus.completed
              : r.status == RideStatus.canceled,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Image.asset('assets/images/logo_green.png', width: 30),
        ),
        leadingWidth: 56,
        title: const Text('Activity'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.ongoing => 'Ongoing',
                        _Filter.completed => 'Completed',
                        _Filter.canceled => 'Canceled',
                      }),
                      selected: filter == f,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: filter == f
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: filter == f
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filter == _Filter.ongoing
                ? _OngoingView(trip: ongoing)
                : list.isEmpty
                ? _Empty(
                    text: filter == _Filter.completed
                        ? 'No completed rides yet'
                        : 'No canceled rides',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _RideTile(record: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RideTile extends ConsumerWidget {
  const _RideTile({required this.record});
  final RideRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final payment =
        methods.where((m) => m.id == record.paymentId).firstOrNull?.title ?? '';
    final canceled = record.status == RideStatus.canceled;

    return InkWell(
      onTap: () => context.push(Routes.rideDetailsFor(record.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                record.rideType.icon,
                size: 22,
                color: canceled ? AppColors.textSecondary : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDateTimeShort(record.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  naira(canceled ? record.fare : record.totalPaid),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canceled ? 'Canceled · Not charged' : payment,
                  style: TextStyle(
                    fontSize: 12,
                    color: canceled ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OngoingView extends StatelessWidget {
  const _OngoingView({required this.trip});
  final TripState? trip;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    if (t == null) return const _Empty(text: 'No ongoing ride');

    final status = switch (t.phase) {
      TripPhase.searching => 'Finding a driver',
      TripPhase.driverEnRoute => 'Driver on the way',
      TripPhase.driverArrived => 'Driver has arrived',
      TripPhase.onTrip => 'On trip',
      _ => '',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(t.rideType.icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.destination.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              naira(t.total),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _Stop(color: AppColors.primary, text: t.pickupName),
              const Divider(height: 18),
              _Stop(color: AppColors.error, text: t.destination.name),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go(Routes.trip),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            foregroundColor: AppColors.primary,
          ),
          child: const Text(
            'Track Route',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
