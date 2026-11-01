import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import '../notifications/notification_service.dart';
import '../router/routes.dart';

/// OSM tiles, darkened in dark mode.
TileLayer goRideTiles() => TileLayer(
  urlTemplate: MapConfig.tileUrl,
  userAgentPackageName: 'com.goride.goride_driver',
  tileBuilder: AppColors.isDark ? darkModeTileBuilder : null,
);

class RoundMapButton extends StatelessWidget {
  const RoundMapButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: color ?? AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: iconColor ?? AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Bell with unread badge.
class BellButton extends ConsumerWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationsProvider);
    final unread = ref.read(notificationsProvider.notifier).unread;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundMapButton(
          icon: Icons.notifications_none,
          tooltip: 'Notifications',
          onTap: () => context.push(Routes.notifications),
        ),
        if (unread > 0)
          Positioned(right: -2, top: -2, child: CountBadge(count: unread)),
      ],
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Round pin used for pickup (green) and drop-off (dark).
class PlacePin extends StatelessWidget {
  const PlacePin({super.key, required this.pickup});
  final bool pickup;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: pickup ? AppColors.primary : const Color(0xFF212121),
          shape: pickup ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: pickup ? null : BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
      ),
    );
  }
}

Marker placeMarker(LatLng p, {required bool pickup}) => Marker(
  point: p,
  width: 30,
  height: 30,
  child: PlacePin(pickup: pickup),
);

/// Small label + value used in stats rows.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Green-dot / square timeline of pickup and destination.
class RouteSummary extends StatelessWidget {
  const RouteSummary({
    super.key,
    required this.pickup,
    required this.pickupSub,
    required this.dropoff,
    required this.dropoffSub,
  });

  final String pickup;
  final String pickupSub;
  final String dropoff;
  final String dropoffSub;

  @override
  Widget build(BuildContext context) {
    Widget row(String t, String s, bool isPickup) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isPickup ? AppColors.primary : AppColors.textPrimary,
              shape: isPickup ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isPickup ? null : BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                s,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      children: [
        row(pickup, pickupSub, true),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 16, color: AppColors.border),
          ),
        ),
        row(dropoff, dropoffSub, false),
      ],
    );
  }
}

/// Simple card container used across the app.
class GoCard extends StatelessWidget {
  const GoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// "1h 25m"
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}
