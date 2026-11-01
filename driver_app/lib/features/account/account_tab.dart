import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../../core/widgets/common.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';
import 'more_screens.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(registrationProvider);
    final e = ref.watch(earningsProvider);
    final p = reg.personal;
    final v = reg.vehicle;
    final docIssues = reg.requiredDocs
        .map(reg.doc)
        .where(
          (d) => d.isExpired || d.expiresSoon || d.status == DocStatus.rejected,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          GoCard(
            onTap: () => context.push(Routes.profile),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary,
                      backgroundImage: p.photo != null
                          ? MemoryImage(p.photo!)
                          : null,
                      child: p.photo == null
                          ? Text(
                              p.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName.isEmpty ? 'GoRide Driver' : p.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            PhoneUtils.pretty(reg.phone),
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          if (v != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.fieldFill,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                v.plate,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    StatTile(
                      value: e.averageRating.toStringAsFixed(2),
                      label: 'Rating',
                      icon: Icons.star_rounded,
                    ),
                    StatTile(
                      value: '${e.completed.length}',
                      label: 'Trips',
                      icon: Icons.route,
                    ),
                    StatTile(
                      value: reg.joinedAt == null
                          ? 'New'
                          : _since(reg.joinedAt!),
                      label: 'With GoRide',
                      icon: Icons.calendar_month,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Group(
            items: [
              _Item(
                Icons.directions_car_outlined,
                'Vehicle',
                Routes.vehicle,
                subtitle: v?.title,
              ),
              _Item(
                Icons.description_outlined,
                'Documents',
                Routes.documents,
                badge: docIssues,
              ),
              _Item(Icons.tune, 'Trip preferences', Routes.tripPreferences),
              _Item(
                Icons.workspace_premium_outlined,
                'My plan',
                Routes.plan,
                subtitle: reg.plan?.title,
              ),
            ],
          ),
          _Group(
            items: [
              _Item(
                Icons.account_balance_wallet_outlined,
                'Wallet',
                Routes.wallet,
              ),
              _Item(
                Icons.account_balance_outlined,
                'Payout account',
                Routes.bank,
                subtitle: reg.bank?.masked,
              ),
              _Item(Icons.star_outline, 'Ratings and feedback', Routes.ratings),
            ],
          ),
          _Group(
            items: [
              _Item(Icons.shield_outlined, 'Safety toolkit', Routes.emergency),
              _Item(
                Icons.contacts_outlined,
                'Emergency contacts',
                Routes.emergencyContacts,
              ),
            ],
          ),
          _Group(
            items: [
              _Item(
                Icons.notifications_none,
                'Notifications',
                Routes.notificationSettings,
              ),
              _Item(
                Icons.palette_outlined,
                'App appearance',
                Routes.appearance,
              ),
              _Item(Icons.card_giftcard, 'Invite drivers', Routes.referral),
              _Item(Icons.help_outline, 'Help and support', Routes.help),
              _Item(
                Icons.description_outlined,
                'Privacy Policy',
                Routes.privacyPolicy,
              ),
              _Item(Icons.gavel_outlined, 'Driver Terms', Routes.terms),
            ],
          ),
          _Group(
            items: [
              _Item(
                Icons.logout,
                'Log out',
                null,
                danger: true,
                onTap: (c) => confirmLogout(c, ref),
              ),
            ],
          ),
          Text(
            'GoRide Driver 1.0.0 (preview)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  static String _since(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days < 30) return '${days}d';
    if (days < 365) return '${days ~/ 30}mo';
    return '${days ~/ 365}y';
  }
}

class _Item {
  const _Item(
    this.icon,
    this.label,
    this.route, {
    this.subtitle,
    this.badge = 0,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? route;
  final String? subtitle;
  final int badge;
  final bool danger;
  final void Function(BuildContext)? onTap;
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
              subtitle: i.subtitle == null
                  ? null
                  : Text(
                      i.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              trailing: i.danger
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i.badge > 0) CountBadge(count: i.badge),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
              onTap: () => i.route != null
                  ? context.push(i.route!)
                  : i.onTap?.call(context),
            ),
        ],
      ),
    );
  }
}
