import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/router/routes.dart';

/// Notification inbox (bell icon on the home map).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _askedNow = false;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationsProvider);
    final ctrl = ref.read(notificationsProvider.notifier);
    final showPrompt = !ctrl.systemPermissionGranted && !_askedNow;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(Routes.notificationSettings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (showPrompt)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Turn on notifications so you never miss a ride request, even when GoRide Driver is in the background.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final ok = await ctrl.requestPermission();
                      if (!context.mounted) return;
                      setState(() => _askedNow = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'Notifications turned on' : 'Notifications are blocked. You can allow them in your phone or browser settings.',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Turn on',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (list.isNotEmpty)
            Row(
              children: [
                Text(
                  '${ctrl.unread} unread',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: ctrl.markAllRead,
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          for (final n in list)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ctrl.markRead(n.id);
                if (n.route != null) context.push(n.route!);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: n.read ? AppColors.surface : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: n.urgent ? AppColors.error : AppColors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
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
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.read
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.body,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatDateTimeShort(n.time),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!n.read)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
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
