import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../booking/payment_methods.dart';

/// Screen 64: type or tap an amount.
class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  static const minAmount = 100;
  static const maxAmount = 500000;

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  static const _quick = [1000, 2000, 5000, 10000, 20000, 50000];
  String _digits = '5000';
  final _focus = FocusNode();

  int get _amount => int.tryParse(_digits) ?? 0;

  String? get _error {
    if (_amount == 0) return null;
    if (_amount < TopUpScreen.minAmount) {
      return 'Minimum top up is ${naira(TopUpScreen.minAmount)}';
    }
    if (_amount > TopUpScreen.maxAmount) {
      return 'Maximum top up is ${naira(TopUpScreen.maxAmount)}';
    }
    return null;
  }

  void _press(String d) {
    if (_digits.length >= 7) return;
    setState(() => _digits = (_digits == '0' ? '' : _digits) + d);
  }

  void _back() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final c = e.character;
    if (c != null && RegExp(r'^\d$').hasMatch(c)) {
      _press(c);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(walletBalanceProvider);
    final valid = _amount > 0 && _error == null;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('Top Up')),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _error != null
                            ? AppColors.error
                            : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          naira(_amount),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? 'Available balance: ${naira(balance)}',
                          style: TextStyle(
                            color: _error != null
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      for (final q in _quick)
                        OutlinedButton(
                          onPressed: () => setState(() => _digits = '$q'),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: _amount == q
                                ? AppColors.primaryLight
                                : null,
                            side: BorderSide(
                              color: _amount == q
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            foregroundColor: AppColors.textPrimary,
                          ),
                          child: Text(
                            naira(q),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Continue',
                    onPressed: valid
                        ? () => context.push(Routes.topUpMethod, extra: _amount)
                        : null,
                  ),
                ],
              ),
            ),
            _Keypad(onDigit: _press, onBack: _back),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBack});
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', '<'],
    ];
    return Container(
      color: AppColors.fieldFill,
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.paddingOf(context).bottom + 6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (k == '<') {
                          onBack();
                        } else {
                          for (final c in k.split('')) {
                            onDigit(c);
                          }
                        }
                      },
                      child: SizedBox(
                        height: 54,
                        child: Center(
                          child: k == '<'
                              ? const Icon(Icons.backspace_outlined)
                              : Text(
                                  k,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
