import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import '../driving/driver_controller.dart';
import '../registration/registration_controller.dart';

/// What kind of requests the driver wants.
class TripPreferencesScreen extends ConsumerWidget {
  const TripPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(driverProvider.select((d) => d.prefs));
    final ctrl = ref.read(driverProvider.notifier);
    final eligible =
        ref.watch(registrationProvider).vehicle?.eligibleTypes ??
        [rideTypes.firstWhere((r) => r.id == 'car')];
    final selected = prefs.rideTypes.isEmpty
        ? eligible.map((e) => e.id).toSet()
        : prefs.rideTypes;

    return SettingsPage(
      title: 'Trip preferences',
      children: [
        _Label('Services'),
        SettingsGroup(
          children: [
            for (final r in eligible)
              SettingsSwitchTile(
                title: r.name,
                subtitle: r.description,
                value: selected.contains(r.id),
                locked: eligible.length == 1,
                onChanged: (v) {
                  final next = {...selected};
                  v ? next.add(r.id) : next.remove(r.id);
                  if (next.isEmpty) return;
                  ctrl.updatePrefs(prefs.copyWith(rideTypes: next));
                },
              ),
          ],
        ),
        _Label('Payments'),
        SettingsGroup(
          children: [
            SettingsSwitchTile(
              title: 'Accept cash trips',
              subtitle: prefs.acceptCash
                  ? 'You get cash, card and wallet trips'
                  : 'Only card and wallet trips (fewer requests)',
              value: prefs.acceptCash,
              onChanged: (v) => ctrl.updatePrefs(prefs.copyWith(acceptCash: v)),
            ),
          ],
        ),
        _Label('Maximum pickup distance'),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Text('Up to'),
                  const Spacer(),
                  Text(
                    '${prefs.maxPickupKm.round()} km',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Slider(
              value: prefs.maxPickupKm,
              min: 2,
              max: 10,
              divisions: 8,
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  ctrl.updatePrefs(prefs.copyWith(maxPickupKm: v)),
            ),
          ],
        ),
        _Label('Heading somewhere?'),
        SettingsGroup(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const Icon(
                Icons.home_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                prefs.destination?.name ?? 'Set a destination',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Only get trips going your way, e.g. on your way home.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: prefs.destination == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => ctrl.updatePrefs(
                        prefs.copyWith(clearDestination: true),
                      ),
                    ),
              onTap: () async {
                final picked = await showModalBottomSheet<Place>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (ctx) => DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.7,
                    builder: (ctx, scroll) => ListView(
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Text(
                            'Where are you heading?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final p in lagosPlaces)
                          ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(p.name),
                            subtitle: Text(p.address),
                            onTap: () => Navigator.pop(ctx, p),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null) {
                  ctrl.updatePrefs(prefs.copyWith(destination: picked));
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: TextStyle(color: AppColors.textSecondary)),
    );
  }
}
