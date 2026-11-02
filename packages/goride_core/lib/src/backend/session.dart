import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ride_types.dart';
import 'backend.dart';

/// The signed-in user's id, kept in sync with Supabase auth.
/// Controllers watch this so they reload on sign-in and clear on sign-out.
class UserIdController extends Notifier<String?> {
  StreamSubscription? _sub;

  @override
  String? build() {
    if (!Backend.ready) return null;
    _sub = Backend.auth.onAuthStateChange.listen((e) {
      final id = e.session?.user.id;
      if (id != state) state = id;
    });
    ref.onDispose(() => _sub?.cancel());
    return Backend.user?.id;
  }
}

final userIdProvider = NotifierProvider<UserIdController, String?>(
  UserIdController.new,
);

/// Loads current prices from the database (the admin can change them).
/// Keeps the built-in prices if offline.
Future<void> loadRideTypes() async {
  try {
    final rows = await Backend.db
        .from('ride_types')
        .select()
        .eq('active', true)
        .order('sort');
    if (rows.isEmpty) return;
    rideTypes = [
      for (final r in rows)
        RideType(
          id: r['id'] as String,
          name: r['name'] as String,
          kind: VehicleKind.values.byName(r['kind'] as String),
          passengers: r['passengers'] as int,
          baseFare: (r['base_fare'] as num).toDouble(),
          perKm: (r['per_km'] as num).toDouble(),
          perMinute: (r['per_minute'] as num).toDouble(),
          minimumFare: (r['minimum_fare'] as num).toDouble(),
          etaMinutes: _eta(r['id'] as String),
          description: (r['description'] as String?) ?? '',
        ),
    ];
  } catch (_) {}
}

(int, int) _eta(String id) => switch (id) {
  'bike' => (2, 4),
  'keke' => (3, 5),
  'car' => (3, 6),
  'comfort' => (4, 7),
  _ => (5, 9),
};

/// Parses a Postgres timestamp into local time.
DateTime? parseTime(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String)?.toLocal();
