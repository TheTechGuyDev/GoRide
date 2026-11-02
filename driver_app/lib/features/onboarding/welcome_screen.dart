import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/logo_green.png', width: 44),
                      const SizedBox(width: 12),
                      const Text(
                        'GoRide Driver',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Drive with GoRide.\nKeep more of what you earn.',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Car, keke or bike. Choose how you pay GoRide and drive on your own time.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _Benefit(
                    icon: Icons.percent,
                    title: '0% for your first month, then 10%',
                    body: 'Half what other apps charge. Or pay a flat weekly fee and keep 100% of every fare.',
                  ),
                  const _Benefit(
                    icon: Icons.bolt,
                    title: 'Instant payouts',
                    body: 'Cash out to any Nigerian bank, any time, free.',
                  ),
                  const _Benefit(
                    icon: Icons.shield_outlined,
                    title: 'Safety on every trip',
                    body: 'Verified riders, trip PIN, live tracking and SOS.',
                  ),
                  const _Benefit(
                    icon: Icons.schedule,
                    title: 'Your hours, your rules',
                    body: 'Go online when you want. No minimum hours.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                children: [
                  AppButton(
                    label: 'Become a driver',
                    onPressed: () => context.push(Routes.signUp),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'I already drive with GoRide',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.push(Routes.signIn),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => context.push(Routes.privacyPolicy),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        '·',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.push(Routes.terms),
                        child: Text(
                          'Driver Terms',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
