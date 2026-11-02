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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  bool _remember = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!EmailField.isValid(_email.text)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestOtp(
            email: _email.text,
            flow: AuthFlow.signIn,
            rememberMe: _remember,
          );
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
            title: 'Welcome Back!',
            emoji: '👋',
            subtitle: 'Enter your email and we\'ll send you a 6-digit code to sign in.',
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
          SocialButton(
            provider: SocialProvider.google,
            onPressed: () async {
              try {
                await ref
                    .read(authControllerProvider.notifier)
                    .signInWithGoogle();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AuthService.message(e))),
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Sign in',
          loading: _loading,
          onPressed: EmailField.isValid(_email.text) ? _submit : null,
        ),
      ),
    );
  }
}
