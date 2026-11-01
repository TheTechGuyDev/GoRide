import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import 'auth_controller.dart';

/// Phone entry for both "Become a driver" and "Sign in".
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, required this.flow});
  final AuthFlow flow;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  String? _error;

  bool get _signUp => widget.flow == AuthFlow.signUp;

  bool get _canSubmit =>
      PhoneUtils.isValid(_phone.text) && (_agreed || !_signUp);

  Future<void> _submit() async {
    if (!PhoneUtils.isValid(_phone.text)) {
      setState(() => _error = 'Enter a valid Nigerian phone number');
      return;
    }
    setState(() => _loading = true);
    await ref
        .read(authControllerProvider.notifier)
        .requestOtp(phone: PhoneUtils.toE164(_phone.text), flow: widget.flow);
    if (!mounted) return;
    setState(() => _loading = false);
    context.push(Routes.otp);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          AuthHeader(
            title: _signUp ? 'Start driving with GoRide' : 'Welcome back',
            subtitle: _signUp
                ? 'Enter your phone number. We\'ll send a code to confirm it\'s you, then help you register your vehicle.'
                : 'Enter the phone number on your driver account.',
          ),
          const SizedBox(height: 32),
          const FieldLabel('Phone Number'),
          PhoneField(
            controller: _phone,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_signUp) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'I agree to the GoRide ',
                      style: const TextStyle(fontSize: 15),
                      children: [
                        TextSpan(
                          text: 'Driver Terms',
                          style: const TextStyle(color: AppColors.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push(Routes.terms),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(color: AppColors.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.push(Routes.privacyPolicy),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text.rich(
              TextSpan(
                text: _signUp
                    ? 'Already a GoRide driver?  '
                    : 'New to GoRide?  ',
                style: const TextStyle(fontSize: 15),
                children: [
                  TextSpan(
                    text: _signUp ? 'Sign in' : 'Become a driver',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.pushReplacement(
                        _signUp ? Routes.signIn : Routes.signUp,
                      ),
                  ),
                ],
              ),
            ),
          ),
          if (!_signUp) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Preview: signing in opens an approved demo driver account so you can try going online straight away.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Continue',
          loading: _loading,
          onPressed: _canSubmit ? _submit : null,
        ),
      ),
    );
  }
}
