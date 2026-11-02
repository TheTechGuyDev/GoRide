import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart' show AuthService, EmailField;

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  String? _error;

  bool get _canSubmit => EmailField.isValid(_email.text) && _agreed;

  Future<void> _submit() async {
    if (!EmailField.isValid(_email.text)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestOtp(email: _email.text, flow: AuthFlow.signUp);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AuthService.message(e);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    context.push(Routes.otp);
  }

  @override
  void dispose() {
    _email.dispose();
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
            subtitle: 'Let\'s get started! Enter your email and we\'ll send you a 6-digit code.',
          ),
          const SizedBox(height: 32),
          const FieldLabel('Email'),
          EmailField(
            controller: _email,
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
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push(Routes.terms),
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
          SocialButton(
            provider: SocialProvider.google,
            onPressed: () async {
              try {
                await ref
                    .read(authControllerProvider.notifier)
                    .signInWithGoogle();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(AuthService.message(e))));
              }
            },
          ),
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
