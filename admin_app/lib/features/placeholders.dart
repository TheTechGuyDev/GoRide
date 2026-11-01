import 'package:flutter/material.dart';

import '../core/theme/admin_theme.dart';
import '../data/models.dart';

/// Shown only while the dashboard is being built step by step.
class ComingPage extends StatelessWidget {
  const ComingPage({super.key, required this.section});
  final Section section;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(section.icon, size: 56, color: AC.primary),
          const SizedBox(height: 12),
          Text(
            section.label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Being built now. Refresh in a little while.',
            style: TextStyle(color: AC.muted),
          ),
        ],
      ),
    );
  }
}

class RiderDetailPage extends StatelessWidget {
  const RiderDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) =>
      const ComingPage(section: Section.riders);
}
