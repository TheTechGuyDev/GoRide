import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// Bottom navigation shell: Home, Promos, Activity, Account.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.local_offer_outlined, Icons.local_offer, 'Promos'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Activity'),
    (Icons.person_outline, Icons.person, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == index,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == index ? _items[i].$2 : _items[i].$1,
                            color: i == index
                                ? AppColors.primary
                                : AppColors.textHint,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _items[i].$3,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == index
                                  ? AppColors.primary
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
        ),
      ),
    );
  }
}

/// Temporary content for tabs built in later steps.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              '$title is coming in a later step',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
