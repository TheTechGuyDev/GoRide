import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart'
    show
        Backend,
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel,
        parseTime,
        userIdProvider;

import '../../features/account/account_settings.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';

/// Categories match the switches in Account > Notifications.
enum NotifyCategory {
  safety('safety'),
  rideStatus('ride_status'),
  messages('messages'),
  scheduled('scheduled'),
  wallet('wallet'),
  traffic('traffic'),
  promos('promos'),
  ratings('ratings'),
  updates('updates');

  const NotifyCategory(this.prefId);
  final String prefId;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.time,
    this.route,
    this.urgent = false,
    this.read = false,
  });

  final int id;
  final NotifyCategory category;
  final String title;
  final String body;
  final DateTime time;

  /// Where tapping it should go.
  final String? route;

  /// Safety alerts: loudest sound, stays until dismissed.
  final bool urgent;
  final bool read;

  AppNotification markRead() => AppNotification(
    id: id,
    category: category,
    title: title,
    body: body,
    time: time,
    route: route,
    urgent: urgent,
    read: true,
  );

  IconData get icon => switch (category) {
    NotifyCategory.safety => Icons.shield,
    NotifyCategory.rideStatus => Icons.directions_car,
    NotifyCategory.messages => Icons.chat_bubble,
    NotifyCategory.scheduled => Icons.event,
    NotifyCategory.wallet => Icons.account_balance_wallet,
    NotifyCategory.traffic => Icons.traffic,
    NotifyCategory.promos => Icons.local_offer,
    NotifyCategory.ratings => Icons.star,
    NotifyCategory.updates => Icons.campaign,
  };

  Color get color => switch (category) {
    NotifyCategory.safety => AppColors.error,
    NotifyCategory.wallet => const Color(0xFF6A1B9A),
    NotifyCategory.promos => AppColors.warning,
    NotifyCategory.scheduled => const Color(0xFF2196F3),
    _ => AppColors.primary,
  };
}

/// Fixed ids so ride updates replace each other instead of piling up.
class NotifyIds {
  static const rideStatus = 1001;
  static const routeAlert = 1002;
  static const sos = 1003;
}

/// Sends notifications to:
///  - the phone's notification bar and lock screen (Android/iOS), or the
///    browser (web preview) when allowed;
///  - an in-app banner at the top of the screen;
///  - the Notifications inbox.
///
/// With the backend, Firebase Cloud Messaging (free) delivers the same
/// notifications when the app is closed; these are the in-app/local ones.
class NotificationsController extends Notifier<List<AppNotification>> {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  int _nextId = 2000;

  RealtimeChannel? _channel;

