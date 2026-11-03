import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../driving/driver_controller.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';
import '../trip/trip_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _follow = true;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Refresh the "online for" timer.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ref.read(driverProvider).online) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loc = ref.read(locationControllerProvider);
      if (loc.status == LocationStatus.notAsked) {
        await ref.read(locationControllerProvider.notifier).requestAndLocate();
        ref.read(driverProvider.notifier).syncLocation();
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _moveTo(LatLng p, {double? zoom}) {
    if (_mapReady) _map.move(p, zoom ?? _map.camera.zoom);
  }

  Future<void> _toggleOnline() async {
    final ctrl = ref.read(driverProvider.notifier);
    final d = ref.read(driverProvider);
    if (d.online) {
      ctrl.goOffline();
      return;
    }
    final reason = ctrl.blockingReason();
    if (reason != null) {
      _showBlocked(reason);
      return;
    }
    final problem = await ctrl.goOnline();
    if (problem != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(problem), duration: const Duration(seconds: 6)),
      );
    }
  }

  void _showBlocked(String reason) {
    final balance = ref.read(earningsProvider).balance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, color: AppColors.error, size: 44),
              const SizedBox(height: 12),
              const Text(
                'You can\'t go online yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: balance <= -DriverController.debtLimit
                    ? 'Settle now'
                    : reason.contains('subscription')
                    ? 'Renew plan'
                    : reason.contains('expired')
                    ? 'Update documents'
                    : 'OK',
                onPressed: () {
                  Navigator.pop(ctx);
                  if (balance <= -DriverController.debtLimit) {
                    context.push(Routes.settle, extra: -balance);
                  } else if (reason.contains('subscription')) {
                    context.push(Routes.plan);
                  } else if (reason.contains('expired')) {
                    context.push(Routes.documents);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(driverProvider);
    final trip = ref.watch(tripProvider);
    final earnings = ref.watch(earningsProvider);
    final reg = ref.watch(registrationProvider);
    final top = MediaQuery.paddingOf(context).top;
    final today = DateTime.now();
    final earnedToday = earnings.earnedOn(today);
    final tripsToday = earnings.tripsOn(today).length;
    final onlineFor = d.onlineSince == null
        ? Duration.zero
        : DateTime.now().difference(d.onlineSince!);
    final minutesBefore = earnings.onlineMinutesByDay[dayKey(today)] ?? 0;
    final kind = reg.vehicle?.kind ?? VehicleKind.car;

    ref.listen(driverProvider.select((s) => s.position), (prev, next) {
      if (_follow && prev != next) _moveTo(next);
    });
    ref.listen(locationControllerProvider, (prev, next) {
      if (prev?.position != next.position) {
        ref.read(driverProvider.notifier).syncLocation();
      }
    });

    final docWarnings = reg.requiredDocs
        .map(reg.doc)
        .where((x) => x.expiresSoon || x.isExpired)
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: d.position,
              initialZoom: 15,
              onMapReady: () => _mapReady = true,
              onPositionChanged: (_, gesture) {
                if (gesture && _follow) setState(() => _follow = false);
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              goRideTiles(),
              if (d.online)
                CircleLayer(
                  circles: [
                    for (final z in demandZones)
                      CircleMarker(
                        point: z.centre,
                        radius: z.radiusM,
                        useRadiusInMeter: true,
                        color:
                            (z.multiplier >= 1.3
                                    ? AppColors.error
                                    : AppColors.warning)
                                .withValues(alpha: 0.18),
                        borderColor:
                            (z.multiplier >= 1.3
                                    ? AppColors.error
                                    : AppColors.warning)
                                .withValues(alpha: 0.5),
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
              if (d.online)
                MarkerLayer(
                  markers: [
                    for (final z in demandZones)
                      Marker(
                        point: z.centre,
                        width: 60,
                        height: 26,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: z.multiplier >= 1.3
                                ? AppColors.error
                                : AppColors.warning,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            '${z.multiplier}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (d.request != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: d.request!.toPickup.points,
                      strokeWidth: 5,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              if (d.request != null)
                MarkerLayer(
                  markers: [
                    placeMarker(d.request!.pickup.position, pickup: true),
                  ],
                ),
              SmoothMarker(
                point: d.position,
                size: d.online ? 110 : 60,
                child: d.online
                    ? PulseRings(
                        size: 110,
                        child: VehicleMarker(
                          heading: d.heading,
                          type: _markerType(kind),
                        ),
                      )
                    : VehicleMarker(
                        heading: d.heading,
                        type: _markerType(kind),
                      ),
              ),
              const SimpleAttributionWidget(
                source: Text(MapConfig.attribution),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),

          // Top bar: profile, today's earnings, notifications.
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _Avatar(
                  initials: reg.personal.initials,
                  onTap: () => context.go(Routes.account),
                ),
                const Spacer(),
                Material(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.go(Routes.earnings),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      child: Text(
                        naira(earnedToday),
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const BellButton(),
              ],
            ),
          ),

          if (trip != null)
            Positioned(
              top: top + 68,
              left: 16,
              right: 16,
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push(Routes.trip),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.navigation, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Trip with ${trip.request.riderFirstName} in progress',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Text(
                          'Open',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (docWarnings.isNotEmpty && !d.online)
            Positioned(
              top: top + 68,
              left: 16,
              right: 16,
              child: Material(
                color: AppColors.surface,
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push(Routes.documents),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            docWarnings.first.isExpired
                                ? '${docWarnings.first.type.title} has expired'
                                : '${docWarnings.first.type.title} expires ${formatDate(docWarnings.first.expiry!)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: Column(
                    children: [
                      if (d.online)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RoundMapButton(
                            icon: Icons.shield_outlined,
                            iconColor: AppColors.error,
                            tooltip: 'Safety',
                            onTap: () => context.push(Routes.emergency),
                          ),
                        ),
                      RoundMapButton(
                        icon: _follow
                            ? Icons.my_location
                            : Icons.location_searching,
                        tooltip: 'Centre on me',
                        onTap: () {
                          setState(() => _follow = true);
                          _moveTo(d.position, zoom: 15);
                        },
                      ),
                    ],
                  ),
                ),
                const PushPromptCard(
                  app: 'driver',
                  message: 'Get ride requests and payment alerts',
                ),
                _BottomPanel(
                  online: d.online,
                  searching: d.searching,
                  earnedToday: earnedToday,
                  tripsToday: tripsToday,
                  onlineFor: onlineFor + Duration(minutes: minutesBefore),
                  acceptance: d.acceptanceRate,
                  quest: earnings.power.enabled
                      ? earnings.powerDay
                      : earnings.weeklyQuest,
                  onToggle: _toggleOnline,
                  onPrefs: () => context.push(Routes.tripPreferences),
                  onRequestNow: () =>
                      ref.read(driverProvider.notifier).requestNow(),
                  headingHome: d.prefs.destination?.name,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  VehicleType _markerType(VehicleKind k) => switch (k) {
    VehicleKind.bike => VehicleType.bike,
    VehicleKind.keke => VehicleType.keke,
    VehicleKind.car => VehicleType.car,
  };
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onTap});
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primary,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.online,
    required this.searching,
    required this.earnedToday,
    required this.tripsToday,
    required this.onlineFor,
    required this.acceptance,
    required this.quest,
    required this.onToggle,
    required this.onPrefs,
    required this.onRequestNow,
    this.headingHome,
  });

  final bool online;
  final bool searching;
  final int earnedToday;
  final int tripsToday;
  final Duration onlineFor;
  final double acceptance;
  final Quest quest;
  final VoidCallback onToggle;
  final VoidCallback onPrefs;
  final VoidCallback onRequestNow;
  final String? headingHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                tooltip: 'Trip preferences',
                onPressed: onPrefs,
                icon: const Icon(Icons.tune),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: online
                                ? AppColors.primary
                                : AppColors.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          online ? 'You\'re online' : 'You\'re offline',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headingHome != null && online
                          ? 'Only trips towards $headingHome'
                          : online
                          ? (searching
                                ? 'Matching you with a rider...'
                                : 'Finding trips near you')
                          : 'Go online to start getting trips',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          if (online) ...[
            const SizedBox(height: 10),
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              StatTile(value: naira(earnedToday), label: 'Today'),
              StatTile(value: '$tripsToday', label: 'Trips'),
              StatTile(value: formatDuration(onlineFor), label: 'Online'),
              StatTile(
                value: '${(acceptance * 100).round()}%',
                label: 'Acceptance',
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => context.go(Routes.earnings),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.completed
                              ? quest.doneText ??
                                    'Weekly quest done: ${naira(quest.reward)} earned'
                              : quest.todoText ??
                                    '${quest.target - quest.done} trips to a ${naira(quest.reward)} bonus',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: quest.progress,
                            minHeight: 5,
                            color: AppColors.warning,
                            backgroundColor: AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: online ? AppColors.error : AppColors.primary,
                shape: const StadiumBorder(),
              ),
              child: Text(
                online ? 'Go offline' : 'Go online',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (online)
            Consumer(
              builder: (context, ref, _) {
                final demo = ref.watch(demoDriveProvider);
                return TextButton(
                  onPressed: () =>
                      ref.read(demoDriveProvider.notifier).set(!demo),
                  child: Text(
                    demo
                        ? 'Demo drive is ON (car drives itself). Tap for real GPS'
                        : 'Testing alone? Tap for demo drive',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
