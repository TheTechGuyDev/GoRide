import 'dart:math';

/// How the rider funds their wallet.
enum TopUpMethod { savedCard, newCard, transfer, ussd }

class TopUpResult {
  const TopUpResult({required this.success, this.reference, this.message});
  final bool success;
  final String? reference;
  final String? message;
}

class TransferAccount {
  const TransferAccount({
    required this.bank,
    required this.accountNumber,
    required this.accountName,
  });
  final String bank;
  final String accountNumber;
  final String accountName;
}

/// Payment provider for wallet top-ups.
///
/// The live version uses Paystack (free to sign up; you only pay a small fee
/// per successful payment, no monthly cost):
///  1. App asks a Supabase Edge Function to initialise the transaction
///     (the Paystack SECRET key lives only on the server).
///  2. App opens Paystack checkout (cards, bank transfer, USSD).
///  3. Paystack calls our webhook; the server verifies and credits the wallet.
/// Until the Paystack test keys are added, [SimulatedPaystack] stands in.
abstract class PaymentGateway {
  bool get isTestMode;
  Future<TopUpResult> chargeCard({required int amount, String? savedCardId});
  Future<TransferAccount> transferAccountFor({required int amount});
  Future<TopUpResult> confirmTransfer({required int amount});
  String ussdCodeFor({required String bankCode, required int amount});
}

class SimulatedPaystack implements PaymentGateway {
  final _rand = Random();

  String _ref() =>
      'PSK_TEST_${DateTime.now().millisecondsSinceEpoch % 100000000}';

  @override
  bool get isTestMode => true;

  @override
  Future<TopUpResult> chargeCard({
    required int amount,
    String? savedCardId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1800));
    return TopUpResult(success: true, reference: _ref());
  }

  @override
  Future<TransferAccount> transferAccountFor({required int amount}) async {
    await Future.delayed(const Duration(milliseconds: 900));
    return TransferAccount(
      bank: 'Wema Bank (Test)',
      accountNumber: '78${10000000 + _rand.nextInt(89999999)}',
      accountName: 'GoRide Wallet Funding',
    );
  }

  @override
  Future<TopUpResult> confirmTransfer({required int amount}) async {
    await Future.delayed(const Duration(seconds: 3));
    return TopUpResult(success: true, reference: _ref());
  }

  @override
  String ussdCodeFor({required String bankCode, required int amount}) =>
      '*$bankCode*000*$amount#';
}