  /// The inbox comes from Supabase (`notifications`); new rows from the
  /// server (refunds, announcements, payouts) pop up as they arrive.
  /// Trip updates are shown by the trip screen itself, so they are not
  /// repeated as banners.
  @override
  List<AppNotification> build() {
    final uid = ref.watch(userIdProvider);
    ref.onDispose(() => _channel?.unsubscribe());
    if (uid == null) return const [];
    Future.microtask(_load);
    _channel = Backend.db
        .channel('inbox-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (p) {
            final r = p.newRecord;
            if (r['category'] == 'trips') {
              _load();
              return;
            }
            notify(
              _category(r['category'] as String?),
              r['title'] as String,
              r['body'] as String,
            );
          },
        )
        .subscribe();
    return const [];
  }

  Future<void> _load() async {
    try {
      final rows = await Backend.db
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      final server = [
        for (final r in rows)
          AppNotification(
            id: (r['id'] as String).hashCode & 0x7fffffff,
            category: _category(r['category'] as String?),
            title: r['title'] as String,
            body: r['body'] as String,
            time: parseTime(r['created_at']) ?? DateTime.now(),
            read: r['read'] as bool? ?? false,
          ),
      ];
      final local = state.where((n) => n.id >= 1000 && n.id < 100000);
      state = [...local, ...server]..sort((a, b) => b.time.compareTo(a.time));
    } catch (_) {}
  }

  static NotifyCategory _category(String? c) => switch (c) {
    'trips' => NotifyCategory.rideStatus,
    'payments' || 'earnings' => NotifyCategory.wallet,
    'safety' => NotifyCategory.safety,
    'promos' => NotifyCategory.promos,
    _ => NotifyCategory.updates,
  };

  int get unread => state.where((n) => !n.read).length;

  Future<void> _init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final route = r.payload;
          if (route != null && route.isNotEmpty) appRouter.push(route);
        },
      );
    } catch (_) {
      // Unsupported platform/browser: in-app banners and inbox still work.
    }
  }

  /// Ask for permission. On the web this must follow a tap.
  Future<bool> requestPermission() async {
    await _init();
    try {
      if (kIsWeb) {
        final web = _plugin
            .resolvePlatformSpecificImplementation<
              WebFlutterLocalNotificationsPlugin
            >();
        if (web == null) return false;
        if (web.permissionStatus == WebNotificationPermission.granted) {
          return true;
        }
        await web.requestNotificationsPermission();
        return web.permissionStatus == WebNotificationPermission.granted;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  bool get systemPermissionGranted {
    if (!kIsWeb) return true;
    try {
      final web = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      return web?.permissionStatus == WebNotificationPermission.granted;
    } catch (_) {
      return false;
    }
  }

  /// Sends a notification if the rider allows this category.
  void notify(
    NotifyCategory category,
    String title,
    String body, {
    String? route,
    int? id,
    bool urgent = false,
  }) {
    final allowed =
        category == NotifyCategory.safety ||
        (ref.read(notificationSettingsProvider)[category.prefId] ?? true);
    if (!allowed) return;

    final n = AppNotification(
      id: id ?? _nextId++,
      category: category,
      title: title,
      body: body,
      time: DateTime.now(),
      route: route,
      urgent: urgent,
    );
    // Same id replaces (e.g. ride status), so the inbox stays tidy.
    state = [n, ...state.where((e) => e.id != n.id)].take(50).toList();
    ref.read(bannerProvider.notifier).show(n);
    _showSystem(n);
  }

  Future<void> _showSystem(AppNotification n) async {
    await _init();
    try {
      await _plugin.show(
        id: n.id,
        title: n.title,
        body: n.body,
        payload: n.route,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            n.urgent ? 'goride_safety' : 'goride_${n.category.prefId}',
            n.urgent ? 'Safety alerts' : _channelName(n.category),
            importance: n.urgent ? Importance.max : Importance.high,
            priority: n.urgent ? Priority.max : Priority.high,
            category: n.urgent
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.status,
            fullScreenIntent: n.urgent,
            color: AppColors.primary,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: n.urgent
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
          ),
          web: WebNotificationDetails(requireInteraction: n.urgent),
        ),
      );
    } catch (_) {
      // No permission yet or unsupported: banner + inbox already shown.
    }
  }

  String _channelName(NotifyCategory c) => switch (c) {
    NotifyCategory.rideStatus => 'Ride status',
    NotifyCategory.messages => 'Driver messages',
    NotifyCategory.scheduled => 'Scheduled rides',
    NotifyCategory.wallet => 'Wallet',
    NotifyCategory.traffic => 'Traffic alerts',
    NotifyCategory.promos => 'Promos',
    NotifyCategory.ratings => 'Ratings',
    _ => 'Updates',
  };

  void markAllRead() {
    state = [for (final n in state) n.markRead()];
    final uid = Backend.user?.id;
    if (uid != null) {
      Backend.db
          .from('notifications')
          .update({'read': true})
          .eq('user_id', uid)
          .eq('read', false)
          .then((_) {}, onError: (_) {});
    }
  }

  void markRead(int id) =>
      state = [for (final n in state) n.id == id ? n.markRead() : n];
  void clear() {
    state = [];
    final uid = Backend.user?.id;
    if (uid != null) {
      Backend.db
          .from('notifications')
          .delete()
          .eq('user_id', uid)
          .then((_) {}, onError: (_) {});
    }
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );

/// The banner currently sliding down from the top (null = none).
class BannerController extends Notifier<AppNotification?> {
  Timer? _timer;

  @override
  AppNotification? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(AppNotification n) {
    state = n;
    _timer?.cancel();
    _timer = Timer(Duration(seconds: n.urgent ? 8 : 4), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

final bannerProvider = NotifierProvider<BannerController, AppNotification?>(
  BannerController.new,
);

/// Wraps the app and slides notification banners in from the top.
class InAppNotificationHost extends ConsumerWidget {
  const InAppNotificationHost({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(bannerProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: n == null ? -160 : top + 8,
          left: 12,
          right: 12,
          child: n == null
              ? const SizedBox.shrink()
              : Dismissible(
                  key: ValueKey(n.id ^ n.time.millisecondsSinceEpoch),
                  direction: DismissDirection.up,
                  onDismissed: (_) =>
                      ref.read(bannerProvider.notifier).dismiss(),
                  child: Material(
                    elevation: 8,
                    shadowColor: Colors.black38,
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        ref.read(bannerProvider.notifier).dismiss();
                        ref.read(notificationsProvider.notifier).markRead(n.id);
                        if (n.route != null) appRouter.push(n.route!);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: n.urgent
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.error,
                                  width: 2,
                                ),
                              )
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: n.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(n.icon, color: n.color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    n.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
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
        ),
      ],
    );
  }
}
