import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/admin_theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late StaffMember _who;
  bool _busy = false;
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    _who = ref.read(storeProvider).staff.first;
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    ref.read(sessionProvider.notifier).signIn(_who);
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref
        .watch(storeProvider)
        .staff
        .where((s) => s.active)
        .toList();
    final wide = MediaQuery.sizeOf(context).width > 900;

    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset('assets/images/logo_green.png', width: 40),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GoRide',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Admin console', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Sign in',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('Staff access only.', style: TextStyle(color: AC.muted)),
              const SizedBox(height: 28),
              Text(
                'Sign in as (preview)',
                style: TextStyle(color: AC.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<StaffMember>(
                initialValue: _who,
                isExpanded: true,
                dropdownColor: AC.card,
                borderRadius: BorderRadius.circular(12),
                items: [
                  for (final s in staff)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        '${s.name} · ${s.role.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _who = v ?? _who),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: _who.email),
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    color: AC.muted,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: 'preview-password'),
                obscureText: _hide,
                onSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AC.muted,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hide
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AC.muted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AC.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AC.field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AC.border),
                ),
                child: Text(
                  'Preview: pick a staff member to see what each role can access (${_who.role.description.toLowerCase()}). Real email sign-in with Supabase Auth comes with the backend.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AC.muted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B5A31), Color(0xFF07140D)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/images/logo_white.png', width: 56),
                    const Spacer(),
                    const Text(
                      'Run GoRide\nfrom one place.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Approve drivers, watch live trips, respond to SOS alerts, pay drivers and set prices.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          Expanded(child: form),
        ],
      ),
    );
  }
}
