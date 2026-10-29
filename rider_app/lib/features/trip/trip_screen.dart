import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_controller.dart';
import '../booking/payment_methods.dart';
import '../booking/ride_types.dart';
import '../home/nearby_cars.dart';
import '../home/widgets/map_markers.dart';
import 'path_utils.dart';
import 'trip_controller.dart';
import 'trip_models.dart';
import 'widgets/trip_widgets.dart';
import '../safety/route_alert_overlay.dart';

/// Screens 26-28 and 33: finding a driver, driver on the way, PIN at
/// pickup, and heading to the destination, all on one live map.
class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _showDetails = false;
  bool _userMovedMap = false;
  TripPhase? _lastPhase;
  Timer? _follow;
  final _sound = AlertSound();

  @override
  void initState() {
    super.initState();
    // Keep the driver in view, unless the rider is panning around.
    _follow = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_userMovedMap) _fitCamera();
    });
  }

  @override
  void dispose() {
    _follow?.cancel();
    _sound.dispose();
    super.dispose();
  }

  void _fitCamera() {
    final trip = ref.read(tripControllerProvider);
    if (!_mapReady || trip == null) return;

    final pts = <LatLng>[];
    switch (trip.phase) {
      case TripPhase.searching:
        _map.move(trip.pickup, 16);
        return;
      case TripPhase.driverEnRoute:
      case TripPhase.driverArrived:
        pts.add(trip.pickup);
        if (trip.driverPosition != null) pts.add(trip.driverPosition!);
      case TripPhase.onTrip:
        if (trip.driverPosition != null) pts.add(trip.driverPosition!);
        pts.add(trip.destination.position);
      case TripPhase.completed:
      case TripPhase.cancelled:
        return;
    }
    if (pts.length < 2 || const Distance()(pts.first, pts.last) < 40) {
      _map.move(pts.first, 17);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.fromLTRB(60, 180, 90, 60),
        maxZoom: 17,
      ),
    );
  }

  void _onPhaseChange(TripState trip) {
    if (_lastPhase == trip.phase) return;
    final previous = _lastPhase;
    _lastPhase = trip.phase;
    _userMovedMap = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitCamera();
      if (trip.phase == TripPhase.driverEnRoute &&
          previous == TripPhase.searching) {
        _showDriverFound(trip);
      }
      if (trip.phase == TripPhase.onTrip &&
          previous == TripPhase.driverArrived) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN verified. Enjoy your ride!')),
        );
      }
      if (trip.phase == TripPhase.completed) {
        context.go(Routes.tripArrived);
      }
    });
  }

  void _showDriverFound(TripState trip) {
    final d = trip.driver!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 36),
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We\'ve found the driver!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      DriverAvatar(driver: d, radius: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    d.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star,
                                  size: 15,
                                  color: AppColors.star,
                                ),
                                Text(' ${d.rating.toStringAsFixed(1)}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.vehicleLine,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Got It',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);
    final photo = ref.watch(authControllerProvider).profile.photo;

    if (trip == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('No active trip. Back to home'),
          ),
        ),
      );
    }
    _onPhaseChange(trip);

    // Alarm + bring the rider back to this screen when safety events happen.
    ref.listen(tripControllerProvider, (prev, next) {
      final hadAlert = prev?.routeAlert != null;
      final alert = next?.routeAlert;
      if (alert != null && !hadAlert) {
        context.go(Routes.trip);
        _sound.start();
      } else if (alert != null &&
          alert.stage == RouteAlertStage.escalated &&
          prev?.routeAlert?.stage != RouteAlertStage.escalated) {
        _sound.start(loud: true);
      } else if (alert == null && hadAlert && next?.emergency == null) {
        _sound.stop();
      }
      if (next?.emergency != null && prev?.emergency == null) {
        _sound.start(loud: true);
        Future.delayed(const Duration(seconds: 4), _sound.stop);
        context.push(Routes.emergency);
      }
    });

    final path = switch (trip.phase) {
      TripPhase.driverEnRoute when trip.approachRoute != null => remainingPath(
        trip.approachRoute!.points,
        trip.progress,
      ),
      TripPhase.onTrip when trip.drivePath != null => trip.tripRoute.points,
      TripPhase.onTrip => remainingPath(trip.tripRoute.points, trip.progress),
      _ => <LatLng>[],
    };
    final showDestination = trip.phase == TripPhase.onTrip;
    final showDriver =
        trip.driverPosition != null && trip.phase != TripPhase.searching;

    final offRoutePath = trip.drivePath == null
        ? const <LatLng>[]
        : travelledPath(trip.drivePath!, trip.progress);

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: trip.pickup,
                          initialZoom: 16,
                          onMapReady: () {
                            _mapReady = true;
                            _fitCamera();
                          },
                          onPositionChanged: (_, hasGesture) {
                            if (hasGesture) _userMovedMap = true;
                          },
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: MapConfig.tileUrl,
                            userAgentPackageName: MapConfig.userAgent,
                          ),
                          if (path.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: path,
                                  strokeWidth: 5,
                                  color: AppColors.primary,
                                  borderStrokeWidth: 1.5,
                                  borderColor: AppColors.primaryDark,
                                ),
                              ],
                            ),
                          if (offRoutePath.length >= 2)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: offRoutePath,
                                  strokeWidth: 5,
                                  color: AppColors.error,
                                  pattern: StrokePattern.dashed(
                                    segments: const [10, 6],
                                  ),
                                ),
                              ],
                            ),
                          if (trip.phase == TripPhase.searching)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: trip.pickup,
                                  width: 260,
                                  height: 260,
                                  child: PulseRings(
                                    child: CircleAvatar(
                                      radius: 34,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: AppColors.primaryLight,
                                        backgroundImage: photo != null
                                            ? MemoryImage(photo)
                                            : null,
                                        child: photo == null
                                            ? const Icon(
                                                Icons.person,
                                                color: AppColors.primary,
                                                size: 30,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            MarkerLayer(
                              markers: [
                                if (trip.phase != TripPhase.onTrip)
                                  Marker(
                                    point: trip.pickup,
                                    width: UserPinMarker.width,
                                    height: UserPinMarker.height,
                                    alignment: Alignment.topCenter,
                                    child: UserPinMarker(photo: photo),
                                  ),
                                if (showDestination)
                                  Marker(
                                    point: trip.destination.position,
                                    width: 48,
                                    height: 48,
                                    alignment: Alignment.topCenter,
                                    child: const Icon(
                                      Icons.location_on,
                                      size: 48,
                                      color: AppColors.error,
                                    ),
                                  ),
                                if (showDriver)
                                  Marker(
                                    point: trip.driverPosition!,
                                    width: 48,
                                    height: 48,
                                    child: VehicleMarker(
                                      heading: trip.driverHeading,
                                      type:
                                          trip.rideType.kind == VehicleKind.bike
                                          ? VehicleType.bike
                                          : VehicleType.car,
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
                        child: trip.emergency != null
                            ? _EmergencyBanner(
                                onTap: () => context.push(Routes.emergency),
                              )
                            : _TripCard(trip: trip),
                      ),
                      if (trip.driver != null)
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 116,
                          right: 16,
                          child: Column(
                            children: [
                              _MapButton(
                                icon: Icons.shield,
                                color: AppColors.error,
                                tooltip: 'Safety',
                                onTap: () => showSafetySheet(
                                  context,
                                  trip,
                                  onSos: () => ref
                                      .read(tripControllerProvider.notifier)
                                      .triggerSos(
                                        automatic: false,
                                        reason: 'Rider pressed SOS',
                                      ),
                                  onEmergencyContacts: () =>
                                      context.push(Routes.emergencyContacts),
                                  onTestRouteAlert:
                                      trip.phase == TripPhase.onTrip &&
                                          trip.routeAlert == null &&
                                          trip.emergency == null &&
                                          trip.drivePath == null
                                      ? ref
                                            .read(
                                              tripControllerProvider.notifier,
                                            )
                                            .simulateWrongTurn
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _MapButton(
                                icon: Icons.share_location,
                                color: AppColors.primary,
                                tooltip: 'Share trip',
                                onTap: () => shareTrip(context, trip),
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: _MapButton(
                          icon: Icons.my_location,
                          color: AppColors.textPrimary,
                          tooltip: 'Follow',
                          onTap: () {
                            _userMovedMap = false;
                            _fitCamera();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _Panel(
                  trip: trip,
                  showDetails: _showDetails,
                  onToggleDetails: () =>
                      setState(() => _showDetails = !_showDetails),
                ),
              ],
            ),
          ),
          if (trip.routeAlert != null)
            Positioned.fill(
              child: RouteAlertOverlay(alert: trip.routeAlert!, trip: trip),
            ),
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.emergency_share, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'EMERGENCY MODE: your contacts can see your live location. Tap for options.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({
    required this.trip,
    required this.showDetails,
    required this.onToggleDetails,
  });

  final TripState trip;
  final bool showDetails;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = trip.driver;
    final canCancel =
        trip.phase == TripPhase.searching ||
        trip.phase == TripPhase.driverEnRoute ||
        trip.phase == TripPhase.driverArrived;

    final (title, subtitle) = switch (trip.phase) {
      TripPhase.searching => (
        'Finding you a nearby driver...',
        'The driver will pick you up as soon as possible after they confirm your order.',
      ),
      TripPhase.driverEnRoute => (
        'Driver is heading to your location...',
        'Driver will arrive in ${trip.minutesLeft} min${trip.minutesLeft == 1 ? '' : 's'}',
      ),
      TripPhase.driverArrived => (
        'Your driver has arrived',
        'Check the plate number, then share your PIN to start the ride',
      ),
      TripPhase.onTrip when trip.drivePath != null => (
        'Off the planned route',
        'GoRide is watching this trip',
      ),
      TripPhase.onTrip => (
        'Heading to destination...',
        'Will arrive at the destination in ${trip.minutesLeft} min${trip.minutesLeft == 1 ? '' : 's'}',
      ),
      _ => ('', ''),
    };

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: d == null ? null : onToggleDetails,
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
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trip.phase == TripPhase.searching) ...[
                  const SizedBox(height: 20),
                  const _PulsingDot(),
                ],
                if (d != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    d.vehicleLine,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: trip.phase == TripPhase.driverArrived ? 17 : 15,
                    ),
                  ),
                ],
                if (trip.phase == TripPhase.driverArrived) ...[
                  const SizedBox(height: 16),
                  _PinBoxes(pin: trip.pin),
                  if (trip.pickupNote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Meet at: ${trip.pickupNote}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
                if (d != null) ...[
                  const Divider(height: 28),
                  DriverRow(
                    driver: d,
                    unread: trip.unreadMessages,
                    onTap: () => context.push(Routes.driverInfo),
                    onChat: () => context.push(Routes.chat),
                    onCall: () => context.push(Routes.call),
                  ),
                ],
                if (showDetails && d != null) _TripDetails(trip: trip),
                if (canCancel) ...[
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Cancel Ride',
                    variant: AppButtonVariant.danger,
                    onPressed: () => context.push(Routes.cancelRide),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripDetails extends ConsumerWidget {
  const _TripDetails({required this.trip});
  final TripState trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final payment =
        methods.where((m) => m.id == trip.paymentId).firstOrNull?.title ?? '';

    Widget row(String a, String b, {bool bold = false, bool green = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Text(a, style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                b,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: green ? AppColors.primary : null,
                ),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          row('Ride', trip.rideType.name),
          row('Payment', payment),
          const Divider(height: 18),
          row('Trip Fare', naira(trip.fare)),
          if (trip.discount > 0)
            row('Discount', '-${naira(trip.discount)}', green: true),
          row('Total', naira(trip.total), bold: true),
        ],
      ),
    );
  }
}

class _PinBoxes extends StatelessWidget {
  const _PinBoxes({required this.pin});
  final String pin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Your ride PIN',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in pin.split(''))
              Container(
                width: 48,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Text(
                  c,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final TripState trip;

  @override
  Widget build(BuildContext context) {
    Widget row(Color c, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            row(AppColors.primary, trip.pickupName),
            const Divider(height: 1),
            row(AppColors.error, trip.destination.name),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(_c),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
