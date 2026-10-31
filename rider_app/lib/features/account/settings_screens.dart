import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_controller.dart';
import '../auth/widgets/auth_widgets.dart';
import 'account_settings.dart';

/// Screen 73: edit personal info.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _genders = ['Male', 'Female', 'Prefer not to say'];
  final _form = GlobalKey<FormState>();
  late final RiderProfile _p = ref.read(authControllerProvider).profile;
  late final _name = TextEditingController(text: _p.fullName);
  late final _email = TextEditingController(text: _p.email);
  late final _phone = TextEditingController(
    text: _p.phone.startsWith(PhoneUtils.dialCode)
        ? _p.phone.substring(4)
        : _p.phone,
  );
  late String? _gender = _p.gender;
  late DateTime? _dob = _p.dateOfBirth;
  late Uint8List? _photo = _p.photo;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (f != null) {
      final bytes = await f.readAsBytes();
      setState(() => _photo = bytes);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref
        .read(authControllerProvider.notifier)
        .saveProfile(
          _p.copyWith(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            gender: _gender,
            dateOfBirth: _dob,
            photo: _photo,
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile updated')));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Info')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: const Color(0xFFEEEEEE),
                      backgroundImage: _photo != null
                          ? MemoryImage(_photo!)
                          : null,
                      child: _photo == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Color(0xFFBDBDBD),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const FieldLabel('Full Name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().split(' ').length < 2)
                  ? 'Enter your first and last name'
                  : null,
            ),
            const SizedBox(height: 18),
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
              validator: (v) =>
                  (v == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 18),
            const FieldLabel('Phone Number'),
            PhoneField(controller: _phone, readOnly: true),
            const SizedBox(height: 6),
            const Text(
              'To change your number, go to Account & Security.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Gender'),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              hint: const Text('Gender'),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: _genders
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Date of Birth'),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(now.year - 25),
                  firstDate: DateTime(1940),
                  lastDate: DateTime(now.year - 16, now.month, now.day),
                );
                if (d != null) setState(() => _dob = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 20),
                ),
                child: Text(
                  _dob == null ? 'Date of Birth' : formatDate(_dob!),
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
        child: AppButton(label: 'Save', loading: _saving, onPressed: _save),
      ),
    );
  }
}

/// Screen 74.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationSettingsProvider);
    return SettingsPage(
      title: 'Notifications',
      children: [
        SettingsGroup(
          children: [
            for (final p in notificationPrefs)
              SettingsSwitchTile(
                title: p.title,
                subtitle: p.subtitle,
                locked: p.locked,
                value: s[p.id] ?? false,
                onChanged: (v) => ref
                    .read(notificationSettingsProvider.notifier)
                    .set(p.id, v),
              ),
          ],
        ),
      ],
    );
  }
}

