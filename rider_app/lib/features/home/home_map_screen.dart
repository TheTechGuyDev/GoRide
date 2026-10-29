import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_controller.dart';
import '../location/location_controller.dart';
import 'nearby_cars.dart';
import 'widgets/location_permission_dialog.dart';
import 'widgets/map_markers.dart';

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final _map = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _askPermissionIfNeeded(),
    );
  }

  Future<void> _askPermissionIfNeeded() async {
    final status = ref.read(locationControllerProvider).status;
    if (status != LocationStatus.notAsked || !mounted) return;
    final grant = await showLocationPermissionDialog(context);
    final controller = ref.read(locationControllerProvider.notifier);
    if (grant) {
      await controller.requestAndLocate();
    } else {
      controller.skip();
    }
  }

  void _moveTo(LatLng p) {
    if (_mapReady) _map.move(p, MapConfig.defaultZoom);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationControllerProvider);
    final vehicles = ref.watch(nearbyVehiclesProvider);
    final photo = ref.watch(authControllerProvider).profile.photo;

    ref.listen(locationControllerProvider, (prev, next) {
      if (prev?.position != next.position) _moveTo(next.position);
    });

    final searching = loc.status == LocationStatus.searching;
    final ready = loc.status == LocationStatus.ready;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: loc.position,
            initialZoom: MapConfig.defaultZoom,
            minZoom: 5,
            maxZoom: 19,
            onMapReady: () => _mapReady = true,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.tileUrl,
              userAgentPackageName: MapConfig.userAgent,
              maxZoom: 19,
            ),
            if (ready)
              MarkerLayer(
                markers: [
                  for (final v in vehicles)
                    Marker(
                      key: ValueKey(v.id),
                      point: v.position,
                      width: 44,
                      height: 44,
                      child: VehicleMarker(heading: v.heading, type: v.type),
                    ),
                  Marker(
                    point: loc.position,
                    width: UserPinMarker.width,
                    height: UserPinMarker.height,
                    alignment: Alignment.topCenter,
                    child: UserPinMarker(photo: photo),
                  ),
                ],
              ),
            if (searching)
              MarkerLayer(
                markers: [
                  Marker(
                    point: loc.position,
                    width: 260,
                    height: 260,
                    child: PulseRings(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: photo != null
                              ? MemoryImage(photo)
                              : null,
                          child: photo == null
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 32,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SimpleAttributionWidget(
              source: Text(MapConfig.attribution),
              alignment: Alignment.bottomLeft,
            ),
          ],
        ),

        // Recenter button (sits above the bottom sheet)
        Positioned(
          right: 16,
          bottom: 16,
          child: _RoundMapButton(
            icon: Icons.my_location,
            onTap: () async {
              await ref.read(locationControllerProvider.notifier).refresh();
              _moveTo(ref.read(locationControllerProvider).position);
            },
          ),
        ),

        if (ready && loc.isFallback)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Center(
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => ref
                      .read(locationControllerProvider.notifier)
                      .requestAndLocate(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Showing Lagos. Tap to use your location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}
