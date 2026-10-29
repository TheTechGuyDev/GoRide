import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../location/location_controller.dart';
import 'home_map_screen.dart';
import 'saved_places.dart';

/// Home tab: map on top, "Where to?" panel below.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(locationControllerProvider).status;

    return Column(
      children: [
        const Expanded(child: HomeMapScreen()),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: status == LocationStatus.searching
              ? const _SearchingPanel()
              : const _WhereToPanel(),
        ),
      ],
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SearchingPanel extends StatelessWidget {
  const _SearchingPanel();

  @override
  Widget build(BuildContext context) {
    return const _PanelShell(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          children: [
            Text(
              'Searching your location...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 20),
            _PulsingDot(),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      alignment: Alignment.center,
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(_c),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _WhereToPanel extends ConsumerWidget {
  const _WhereToPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);

    return _PanelShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Where to?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Material(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(Routes.whereTo),
                  child: const SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        SizedBox(width: 18),
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Enter location',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  for (final p in places)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _PlaceChip(
                        label: p.label,
                        onTap: () => context.push(Routes.whereTo, extra: p.id),
                      ),
                    ),
                  _PlaceChip(
                    label: 'Add',
                    icon: Icons.add,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saved addresses come with Account'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
