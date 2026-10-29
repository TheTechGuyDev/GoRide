import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../home/saved_places.dart';
import '../location/location_controller.dart';
import 'booking_controller.dart';
import 'map_picker_screen.dart';
import 'place.dart';

class WhereToScreen extends ConsumerStatefulWidget {
  const WhereToScreen({super.key, this.savedPlaceId});

  /// When opened from a Home/Office chip, skip straight to pickup.
  final String? savedPlaceId;

  @override
  ConsumerState<WhereToScreen> createState() => _WhereToScreenState();
}

class _WhereToScreenState extends ConsumerState<WhereToScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  bool _showRecent = true;
  bool _loading = false;
  bool _searchFailed = false;
  List<Place> _results = [];
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    if (widget.savedPlaceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final saved = ref
            .read(savedPlacesProvider)
            .where((s) => s.id == widget.savedPlaceId)
            .firstOrNull;
        if (saved != null) _chooseSaved(saved, replace: true);
      });
    }
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    setState(() {});
    if (text.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
        _searchFailed = false;
      });
      return;
    }
    // Nominatim allows 1 request/second; wait for the rider to pause typing.
    _debounce = Timer(const Duration(milliseconds: 700), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_searchId;
    setState(() {
      _loading = true;
      _searchFailed = false;
    });
    try {
      final near = ref.read(locationControllerProvider).position;
      final results = await ref
          .read(geocodingServiceProvider)
          .search(text, near: near);
      if (!mounted || id != _searchId) return;
      results.sort((a, b) => _metres(a).compareTo(_metres(b)));
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _loading = false;
        _searchFailed = true;
      });
    }
  }

  double _metres(Place p) {
    final me = ref.read(locationControllerProvider).position;
    return const Distance()(me, p.position);
  }

  void _choose(Place p, {bool replace = false}) {
    ref.read(bookingControllerProvider.notifier).setDestination(p);
    if (replace) {
      context.pushReplacement(Routes.setPickup);
    } else {
      context.push(Routes.setPickup);
    }
  }

  void _chooseSaved(SavedPlace s, {bool replace = false}) {
    _choose(
      Place(
        id: 'saved-${s.id}',
        name: s.label,
        address: s.address,
        position: s.position,
      ),
      replace: replace,
    );
  }

  Future<void> _selectFromMap() async {
    final start = ref.read(locationControllerProvider).position;
    final picked = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          mode: MapPickerMode.destination,
          initialCenter: start,
        ),
      ),
    );
    if (picked != null && mounted) _choose(picked);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedPlacesProvider);
    final pickup = ref.watch(bookingControllerProvider).pickup;
    final typing = _query.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        centerTitle: false,
        titleSpacing: 0,
        title: const Text('Where do you want to go?'),
      ),
      body: Column(
        children: [
          // Pickup + destination card
          Container(
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _FieldBox(
                  icon: const Icon(
                    Icons.circle,
                    size: 12,
                    color: AppColors.primary,
                  ),
                  child: Text(
                    pickup?.name ?? 'Your current location',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _FieldBox(
                        icon: const Icon(
                          Icons.location_on,
                          size: 18,
                          color: AppColors.error,
                        ),
                        child: TextField(
                          controller: _query,
                          focusNode: _focus,
                          autofocus: widget.savedPlaceId == null,
                          onChanged: _onChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (t) {
                            _debounce?.cancel();
                            if (t.trim().length >= 2) _search(t);
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Where to?',
                            isDense: true,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Multiple stops are coming soon'),
                        ),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.add, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                if (!typing) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _Chip(
                          label: 'Select from map',
                          icon: Icons.map_outlined,
                          onTap: _selectFromMap,
                        ),
                        for (final s in saved)
                          _Chip(label: s.label, onTap: () => _chooseSaved(s)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: typing ? _buildResults() : _buildRecentSuggested()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_searchFailed) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        text: 'Couldn\'t search right now. Check your connection.',
        actionLabel: 'Try again',
        onAction: () => _search(_query.text),
      );
    }
    if (_results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        text: 'No places found. Try a nearby landmark, or pick it on the map.',
        actionLabel: 'Select from map',
        onAction: _selectFromMap,
      );
    }
    return Column(
      children: [
        if (_loading)
          const LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.primary,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: _PlaceList(
            places: _results,
            distance: _metres,
            onTap: _choose,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSuggested() {
    final recent = ref.watch(recentPlacesProvider);
    // Suggested: what's closest to the rider among recent + bookmarked.
    final suggested = [...recent]
      ..sort((a, b) => _metres(a).compareTo(_metres(b)));
    final list = _showRecent ? recent : suggested;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _Tab(
                  label: 'Recent',
                  selected: _showRecent,
                  onTap: () => setState(() => _showRecent = true),
                ),
                _Tab(
                  label: 'Suggested',
                  selected: !_showRecent,
                  onTap: () => setState(() => _showRecent = false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _PlaceList(places: list, distance: _metres, onTap: _choose),
        ),
      ],
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.icon, required this.child});
  final Widget icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(width: 20, child: Center(child: icon)),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceList extends ConsumerWidget {
  const _PlaceList({
    required this.places,
    required this.distance,
    required this.onTap,
  });

  final List<Place> places;
  final double Function(Place) distance;
  final ValueChanged<Place> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> marks = ref.watch(bookmarkedPlacesProvider);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: places.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = places[i];
        final saved = marks.contains(p.id);
        return InkWell(
          onTap: () => onTap(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.location_on_outlined, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.address,
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
                const SizedBox(width: 8),
                Text(
                  formatDistance(distance(p)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(bookmarkedPlacesProvider.notifier).toggle(p),
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    color: saved ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
