import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import 'registration_controller.dart';

/// Shown after submitting, while the GoRide team reviews the application.
class ApplicationStatusScreen extends ConsumerWidget {
  const ApplicationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(registrationProvider);
    final status = reg.status;
    final rejected = reg.requiredDocs
        .map(reg.doc)
        .where((d) => d.status == DocStatus.rejected)
        .toList();

    final (
      IconData icon,
      Color color,
      String title,
      String body,
    ) = switch (status) {
      ApprovalStatus.approved => (
        Icons.verified,
        AppColors.primary,
        'You\'re approved!',
        'Welcome to GoRide, ${reg.personal.firstName}. You can go online and start earning now.',
      ),
      ApprovalStatus.rejected => (
        Icons.error_outline,
        AppColors.error,
        'Action needed',
        'Some documents need to be uploaded again. Fix them and resubmit.',
      ),
      _ => (
        Icons.hourglass_top,
        AppColors.warning,
        'Application in review',
        'We\'re checking your documents. This usually takes 24 to 48 hours. We\'ll notify you when it\'s done.',
      ),
    };

    final stages = [
      ('Application submitted', true),
      ('Documents checked', status == ApprovalStatus.approved),
      ('Background check (NIN and licence)', status == ApprovalStatus.approved),
      ('Approved to drive', status == ApprovalStatus.approved),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Application'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 52),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          if (status == ApprovalStatus.rejected)
            for (final d in rejected)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.error),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: Icon(d.type.icon, color: AppColors.error),
                  title: Text(
                    d.type.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(d.note ?? 'Please upload again'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.regDocumentFor(d.type.name)),
                ),
              )
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < stages.length; i++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Icon(
                              stages[i].$2
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: stages[i].$2
                                  ? AppColors.primary
                                  : AppColors.textHint,
                            ),
                            if (i < stages.length - 1)
                              Container(
                                width: 2,
                                height: 26,
                                color: stages[i + 1].$2
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            stages[i].$1,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: stages[i].$2
                                  ? null
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (status == ApprovalStatus.pending) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Our team reviews applications within 24 hours. You will get a notification as soon as you are approved, and this screen updates by itself.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: switch (status) {
          ApprovalStatus.approved => AppButton(
            label: 'Start driving',
            onPressed: () => context.go(Routes.home),
          ),
          ApprovalStatus.rejected => AppButton(
            label: 'Resubmit',
            onPressed: rejected.isEmpty
                ? () => ref.read(registrationProvider.notifier).resubmit()
                : null,
          ),
          _ => AppButton(
            label: 'Contact support',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(Routes.help),
          ),
        },
      ),
    );
  }
}
