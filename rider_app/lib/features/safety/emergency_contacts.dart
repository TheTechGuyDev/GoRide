import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.email = '',
  });

  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
}

/// Next of kin who get alerted in an emergency.
/// Later: `emergency_contacts` table in Supabase.
class EmergencyContactsController extends Notifier<List<EmergencyContact>> {
  static const maxContacts = 3;

  @override
  List<EmergencyContact> build() => const [];

  void save(EmergencyContact c) {
    final i = state.indexWhere((e) => e.id == c.id);
    if (i == -1) {
      if (state.length >= maxContacts) return;
      state = [...state, c];
    } else {
      state = [...state]..[i] = c;
    }
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();
}

final emergencyContactsProvider =
    NotifierProvider<EmergencyContactsController, List<EmergencyContact>>(
      EmergencyContactsController.new,
    );

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);
    final canAdd = contacts.length < EmergencyContactsController.maxContacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'If your driver leaves the route and you don\'t respond, or you press SOS, '
                    'GoRide alerts these people with your live location.',
                    style: TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No emergency contacts yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          for (final c in contacts)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  '${c.name} (${c.relationship})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [c.phone, if (c.email.isNotEmpty) c.email].join('\n'),
                ),
                isThreeLine: c.email.isNotEmpty,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _edit(context, ref, c);
                    if (v == 'remove') {
                      ref.read(emergencyContactsProvider.notifier).remove(c.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AppButton(
            label: canAdd ? 'Add contact' : 'Maximum of 3 contacts',
            onPressed: canAdd ? () => _edit(context, ref, null) : null,
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    EmergencyContact? existing,
  ) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ContactForm(existing: existing),
    );
    if (result != null) {
      ref.read(emergencyContactsProvider.notifier).save(result);
    }
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.existing});
  final EmergencyContact? existing;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late String _relationship = widget.existing?.relationship ?? 'Parent';

  static const _relationships = [
    'Parent',
    'Spouse',
    'Sibling',
    'Partner',
    'Friend',
    'Relative',
    'Colleague',
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'Add emergency contact'
                  : 'Edit contact',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              items: _relationships
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _relationship = v ?? _relationship),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Phone number (e.g. 0803 123 4567)',
              ),
              validator: (v) =>
                  (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10)
                  ? 'Enter a valid phone number'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Email (recommended, alerts are sent here free)',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                    ? null
                    : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Save',
              onPressed: () {
                if (!_key.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  EmergencyContact(
                    id:
                        widget.existing?.id ??
                        'ec-${DateTime.now().microsecondsSinceEpoch}',
                    name: _name.text.trim(),
                    relationship: _relationship,
                    phone: _phone.text.trim(),
                    email: _email.text.trim(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