/// Screen 75.
class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required String doneMessage,
    bool typeToConfirm = false,
  }) async {
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              if (typeToConfirm) ...[
                const SizedBox(height: 14),
                const Text('Type DELETE to confirm'),
                const SizedBox(height: 6),
                TextField(controller: typed, onChanged: (_) => setState(() {})),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: typeToConfirm && typed.text.trim() != 'DELETE'
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(
                action,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(doneMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(securitySettingsProvider);
    final n = ref.read(securitySettingsProvider.notifier);
    final phone = ref.watch(authControllerProvider).profile.phone;

    return SettingsPage(
      title: 'Account & Security',
      children: [
        SettingsGroup(
          children: [
            SettingsSwitchTile(
              title: 'Fingerprint / Face unlock',
              subtitle: 'Unlock GoRide with your phone\'s biometrics',
              value: s['biometric'] ?? false,
              onChanged: (v) => n.set('biometric', v),
            ),
            SettingsSwitchTile(
              title: 'Two-step verification',
              subtitle: 'Ask for an SMS code when signing in on a new phone',
              value: s['two_step'] ?? false,
              onChanged: (v) => n.set('two_step', v),
            ),
            SettingsSwitchTile(
              title: 'Ride PIN',
              subtitle: 'Driver must enter your PIN before the trip starts',
              value: s['trip_pin'] ?? true,
              onChanged: (v) => n.set('trip_pin', v),
            ),
            SettingsSwitchTile(
              title: 'Hide my full name from drivers',
              subtitle: 'Drivers only see your first name',
              value: s['hide_name'] ?? false,
              onChanged: (v) => n.set('hide_name', v),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsLinkTile(
              title: 'Change phone number',
              subtitle: phone.isEmpty ? null : PhoneUtils.pretty(phone),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Changing number needs SMS verification (Supabase step)',
                  ),
                ),
              ),
            ),
            SettingsLinkTile(
              title: 'Device management',
              subtitle: 'This phone · active now',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You\'re signed in on 1 device')),
              ),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsLinkTile(
              title: 'Deactivate account',
              subtitle:
                  'Temporarily hide your account. Sign in again to reactivate.',
              onTap: () => _confirm(
                context,
                title: 'Deactivate account?',
                body: 'You can come back any time by signing in.',
                action: 'Deactivate',
                doneMessage:
                    'Deactivation will apply once the backend is connected',
              ),
            ),
            SettingsLinkTile(
              title: 'Delete account',
              subtitle: 'Permanently remove your account and data.',
              danger: true,
              onTap: () => _confirm(
                context,
                title: 'Delete account permanently?',
                body: 'Your profile, saved places and trip history will be deleted. Your wallet balance must be ₦0 first. This can\'t be undone.',
                action: 'Delete',
                typeToConfirm: true,
                doneMessage: 'Deletion request will be processed once the backend is connected',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Screen 76.
class LinkedAccountsScreen extends ConsumerWidget {
  const LinkedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(linkedAccountsProvider);
    Widget row(String id, IconData icon, Color color, String name) {
      final linked = s[id] ?? false;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: color, size: 30),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: TextButton(
          onPressed: () =>
              ref.read(linkedAccountsProvider.notifier).set(id, !linked),
          child: Text(
            linked ? 'Disconnect' : 'Connect',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: linked ? AppColors.textSecondary : AppColors.primary,
            ),
          ),
        ),
      );
    }

    return SettingsPage(
      title: 'Linked Accounts',
      children: [
        SettingsGroup(
          children: [
            row(
              'google',
              Icons.g_mobiledata,
              const Color(0xFFDB4437),
              'Google',
            ),
            row('apple', Icons.apple, Colors.black, 'Apple'),
          ],
        ),
        const Text(
          'Linked accounts let you sign in without an SMS code. Real linking starts with Supabase.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Screen 77, under Nigeria Data Protection Act (NDPA) rights.
class DataPrivacyScreen extends ConsumerWidget {
  const DataPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(privacySettingsProvider);
    final n = ref.read(privacySettingsProvider.notifier);
    return SettingsPage(
      title: 'Data & Privacy',
      children: [
        SettingsGroup(
          children: [
            SettingsSwitchTile(
              title: 'Usage analytics',
              subtitle: 'Help improve GoRide with anonymous usage data',
              value: s['analytics'] ?? false,
              onChanged: (v) => n.set('analytics', v),
            ),
            SettingsSwitchTile(
              title: 'Personalised suggestions',
              subtitle: 'Suggest places based on your trips',
              value: s['personalised'] ?? false,
              onChanged: (v) => n.set('personalised', v),
            ),
            SettingsSwitchTile(
              title: 'Crash reports',
              subtitle: 'Send crash details so we can fix problems',
              value: s['crash_reports'] ?? false,
              onChanged: (v) => n.set('crash_reports', v),
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsLinkTile(
              title: 'Download my data',
              subtitle: 'Get a copy of your profile, trips and payments',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'We\'ll email your data within 72 hours (once the backend is live)',
                  ),
                ),
              ),
            ),
            SettingsLinkTile(
              title: 'Emergency contacts',
              subtitle: 'Who gets your location in an emergency',
              onTap: () => context.push(Routes.emergencyContacts),
            ),
          ],
        ),
        const Text(
          'Your rights under the Nigeria Data Protection Act 2023: access, correct, download or delete your data at any time.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
