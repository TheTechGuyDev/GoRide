import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../trip/trip_controller.dart';
import '../trip/trip_models.dart';

/// Plays the alarm and vibrates while a route alert or emergency is active.
class AlertSound {
  AudioPlayer? _player;
  Timer? _haptics;
  bool _playing = false;

  Future<void> start({bool loud = false}) async {
    _haptics?.cancel();
    _haptics = Timer.periodic(
      Duration(milliseconds: loud ? 900 : 1800),
      (_) => HapticFeedback.heavyImpact(),
    );
    HapticFeedback.heavyImpact();
    try {
      _player ??= AudioPlayer();
      await _player!.setVolume(loud ? 1.0 : 0.6);
      if (!_playing) {
        _playing = true;
        await _player!.setReleaseMode(ReleaseMode.loop);
        await _player!.play(AssetSource('sounds/route_alert.wav'));
      }
    } catch (_) {
      // Sound can be blocked (e.g. browser autoplay rules); vibration and the
      // on-screen alert still work.
    }
  }

  Future<void> stop() async {
    _haptics?.cancel();
    _playing = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    _haptics?.cancel();
    _player?.dispose();
  }
}

/// Full-screen alert when the driver leaves the agreed route.
class RouteAlertOverlay extends ConsumerStatefulWidget {
  const RouteAlertOverlay({super.key, required this.alert, required this.trip});

  final RouteAlert alert;
  final TripState trip;

  @override
  ConsumerState<RouteAlertOverlay> createState() => _RouteAlertOverlayState();
}

class _RouteAlertOverlayState extends ConsumerState<RouteAlertOverlay>
    with SingleTickerProviderStateMixin {
  // Only animates once escalated, to keep low-end phones smooth.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final trip = widget.trip;
    final controller = ref.read(tripControllerProvider.notifier);
    final total = TripController.alertTimeout.inMilliseconds;
    final leftMs = a.deadline.difference(DateTime.now()).inMilliseconds;
    final left = (leftMs / 1000).ceil().clamp(0, 999);
    final fraction = (leftMs / total).clamp(0.0, 1.0);
    final escalated = a.stage == RouteAlertStage.escalated;
    if (escalated && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!escalated && _pulse.isAnimating) {
      _pulse.stop();
    }

    final lastDriverMessage = trip.messages
        .where((m) => !m.fromRider)
        .lastOrNull;
    final driverReplied =
        a.askedDriver &&
        lastDriverMessage != null &&
        lastDriverMessage.time.isAfter(a.startedAt);

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) => Container(
                      width: double.infinity,
                      color: Color.lerp(
                        AppColors.error,
                        const Color(0xFFB71C1C),
                        escalated ? _pulse.value : 0,
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: child,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            escalated
                                ? 'Sending SOS in $left s'
                                : 'Your driver has left the route',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: fraction,
                                      strokeWidth: 6,
                                      backgroundColor: AppColors.border,
                                      color: escalated
                                          ? AppColors.error
                                          : AppColors.warning,
                                    ),
                                  ),
                                  Text(
                                    '$left',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'The car is going a different way from the route on your app. '
                                'If you know this way, accept it. If you don\'t answer, '
                                'SOS is sent to your emergency contacts automatically.',
                                style: const TextStyle(
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (driverReplied) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.fieldFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${trip.driver?.firstName ?? 'Driver'}: "${lastDriverMessage.text}"',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ] else if (a.askedDriver) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Waiting for your driver\'s reply...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 18),
                        AppButton(
                          label: 'I know this route, continue',
                          onPressed: controller.acceptNewRoute,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: a.askedDriver
                              ? 'Asked driver (+1 min)'
                              : 'Ask driver why',
                          variant: AppButtonVariant.secondary,
                          onPressed: a.askedDriver
                              ? null
                              : controller.askDriverAboutRoute,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Send SOS now',
                          variant: AppButtonVariant.danger,
                          onPressed: () => controller.triggerSos(
                            automatic: false,
                            reason:
                                'Rider did not recognise the driver\'s route',
                          ),
                        ),
                      ],
                    ),
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
