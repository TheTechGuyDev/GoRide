import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goride_core/goride_core.dart';

/// Bottom navigation shell: Home, Earnings, Trips, Account.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Earnings',
    ),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Trips'),
    (Icons.person_outline, Icons.person, 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
