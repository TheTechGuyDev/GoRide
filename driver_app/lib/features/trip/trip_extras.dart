import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../earnings/earnings_controller.dart';
import '../registration/plans.dart';
import '../registration/registration_controller.dart';
import 'trip_controller.dart';
import 'trip_screen.dart' show callRider;

/// Cancel before the trip starts.
class CancelTripScreen extends ConsumerStatefulWidget {
  const CancelTripScreen({super.key});

  @override
  ConsumerState<CancelTripScreen> createState() => _CancelTripScreenState();
}

class _CancelTripScreenState extends ConsumerState<CancelTripScreen> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final waited = t?.arrivedAt == null
        ? Duration.zero
        : DateTime.now().difference(t!.arrivedAt!);
    final canNoShow =
        t?.stage == TripStage.arrived && waited >= TripController.noShowAfter;
    final reasons = [
      if (t?.stage == TripStage.arrived) 'Rider didn\'t show up',
      'Rider asked me to cancel',
      'Pickup is too far',
      'Rider has too many people or luggage',
      'I don\'t feel safe',
      'Vehicle problem',
      'Other',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel trip')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            'Why are you cancelling?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          for (final r in reasons)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: r,
              // ignore: deprecated_member_use
              groupValue: _reason,
              activeColor: AppColors.primary,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _reason = v),
              title: Text(r),
              subtitle: r == 'Rider didn\'t show up'
                  ? Text(
                      canNoShow
                          ? 'You\'ll get a ${naira(TripController.noShowFee)} cancellation fee'
                          : 'Wait ${TripController.noShowAfter.inMinutes} minutes at pickup to earn the cancellation fee',
                      style: TextStyle(
                        fontSize: 12,
                        color: canNoShow
                            ? AppColors.primary
                            : AppColors.textHint,
                      ),
                    )
                  : null,
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Frequent cancellations lower your cancellation rate and can limit the requests you get. If you feel unsafe, cancel and use the shield button for help.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Cancel trip',
          variant: AppButtonVariant.danger,
          onPressed: _reason == null || t == null
              ? null
              : () {
                  ref.read(tripProvider.notifier).cancel(_reason!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Trip cancelled. You\'re back online.'),
                    ),
                  );
                  context.go(Routes.home);
                },
        ),
      ),
    );
  }
}

/// Chat with the rider (simulated replies until Supabase Realtime).
class TripChatScreen extends ConsumerStatefulWidget {
  const TripChatScreen({super.key});

  @override
  ConsumerState<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends ConsumerState<TripChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final TripController _ctrl;

  static const _quick = [
    'I\'m on my way',
    'I\'ve arrived',
    'I\'m in traffic, 5 more minutes',
    'Where exactly are you?',
    'Please come to the main road',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(tripProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.chatOpened(true));
  }

  @override
  void dispose() {
    final c = _ctrl;
    Future.microtask(() => c.chatOpened(false));
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String s) {
    _ctrl.sendMessage(s);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    ref.listen(tripProvider.select((t) => t?.messages.length), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        if (t != null && t.unread > 0) _ctrl.chatOpened(true);
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.request.riderFirstName ?? 'Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: callRider,
          ),
        ],
      ),
      body: t == null
          ? const Center(child: Text('This trip has ended'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Text(
                          'Messages are only kept for this trip',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final m in t.messages)
                        Align(
                          alignment: m.fromDriver
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: m.fromDriver
                                  ? AppColors.primary
                                  : AppColors.fieldFill,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  m.text,
                                  style: TextStyle(
                                    color: m.fromDriver ? Colors.white : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatTime(m.time),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: m.fromDriver
                                        ? Colors.white70
                                        : AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final q in _quick)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(q),
                            onPressed: () => _send(q),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            textInputAction: TextInputAction.send,
                            onSubmitted: _send,
                            decoration: const InputDecoration(
                              hintText: 'Message',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _send(_text.text),
                            child: const SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Fare summary, cash collection and rating the rider.
class TripCompleteScreen extends ConsumerStatefulWidget {
  const TripCompleteScreen({super.key});

  @override
  ConsumerState<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends ConsumerState<TripCompleteScreen> {
  int _stars = 5;
  final _tags = <String>{};

  static const _tagOptions = [
    'Polite',
    'On time',
    'Clear pickup spot',
    'Respectful',
    'Late',
    'Rude',
  ];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    if (t == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('Back to home'),
          ),
        ),
      );
    }
    final r = t.request;
    final plan = ref.watch(registrationProvider).plan;
    final commission = plan?.commissionOn(t.totalFare) ?? 0;
    final cash = r.payment == PaymentKind.cash;
    final canFinish = !cash || t.cashCollected;
    final mins = t.startedAt == null
        ? r.trip.minutes
        : DateTime.now().difference(t.startedAt!).inMinutes.clamp(1, 999);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Trip complete'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    cash
                        ? 'Collect from ${r.riderFirstName}'
                        : 'Paid by ${r.payment.label.toLowerCase()}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    naira(t.totalFare),
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.trip.km.toStringAsFixed(1)} km · $mins min',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (cash)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.cashCollected
                      ? AppColors.primaryLight
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      t.cashCollected ? Icons.check_circle : Icons.payments,
                      color: t.cashCollected
                          ? AppColors.primary
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.cashCollected
                            ? 'Cash collected'
                            : 'Collect ${naira(t.totalFare)} in cash before the rider leaves.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!t.cashCollected)
                      TextButton(
                        onPressed: () =>
                            ref.read(tripProvider.notifier).markCashCollected(),
                        child: const Text('Collected'),
                      ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _Line('Trip fare', naira(r.fare)),
                  if (t.waitingFee > 0)
                    _Line('Waiting fee', naira(t.waitingFee)),
                  if (r.surge > 1) _Line('Busy area', '${r.surge}x included'),
                  _Line(
                    commission > 0
                        ? 'GoRide commission (${(PlanPricing.commissionRate * 100).round()}%)'
                        : 'Commission',
                    commission > 0
                        ? '-${naira(commission)}'
                        : plan?.foundingFree == true
                        ? 'None (founding month)'
                        : 'None (subscription)',
                  ),
                  const Divider(height: 24),
                  _Line(
                    'You earn',
                    naira(t.totalFare - commission),
                    bold: true,
                  ),
                  if (cash && commission > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'You keep the cash. The ${naira(commission)} commission is taken from your GoRide wallet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'How was ${r.riderFirstName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _stars = i),
                    icon: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: AppColors.star,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _tagOptions)
                  FilterChip(
                    label: Text(tag),
                    selected: _tags.contains(tag),
                    showCheckmark: false,
                    selectedColor: AppColors.primaryLight,
                    onSelected: (v) =>
                        setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
                  ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: AppButton(
            label: canFinish ? 'Done' : 'Confirm cash collected first',
            onPressed: canFinish
                ? () {
                    ref.read(tripProvider.notifier).finish(riderRating: _stars);
                    context.go(Routes.home);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 17 : 15,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold
                  ? style
                  : style.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}
