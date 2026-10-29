import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import 'trip_controller.dart';

/// Screen 43.
class CancelRideScreen extends ConsumerStatefulWidget {
  const CancelRideScreen({super.key});

  @override
  ConsumerState<CancelRideScreen> createState() => _CancelRideScreenState();
}

class _CancelRideScreenState extends ConsumerState<CancelRideScreen> {
  static const _reasons = [
    'Change in plans',
    'Waiting for long time',
    'Unable to contact driver',
    'Driver asked me to cancel',
    'Driver asked for more money',
    'Driver denied to come to pickup',
    'Wrong address shown',
    'The price is not reasonable',
    'Emergency situation',
    'Booking mistake',
    'Bad weather / flooding',
    'Other',
  ];

  String _selected = _reasons.first;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Cancel Ride'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 24, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 0, 8),
            child: Text(
              'Why are you cancelling?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v ?? _selected),
            child: Column(
              children: [
                for (final r in _reasons)
                  RadioListTile<String>(
                    value: r,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(r, style: const TextStyle(fontSize: 15)),
                  ),
              ],
            ),
          ),
          if (_selected == 'Other')
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: TextField(
                controller: _other,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Tell us more'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AppButton(
            label: 'Confirm',
            onPressed: () {
              final reason =
                  _selected == 'Other' && _other.text.trim().isNotEmpty
                  ? _other.text.trim()
                  : _selected;
              ref.read(tripControllerProvider.notifier).cancel(reason);
              context.go(Routes.rideCanceled);
            },
          ),
        ),
      ),
    );
  }
}

/// Screen 44.
class RideCanceledScreen extends ConsumerWidget {
  const RideCanceledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'Ride has been canceled!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You were not charged for this ride. You can see your cancellation history in the Activity tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const Spacer(),
                AppButton(
                  label: 'OK',
                  onPressed: () {
                    ref.read(tripControllerProvider.notifier).clear();
                    context.go(Routes.home);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
