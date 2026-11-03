import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'backend.dart';
import 'push_js_stub.dart' if (dart.library.js_interop) 'push_js_web.dart';

/// Push notifications (trip updates, payments) on phones and browsers.
/// Signing keys are on the server; the app only needs the public key.
class PushService {
  PushService._();

  /// 'default' (not asked yet), 'granted', 'denied' or 'unsupported'.
  static String get permission => pushPermission();

  /// Subscribes this device. With [ask] false it only refreshes an existing
  /// permission (no popup). Returns true when push is on.
  static Future<bool> enable({required String app, bool ask = true}) async {
    final key = Backend.config['vapid_public_key'];
    final uid = Backend.user?.id;
    if (key == null || uid == null) return false;
    try {
      final raw = await pushSubscribe(key, ask);
      if (raw.isEmpty) return false;
      final sub = jsonDecode(raw) as Map<String, dynamic>;
      final keys = Map<String, dynamic>.from(sub['keys'] as Map);
      await Backend.db.from('push_subscriptions').upsert({
        'endpoint': sub['endpoint'],
        'user_id': uid,
        'p256dh': keys['p256dh'],
        'auth': keys['auth'],
        'app': app,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// "Turn on notifications" card, shown until the user decides.
class PushPromptCard extends StatefulWidget {
  const PushPromptCard({super.key, required this.app, required this.message});

  final String app;
  final String message;

  @override
  State<PushPromptCard> createState() => _PushPromptCardState();
}

class _PushPromptCardState extends State<PushPromptCard> {
  late String _perm = PushService.permission;
  bool _busy = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    // Already allowed: keep this device subscribed silently.
    if (_perm == 'granted') PushService.enable(app: widget.app, ask: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || _perm != 'default') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12)],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await PushService.enable(app: widget.app);
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _perm = PushService.permission;
                      });
                    }
                  },
            child: const Text('Turn on'),
          ),
          IconButton(
            tooltip: 'Not now',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _hidden = true),
          ),
        ],
      ),
    );
  }
}
