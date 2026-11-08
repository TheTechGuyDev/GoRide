import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'backend.dart';
import 'push_js_stub.dart' if (dart.library.js_interop) 'push_js_web.dart';

/// Push notifications (trip updates, payments) on phones and browsers.
/// Signing keys are on the server; the app only needs the public key.
class PushService {
  PushService._();

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool _firebaseReady = false;

  /// Android apps: Firebase is set up from google-services.json in the build.
  static Future<bool> _initFirebase() async {
    if (_firebaseReady) return true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {}
    return _firebaseReady;
  }

  /// 'default' (not asked yet), 'granted', 'denied' or 'unsupported'.
  static String get permission => _android ? _androidPerm : pushPermission();
  static String _androidPerm = 'unsupported';

  /// Works out the Android permission state (call once at start).
  static Future<String> checkPermission() async {
    if (!_android) return pushPermission();
    if (!await _initFirebase()) return _androidPerm = 'unsupported';
    final st = await FirebaseMessaging.instance.getNotificationSettings();
    return _androidPerm = switch (st.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => 'granted',
      AuthorizationStatus.denied => 'denied',
      _ => 'default',
    };
  }

  static Future<bool> _enableAndroid(String app, bool ask, String uid) async {
    if (!await _initFirebase()) return false;
    final fm = FirebaseMessaging.instance;
    if (ask) await fm.requestPermission();
    if (await checkPermission() != 'granted') return false;
    // ignore: deprecated_member_use
    final token = await fm.getToken();
    if (token == null) return false;
    Future<void> save(String t) =>
        Backend.db.from('push_subscriptions').upsert({
          'endpoint': 'fcm:$t',
          'user_id': uid,
          'p256dh': '-',
          'auth': '-',
          'app': app,
        });
    await save(token);
    // ignore: deprecated_member_use
    fm.onTokenRefresh.listen((t) => save(t).catchError((_) {}));
    return true;
  }

  /// Subscribes this device. With [ask] false it only refreshes an existing
  /// permission (no popup). Returns true when push is on.
  static Future<bool> enable({required String app, bool ask = true}) async {
    final key = Backend.config['vapid_public_key'];
    final uid = Backend.user?.id;
    if (uid == null) return false;
    if (_android) {
      try {
        return await _enableAndroid(app, ask, uid);
      } catch (_) {
        return false;
      }
    }
    if (key == null) return false;
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
    PushService.checkPermission().then((p) {
      if (mounted) setState(() => _perm = p);
      // Already allowed: keep this device subscribed silently.
      if (p == 'granted') PushService.enable(app: widget.app, ask: false);
    });
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
