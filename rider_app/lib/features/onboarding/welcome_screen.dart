import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/images/logo_green.png', width: 64),
              const SizedBox(height: 40),
              const Text(
                'Let\'s Get Started!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'Let\'s dive in into your account',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              const _SocialButton(
                icon: FaIcon(
                  FontAwesomeIcons.google,
                  color: Color(0xFFDB4437),
                  size: 20,
                ),
                label: 'Continue with Google',
              ),
              const SizedBox(height: 14),
              const _SocialButton(
                icon: FaIcon(FontAwesomeIcons.apple, size: 22),
                label: 'Continue with Apple',
              ),
              const Spacer(),
              AppButton(
                label: 'Sign up',
                onPressed: () => context.push(Routes.signUp),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Sign in',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(Routes.signIn),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const Text(
                    '·',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Social sign-in will be enabled with Supabase'),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            SizedBox(width: 24, child: Center(child: icon)),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }
}
