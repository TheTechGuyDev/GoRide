import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The one Supabase project shared by the rider app, driver app and admin.
/// The publishable key is safe to ship in apps; security comes from the
/// row level security rules in supabase/migrations.
class Backend {
  Backend._();

  static const url = 'https://xucckoofhmbyrnvvbxii.supabase.co';
  static const publishableKey = 'sb_publishable_OZHdPcTqdJNxvp-6XsKmiw_EWCd1a07';

  static bool _ready = false;
  static bool get ready => _ready;

  static Future<void> init() async {
    if (_ready) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _ready = true;
  }

  static SupabaseClient get db => Supabase.instance.client;
  static GoTrueClient get auth => db.auth;
  static User? get user => _ready ? auth.currentUser : null;
  static bool get signedIn => user != null;

  /// Where Google sends the user back to after signing in.
  /// Web: the page the app is running on. Phones: the app's deep link.
  static String redirectUrl({required String mobileScheme}) {
    if (kIsWeb) return '${Uri.base.origin}${Uri.base.path}';
    return '$mobileScheme://login-callback';
  }
}

/// Email-code and Google sign-in, shared by both apps.
class AuthService {
  AuthService._();

  /// Sends a 6-digit code. [createUser] false makes sign-in fail for unknown emails.
  static Future<void> sendCode(
    String email, {
    required bool createUser,
    Map<String, dynamic>? data,
  }) => Backend.auth.signInWithOtp(
    email: email.trim().toLowerCase(),
    shouldCreateUser: createUser,
    data: data,
  );

  static Future<User> verifyCode(String email, String code) async {
    final res = await Backend.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code,
      type: OtpType.email,
    );
    final user = res.user;
    if (user == null) throw const AuthException('That code did not work. Try again.');
    return user;
  }

  /// Opens Google. On web the page reloads signed in; the app picks the
  /// session up on start.
  static Future<void> google({required String mobileScheme}) =>
      Backend.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Backend.redirectUrl(mobileScheme: mobileScheme),
      );

  static Future<void> signOut() => Backend.auth.signOut();

  /// Plain-language message for any sign-in or database error.
  static String message(Object e) {
    final raw = switch (e) {
      AuthException(:final message) => message,
      PostgrestException(:final message) => message,
      _ => e.toString(),
    };
    final m = raw.toLowerCase();
    if (m.contains('signups not allowed') || m.contains('user not found')) {
      return 'No account uses this email yet. Sign up first.';
    }
    if (m.contains('expired') || m.contains('invalid') && m.contains('token')) {
      return 'That code is wrong or has expired. Request a new one.';
    }
    if (m.contains('rate limit') || m.contains('only request this after')) {
      return 'Please wait a minute before asking for another code.';
    }
    if (m.contains('profiles_phone_key') || m.contains('duplicate key') && m.contains('phone')) {
      return 'This phone number is already linked to another account.';
    }
    if (m.contains('failed host lookup') || m.contains('socketexception') || m.contains('failed to fetch')) {
      return 'No internet connection. Check your network and try again.';
    }
    return raw;
  }
}
