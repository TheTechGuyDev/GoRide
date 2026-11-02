import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import '../../core/router/routes.dart';
import '../earnings/earnings_controller.dart';
import '../registration/registration_controller.dart';

/// Whether the code screen was reached from sign up or sign in.
enum AuthFlow { signUp, signIn }

class AuthState {
  const AuthState({
    this.email = '',
    this.flow = AuthFlow.signUp,
    this.isSignedIn = false,
  });

  final String email;
  final AuthFlow flow;
  final bool isSignedIn;

  AuthState copyWith({String? email, AuthFlow? flow, bool? isSignedIn}) {
    return AuthState(
      email: email ?? this.email,
      flow: flow ?? this.flow,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
  }
}

/// Real sign-in with Supabase: email code or Google.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> requestOtp({
    required String email,
    required AuthFlow flow,
  }) async {
    await AuthService.sendCode(
      email,
      createUser: flow == AuthFlow.signUp,
      data: const {'role': 'driver'},
    );
    state = state.copyWith(email: email.trim().toLowerCase(), flow: flow);
  }

  /// Returns an error message, or null when the code is right.
  Future<String?> verifyOtp(String code) async {
    try {
      await AuthService.verifyCode(state.email, code);
      return null;
    } catch (e) {
      return AuthService.message(e);
    }
  }

  Future<void> signInWithGoogle() =>
      AuthService.google(mobileScheme: 'goridedriver');

  /// After sign-in (or on app start with a saved session): makes sure the
  /// driver record exists and returns where to go next, or null if signed out.
  Future<String?> enter() async {
    final user = Backend.user;
    if (user == null) return null;
    final d = await Backend.db.rpc('become_driver') as Map<String, dynamic>;
    final p = await Backend.db
        .from('profiles')
        .select('phone')
        .eq('id', user.id)
        .single();
    final contact = (p['phone'] as String?) ?? user.email ?? '';
    state = state.copyWith(email: user.email, isSignedIn: true);

    // Trips, earnings and registration still run on preview data until the
    // driver app is connected in the next step.
    if (d['status'] == 'approved') {
      ref.read(registrationProvider.notifier).loadDemoDriver(contact);
      ref.read(earningsProvider.notifier).seedDemo();
      return Routes.home;
    }
    ref.read(registrationProvider.notifier).startFresh(contact);
    ref.read(earningsProvider.notifier).reset();
    return Routes.registration;
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    state = const AuthState();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
