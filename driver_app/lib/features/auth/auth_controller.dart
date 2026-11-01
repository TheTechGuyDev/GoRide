import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';

/// Whether the OTP screen was reached from sign up or sign in.
enum AuthFlow { signUp, signIn }

class AuthState {
  const AuthState({
    this.phone = '',
    this.flow = AuthFlow.signUp,
    this.isSignedIn = false,
  });

  /// E.164, e.g. +2348012345678
  final String phone;
  final AuthFlow flow;
  final bool isSignedIn;

  AuthState copyWith({String? phone, AuthFlow? flow, bool? isSignedIn}) {
    return AuthState(
      phone: phone ?? this.phone,
      flow: flow ?? this.flow,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
  }
}

/// Mock auth. Supabase later:
/// - requestOtp -> supabase.auth.signInWithOtp(phone: ...)
/// - verifyOtp  -> supabase.auth.verifyOTP(...)
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> requestOtp({
    required String phone,
    required AuthFlow flow,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(phone: phone, flow: flow);
  }

  /// Preview mode: any 4-digit code is accepted.
  Future<bool> verifyOtp(String code) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (code.length != 4) return false;
    state = state.copyWith(isSignedIn: true);
    if (state.flow == AuthFlow.signIn) {
      // Preview: signing in loads an approved demo driver.
      ref.read(registrationProvider.notifier).loadDemoDriver(state.phone);
      ref.read(earningsProvider.notifier).seedDemo();
    } else {
      ref.read(registrationProvider.notifier).startFresh(state.phone);
      ref.read(earningsProvider.notifier).reset();
    }
    return true;
  }

  void signOut() => state = const AuthState();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
