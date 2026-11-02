import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:image_picker/image_picker.dart';

import 'registration_controller.dart';

const driverCities = ['Ibadan', 'Ilorin', 'Abeokuta', 'Lagos', 'Abuja'];

/// Used during registration and later as "Edit profile".
class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key, this.editing = false});
  final bool editing;

  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  static const _genders = ['Male', 'Female', 'Prefer not to say'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _referral;
  late String _city;
  String? _gender;
  DateTime? _dob;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    final reg = ref.read(registrationProvider);
    final p = reg.personal;
    _name = TextEditingController(text: p.fullName);
    _email = TextEditingController(text: p.email);
    _referral = TextEditingController(text: p.referralCode);
    _phone = TextEditingController(
      text: reg.phone.startsWith(PhoneUtils.dialCode)
          ? reg.phone.substring(4)
          : reg.phone,
    );
    _city = p.city;
    _gender = p.gender;
    _dob = p.dateOfBirth;
    _photo = p.photo;
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photo = bytes);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1950),
      // Drivers must be at least 21.
      lastDate: DateTime(now.year - 21, now.month, now.day),
      helpText: 'Date of birth (21 or older)',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add your date of birth')),
      );
      return;
    }
    if (!PhoneUtils.isValid(_phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Nigerian phone number')),
      );
      return;
    }
    ref
        .read(registrationProvider.notifier)
        .savePersonal(
          phone: PhoneUtils.toE164(_phone.text),
          PersonalDetails(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            city: _city,
            gender: _gender,
            dateOfBirth: _dob,
            photo: _photo,
            referralCode: _referral.text.trim().toUpperCase(),
          ),
        );
    if (widget.editing) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
    context.pop();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _referral.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit profile' : 'Personal details'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.fieldFill,
                          backgroundImage: _photo != null
                              ? MemoryImage(_photo!)
                              : null,
                          child: _photo == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.textHint,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Clear face photo, no sunglasses',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const FieldLabel('Full name (as on your licence)'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Tunde Bakare'),
              validator: (v) => (v == null || v.trim().split(' ').length < 2)
                  ? 'Enter your first and last name'
                  : null,
            ),
            const SizedBox(height: 20),
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
              validator: (v) =>
                  (v == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 20),
            const FieldLabel('Phone number'),
            PhoneField(
              controller: _phone,
              readOnly: ref.read(registrationProvider).phone.startsWith('+'),
            ),
            const SizedBox(height: 20),
            const FieldLabel('City you\'ll drive in'),
            DropdownButtonFormField<String>(
              initialValue: _city,
              icon: const Icon(Icons.keyboard_arrow_down),
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final c in driverCities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _city = v ?? _city),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Gender'),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        isExpanded: true,
                        hint: const Text('Select'),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        borderRadius: BorderRadius.circular(12),
                        items: [
                          for (final g in _genders)
                            DropdownMenuItem(value: g, child: Text(g)),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('Date of birth'),
                      InkWell(
                        onTap: _pickDob,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                            ),
                          ),
                          child: Text(
                            _dob == null ? 'Select' : formatDate(_dob!),
                            style: TextStyle(
                              fontSize: 16,
                              color: _dob == null ? AppColors.textHint : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!widget.editing) ...[
              const SizedBox(height: 20),
              const FieldLabel('Referral code (optional)'),
              TextFormField(
                controller: _referral,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'From a GoRide driver who invited you',
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(label: 'Save', onPressed: _save),
      ),
    );
  }
}
