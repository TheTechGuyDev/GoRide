import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/payment_gateway.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_button.dart';
import '../booking/payment_methods.dart';

final paymentGatewayProvider = Provider<PaymentGateway>(
  (_) => SimulatedPaystack(),
);

class _MethodOption {
  const _MethodOption(
    this.method,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
  );
  final TopUpMethod method;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _options = [
  _MethodOption(
    TopUpMethod.savedCard,
    'Mastercard',
    '•••• •••• •••• 4679',
    Icons.credit_card,
    Color(0xFF1A237E),
  ),
  _MethodOption(
    TopUpMethod.newCard,
    'New debit card',
    'Verve, Mastercard or Visa via Paystack',
    Icons.add_card,
    Color(0xFF00897B),
  ),
  _MethodOption(
    TopUpMethod.transfer,
    'Bank Transfer',
    'Send to a one-time account number',
    Icons.account_balance,
    Color(0xFF6A1B9A),
  ),
  _MethodOption(
    TopUpMethod.ussd,
    'USSD',
    'Pay with your bank\'s USSD code, no data needed',
    Icons.dialpad,
    Color(0xFFEF6C00),
  ),
];

/// Screen 65: choose how to pay, then Paystack checkout.
class TopUpMethodScreen extends ConsumerStatefulWidget {
  const TopUpMethodScreen({super.key, required this.amount});

  final int amount;

  @override
  ConsumerState<TopUpMethodScreen> createState() => _TopUpMethodScreenState();
}

class _TopUpMethodScreenState extends ConsumerState<TopUpMethodScreen> {
  TopUpMethod _method = TopUpMethod.savedCard;
  bool _busy = false;

  String get _methodLabel => switch (_method) {
    TopUpMethod.savedCard => 'Mastercard •••• 4679',
    TopUpMethod.newCard => 'Debit card',
    TopUpMethod.transfer => 'Bank Transfer',
    TopUpMethod.ussd => 'USSD',
  };

  Future<void> _confirm() async {
    final gateway = ref.read(paymentGatewayProvider);
    TopUpResult? result;

    switch (_method) {
      case TopUpMethod.savedCard:
        setState(() => _busy = true);
        result = await gateway.chargeCard(
          amount: widget.amount,
          savedCardId: 'card-4679',
        );
      case TopUpMethod.newCard:
        result = await showModalBottomSheet<TopUpResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) =>
              _CardCheckout(amount: widget.amount, gateway: gateway),
        );
      case TopUpMethod.transfer:
        result = await showModalBottomSheet<TopUpResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) =>
              _TransferCheckout(amount: widget.amount, gateway: gateway),
        );
      case TopUpMethod.ussd:
        result = await showModalBottomSheet<TopUpResult>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) =>
              _UssdCheckout(amount: widget.amount, gateway: gateway),
        );
    }

    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null || !result.success) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Payment failed')),
        );
      }
      return;
    }

    ref
        .read(walletBalanceProvider.notifier)
        .credit(
          widget.amount,
          method: _methodLabel,
          reference: result.reference,
        );
    await _showSuccess();
    if (mounted) {
      // Back to wherever top up was opened from.
      context.pop();
      context.pop();
    }
  }

  Future<void> _showSuccess() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 22),
              const Text(
                'Top Up Successful!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'You\'ve successfully added ${naira(widget.amount)} to your GoRide Wallet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'OK', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Top Up Method')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final o in _options) ...[
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _method == o.method
                      ? AppColors.primary
                      : AppColors.border,
                  width: _method == o.method ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _busy ? null : () => setState(() => _method = o.method),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: o.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(o.icon, color: o.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              o.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_method == o.method)
                        const Icon(Icons.check, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 14, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Secured by Paystack · Test mode',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AppButton(
            label: 'Confirm Top Up · ${naira(widget.amount)}',
            loading: _busy,
            onPressed: _confirm,
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.amount, required this.title});
  final int amount;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF011B33),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'paystack',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'TEST MODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
            const Spacer(),
            Text(
              naira(amount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CardCheckout extends StatefulWidget {
  const _CardCheckout({required this.amount, required this.gateway});
  final int amount;
  final PaymentGateway gateway;

  @override
  State<_CardCheckout> createState() => _CardCheckoutState();
}

class _CardCheckoutState extends State<_CardCheckout> {
  // Paystack's official test card.
  final _number = TextEditingController(text: '4084 0840 8408 4081');
  final _expiry = TextEditingController(text: '12/30');
  final _cvv = TextEditingController(text: '408');
  bool _busy = false;

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(amount: widget.amount, title: 'Pay with card'),
          const SizedBox(height: 16),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Card number',
              prefixIcon: Icon(Icons.credit_card),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiry,
                  decoration: const InputDecoration(hintText: 'MM/YY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvv,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'CVV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Test card pre-filled. No real money moves in test mode.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Pay ${naira(widget.amount)}',
            loading: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              final r = await widget.gateway.chargeCard(amount: widget.amount);
              if (context.mounted) Navigator.pop(context, r);
            },
          ),
        ],
      ),
    );
  }
}

class _TransferCheckout extends StatefulWidget {
  const _TransferCheckout({required this.amount, required this.gateway});
  final int amount;
  final PaymentGateway gateway;

  @override
  State<_TransferCheckout> createState() => _TransferCheckoutState();
}

class _TransferCheckoutState extends State<_TransferCheckout> {
  TransferAccount? _account;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    widget.gateway
        .transferAccountFor(amount: widget.amount)
        .then((a) => mounted ? setState(() => _account = a) : null);
  }

  @override
  Widget build(BuildContext context) {
    final a = _account;
    Widget line(String label, String value, {bool copy = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (copy)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$value copied')));
              },
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(amount: widget.amount, title: 'Pay with bank transfer'),
          const SizedBox(height: 12),
          if (a == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  line('Bank', a.bank),
                  line('Account number', a.accountNumber, copy: true),
                  line('Account name', a.accountName),
                  line('Amount', naira(widget.amount), copy: true),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This account number is for this payment only and expires in 30 minutes.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: _confirming
                  ? 'Confirming your transfer...'
                  : 'I\'ve sent the money',
              loading: _confirming,
              onPressed: () async {
                setState(() => _confirming = true);
                final r = await widget.gateway.confirmTransfer(
                  amount: widget.amount,
                );
                if (context.mounted) Navigator.pop(context, r);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _UssdCheckout extends StatefulWidget {
  const _UssdCheckout({required this.amount, required this.gateway});
  final int amount;
  final PaymentGateway gateway;

  @override
  State<_UssdCheckout> createState() => _UssdCheckoutState();
}

class _UssdCheckoutState extends State<_UssdCheckout> {
  static const _banks = [
    ('GTBank', '737'),
    ('Access Bank', '901'),
    ('Zenith Bank', '966'),
    ('UBA', '919'),
    ('First Bank', '894'),
  ];
  int _bank = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.gateway.ussdCodeFor(
      bankCode: _banks[_bank].$2,
      amount: widget.amount,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(amount: widget.amount, title: 'Pay with USSD'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _banks.length; i++)
                ChoiceChip(
                  label: Text(_banks[i].$1),
                  selected: _bank == i,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (_) => setState(() => _bank = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text(
                  'Dial this code on the phone linked to your bank account',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'I\'ve completed the payment',
            loading: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              final r = await widget.gateway.confirmTransfer(
                amount: widget.amount,
              );
              if (context.mounted) Navigator.pop(context, r);
            },
          ),
        ],
      ),
    );
  }
}
