import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/routes.dart';
import '../auth/auth_controller.dart';
import '../driving/driver_controller.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';
import '../trip/trip_controller.dart';

/// Support contacts. Change these to your real numbers before launch.
class SupportContacts {
  static const whatsapp = '2348000000000';
  static const phone = '+2348000000000';
  static const email = 'support@goride.ng';
}

class _Faq {
  const _Faq(this.category, this.q, this.a);
  final String category;
  final String q;
  final String a;
}

const _faqs = [
  _Faq(
    'Getting started',
    'How long does approval take?',
    'Usually 24 to 48 hours after you submit all documents. We check your NIN and licence, then approve you in the app.',
  ),
  _Faq(
    'Getting started',
    'What vehicles can I use?',
    'Cars from 2008 or newer (Comfort from 2014), kekes from 2014 and bikes from 2015, in good condition with valid papers.',
  ),
  _Faq(
    'Getting started',
    'Do I need a LASDRI card?',
    'Car and keke drivers in Lagos need a valid LASDRI card. Bike riders can upload it later.',
  ),
  _Faq(
    'Trips',
    'How do I get ride requests?',
    'Tap "Go online" on the home screen. Requests near you pop up with the fare and distance. You have 15 seconds to accept.',
  ),
  _Faq(
    'Trips',
    'What is the rider PIN?',
    'Every rider has a 4-digit PIN. Ask for it when they get in and type it to start the trip. It makes sure you picked up the right person.',
  ),
  _Faq(
    'Trips',
    'The rider is not coming out',
    'Waiting is free for 3 minutes, then a waiting fee applies. After 5 minutes you can cancel as "Rider didn\'t show up" and earn a cancellation fee.',
  ),
  _Faq(
    'Trips',
    'I need to take a different route',
    'Tap "Taking another route? Tell the rider" during the trip and choose a reason. Riders get a safety alert when a car leaves the route, so telling them first keeps them calm.',
  ),
  _Faq(
    'Money',
    'Commission or subscription: which is better?',
    'Commission (10%) suits part-time drivers: you pay nothing upfront. A subscription suits full-time drivers: you pay a flat fee and keep 100% of fares. You can switch in My plan.',
  ),
  _Faq(
    'Money',
    'How do cash trips work?',
    'You keep the cash. On the commission plan, GoRide\'s commission is taken from your wallet. If you owe more than ₦5,000, settle it before going online again.',
  ),
  _Faq(
    'Money',
    'When can I cash out?',
    'Any time, from ₦1,000. Payouts go instantly to your bank account and are free.',
  ),
  _Faq(
    'Safety',
    'What if I feel unsafe?',
    'Tap the shield on the map. You can call 112, alert GoRide\'s safety team and share your live trip with your emergency contacts.',
  ),
  _Faq(
    'Account',
    'A document is about to expire',
    'Upload the new one in Account > Documents before it expires. Expired documents stop you from going online.',
  ),
];

