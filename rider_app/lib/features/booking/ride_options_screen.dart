import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/map_config.dart';
import '../../core/router/routes.dart';
import '../../core/services/routing_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_controller.dart';
import '../home/widgets/map_markers.dart';
import '../location/location_controller.dart';
import 'booking_controller.dart';
import 'payment_methods.dart';
import 'ride_types.dart';

/// Screens 20-25: route preview, ride types with fares, payment and promo.
class RideOptionsScreen extends ConsumerStatefulWidget {
  const RideOptionsScreen({super.key});

  @override
  ConsumerState<RideOptionsScreen> createState() => _RideOptionsScreenState();
}

class _RideOptionsScreenState extends ConsumerState<RideOptionsScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _expanded = false;
  RouteInfo? _fittedFor;

  void _fit(RouteInfo route) {
    if (!_mapReady || identical(_fittedFor, route)) return;
    _fittedFor = route;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: route.points,
        padding: const EdgeInsets.fromLTRB(48, 150, 48, 48),
        maxZoom: 17,
      ),
    );
  }

  void _book(RouteInfo route) {
    final booking = ref.read(bookingControllerProvider);
    final fare = booking.rideType.fareFor(route).total;
    final discount = booking.promo?.discountFor(booking.rideTypeId, fare) ?? 0;
    final payable = fare - discount;

    if (booking.paymentId == 'wallet' &&
        ref.read(walletBalanceProvider) < payable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your wallet balance is too low for ${naira(payable)}. '
            'Choose another payment method or top up.',
          ),
          action: SnackBarAction(
            label: 'Change',
            onPressed: () => context.push(Routes.paymentMethod),
          ),
        ),
      );
      return;
    }
    context.push(Routes.findingDriver);
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingControllerProvider);
    final routeAsync = ref.watch(bookingRouteProvider);
    final photo = ref.watch(authControllerProvider).profile.photo;
    final pickupPoint =
        booking.pickup?.position ??
        ref.read(locationControllerProvider).position;
    final route = routeAsync.value;

    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(route));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final mapHeight = _expanded ? 170.0 : box.maxHeight * 0.40;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                height: mapHeight,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: pickupPoint,
                        initialZoom: 14,
                        onMapReady: () {
                          _mapReady = true;
                          if (route != null) _fit(route);
                        },
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: MapConfig.tileUrl,
                          userAgentPackageName: MapConfig.userAgent,
                        ),
                        if (route != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: route.points,
                                strokeWidth: 5,
                                color: AppColors.primary,
                                borderStrokeWidth: 1.5,
                                borderColor: AppColors.primaryDark,
                                pattern: route.isEstimate
                                    ? StrokePattern.dashed(
                                        segments: const [10, 8],
                                      )
                                    : const StrokePattern.solid(),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pickupPoint,
                              width: UserPinMarker.width * 0.75,
                              height: UserPinMarker.height * 0.75,
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                child: UserPinMarker(photo: photo),
                              ),
                            ),
                            if (booking.destination != null)
                              Marker(
                                point: booking.destination!.position,
                                width: 44,
                                height: 44,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on,
                                  size: 44,
                                  color: AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 12,
                      left: 16,
                      right: 16,
                      child: _TripCard(
                        pickup: booking.pickup?.name ?? 'Your current location',
                        destination: booking.destination?.name ?? '',
                        onTap: () => context.pop(),
                      ),
                    ),
                    if (!_expanded)
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: _CircleButton(
                          icon: Icons.chevron_left,
                          onTap: () => context.pop(),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: routeAsync.when(
                  loading: () => const _Calculating(),
                  error: (_, _) => const _Calculating(),
                  data: (r) => r == null
                      ? const _Calculating()
                      : _OptionsPanel(
                          route: r,
                          expanded: _expanded,
                          onToggleExpand: () =>
                              setState(() => _expanded = !_expanded),
                          onBook: () => _book(r),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionsPanel extends ConsumerWidget {
  const _OptionsPanel({
    required this.route,
    required this.expanded,
    required this.onToggleExpand,
    required this.onBook,
  });

  final RouteInfo route;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingControllerProvider);
    final methods = ref.watch(paymentMethodsProvider);
    final balance = ref.watch(walletBalanceProvider);
    final payment = methods.firstWhere(
      (m) => m.id == booking.paymentId,
      orElse: () => methods.first,
    );
    final promo = booking.promo;
    final selectedFare = booking.rideType.fareFor(route).total;
    final selectedDiscount =
        promo?.discountFor(booking.rideTypeId, selectedFare) ?? 0;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Drag handle: tap to expand / collapse the list.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleExpand,
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if ((v < 0 && !expanded) || (v > 0 && expanded)) {
                onToggleExpand();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${route.km.toStringAsFixed(1)} km · about ${route.minutes} min',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (route.isEstimate) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '(estimated)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(
                        expanded ? Icons.expand_more : Icons.expand_less,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              itemCount: rideTypes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final type = rideTypes[i];
                final fare = type.fareFor(route).total;
                final discount = promo?.discountFor(type.id, fare) ?? 0;
                return _RideTypeCard(
                  type: type,
                  fare: fare,
                  discount: discount,
                  selected: type.id == booking.rideTypeId,
                  onTap: () => ref
                      .read(bookingControllerProvider.notifier)
                      .selectRideType(type.id),
                  onInfo: () =>
                      _showFareBreakdown(context, type, route, discount),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _RowLink(
            label: 'Payment',
            onTap: () => context.push(Routes.paymentMethod),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(payment.icon, size: 18, color: payment.color),
                const SizedBox(width: 6),
                Text(
                  payment.kind == PaymentKind.wallet
                      ? '${payment.title} (${naira(balance)})'
                      : payment.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          _RowLink(
            label: 'Promos / Vouchers',
            onTap: () => context.push(Routes.applyPromo),
            trailing: promo == null
                ? const Text(
                    'Add code',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      promo.code,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scheduled rides come in a later step'),
                      ),
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label:
                          'Book ${booking.rideType.name} · ${naira(selectedFare - selectedDiscount)}',
                      onPressed: onBook,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideTypeCard extends StatelessWidget {
  const _RideTypeCard({
    required this.type,
    required this.fare,
    required this.discount,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  final RideType type;
  final int fare;
  final int discount;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(type.icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${type.etaMinutes.$1}-${type.etaMinutes.$2} mins',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${type.passengers}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (discount > 0) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        naira(fare - discount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (discount > 0)
                    Text(
                      naira(fare),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'How is this fare calculated?',
                onPressed: onInfo,
                icon: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Transparent fare: shows exactly how the price was built.
void _showFareBreakdown(
  BuildContext context,
  RideType type,
  RouteInfo route,
  int discount,
) {
  final f = type.fareFor(route);
  showModalBottomSheet<void>(
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
            Text(
              '${type.name} fare',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              type.description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _line('Base fare', naira(f.base)),
            _line(
              'Distance (${route.km.toStringAsFixed(1)} km × ${naira(type.perKm)})',
              naira(f.distance),
            ),
            _line(
              'Time (${route.minutes} min × ${naira(type.perMinute)})',
              naira(f.time),
            ),
            if (f.minimumTopUp > 0)
              _line('Minimum fare adjustment', naira(f.minimumTopUp)),
            if (discount > 0)
              _line('Promo discount', '-${naira(discount)}', green: true),
            const Divider(height: 28),
            _line('Total', naira(f.total - discount), bold: true),
            const SizedBox(height: 12),
            const Text(
              'Rounded to the nearest ₦50. The final fare only changes if the route or stops change significantly.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _line(
  String label,
  String value, {
  bool bold = false,
  bool green = false,
}) {
  final style = TextStyle(
    fontSize: bold ? 17 : 15,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    color: green ? AppColors.primary : null,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bold
                ? style
                : style.copyWith(color: green ? null : AppColors.textSecondary),
          ),
        ),
        Text(value, style: style),
      ],
    ),
  );
}

class _RowLink extends StatelessWidget {
  const _RowLink({
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final String label;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            trailing,
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.pickup,
    required this.destination,
    required this.onTap,
  });

  final String pickup;
  final String destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget row(Color color, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              row(AppColors.primary, pickup),
              const Divider(height: 1),
              row(AppColors.error, destination),
            ],
          ),
        ),
      ),
    );
  }
}

class _Calculating extends StatelessWidget {
  const _Calculating();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Finding the best route and fares...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon)),
      ),
    );
  }
}
