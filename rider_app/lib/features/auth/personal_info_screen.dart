import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  static const _genders = ['Male', 'Female', 'Prefer not to say'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  late final TextEditingController _phone;
  String? _gender;
  DateTime? _dob;
  Uint8List? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final phone = ref.read(authControllerProvider).profile.phone;
    _phone = TextEditingController(
      text: phone.startsWith(PhoneUtils.dialCode) ? phone.substring(4) : phone,
    );
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
    final latest = DateTime(now.year - 16, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: latest,
      helpText: 'Date of Birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender and date of birth'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final auth = ref.read(authControllerProvider.notifier);
    final current = ref.read(authControllerProvider).profile;
    await auth.saveProfile(
      current.copyWith(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        gender: _gender,
        dateOfBirth: _dob,
        photo: _photo,
      ),
    );
    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fill Personal Info')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Center(
              child: _Avatar(photo: _photo, onTap: _pickPhoto),
            ),
            const SizedBox(height: 28),
            const FieldLabel('Full Name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Full Name'),
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
                hintText: 'Email',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
              validator: (v) =>
                  (v == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 20),
            const FieldLabel('Phone Number'),
            PhoneField(controller: _phone, readOnly: true),
            const SizedBox(height: 20),
            const FieldLabel('Gender'),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              hint: const Text('Gender'),
              icon: const Icon(Icons.keyboard_arrow_down),
              borderRadius: BorderRadius.circular(12),
              items: _genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Date of Birth'),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 20),
                ),
                child: Text(
                  _dob == null ? 'Date of Birth' : _formatDate(_dob!),
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
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Continue',
          loading: _saving,
          onPressed: _submit,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo, required this.onTap});

  final Uint8List? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: const Color(0xFFEEEEEE),
              backgroundImage: photo != null ? MemoryImage(photo!) : null,
              child: photo == null
                  ? const Icon(Icons.person, size: 64, color: Color(0xFFBDBDBD))
                  : null,
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.edit, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
