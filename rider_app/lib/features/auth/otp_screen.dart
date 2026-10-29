import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 4;
  static const _resendSeconds = 60;

  String _code = '';
  int _secondsLeft = _resendSeconds;
  Timer? _timer;
  bool _verifying = false;
  String? _error;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft--);
    });
  }

  void _press(String digit) {
    if (_verifying || _code.length >= _length) return;
    setState(() {
      _code += digit;
      _error = null;
    });
    if (_code.length == _length) _verify();
  }

  void _backspace() {
    if (_verifying || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final auth = ref.read(authControllerProvider.notifier);
    final ok = await auth.verifyOtp(_code);
    if (!mounted) return;
    setState(() => _verifying = false);

    if (!ok) {
      setState(() {
        _error = 'Invalid code, please try again';
        _code = '';
      });
      return;
    }

    final flow = ref.read(authControllerProvider).flow;
    if (flow == AuthFlow.signUp) {
      context.pushReplacement(Routes.personalInfo);
    } else {
      auth.completeSignIn();
      context.go(Routes.home);
    }
  }

  /// Lets a physical keyboard type the code too (web preview / tablets).
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _press(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authControllerProvider).profile.phone;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  AuthHeader(
                    title: 'Enter OTP Code',
                    emoji: '🔐',
                    subtitle:
                        'Check your messages! We\'ve sent a one-time code to ${PhoneUtils.pretty(phone)}. Enter the code below to verify your account and continue.',
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: List.generate(_length, (i) {
                      final filled = i < _code.length;
                      final active = i == _code.length;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: i == _length - 1 ? 0 : 12,
                          ),
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryLight
                                : AppColors.fieldFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _error != null
                                  ? AppColors.error
                                  : active
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: active ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            filled ? _code[i] : '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_verifying)
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  else ...[
                    Center(
                      child: _secondsLeft > 0
                          ? Text.rich(
                              TextSpan(
                                text: 'You can resend the code in ',
                                style: const TextStyle(fontSize: 15),
                                children: [
                                  TextSpan(
                                    text: '$_secondsLeft',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const TextSpan(text: ' seconds'),
                                ],
                              ),
                            )
                          : const Text(
                              'Didn\'t get the code?',
                              style: TextStyle(fontSize: 15),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _secondsLeft > 0
                            ? null
                            : () {
                                _startTimer();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('A new code has been sent'),
                                  ),
                                );
                              },
                        child: Text(
                          'Resend code',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _secondsLeft > 0
                                ? AppColors.textHint
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Preview mode: any 4 digits will work',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint),
                    ),
                  ),
                ],
              ),
            ),
            _NumberPad(onDigit: _press, onBackspace: _backspace),
          ],
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];

    return Container(
      color: AppColors.fieldFill,
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((row) {
          return Row(
            children: row.map((key) {
              return Expanded(
                child: SizedBox(
                  height: 60,
                  child: key.isEmpty
                      ? const SizedBox()
                      : InkWell(
                          onTap: () =>
                              key == '<' ? onBackspace() : onDigit(key),
                          child: Center(
                            child: key == '<'
                                ? const Icon(Icons.backspace_outlined)
                                : Text(
                                    key,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
