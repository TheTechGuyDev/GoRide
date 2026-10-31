import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../booking/map_picker_screen.dart';
import '../booking/place.dart';
import '../home/saved_places.dart';
import '../location/location_controller.dart';

/// Screens 67, 70-72.
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, SavedPlace? p) async {
    final result = await Navigator.of(context).push<SavedPlace>(
      MaterialPageRoute(builder: (_) => AddressFormScreen(existing: p)),
    );
    if (result == null) return;
    ref.read(savedPlacesProvider.notifier).save(result);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(p == null ? 'New address added' : 'Address updated'),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedPlace p,
  ) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete Address',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              const Divider(height: 32),
              Text(
                'Are you sure you want to delete "${p.label}"?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Yes, Delete',
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    ref.read(savedPlacesProvider.notifier).remove(p.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${p.label}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => ref.read(savedPlacesProvider.notifier).save(p),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);
    final full = places.length >= SavedPlacesController.maxPlaces;

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        backgroundColor: AppColors.fieldFill,
      ),
      body: places.isEmpty
          ? Center(
              child: Text(
                'No saved addresses yet',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final p = places[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                        child: Row(
                          children: [
                            Icon(p.icon, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Share',
                              icon: const Icon(Icons.share_outlined, size: 20),
                              onPressed: () async {
                                final text =
                                    '${p.label}: ${p.address}${p.details.isEmpty ? '' : ' (${p.details})'}\n'
                                    'https://www.openstreetmap.org/?mlat=${p.position.latitude}&mlon=${p.position.longitude}#map=17/${p.position.latitude}/${p.position.longitude}';
                                try {
                                  await SharePlus.instance.share(
                                    ShareParams(text: text),
                                  );
                                } catch (_) {
                                  await Clipboard.setData(
                                    ClipboardData(text: text),
                                  );
                                }
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) => v == 'edit'
                                  ? _edit(context, ref, p)
                                  : _delete(context, ref, p),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 20),
                                      SizedBox(width: 10),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.error,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.address,
                              style: const TextStyle(height: 1.4),
                            ),
                            if (p.details.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                p.details,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: AppButton(
            label: full ? 'Maximum of 10 addresses' : 'Add Address',
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: full ? null : () => _edit(context, ref, null),
          ),
        ),
      ),
    );
  }
}

/// Screen 68: add or edit an address.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.existing});
  final SavedPlace? existing;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  static const _suggestions = [
    'Home',
    'Office',
    'School',
    'Gym',
    'Church',
    'Mosque',
  ];
  late final _label = TextEditingController(text: widget.existing?.label);
  late final _details = TextEditingController(text: widget.existing?.details);
  late Place? _place = widget.existing == null
      ? null
      : Place(
          id: widget.existing!.id,
          name: widget.existing!.address.split(',').first,
          address: widget.existing!.address,
          position: widget.existing!.position,
        );

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickOnMap());
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final start =
        _place?.position ?? ref.read(locationControllerProvider).position;
    final picked = await Navigator.of(context).push<Place>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          mode: MapPickerMode.destination,
          initialCenter: start,
        ),
      ),
    );
    if (picked != null) setState(() => _place = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = _place;
    final canSave = p != null && _label.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Add an Address' : 'Edit Address',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickOnMap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: p == null
                        ? Text(
                            'Choose location on the map',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p.address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Icon(Icons.map_outlined, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Name',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. Mum\'s House'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _label.text = s),
                  backgroundColor: AppColors.surface,
                  shape: StadiumBorder(
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Address Details',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _details,
            decoration: const InputDecoration(
              hintText: 'e.g. Flat 3, blue gate, opposite the pharmacy',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Save Address',
                  onPressed: !canSave
                      ? null
                      : () => Navigator.pop(
                          context,
                          SavedPlace(
                            id:
                                widget.existing?.id ??
                                'place-${DateTime.now().millisecondsSinceEpoch}',
                            label: _label.text.trim(),
                            address: p.address.isEmpty
                                ? p.name
                                : '${p.name}, ${p.address}',
                            position: p.position,
                            details: _details.text.trim(),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
