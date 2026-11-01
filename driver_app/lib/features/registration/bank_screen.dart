import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import 'registration_controller.dart';

/// Payout account. Account names will be checked with Paystack's free
/// "resolve account number" API.
class BankScreen extends ConsumerStatefulWidget {
  const BankScreen({super.key});

  @override
  ConsumerState<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends ConsumerState<BankScreen> {
  String? _bank;
  late final TextEditingController _number;
  String? _resolvedName;
  bool _resolving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = ref.read(registrationProvider).bank;
    _bank = b?.bank;
    _number = TextEditingController(text: b?.accountNumber ?? '');
    _resolvedName = b?.accountName;
  }

  Future<void> _resolve() async {
    if (_bank == null || _number.text.length != 10) return;
    setState(() {
      _resolving = true;
      _resolvedName = null;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final name = ref.read(registrationProvider).personal.fullName;
    setState(() {
      _resolving = false;
      if (_number.text.startsWith('000')) {
        _error = 'We couldn\'t find this account. Check the number and bank.';
      } else {
        _resolvedName = (name.isEmpty ? 'GoRide Driver' : name).toUpperCase();
      }
    });
  }

  void _save() {
    ref
        .read(registrationProvider.notifier)
        .saveBank(
          BankDetails(
            bank: _bank!,
            accountNumber: _number.text,
            accountName: _resolvedName!,
          ),
        );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Payout account saved')));
    context.pop();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(registrationProvider).personal.fullName;
    return Scaffold(
      appBar: AppBar(title: const Text('Payout bank account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            'Your earnings are paid here. The account name must match your name${name.isEmpty ? '' : ' ($name)'}.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          const FieldLabel('Bank'),
          DropdownButtonFormField<String>(
            initialValue: _bank,
            isExpanded: true,
            hint: const Text('Select your bank'),
            menuMaxHeight: 380,
            icon: const Icon(Icons.keyboard_arrow_down),
            borderRadius: BorderRadius.circular(12),
            items: [
              for (final b in nigerianBanks)
                DropdownMenuItem(value: b, child: Text(b)),
            ],
            onChanged: (v) {
              setState(() {
                _bank = v;
                _resolvedName = null;
              });
              _resolve();
            },
          ),
          const SizedBox(height: 20),
          const FieldLabel('Account number'),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: '10-digit NUBAN',
              errorText: _error,
            ),
            onChanged: (v) {
              setState(() {
                _resolvedName = null;
                _error = null;
              });
              if (v.length == 10) _resolve();
            },
          ),
          const SizedBox(height: 16),
          if (_resolving)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Checking account...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          if (_resolvedName != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _resolvedName!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Save account',
          onPressed: _resolvedName != null ? _save : null,
        ),
      ),
    );
  }
}
