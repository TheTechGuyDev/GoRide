import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/money.dart';
import 'backend.dart';

/// Real Paystack payments for wallet top-ups and commission settlement.
///
/// The app asks the `paystack` server function to start a payment (the
/// secret key stays on the server), opens Paystack's secure page, then checks
/// with the server until Paystack confirms. The server credits the wallet.
class PaystackCheckout {
  PaystackCheckout._();

  /// Returns the Paystack reference when paid, or null if cancelled/failed
  /// (a message is shown to the user).
  static Future<String?> pay(
    BuildContext context, {
    required int amount,
    String purpose = 'top_up',
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    Map<String, dynamic> started;
    try {
      final res = await Backend.db.functions.invoke(
        'paystack',
        body: {'action': 'init', 'amount': amount, 'purpose': purpose},
      );
      started = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final error = details is Map ? details['error']?.toString() : null;
      if (!context.mounted) return null;
      if (error == 'not_configured') {
        await _notReady(context);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(error ?? 'Could not start the payment.')),
        );
      }
      return null;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.message(e))),
      );
      return null;
    }

    final reference = started['reference'] as String;
    final url = Uri.parse(started['authorization_url'] as String);
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!context.mounted) return null;
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WaitingDialog(reference: reference, amount: amount, url: url),
    );
    return paid == true ? reference : null;
  }

  static Future<void> _notReady(BuildContext context) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Payments not set up yet'),
      content: const Text(
        'Card and transfer payments start once GoRide adds its Paystack keys. Please try again later.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _WaitingDialog extends StatefulWidget {
  const _WaitingDialog({
    required this.reference,
    required this.amount,
    required this.url,
  });
  final String reference;
  final int amount;
  final Uri url;

  @override
  State<_WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<_WaitingDialog> {
  Timer? _timer;
  bool _checking = false;
  String? _note;
  final _started = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final res = await Backend.db.functions.invoke(
        'paystack',
        body: {'action': 'verify', 'reference': widget.reference},
      );
      final status = (res.data as Map)['status'];
      if (!mounted) return;
      if (status == 'success') {
        _timer?.cancel();
        Navigator.pop(context, true);
        return;
      }
      if (status == 'failed' || status == 'abandoned') {
        setState(() => _note = 'The payment was not completed. You can try again.');
      } else if (manual) {
        setState(() => _note = 'We have not received the payment yet.');
      }
    } catch (_) {
      if (manual && mounted) {
        setState(() => _note = 'Could not check right now. Try again.');
      }
    } finally {
      _checking = false;
    }
    // Stop polling after 15 minutes.
    if (DateTime.now().difference(_started) > const Duration(minutes: 15)) {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pay ${naira(widget.amount)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 18),
          const Text(
            'Finish the payment on the Paystack page. This updates by itself once Paystack confirms it.',
            textAlign: TextAlign.center,
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              _note!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          TextButton(
            onPressed: () => launchUrl(
              widget.url,
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            ),
            child: const Text('Open Paystack again'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _check(manual: true),
          child: const Text('I have paid'),
        ),
      ],
    );
  }
}