/// Driver FAQ and contact support.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _category = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ..._faqs.map((f) => f.category).toSet()];
    final q = _query.toLowerCase();
    final list = _faqs
        .where((f) => _category == 'All' || f.category == _category)
        .where(
          (f) =>
              q.isEmpty ||
              f.q.toLowerCase().contains(q) ||
              f.a.toLowerCase().contains(q),
        )
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Help & Support'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFamily: 'Urbanist',
            ),
            tabs: const [
              Tab(text: 'FAQ'),
              Tab(text: 'Contact us'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search help',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in cats)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _category == c
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No answers found. Try "Contact us".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                for (final f in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          f.q,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        expandedAlignment: Alignment.centerLeft,
                        iconColor: AppColors.primary,
                        children: [
                          Text(
                            f.a,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ContactTile(
                  icon: Icons.chat,
                  color: const Color(0xFF25D366),
                  title: 'WhatsApp',
                  subtitle: 'Fastest. We reply within minutes, 24/7',
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://wa.me/${SupportContacts.whatsapp}?text=${Uri.encodeComponent('Hello GoRide driver support, ')}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                _ContactTile(
                  icon: Icons.call,
                  color: AppColors.primary,
                  title: 'Call us',
                  subtitle: SupportContacts.phone,
                  onTap: () => launchUrl(
                    Uri(scheme: 'tel', path: SupportContacts.phone),
                  ),
                ),
                _ContactTile(
                  icon: Icons.mail_outline,
                  color: const Color(0xFF2196F3),
                  title: 'Email',
                  subtitle: SupportContacts.email,
                  onTap: () => launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: SupportContacts.email,
                      queryParameters: {'subject': 'GoRide support'},
                    ),
                  ),
                ),
                _ContactTile(
                  icon: Icons.sos,
                  color: AppColors.error,
                  title: 'Emergency (112)',
                  subtitle: 'If you are in danger right now',
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                ),
                const SizedBox(height: 8),
                Text(
                  'Driver support numbers above are placeholders until GoRide\'s real lines are set up.',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Draft text: have a Nigerian lawyer review before launch.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.terms});
  final bool terms;

  @override
  Widget build(BuildContext context) {
    final sections = terms ? _termsSections : _privacySections;
    return Scaffold(
      appBar: AppBar(title: Text(terms ? 'Driver Terms' : 'Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x1AFF9800),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Draft for preview. To be reviewed by a lawyer before launch.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final (title, body) in sections) ...[
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(height: 1.6, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

const _privacySections = [
  (
    '1. What we collect',
    'Your name, phone, email, photo, NIN, driver\'s licence, vehicle documents, bank details for payouts, trip history and your location while you are online.',
  ),
  (
    '2. Why we use it',
    'To verify you, match you with riders, show riders where you are during a trip, pay you, keep everyone safe and provide support.',
  ),
  (
    '3. Location',
    'While you are online we share your location with GoRide to send you requests. During a trip your rider sees your live location. When you go offline, sharing stops.',
  ),
  (
    '4. Verification',
    'Your NIN and licence are checked with official sources (NIMC, FRSC). Documents are only seen by GoRide\'s verification team.',
  ),
  (
    '5. Your rights (NDPA 2023)',
    'You can access, correct or delete your data at any time by contacting support. Some trip and payment records must be kept for legal reasons.',
  ),
];

const _termsSections = [
  (
    '1. Driving with GoRide',
    'You are an independent driver. You must hold a valid licence, insurance and vehicle papers, and keep them up to date in the app.',
  ),
  (
    '2. Fees',
    'Founding drivers pay 0% commission for their first 30 days. After that, on the commission plan GoRide keeps 10% of each fare. On a subscription you pay a fixed fee per period and keep all fares. Prices can change with 7 days\' notice.',
  ),
  (
    '3. Cash trips',
    'You collect cash fares directly. Commission on cash trips is deducted from your GoRide wallet. Balances owed above the limit pause your account until settled.',
  ),
  (
    '4. Conduct',
    'Be respectful, follow traffic laws, never ask riders for extra money and always use the rider PIN. Harassment, unsafe driving or fraud leads to deactivation.',
  ),
  (
    '5. Safety features',
    'Route alerts and SOS help keep riders and drivers safe, but they do not replace emergency services. In danger, call 112.',
  ),
];

/// Invite other drivers: bonus when they complete 20 trips.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  static const reward = 5000;
  static const tripsNeeded = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(registrationProvider).personal.fullName;
    final first = name.isEmpty ? 'DRIVE' : name.split(' ').first.toUpperCase();
    final code = 'D-$first${(name.hashCode.abs() % 900 + 100)}';
    final message =
        'Drive with GoRide and keep more of what you earn. Sign up with my code $code. https://thetechguydev.github.io/GoRide/driver/';

    return Scaffold(
      appBar: AppBar(title: const Text('Invite drivers')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0CC25F), Color(0xFF079A4A)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Icon(Icons.groups, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Earn ${naira(reward)} per driver',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'When a driver you invite completes $tripsNeeded trips in their first 30 days, you get the bonus in your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your invite code',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$code copied')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.copy, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Share invite',
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () async {
              try {
                await SharePlus.instance.share(ShareParams(text: message));
              } catch (_) {
                await Clipboard.setData(ClipboardData(text: message));
              }
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _Stat(value: '0', label: 'Drivers joined'),
              const SizedBox(width: 12),
              _Stat(value: naira(0), label: 'Bonus earned'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Log out: go offline, clear everything, back to Welcome.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final onTrip = ref.read(tripProvider) != null;
  if (onTrip) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finish your current trip before logging out'),
      ),
    );
    return;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Log out',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
            const Divider(height: 32),
            const Text(
              'You\'ll go offline and stop getting requests.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Yes, log out',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  ref.read(driverProvider.notifier).goOffline();
  ref.read(registrationProvider.notifier).reset();
  ref.read(earningsProvider.notifier).reset();
  await ref.read(authControllerProvider.notifier).signOut();
  if (context.mounted) context.go(Routes.welcome);
}
