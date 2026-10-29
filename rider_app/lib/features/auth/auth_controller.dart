import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the OTP screen was reached from sign up or sign in.
enum AuthFlow { signUp, signIn }

class RiderProfile {
  const RiderProfile({
    this.phone = '',
    this.fullName = '',
    this.email = '',
    this.gender,
    this.dateOfBirth,
    this.photo,
  });

  final String phone; // E.164, e.g. +2348012345678
  final String fullName;
  final String email;
  final String? gender;
  final DateTime? dateOfBirth;
  final Uint8List? photo;

  RiderProfile copyWith({
    String? phone,
    String? fullName,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    Uint8List? photo,
  }) {
    return RiderProfile(
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photo: photo ?? this.photo,
    );
  }
}

class AuthState {
  const AuthState({
    this.profile = const RiderProfile(),
    this.flow = AuthFlow.signUp,
    this.isSignedIn = false,
    this.rememberMe = true,
  });

  final RiderProfile profile;
  final AuthFlow flow;
  final bool isSignedIn;
  final bool rememberMe;

  AuthState copyWith({
    RiderProfile? profile,
    AuthFlow? flow,
    bool? isSignedIn,
    bool? rememberMe,
  }) {
    return AuthState(
      profile: profile ?? this.profile,
      flow: flow ?? this.flow,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }
}

/// Mock auth. Every method here is where a Supabase call goes later:
/// - requestOtp  -> supabase.auth.signInWithOtp(phone: ...)
/// - verifyOtp   -> supabase.auth.verifyOTP(...)
/// - saveProfile -> insert into `riders` table
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> requestOtp({
    required String phone,
    required AuthFlow flow,
    bool rememberMe = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(
      flow: flow,
      rememberMe: rememberMe,
      profile: state.profile.copyWith(phone: phone),
    );
  }

  /// Preview mode: any 4-digit code is accepted.
  Future<bool> verifyOtp(String code) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return code.length == 4;
  }

  Future<void> saveProfile(RiderProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(profile: profile, isSignedIn: true);
  }

  void completeSignIn() {
    state = state.copyWith(isSignedIn: true);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
