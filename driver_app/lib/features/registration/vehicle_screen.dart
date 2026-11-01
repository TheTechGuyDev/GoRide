import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import 'registration_controller.dart';

/// Oldest vehicle year GoRide accepts for each service.
int minimumYear(String rideTypeId) => switch (rideTypeId) {
  'bike' => 2015,
  'keke' => 2014,
  'comfort' => 2014,
  'xl' => 2010,
  _ => 2008,
};

String requirementsFor(String rideTypeId) => switch (rideTypeId) {
  'bike' => '${minimumYear('bike')} or newer · spare helmet for riders',
  'keke' => '${minimumYear('keke')} or newer · good canopy and seats',
  'comfort' => '${minimumYear('comfort')} or newer · 4 doors · working AC',
  'xl' => '${minimumYear('xl')} or newer · 6 or more seats · working AC',
  _ => '${minimumYear('car')} or newer · 4 doors · working AC',
};

List<String> makesFor(VehicleKind kind) => switch (kind) {
  VehicleKind.bike => ['Bajaj', 'TVS', 'Honda', 'Qlink', 'Suzuki', 'Haojue'],
  VehicleKind.keke => ['Bajaj', 'TVS', 'Piaggio', 'Mahindra'],
  VehicleKind.car => [
    'Toyota',
    'Honda',
    'Hyundai',
    'Kia',
    'Lexus',
    'Nissan',
    'Mercedes-Benz',
    'Ford',
    'Peugeot',
    'Innoson',
    'Volkswagen',
  ],
};

const vehicleColours = [
  'Black',
  'White',
  'Silver',
  'Grey',
  'Blue',
  'Red',
  'Green',
  'Gold',
  'Brown',
  'Yellow',
];

class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key});

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  String? _make;
  late final TextEditingController _model;
  late final TextEditingController _plate;
  int? _year;
  String? _colour;
  int _seats = 4;

  @override
  void initState() {
    super.initState();
    final v = ref.read(registrationProvider).vehicle;
    _type = v?.rideTypeId ?? 'car';
    _make = v?.make.isEmpty ?? true ? null : v!.make;
    _model = TextEditingController(text: v?.model ?? '');
    _plate = TextEditingController(text: v?.plate ?? '');
    _year = v?.year;
    _colour = v?.color.isEmpty ?? true ? null : v!.color;
    _seats = v?.seats ?? 4;
  }

  VehicleKind get _kind => rideTypes.firstWhere((r) => r.id == _type).kind;

  void _selectType(String id) {
    final oldKind = _kind;
    setState(() {
      _type = id;
      if (_kind != oldKind) _make = null;
      if (_year != null && _year! < minimumYear(id)) _year = null;
      if (id == 'xl' && _seats < 6) _seats = 6;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_make == null || _year == null || _colour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose make, year and colour')),
      );
      return;
    }
    ref
        .read(registrationProvider.notifier)
        .saveVehicle(
          VehicleDetails(
            rideTypeId: _type,
            make: _make!,
            model: _model.text.trim(),
            year: _year,
            color: _colour!,
            plate: _formatPlate(_plate.text),
            seats: _kind == VehicleKind.car
                ? _seats
                : (_kind == VehicleKind.bike ? 1 : 3),
          ),
        );
    context.pop();
  }

  /// "kja482gd" -> "KJA 482 GD"
  String _formatPlate(String raw) {
    final c = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return '${c.substring(0, 3)} ${c.substring(3, c.length - 2)} ${c.substring(c.length - 2)}';
  }

  @override
  void dispose() {
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = DateTime.now().year; y >= minimumYear(_type); y--) y,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Your vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const FieldLabel('Which service will you drive for?'),
            for (final r in rideTypes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectType(r.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _type == r.id
                          ? AppColors.primaryLight
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _type == r.id
                            ? AppColors.primary
                            : AppColors.border,
                        width: _type == r.id ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(r.icon, size: 32, color: AppColors.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                requirementsFor(r.id),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _type == r.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _type == r.id
                              ? AppColors.primary
                              : AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Make'),
                      DropdownButtonFormField<String>(
                        key: ValueKey('make-$_kind'),
                        initialValue: _make,
                        isExpanded: true,
                        hint: const Text('Select'),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          for (final m in makesFor(_kind))
                            DropdownMenuItem(value: m, child: Text(m)),
                        ],
                        onChanged: (v) => setState(() => _make = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Model'),
                      TextFormField(
                        controller: _model,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: _kind == VehicleKind.car
                              ? 'e.g. Corolla'
                              : 'e.g. RE',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Year'),
                      DropdownButtonFormField<int>(
                        key: ValueKey('year-$_type'),
                        initialValue: _year,
                        isExpanded: true,
                        hint: const Text('Select'),
                        menuMaxHeight: 320,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          for (final y in years)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) => setState(() => _year = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Colour'),
                      DropdownButtonFormField<String>(
                        initialValue: _colour,
                        isExpanded: true,
                        hint: const Text('Select'),
                        menuMaxHeight: 320,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          for (final c in vehicleColours)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _colour = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const FieldLabel('Plate number'),
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(hintText: 'e.g. KJA 482 GD'),
              validator: (v) {
                final clean = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                return RegExp(r'^[A-Za-z]{3}\d{2,3}[A-Za-z]{2}$')
                        .hasMatch(clean)
                    ? null
                    : 'Use the format ABC 123 DE';
              },
            ),
            if (_kind == VehicleKind.car) ...[
              const SizedBox(height: 20),
              const FieldLabel('Passenger seats'),
              Row(
                children: [
                  for (final s in [4, 6, 7])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text('$s seats'),
                        selected: _seats == s,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _seats == s
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        onSelected: _type == 'xl' && s < 6
                            ? null
                            : (_) => setState(() => _seats = s),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(label: 'Save vehicle', onPressed: _save),
      ),
    );
  }
}
