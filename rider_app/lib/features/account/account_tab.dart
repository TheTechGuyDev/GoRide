import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/phone_utils.dart';
import '../auth/auth_controller.dart';
import '../booking/payment_methods.dart';

/// Screen 63 (account home). Full settings pages arrive in Steps 10-11.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final balance = ref.watch(walletBalanceProvider);
    final name = profile.fullName.isEmpty ? 'GoRide Rider' : profile.fullName;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Image.asset('assets/images/logo_green.png', width: 30),
        ),
        leadingWidth: 56,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: profile.photo != null
                        ? MemoryImage(profile.photo!)
                        : null,
                    child: profile.photo == null
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    profile.phone.isEmpty
                        ? 'Not signed in'
                        : PhoneUtils.pretty(profile.phone),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                  onTap: () => context.push(Routes.wallet),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    naira(balance),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: const Text('Available balance'),
                  trailing: OutlinedButton(
                    onPressed: () => context.push(Routes.topUp),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text(
                      'Top Up',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Item(
            icon: Icons.account_balance_wallet_outlined,
            label: 'GoRide Wallet',
            onTap: () => context.push(Routes.wallet),
          ),
          _Item(
            icon: Icons.contacts_outlined,
            label: 'Emergency Contacts',
            onTap: () => context.push(Routes.emergencyContacts),
          ),
          _Item(
            icon: Icons.credit_card,
            label: 'Payment Methods',
            onTap: () => context.push(Routes.paymentMethod),
          ),
          const SizedBox(height: 16),
          const Text(
            'Profile, saved addresses, notifications, appearance and help are coming in the next steps.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
