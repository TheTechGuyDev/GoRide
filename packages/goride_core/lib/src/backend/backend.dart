import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session.dart';

/// The one Supabase project shared by the rider app, driver app and admin.
/// The publishable key is safe to ship in apps; security comes from the
/// row level security rules in supabase/migrations.
class Backend {
  Backend._();

  static const url = 'https://xucckoofhmbyrnvvbxii.supabase.co';
  static const publishableKey =
      'sb_publishable_OZHdPcTqdJNxvp-6XsKmiw_EWCd1a07';

  static bool _ready = false;
  static bool get ready => _ready;

  /// [sessionKey] keeps each app's sign-in separate. All three web apps
  /// live on the same website, so without it signing in or out of one app
  /// (in another tab) would replace the session of the others.
  static Future<void> init({String? sessionKey}) async {
    if (_ready) return;
    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: sessionKey == null
            ? null
            : SharedPreferencesLocalStorage(persistSessionKey: sessionKey),
      ),
    );
    _ready = true;
    await Future.wait([loadRideTypes(), loadConfig()]);
  }

  static SupabaseClient get db => Supabase.instance.client;

  /// Public settings from the admin dashboard > Integrations
  /// (e.g. Paystack public key, map style). Never contains secrets.
  static Map<String, String> config = const {};

  static Future<void> loadConfig() async {
    try {
      final j = await db.rpc('public_config');
      config = {
        for (final e in (j as Map).entries)
          if (e.value != null) e.key as String: e.value.toString(),
      };
    } catch (_) {}
  }

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

/// Every `trips` column apps may read (the PIN is private to the rider).
const tripColumns =
    'id, code, rider_id, driver_id, ride_type_id, status, pickup_address, '
    'pickup_lat, pickup_lng, dropoff_address, dropoff_lat, dropoff_lng, stops, '
    'distance_km, duration_min, surge, fare, discount, promo_code, waiting_fee, '
    'total_fare, commission, driver_earning, payment, scheduled_for, '
    'requested_at, accepted_at, arrived_at, started_at, completed_at, '
    'cancelled_at, cancelled_by, cancel_reason, refunded';

/// Email-code and Google sign-in, shared by both apps.
class AuthService {
  AuthService._();

  /// Login protection on the server: account lockout after 5 wrong codes
  /// and limits per network. Throws a friendly message when blocked.
  static Future<void> _guard(String action, String email, {bool? ok}) async {
    Map<String, dynamic>? res;
    try {
      final r = await Backend.db.functions.invoke(
        'auth-guard',
        body: {'action': action, 'email': email, 'ok': ?ok},
      );
      res = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
    } catch (_) {
      return; // if the guard is unreachable, Supabase's own limits still apply
    }
    if (res != null && res['ok'] == false) {
      throw AuthException(res['message']?.toString() ?? 'Please try later.');
    }
  }

  /// Sends a 6-digit code. [createUser] false makes sign-in fail for unknown emails.
  static Future<void> sendCode(
    String email, {
    required bool createUser,
    Map<String, dynamic>? data,
  }) async {
    final e = email.trim().toLowerCase();
    await _guard('can_send', e);
    await Backend.auth.signInWithOtp(
      email: e,
      shouldCreateUser: createUser,
      data: data,
    );
    _guard('sent', e);
  }

  static Future<User> verifyCode(String email, String code) async {
    final e = email.trim().toLowerCase();
    await _guard('can_verify', e);
    try {
      final res = await Backend.auth.verifyOTP(
        email: e,
        token: code,
        type: OtpType.email,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('That code did not work. Try again.');
      }
      _guard('record', e, ok: true);
      return user;
    } on AuthException {
      await _guard('record', e, ok: false);
      rethrow;
    }
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
    if (m.contains('profiles_phone_key') ||
        m.contains('duplicate key') && m.contains('phone')) {
      return 'This phone number is already linked to another account.';
    }
    if (m.contains('failed host lookup') ||
        m.contains('socketexception') ||
        m.contains('failed to fetch')) {
      return 'No internet connection. Check your network and try again.';
    }
    return raw;
  }
}
