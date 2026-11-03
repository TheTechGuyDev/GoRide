import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/widgets/rider_avatar.dart';

import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';
import 'trip_controller.dart';

/// Opens turn-by-turn directions in Google Maps (free, no API key).
Future<void> openNavigation(LatLng to) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${to.latitude},${to.longitude}&travelmode=driving',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Masked call to the rider. Later: a free relay number so neither side
/// sees the other's real phone number.
Future<void> callRider() =>
    launchUrl(Uri(scheme: 'tel', path: '+2342013300000'));

class TripScreen extends ConsumerStatefulWidget {
  const TripScreen({super.key});

  @override
  ConsumerState<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends ConsumerState<TripScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _follow = true;
  TripStage? _lastStage;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(tripProvider)?.stage == TripStage.arrived) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _fit(ActiveTrip t) {
    if (!_mapReady) return;
    final pts = [t.position, ...t.leg];
    if (pts.length < 2) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(50, 120, 50, 360),
        maxZoom: 16.5,
      ),
    );
  }

  Future<void> _enterPin(ActiveTrip t) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PinSheet(),
    );
    if (ok == true && mounted) {
      setState(() => _follow = true);
    }
  }

  Future<void> _changeRoute() async {
    const reasons = [
      'Heavy traffic ahead',
      'Road is closed',
      'Police checkpoint / roadblock',
      'Flooded road',
      'Rider asked me to',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Taking another route?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Text(
                  'Your rider gets an alert when you leave the planned route. Tell them why so they don\'t worry.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              for (final r in reasons)
                ListTile(
                  leading: const Icon(
                    Icons.alt_route,
                    color: AppColors.primary,
                  ),
                  title: Text(r),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    ref.read(tripProvider.notifier).announceRouteChange(reason);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rider has been told about the new route')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final kind =
        ref.watch(registrationProvider).vehicle?.kind ?? VehicleKind.car;

    ref.listen(tripProvider, (prev, next) {
      if (next == null) return;
      if (next.stage == TripStage.completed) {
        context.pushReplacement(Routes.tripComplete);
        return;
      }
      if (next.stage != _lastStage) {
        _lastStage = next.stage;
        _follow = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fit(next));
      } else if (_follow && _mapReady && prev?.position != next.position) {
        // Keep the car in view without jumping every tick.
        final bounds = _map.camera.visibleBounds;
        if (!bounds.contains(next.position)) _fit(next);
      }
    });

    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 60,
                color: AppColors.textHint,
              ),
              const SizedBox(height: 12),
              const Text('No active trip'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    }

    final r = t.request;
    final toPickup =
        t.stage == TripStage.toPickup || t.stage == TripStage.arrived;
    final target = toPickup ? r.pickup : r.destination;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: t.position,
              initialZoom: 15,
              onMapReady: () {
                _mapReady = true;
                _lastStage = t.stage;
                _fit(t);
              },
              onPositionChanged: (_, gesture) {
                if (gesture && _follow) setState(() => _follow = false);
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              goRideTiles(),
              if (t.remaining.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: t.remaining,
                      strokeWidth: 6,
                      color: toPickup
                          ? AppColors.primary
                          : const Color(0xFF2196F3),
                      borderStrokeWidth: 1.5,
                      borderColor: toPickup
                          ? AppColors.primaryDark
                          : const Color(0xFF1565C0),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  placeMarker(target.position, pickup: toPickup),
                  Marker(
                    point: t.position,
                    width: 60,
                    height: 60,
                    child: VehicleMarker(
                      heading: t.heading,
                      type: switch (kind) {
                        VehicleKind.bike => VehicleType.bike,
                        VehicleKind.keke => VehicleType.keke,
                        VehicleKind.car => VehicleType.car,
                      },
                    ),
                  ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text(MapConfig.attribution),
                alignment: Alignment.topRight,
              ),
            ],
          ),

          // Direction banner
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Material(
              color: toPickup ? AppColors.primary : const Color(0xFF1E88E5),
              borderRadius: BorderRadius.circular(18),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Icon(
                      t.stage == TripStage.arrived
                          ? Icons.hourglass_bottom
                          : t.stage == TripStage.atDestination
                          ? Icons.flag
                          : Icons.navigation,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (t.stage) {
                              TripStage.toPickup =>
                                '${formatDistance(t.remainingMetres)} to pickup',
                              TripStage.arrived => 'At pickup',
                              TripStage.atDestination => 'You have arrived',
                              _ =>
                                '${formatDistance(t.remainingMetres)} to drop-off',
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            target.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => openNavigation(target.position),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.turn_right, size: 18),
                      label: const Text('Navigate'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Back + SOS + recentre
          Positioned(
            top: top + 92,
            left: 12,
            child: RoundMapButton(
              icon: Icons.arrow_back,
              tooltip: 'Home',
              onTap: () => context.go(Routes.home),
            ),
          ),
          Positioned(
            top: top + 92,
            right: 12,
            child: Column(
              children: [
                RoundMapButton(
                  icon: Icons.shield,
                  color: AppColors.error,
                  iconColor: Colors.white,
                  tooltip: 'Safety and SOS',
                  onTap: () => context.push(Routes.emergency),
                ),
                const SizedBox(height: 10),
                RoundMapButton(
                  icon: _follow ? Icons.my_location : Icons.location_searching,
                  tooltip: 'Recentre',
                  onTap: () {
                    setState(() => _follow = true);
                    _fit(t);
                  },
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _TripPanel(
              trip: t,
              onArrived: () => ref.read(tripProvider.notifier).arrived(),
              onStart: () => _enterPin(t),
              onEnd: () => ref.read(tripProvider.notifier).endTrip(),
              onChangeRoute: _changeRoute,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripPanel extends StatelessWidget {
  const _TripPanel({
    required this.trip,
    required this.onArrived,
    required this.onStart,
    required this.onEnd,
    required this.onChangeRoute,
  });

  final ActiveTrip trip;
  final VoidCallback onArrived;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onChangeRoute;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final r = t.request;
    final waited = t.arrivedAt == null
        ? Duration.zero
        : DateTime.now().difference(t.arrivedAt!);
    final freeLeft = TripController.freeWait - waited;

    final String title = switch (t.stage) {
      TripStage.toPickup => 'Picking up ${r.riderFirstName}',
      TripStage.arrived => 'Waiting for ${r.riderFirstName}',
      TripStage.atDestination => 'Drop off ${r.riderFirstName}',
      _ => 'Dropping off ${r.riderFirstName}',
    };

    final Widget primary = switch (t.stage) {
      TripStage.toPickup => AppButton(
        label: t.progress >= 0.85
            ? 'I\'ve arrived'
            : 'Arriving in ${t.remainingMinutes} min',
        onPressed: t.progress >= 0.85 ? onArrived : null,
      ),
      TripStage.arrived => AppButton(
        label: 'Start trip',
        icon: const Icon(Icons.pin, color: Colors.white),
        onPressed: onStart,
      ),
      TripStage.atDestination => AppButton(label: 'End trip', onPressed: onEnd),
      _ => _SlideToEnd(
        enabled: t.progress >= 0.8,
        label: t.progress >= 0.8
            ? 'End trip'
            : '${t.remainingMinutes} min to drop-off',
        onDone: onEnd,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RiderAvatar(request: r, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.star,
                        ),
                        Text(' ${r.riderRating.toStringAsFixed(1)}  ·  '),
                        Icon(
                          r.payment.icon,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        Text(
                          ' ${naira(t.totalFare)} · ${r.payment.label}',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _CircleAction(icon: Icons.call, onTap: callRider),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CircleAction(
                    icon: Icons.chat_bubble_outline,
                    onTap: () => context.push(Routes.tripChat),
                  ),
                  if (t.unread > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: CountBadge(count: t.unread),
                    ),
                ],
              ),
            ],
          ),
          if (t.stage == TripStage.arrived) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: freeLeft.isNegative
                    ? AppColors.warning.withValues(alpha: 0.12)
                    : AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      freeLeft.isNegative
                          ? 'Waiting fee: ${naira(t.waitingFee)} (${naira(TripController.waitingFeePerMin)}/min)'
                          : 'Free waiting time left',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _mmss(freeLeft.isNegative ? waited : freeLeft),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (t.stage == TripStage.toPickup && r.pickupNote != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"${r.pickupNote}"',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          RouteSummary(
            pickup: r.pickup.name,
            pickupSub: r.pickup.address,
            dropoff: r.destination.name,
            dropoffSub: r.destination.address,
          ),
          if (t.stage == TripStage.onTrip) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onChangeRoute,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alt_route,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.routeChangeReason == null
                            ? 'Taking another route? Tell the rider'
                            : 'Rider told: ${t.routeChangeReason}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          primary,
          if (t.stage == TripStage.toPickup || t.stage == TripStage.arrived)
            Center(
              child: TextButton(
                onPressed: () => context.push(Routes.cancelTrip),
                child: const Text(
                  'Cancel trip',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _mmss(Duration d) {
    final s = d.inSeconds.abs();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

/// Slide to end, so the trip isn't ended by an accidental tap.
class _SlideToEnd extends StatefulWidget {
  const _SlideToEnd({
    required this.enabled,
    required this.label,
    required this.onDone,
  });

  final bool enabled;
  final String label;
  final VoidCallback onDone;

  @override
  State<_SlideToEnd> createState() => _SlideToEndState();
}

class _SlideToEndState extends State<_SlideToEnd> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const knob = 52.0;
        final max = c.maxWidth - knob - 8;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: widget.enabled
                ? const Color(0xFF1E88E5)
                : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                widget.enabled
                    ? 'Slide to ${widget.label.toLowerCase()}'
                    : widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: widget.enabled
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
              if (widget.enabled)
                Positioned(
                  left: 4 + _drag,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => setState(
                      () => _drag = (_drag + d.delta.dx).clamp(0, max),
                    ),
                    onHorizontalDragEnd: (_) {
                      if (_drag > max * 0.85) {
                        HapticFeedback.mediumImpact();
                        widget.onDone();
                      }
                      setState(() => _drag = 0);
                    },
                    child: Container(
                      width: knob,
                      height: knob,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.double_arrow,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Rider reads out their 4-digit PIN; trip starts only if it matches.
class _PinSheet extends ConsumerStatefulWidget {
  const _PinSheet();

  @override
  ConsumerState<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<_PinSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  bool _checking = false;

  Future<void> _submit() async {
    if (_checking) return;
    setState(() => _checking = true);
    final error = await ref.read(tripProvider.notifier).startTrip(_ctrl.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (error == null) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = error;
        _ctrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter rider\'s PIN',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask the rider for the 4-digit PIN in their app. This makes sure you pick up the right person.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(
                fontSize: 34,
                letterSpacing: 18,
                fontWeight: FontWeight.w700,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                errorText: _error,
              ),
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                if (v.length == 4) _submit();
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The rider sees their PIN in the GoRide app.',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Start trip',
            loading: _checking,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
