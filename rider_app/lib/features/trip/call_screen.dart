import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'trip_controller.dart';
import 'widgets/trip_widgets.dart';

/// Screen 31: in-app voice call (numbers stay private).
/// Today the call is simulated. With the backend it can use free WebRTC
/// (peer-to-peer audio) signalled through Supabase Realtime.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      setState(() => _connected = true);
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() => _seconds++),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _status {
    if (!_connected) return 'Calling...';
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(tripControllerProvider)?.driver;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0CC25F), Color(0xFF0A7A44), Color(0xFF1E3A5F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
              ),
              const Spacer(),
              if (d != null) DriverAvatar(driver: d, radius: 72),
              const SizedBox(height: 28),
              Text(
                d?.name ?? 'Driver',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'GoRide private call',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallButton(
                    icon: Icons.call_end,
                    color: const Color(0xFFF75555),
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 24),
                  _CallButton(
                    icon: _speaker ? Icons.volume_up : Icons.volume_down,
                    color: Colors.white.withValues(
                      alpha: _speaker ? 0.45 : 0.2,
                    ),
                    onTap: () => setState(() => _speaker = !_speaker),
                  ),
                  const SizedBox(width: 24),
                  _CallButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    color: Colors.white.withValues(alpha: _muted ? 0.45 : 0.2),
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
