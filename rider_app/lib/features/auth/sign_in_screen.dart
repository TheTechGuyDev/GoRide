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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phone = TextEditingController();
  bool _remember = true;
  bool _loading = false;
  String? _error;

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
          flow: AuthFlow.signIn,
          rememberMe: _remember,
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
            title: 'Welcome Back!',
            emoji: '👋',
            subtitle: 'Please enter your phone number to sign in to your GoRide account.',
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
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? false),
              ),
              const Text('Remember me', style: TextStyle(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text.rich(
              TextSpan(
                text: 'Don\'t have an account?  ',
                style: const TextStyle(fontSize: 15),
                children: [
                  TextSpan(
                    text: 'Sign up',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => context.pushReplacement(Routes.signUp),
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
          label: 'Sign in',
          loading: _loading,
          onPressed: PhoneUtils.isValid(_phone.text) ? _submit : null,
        ),
      ),
    );
  }
}
