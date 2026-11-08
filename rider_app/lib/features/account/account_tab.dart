import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'more_screens.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/phone_utils.dart';
import '../auth/auth_controller.dart';
import '../booking/payment_methods.dart';

/// Screen 63: account home.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final balance = ref.watch(walletBalanceProvider);
    final name = profile.fullName.isEmpty ? 'GoRide Rider' : profile.fullName;

    return Scaffold(
      backgroundColor: AppColors.fieldFill,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.fieldFill,
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
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  onTap: () => context.push(Routes.editProfile),
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
                        ? 'Tap to complete your profile'
                        : PhoneUtils.pretty(profile.phone),
                  ),
                  trailing: const Icon(Icons.chevron_right),
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
                      side: BorderSide(color: AppColors.border),
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
          _Group(
            items: [
              _Item(
                Icons.place_outlined,
                'Saved Addresses',
                Routes.savedAddresses,
              ),
              _Item(
                Icons.credit_card,
                'Payment Methods',
                Routes.paymentSettings,
              ),
              _Item(
                Icons.notifications_none,
                'Notifications',
                Routes.notificationSettings,
              ),
              _Item(
                Icons.contacts_outlined,
                'Emergency Contacts',
                Routes.emergencyContacts,
              ),
            ],
          ),
          _Group(
            items: [
              _Item(
                Icons.shield_outlined,
                'Account & Security',
                Routes.accountSecurity,
              ),
              _Item(Icons.link, 'Linked Accounts', Routes.linkedAccounts),
              _Item(
                Icons.privacy_tip_outlined,
                'Data & Privacy',
                Routes.dataPrivacy,
              ),
            ],
          ),
          _Group(
            items: [
              _Item(
                Icons.palette_outlined,
                'App Appearance',
                Routes.appearance,
              ),
              _Item(Icons.card_giftcard, 'Invite Friends', Routes.referral),
              _Item(Icons.help_outline, 'Help & Support', Routes.help),
              _Item(
                Icons.description_outlined,
                'Privacy Policy',
                Routes.privacyPolicy,
              ),
              _Item(Icons.gavel_outlined, 'Terms of Service', Routes.terms),
              _Item(Icons.star_outline, 'Rate GoRide', null, onTap: showRateUs),
            ],
          ),
          _Group(
            items: [
              _Item(
                Icons.logout,
                'Logout',
                null,
                danger: true,
                onTap: (c) => confirmLogout(c, ref),
              ),
              _Item(
                Icons.delete_forever_outlined,
                'Delete my account',
                null,
                danger: true,
                onTap: (c) => deleteAccount(c, ref),
              ),
            ],
          ),
          Text(
            'GoRide 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _Item {
  const _Item(
    this.icon,
    this.label,
    this.route, {
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String? route;
  final void Function(BuildContext)? onTap;
  final bool danger;
}

class _Group extends StatelessWidget {
  const _Group({required this.items});
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final i in items)
            ListTile(
              leading: Icon(
                i.icon,
                color: i.danger ? AppColors.error : AppColors.textPrimary,
              ),
              title: Text(
                i.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: i.danger ? AppColors.error : null,
                ),
              ),
              trailing: i.danger ? null : const Icon(Icons.chevron_right),
              onTap: () => i.route != null
                  ? context.push(i.route!)
                  : i.onTap?.call(context),
            ),
        ],
      ),
    );
  }
}
