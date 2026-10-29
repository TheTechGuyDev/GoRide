import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/map_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_controller.dart';
import '../home/widgets/map_markers.dart';
import '../location/location_controller.dart';
import 'booking_controller.dart';
import 'place.dart';

enum MapPickerMode { pickup, destination }

/// Drag the map under a fixed pin to choose a point.
/// The address under the pin is looked up with free Nominatim reverse geocoding.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({
    super.key,
    required this.mode,
    required this.initialCenter,
    this.onConfirm,
  });

  final MapPickerMode mode;
  final LatLng initialCenter;

  /// If null, the screen pops with the chosen [Place].
  final ValueChanged<Place>? onConfirm;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  final _map = MapController();
  Timer? _debounce;
  late LatLng _center = widget.initialCenter;
  Place? _place;
  bool _looking = true;
  bool _dragging = false;
  int _lookupId = 0;

  bool get _isPickup => widget.mode == MapPickerMode.pickup;

  void _onMove(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!hasGesture) return;
    if (!_dragging) setState(() => _dragging = true);
    _debounce?.cancel();
    // Wait until the rider stops moving the map (Nominatim: 1 req/sec).
    _debounce = Timer(const Duration(milliseconds: 900), () {
      setState(() => _dragging = false);
      _lookup();
    });
  }

  Future<void> _lookup() async {
    final id = ++_lookupId;
    final point = _center;
    setState(() => _looking = true);

    Place? found;
    try {
      found = await ref.read(geocodingServiceProvider).reverse(point);
    } catch (_) {}
    if (!mounted || id != _lookupId) return;

    setState(() {
      _looking = false;
      _place =
          found ??
          Place(
            id: 'pin-${point.latitude},${point.longitude}',
            name: 'Pinned location',
            address:
                '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
            position: point,
          );
    });
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(
      text: ref.read(bookingControllerProvider).pickupNote,
    );
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup note for driver',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Help your driver find you: a landmark, gate or building colour.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(
                hintText: 'e.g. Opposite GTBank, blue gate',
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Save note',
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
      ),
    );
    if (note != null) {
      ref.read(bookingControllerProvider.notifier).setPickupNote(note);
    }
  }

  void _confirm() {
    final p = _place;
    if (p == null) return;
    if (widget.onConfirm != null) {
      widget.onConfirm!(p);
    } else {
      Navigator.of(context).pop(p);
    }
  }

  void _recenter() {
    final me = ref.read(locationControllerProvider).position;
    _map.move(me, MapConfig.defaultZoom + 1);
    _center = me;
    _lookup();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(authControllerProvider).profile.photo;
    final note = ref.watch(bookingControllerProvider).pickupNote;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: MapConfig.defaultZoom + 1,
                    onMapReady: _lookup,
                    onPositionChanged: _onMove,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapConfig.tileUrl,
                      userAgentPackageName: MapConfig.userAgent,
                    ),
                    const SimpleAttributionWidget(
                      source: Text(MapConfig.attribution),
                      alignment: Alignment.bottomLeft,
                    ),
                  ],
                ),

                // Fixed centre pin: its tip sits on the map centre.
                IgnorePointer(
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 150),
                    offset: Offset(0, _dragging ? -0.62 : -0.5),
                    child: _isPickup
                        ? UserPinMarker(photo: photo)
                        : const Icon(
                            Icons.location_on,
                            size: 56,
                            color: AppColors.error,
                          ),
                  ),
                ),
                // Little shadow dot marking the exact point.
                IgnorePointer(
                  child: Container(
                    width: 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                Positioned(
                  left: 16,
                  bottom: 24,
                  child: _CircleButton(
                    icon: Icons.chevron_left,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: _CircleButton(
                    icon: Icons.my_location,
                    onTap: _recenter,
                  ),
                ),
              ],
            ),
          ),

          // Bottom panel
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPickup ? 'Set pickup location' : 'Choose destination',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.location_on_outlined),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _looking || _dragging
                              ? const Text(
                                  'Finding address...',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _place?.name ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _place?.address ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        if (_isPickup)
                          IconButton(
                            tooltip: 'Add pickup note',
                            onPressed: _editNote,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                      ],
                    ),
                    if (_isPickup && note.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: _isPickup ? 'Next' : 'Confirm destination',
                      onPressed: (_looking || _dragging || _place == null)
                          ? null
                          : _confirm,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
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
        child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 24)),
      ),
    );
  }
}
