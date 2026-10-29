import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _phone = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  String? _error;

  bool get _canSubmit => PhoneUtils.isValid(_phone.text) && _agreed;

  Future<void> _submit() async {
    if (!PhoneUtils.isValid(_phone.text)) {
      setState(() => _error = 'Enter a valid Nigerian phone number');
      return;
    }
    setState(() => _loading = true);
    await ref
        .read(authControllerProvider.notifier)
        .requestOtp(
          phone: PhoneUtils.toE164(_phone.text),
          flow: AuthFlow.signUp,
        );
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
          const AuthHeader(
            title: 'Join GoRide Today',
            emoji: '✨',
            subtitle: 'Let\'s get started! Enter your phone number to create your GoRide account.',
          ),
          const SizedBox(height: 32),
          const FieldLabel('Phone Number'),
          PhoneField(
            controller: _phone,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
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
                    text: 'I agree to GoRide ',
                    style: const TextStyle(fontSize: 15),
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: const TextStyle(color: AppColors.primary),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text.rich(
              TextSpan(
                text: 'Already have an account?  ',
                style: const TextStyle(fontSize: 15),
                children: [
                  TextSpan(
                    text: 'Sign in',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.pushReplacement(Routes.signIn),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const OrDivider(),
          const SizedBox(height: 28),
          const SocialButton(provider: SocialProvider.google),
          const SizedBox(height: 14),
          const SocialButton(provider: SocialProvider.apple),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Sign up',
          loading: _loading,
          onPressed: _canSubmit ? _submit : null,
        ),
      ),
    );
  }
}
