import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import 'registration_controller.dart';

/// Checklist of everything a new driver must complete before review.
class RegistrationHubScreen extends ConsumerStatefulWidget {
  const RegistrationHubScreen({super.key});

  @override
  ConsumerState<RegistrationHubScreen> createState() =>
      _RegistrationHubScreenState();
}

class _RegistrationHubScreenState extends ConsumerState<RegistrationHubScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await ref.read(registrationProvider.notifier).submit();
    if (!mounted) return;
    setState(() => _submitting = false);
    context.go(Routes.regStatus);
  }

  @override
  Widget build(BuildContext context) {
    final reg = ref.watch(registrationProvider);
    final steps = [
      _Step(
        icon: Icons.person_outline,
        title: 'Personal details',
        subtitle: reg.personal.isComplete
            ? reg.personal.fullName
            : 'Name, date of birth, city and photo',
        done: reg.personal.isComplete,
        route: Routes.regPersonal,
      ),
      _Step(
        icon: Icons.directions_car_outlined,
        title: 'Vehicle',
        subtitle: reg.vehicle?.isComplete ?? false
            ? '${reg.vehicle!.rideType.name} · ${reg.vehicle!.plate}'
            : 'What you drive and its plate number',
        done: reg.vehicle?.isComplete ?? false,
        route: Routes.regVehicle,
      ),
      _Step(
        icon: Icons.description_outlined,
        title: 'Documents',
        subtitle: reg.vehicle == null
            ? 'Add your vehicle first'
            : '${reg.docsUploaded} of ${reg.requiredDocs.length} uploaded',
        done: reg.docsComplete && reg.vehicle != null,
        route: reg.vehicle == null ? null : Routes.regDocuments,
      ),
      _Step(
        icon: Icons.payments_outlined,
        title: 'How you pay GoRide',
        subtitle: reg.plan?.title ?? 'Commission or subscription',
        done: reg.plan != null,
        route: reg.vehicle == null ? null : Routes.regPlan,
      ),
      _Step(
        icon: Icons.account_balance_outlined,
        title: 'Payout bank account',
        subtitle: reg.bank?.masked ?? 'Where we send your earnings',
        done: reg.bank != null,
        route: Routes.regBank,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Driver registration'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: reg.stepsDone / 5,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Text(
                        '${reg.stepsDone}/5',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reg.readyToSubmit
                            ? 'All done!'
                            : 'Let\'s get you on the road',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reg.readyToSubmit
                            ? 'Submit your application for review.'
                            : 'Complete these 5 steps. It takes about 10 minutes.',
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final s in steps)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: s.done ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                enabled: s.route != null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                onTap: s.route == null ? null : () => context.push(s.route!),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: s.done ? AppColors.primary : AppColors.fieldFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    s.done ? Icons.check : s.icon,
                    color: s.done ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                title: Text(
                  s.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  s.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your documents are only seen by the GoRide verification team.',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: AppButton(
          label: 'Submit for review',
          loading: _submitting,
          onPressed: reg.readyToSubmit ? _submit : null,
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final String? route;
}
