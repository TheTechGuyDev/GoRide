import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../earnings/earnings_controller.dart';
import 'plans.dart';
import 'registration_controller.dart';

/// Commission or subscription. Used in registration and Account > My plan.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key, this.manage = false});

  /// True when opened after approval (renew / switch plans).
  final bool manage;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late PlanType _type;
  late SubscriptionPeriod _period;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(registrationProvider).plan ?? const DriverPlan();
    _type = plan.type;
    _period = plan.period;
  }

  VehicleKind get _kind =>
      ref.read(registrationProvider).vehicle?.kind ?? VehicleKind.car;

  int get _price => PlanPricing.subscriptionPrice(_kind, _period);

  Future<void> _save() async {
    final reg = ref.read(registrationProvider.notifier);
    final current = ref.read(registrationProvider).plan ?? const DriverPlan();

    if (!widget.manage) {
      reg.savePlan(DriverPlan(type: _type, period: _period));
      context.pop();
      return;
    }

    if (_type == PlanType.commission) {
      reg.savePlan(const DriverPlan());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are now on the commission plan')),
      );
      context.pop();
      return;
    }

    // Subscription: pay from wallet.
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final paid = ref
        .read(earningsProvider.notifier)
        .paySubscription(_price, _period);
    setState(() => _busy = false);
    if (!paid) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not enough in your wallet'),
          content: Text(
            'You need ${naira(_price)} to pay for this plan. Top up your wallet with Paystack, then try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Top up'),
            ),
          ],
        ),
      );
      if (go == true && mounted) context.push(Routes.settle, extra: _price);
      return;
    }
    final start = current.subscriptionActive && current.period == _period
        ? current.paidUntil!
        : DateTime.now();
    reg.savePlan(
      DriverPlan(
        type: PlanType.subscription,
        period: _period,
        paidUntil: start.add(_period.length),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_period.label} plan active. You keep 100% of every fare.',
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(registrationProvider).plan;
    final active = current?.subscriptionActive ?? false;
    final lockedToSub = widget.manage && active;

    // Weekly example to compare the plans.
    const weeklyFares = 60000;
    final keepCommission =
        weeklyFares - (weeklyFares * PlanPricing.commissionRate).round();
    final weeklySub = PlanPricing.subscriptionPrice(
      _kind,
      SubscriptionPeriod.weekly,
    );
    final keepSub = weeklyFares - weeklySub;

    final String buttonLabel;
    if (!widget.manage) {
      buttonLabel = 'Save';
    } else if (_type == PlanType.commission) {
      buttonLabel = 'Switch to commission';
    } else if (active && current!.period == _period) {
      buttonLabel = 'Renew early · ${naira(_price)}';
    } else {
      buttonLabel = 'Pay ${naira(_price)} from wallet';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manage ? 'My plan' : 'How you pay GoRide'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (widget.manage && current != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current plan',
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          current.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (current.isSubscription)
                          Text(
                            active
                                ? 'Paid until ${formatDateTimeShort(current.paidUntil!)}'
                                : 'Expired. Renew to go online.',
                            style: const TextStyle(color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _PlanCard(
            selected: _type == PlanType.commission,
            enabled: !lockedToSub,
            title: 'Commission',
            price: '${(PlanPricing.commissionRate * 100).round()}% per trip',
            points: const [
              'Nothing to pay upfront',
              'Best if you drive part-time',
              'On cash trips, commission is taken from your wallet',
            ],
            onTap: () => setState(() => _type = PlanType.commission),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            selected: _type == PlanType.subscription,
            enabled: true,
            title: 'Subscription',
            price:
                'From ${naira(PlanPricing.subscriptionPrice(_kind, SubscriptionPeriod.daily))}/day',
            badge: 'Keep 100%',
            points: const [
              'Pay a flat fee, keep every naira of your fares',
              'Best if you drive full-time',
              'Pay from your GoRide wallet',
            ],
            onTap: () => setState(() => _type = PlanType.subscription),
          ),
          if (lockedToSub && _type == PlanType.commission)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You can switch to commission after your subscription ends.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          if (_type == PlanType.subscription) ...[
            const SizedBox(height: 20),
            const FieldLabel('Choose a period'),
            Row(
              children: [
                for (final p in SubscriptionPeriod.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: p == SubscriptionPeriod.monthly ? 0 : 10,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _period = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _period == p
                                ? AppColors.primaryLight
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _period == p
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: _period == p ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                p.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                naira(PlanPricing.subscriptionPrice(_kind, p)),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example: ${naira(weeklyFares)} in fares in a week',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _CompareRow('Commission plan, you keep', naira(keepCommission)),
                const SizedBox(height: 6),
                _CompareRow('Weekly subscription, you keep', naira(keepSub)),
                const SizedBox(height: 10),
                Text(
                  'You can change plans at any time. Prices are set by GoRide and may change with notice.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: buttonLabel,
          loading: _busy,
          onPressed: lockedToSub && _type == PlanType.commission ? null : _save,
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.price,
    required this.points,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final bool enabled;
  final String title;
  final String price;
  final String? badge;
  final List<String> points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.primary : AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4),
                child: Text(
                  price,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final p in points)
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
