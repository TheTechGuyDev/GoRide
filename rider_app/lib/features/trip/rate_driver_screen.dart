import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../activity/ride_history.dart';
import '../booking/payment_methods.dart';
import 'trip_controller.dart';
import 'widgets/trip_widgets.dart';

/// Screens 35/36: rate the driver.
class RateDriverScreen extends ConsumerStatefulWidget {
  const RateDriverScreen({super.key});

  @override
  ConsumerState<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends ConsumerState<RateDriverScreen> {
  int _stars = 0;
  bool _showDetails = true;
  final _selected = <String>{};

  static const _compliments = [
    'Great driving',
    'Clean car',
    'Friendly',
    'Knew the roads',
    'Good music',
    'On time',
  ];
  static const _problems = [
    'Unsafe driving',
    'Rude driver',
    'Car not clean',
    'Took a long route',
    'Asked for extra money',
    'Late pickup',
  ];

  void _finish() {
    final trip = ref.read(tripControllerProvider);
    if (trip == null) return context.go(Routes.home);
    ref
        .read(rideHistoryProvider.notifier)
        .update(
          trip.id,
          (r) => r.copyWith(rating: _stars, feedback: _selected.toList()),
        );
    if (_stars >= 4) {
      context.go(Routes.tipDriver);
    } else {
      context.go(Routes.feedbackThanks);
    }
  }

  void _close() {
    ref.read(tripControllerProvider.notifier).clear();
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);
    final d = trip?.driver;
    final methods = ref.watch(paymentMethodsProvider);
    final payment =
        methods.where((m) => m.id == trip?.paymentId).firstOrNull?.title ?? '';
    final chips = _stars >= 4 ? _compliments : _problems;

    Widget row(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(a, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            b,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _close),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            if (d != null) Center(child: DriverAvatar(driver: d, radius: 52)),
            const SizedBox(height: 20),
            Text(
              _stars == 5
                  ? 'Wow 5 Stars!'
                  : 'How was ${d?.firstName ?? 'the driver'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Help GoRide do better by rating this trip',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const Divider(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 46,
                    onPressed: () => setState(() {
                      _stars = i;
                      _selected.clear();
                    }),
                    icon: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i <= _stars
                          ? AppColors.star
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
              ],
            ),
            if (_stars > 0) ...[
              const SizedBox(height: 12),
              Text(
                _stars >= 4 ? 'What went well?' : 'What went wrong?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in chips)
                    FilterChip(
                      label: Text(c),
                      selected: _selected.contains(c),
                      showCheckmark: false,
                      selectedColor: _stars >= 4
                          ? AppColors.primaryLight
                          : const Color(0xFFFFEBEE),
                      side: BorderSide(
                        color: _selected.contains(c)
                            ? (_stars >= 4
                                  ? AppColors.primary
                                  : AppColors.error)
                            : AppColors.border,
                      ),
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.white,
                      onSelected: (on) => setState(
                        () => on ? _selected.add(c) : _selected.remove(c),
                      ),
                    ),
                ],
              ),
            ],
            if (trip != null) ...[
              const SizedBox(height: 20),
              if (_showDetails)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      row('Ride', trip.rideType.name),
                      row('Payment', payment),
                      const Divider(height: 20),
                      row('Trip Fare', naira(trip.fare)),
                      if (trip.discount > 0)
                        row('Discount', '-${naira(trip.discount)}'),
                      row('Total Paid', naira(trip.total), bold: true),
                    ],
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => _showDetails = !_showDetails),
                child: Text(
                  _showDetails ? 'Hide details' : 'Show details',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: AppButton(
              label: 'Give Rating',
              onPressed: _stars == 0 ? null : _finish,
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 37: optional tip, paid from the wallet.
class TipDriverScreen extends ConsumerStatefulWidget {
  const TipDriverScreen({super.key});

  @override
  ConsumerState<TipDriverScreen> createState() => _TipDriverScreenState();
}

class _TipDriverScreenState extends ConsumerState<TipDriverScreen> {
  static const _amounts = [100, 200, 300, 500, 1000, 1500, 2000, 3000, 5000];
  int? _amount = 500;
  final _custom = TextEditingController();
  bool _customMode = false;
  String? _error;

  int get _tip => _customMode
      ? int.tryParse(_custom.text.replaceAll(RegExp(r'\D'), '')) ?? 0
      : (_amount ?? 0);

  void _pay() {
    final tip = _tip;
    if (tip <= 0) return;
    if (tip > 50000) {
      setState(() => _error = 'Maximum tip is ${naira(50000)}');
      return;
    }
    final balance = ref.read(walletBalanceProvider);
    if (balance < tip) {
      setState(
        () => _error =
            'Your wallet balance is ${naira(balance)}. Choose a smaller tip.',
      );
      return;
    }
    final trip = ref.read(tripControllerProvider);
    ref.read(walletBalanceProvider.notifier).debit(tip);
    if (trip != null) {
      ref
          .read(rideHistoryProvider.notifier)
          .update(trip.id, (r) => r.copyWith(tip: tip));
    }
    context.go(Routes.feedbackThanks, extra: tip);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);
    final d = trip?.driver;
    final balance = ref.watch(walletBalanceProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go(Routes.feedbackThanks),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            if (d != null) Center(child: DriverAvatar(driver: d, radius: 52)),
            const SizedBox(height: 20),
            const Text(
              'Thank you for rating!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Would you like to add a tip to make ${d?.firstName ?? 'your driver'}\'s day?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const Divider(height: 36),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                for (final a in _amounts)
                  _TipChip(
                    label: naira(a),
                    selected: !_customMode && _amount == a,
                    onTap: () => setState(() {
                      _customMode = false;
                      _amount = a;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_customMode)
              TextField(
                controller: _custom,
                autofocus: true,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: '₦ ',
                ),
              )
            else
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _customMode = true),
                  child: const Text(
                    'Enter custom amount',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            const Divider(height: 36),
            Text(
              'Tip is charged from your GoRide Wallet (${naira(balance)}). '
              '100% of the tip goes to your driver.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Skip',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => context.go(Routes.feedbackThanks),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: _tip > 0 ? 'Pay ${naira(_tip)}' : 'Pay Tip',
                    onPressed: _tip > 0 ? _pay : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 38.
class FeedbackThanksScreen extends ConsumerWidget {
  const FeedbackThanksScreen({super.key, this.tip});

  final int? tip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripControllerProvider);

    void done({bool receipt = false}) {
      final id = trip?.id;
      final router = GoRouter.of(context);
      ref.read(tripControllerProvider.notifier).clear();
      if (receipt && id != null) {
        // Land on Activity first so "back" from the receipt goes there.
        router.go(Routes.activity);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => router.push(Routes.rideDetailsFor(id)),
        );
      } else {
        router.go(Routes.home);
      }
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 54),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Thanks for your feedback!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  tip != null && tip! > 0
                      ? 'Your ${naira(tip!)} tip has been sent to your driver. See you on your next trip!'
                      : 'See you on your next trip!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                if (trip != null)
                  TextButton(
                    onPressed: () => done(receipt: true),
                    child: const Text(
                      'View receipt',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                AppButton(label: 'OK', onPressed: done),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
