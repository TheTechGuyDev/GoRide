import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

/// Whether the code screen was reached from sign up or sign in.
enum AuthFlow { signUp, signIn }

class RiderProfile {
  const RiderProfile({
    this.phone = '',
    this.fullName = '',
    this.email = '',
    this.gender,
    this.dateOfBirth,
    this.photo,
    this.avatarUrl,
  });

  final String phone; // E.164, e.g. +2348012345678
  final String fullName;
  final String email;
  final String? gender;
  final DateTime? dateOfBirth;
  final Uint8List? photo;
  final String? avatarUrl;

  /// Name and phone are required before booking.
  bool get complete => fullName.trim().isNotEmpty && phone.isNotEmpty;

  RiderProfile copyWith({
    String? phone,
    String? fullName,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    Uint8List? photo,
    String? avatarUrl,
  }) {
    return RiderProfile(
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      photo: photo ?? this.photo,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory RiderProfile.fromRow(Map<String, dynamic> r) => RiderProfile(
    phone: (r['phone'] as String?) ?? '',
    fullName: (r['full_name'] as String?) ?? '',
    email: (r['email'] as String?) ?? '',
    gender: r['gender'] as String?,
    dateOfBirth: r['date_of_birth'] == null
        ? null
        : DateTime.tryParse(r['date_of_birth'] as String),
    avatarUrl: r['avatar_url'] as String?,
  );
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

/// Real sign-in with Supabase: email code or Google.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  /// Sends the 6-digit code. Sign in fails if the email has no account.
  Future<void> requestOtp({
    required String email,
    required AuthFlow flow,
    bool rememberMe = true,
  }) async {
    await AuthService.sendCode(
      email,
      createUser: flow == AuthFlow.signUp,
      data: const {'role': 'rider'},
    );
    state = state.copyWith(
      flow: flow,
      rememberMe: rememberMe,
      profile: state.profile.copyWith(email: email.trim().toLowerCase()),
    );
  }

  /// Returns an error message, or null when the code is right.
  Future<String?> verifyOtp(String code) async {
    try {
      await AuthService.verifyCode(state.profile.email, code);
      await loadProfile();
      return null;
    } catch (e) {
      return AuthService.message(e);
    }
  }

  Future<void> signInWithGoogle() =>
      AuthService.google(mobileScheme: 'goride');

  /// Loads the signed-in rider's profile. Returns false if not signed in.
  Future<bool> loadProfile() async {
    final user = Backend.user;
    if (user == null) return false;
    final row = await Backend.db
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final profile = row == null
        ? RiderProfile(email: user.email ?? '')
        : RiderProfile.fromRow(row).copyWith(email: user.email);
    state = state.copyWith(profile: profile, isSignedIn: profile.complete);
    return true;
  }

  /// Saves name, phone (first time only), gender, birthday and photo.
  Future<void> saveProfile(RiderProfile p) async {
    final user = Backend.user;
    if (user == null) throw const AuthException('Please sign in again.');
    String? avatarUrl = p.avatarUrl;
    if (p.photo != null && p.photo != state.profile.photo) {
      final path = '${user.id}/avatar.jpg';
      await Backend.db.storage
          .from('avatars')
          .uploadBinary(
            path,
            p.photo!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      avatarUrl =
          '${Backend.db.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    }
    final update = <String, dynamic>{
      'full_name': p.fullName.trim(),
      'gender': p.gender,
      'date_of_birth': p.dateOfBirth?.toIso8601String().substring(0, 10),
      'avatar_url': avatarUrl,
    };
    if (state.profile.phone.isEmpty && p.phone.isNotEmpty) {
      update['phone'] = p.phone;
    }
    await Backend.db.from('profiles').update(update).eq('id', user.id);
    state = state.copyWith(
      profile: p.copyWith(avatarUrl: avatarUrl),
      isSignedIn: true,
    );
  }

  void completeSignIn() => state = state.copyWith(isSignedIn: true);

  Future<void> signOut() async {
    await AuthService.signOut();
    state = const AuthState();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
