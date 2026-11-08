import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goride_core/goride_core.dart' show confirmDeleteAccount;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../auth/auth_controller.dart';
import '../trip/trip_controller.dart';

export 'package:goride_core/src/widgets/appearance_screen.dart';

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
    'Rides',
    'How do I book a ride?',
    'Tap "Where to?" on the home screen, choose your destination, confirm your pickup point, pick a ride type and tap Book.',
  ),
  _Faq(
    'Rides',
    'Can I book a ride for later?',
    'Yes. On the ride options screen tap the calendar button and choose a day and time up to 7 days ahead. Your fare is locked when you book.',
  ),
  _Faq(
    'Rides',
    'What is the ride PIN?',
    'A 4-digit code shown when your driver arrives. Only tell it to the driver in the car with the right plate number. The trip can\'t start without it.',
  ),
  _Faq(
    'Rides',
    'How do I cancel a ride?',
    'Tap Cancel Ride on the trip screen and choose a reason. Scheduled rides can be cancelled free up to 1 hour before pickup.',
  ),
  _Faq(
    'Payments',
    'How are fares calculated?',
    'A base fare plus a rate per km and per minute, with a minimum fare. Tap the ⓘ next to any price to see the breakdown.',
  ),
  _Faq(
    'Payments',
    'How do I top up my wallet?',
    'Go to Account > Top Up. You can pay by card, bank transfer or USSD. Payments are processed securely by Paystack.',
  ),
  _Faq(
    'Payments',
    'My driver asked for extra money. What do I do?',
    'Don\'t pay more than the fare in the app. Report it from Ride Details > ⋮ > Report a problem, or choose "Driver asked for more money" if you cancel.',
  ),
  _Faq(
    'Payments',
    'I was charged but my ride was cancelled',
    'You are only charged when a trip is completed. If money left your account for a cancelled ride, contact support with the booking ID and we\'ll refund it.',
  ),
  _Faq(
    'Safety',
    'What happens if my driver goes off route?',
    'GoRide alerts you with a sound. You can accept the new route, ask the driver why, or send SOS. If you don\'t respond in 60 seconds, SOS is sent automatically to your emergency contacts.',
  ),
  _Faq(
    'Safety',
    'Who are emergency contacts?',
    'Up to 3 people you trust. In an emergency they get your live location, driver and car details. Add them in Account > Emergency Contacts.',
  ),
  _Faq(
    'Safety',
    'How do I call for help during a trip?',
    'Tap the red shield on the trip screen to call 112, share your trip, or send SOS.',
  ),
  _Faq(
    'Account',
    'How do I change my phone number?',
    'Go to Account > Account & Security > Change phone number. You will confirm the new number with an SMS code.',
  ),
  _Faq(
    'Account',
    'I left something in the car',
    'Open Activity, tap the trip, then ⋮ > Report a lost item. We\'ll connect you with the driver.',
  ),
];

/// Screens 84-86: FAQ and contact support.
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
                      'https://wa.me/${SupportContacts.whatsapp}?text=${Uri.encodeComponent('Hello GoRide support, ')}',
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
                  'Support numbers above are placeholders until GoRide\'s real lines are set up.',
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

/// Screens 87-88. Draft text: have a Nigerian lawyer review before launch.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.terms});
  final bool terms;

  @override
  Widget build(BuildContext context) {
    final sections = terms ? _termsSections : _privacySections;
    return Scaffold(
      appBar: AppBar(
        title: Text(terms ? 'Terms of Service' : 'Privacy Policy'),
      ),
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
    'Your name, phone number, email, profile photo, payment details (handled by Paystack), trip history, and your location while you use GoRide.',
  ),
  (
    '2. Why we use it',
    'To match you with drivers, show your trip in real time, process payments, keep you safe (route alerts, SOS), give support, and improve GoRide.',
  ),
  (
    '3. Location',
    'We use your location to set pickups and track trips. During a trip, your location is shared with your driver and, in an emergency, with your emergency contacts and our safety team.',
  ),
  (
    '4. Who we share with',
    'Your driver (first name, pickup, destination), payment providers like Paystack, and law enforcement only when required by Nigerian law. We never sell your data.',
  ),
  (
    '5. Your rights (NDPA 2023)',
    'You can access, correct, download or delete your data at any time from Account > Data & Privacy, or by contacting support.',
  ),
  (
    '6. How long we keep it',
    'Trip and payment records are kept as required for tax and legal purposes. Other data is deleted when you delete your account.',
  ),
];

const _termsSections = [
  (
    '1. Using GoRide',
    'GoRide connects riders with independent drivers. You must be at least 16 to use GoRide and give accurate information.',
  ),
  (
    '2. Fares and payment',
    'You agree to pay the fare shown in the app. Fares may change if the route or stops change significantly. Cash fares are paid directly to the driver.',
  ),
  (
    '3. Cancellations',
    'You can cancel before pickup. Scheduled rides can be cancelled free up to 1 hour before pickup; later cancellations may attract a fee.',
  ),
  (
    '4. Behaviour',
    'Treat drivers with respect. Damage, violence or abuse can lead to account suspension and may be reported to the police.',
  ),
  (
    '5. Safety features',
    'Route alerts and SOS are designed to help, but they don\'t replace emergency services. In danger, call 112.',
  ),
  (
    '6. Liability',
    'GoRide is not responsible for items left in vehicles, but we will help you contact your driver.',
  ),
];

/// Invite friends: both get ride credit.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  static const reward = 500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authControllerProvider).profile.fullName;
    final first = name.isEmpty ? 'GORIDE' : name.split(' ').first.toUpperCase();
    final code = '$first${(name.hashCode.abs() % 900 + 100)}';
    final message =
        'Join me on GoRide, safe rides across Lagos. Use my code $code and get ${naira(reward)} off your first ride! https://thetechguydev.github.io/GoRide/';

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Friends')),
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
                const Icon(Icons.card_giftcard, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Give ${naira(reward)}, get ${naira(reward)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'When a friend takes their first ride with your code, you both get ride credit.',
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
              _Stat(value: '0', label: 'Friends joined'),
              const SizedBox(width: 12),
              _Stat(value: naira(0), label: 'Credit earned'),
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

/// Rate us dialog: 4-5 stars → app store; lower → feedback to support.
Future<void> showRateUs(BuildContext context) async {
  var stars = 0;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Enjoying GoRide?', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tap a star to rate us', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => stars = i),
                    icon: Icon(
                      i <= stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.star,
                      size: 34,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: stars == 0
                ? null
                : () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          stars >= 4
                              ? 'Thank you! The Play Store / App Store link opens once GoRide is published.'
                              : 'Thanks. Tell us what to improve in Help & Support.',
                        ),
                      ),
                    );
                  },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}

/// Screen 89: log out.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
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
              'Logout',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
            const Divider(height: 32),
            const Text(
              'Are you sure you want to log out?',
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
                    label: 'Yes, Logout',
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
  ref.read(tripControllerProvider.notifier).clear();
  await ref.read(authControllerProvider.notifier).signOut();
  ref.invalidate(authControllerProvider);
  if (context.mounted) context.go(Routes.welcome);
}

/// Google Play rule: users can delete their account inside the app.
Future<void> deleteAccount(BuildContext context, WidgetRef ref) async {
  if (!await confirmDeleteAccount(context)) return;
  ref.read(tripControllerProvider.notifier).clear();
  await ref.read(authControllerProvider.notifier).signOut();
  ref.invalidate(authControllerProvider);
  if (context.mounted) context.go(Routes.welcome);
}
