import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'remote.dart';

/// Everything the dashboard shows. Mock data now; once Supabase is added
/// each list is a table (drivers, riders, trips, payouts, sos_events,
/// support_tickets, promos, broadcasts, staff, audit_log, app_settings)
/// read with row-level security for staff roles.
class AdminData {
  const AdminData({
    required this.drivers,
    required this.riders,
    required this.trips,
    required this.payouts,
    required this.subscriptions,
    required this.safety,
    required this.tickets,
    required this.promos,
    required this.broadcasts,
    required this.staff,
    required this.audit,
    required this.pricing,
    required this.planPrices,
    required this.channels,
    required this.settings,
  });

  final List<Driver> drivers;
  final List<Rider> riders;
  final List<Trip> trips;
  final List<Payout> payouts;
  final List<SubscriptionPayment> subscriptions;
  final List<SafetyEvent> safety;
  final List<Ticket> tickets;
  final List<Promo> promos;
  final List<Broadcast> broadcasts;
  final List<StaffMember> staff;
  final List<AuditEntry> audit;
  final List<RidePricing> pricing;
  final List<PlanPrice> planPrices;
  final List<AlertChannel> channels;
  final AppSettings settings;

  Driver? driver(String id) {
    for (final d in drivers) {
      if (d.id == id) return d;
    }
    return null;
  }

  Rider? rider(String id) {
    for (final r in riders) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Trip> tripsOn(DateTime day) => trips
      .where(
        (t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day,
      )
      .toList();

  List<Driver> get pendingDrivers =>
      drivers.where((d) => d.status == DriverStatus.pending).toList();

  int get openSafety =>
      safety.where((s) => s.status != SafetyStatus.resolved).length;

  int get openTickets =>
      tickets.where((t) => t.status == TicketStatus.open).length;

  int get pendingPayouts =>
      payouts.where((p) => p.status == PayoutStatus.pending).length;

  AdminData copyWith({
    List<Driver>? drivers,
    List<Rider>? riders,
    List<Trip>? trips,
    List<Payout>? payouts,
    List<SafetyEvent>? safety,
    List<Ticket>? tickets,
    List<Promo>? promos,
    List<Broadcast>? broadcasts,
    List<StaffMember>? staff,
    List<AuditEntry>? audit,
    List<RidePricing>? pricing,
    List<PlanPrice>? planPrices,
    List<AlertChannel>? channels,
    AppSettings? settings,
  }) {
    return AdminData(
      drivers: drivers ?? this.drivers,
      riders: riders ?? this.riders,
      trips: trips ?? this.trips,
      payouts: payouts ?? this.payouts,
      subscriptions: subscriptions,
      safety: safety ?? this.safety,
      tickets: tickets ?? this.tickets,
      promos: promos ?? this.promos,
      broadcasts: broadcasts ?? this.broadcasts,
      staff: staff ?? this.staff,
      audit: audit ?? this.audit,
      pricing: pricing ?? this.pricing,
      planPrices: planPrices ?? this.planPrices,
      channels: channels ?? this.channels,
      settings: settings ?? this.settings,
    );
  }
}

/// The signed-in staff member. Staff sign in with an email code; access
/// comes from the `staff` table (or an invite in `staff_invites`).
class SessionController extends Notifier<StaffMember?> {
  @override
  StaffMember? build() {
    Future.microtask(restore);
    return null;
  }

  /// Re-opens the dashboard if a staff session is saved in the browser.
  Future<void> restore() async {
    if (Backend.user == null) return;
    try {
      await _claim();
    } catch (_) {}
  }

  /// After the email code is verified. Returns an error if not staff.
  Future<String?> enter() async {
    try {
      final me = await _claim();
      if (me == null) {
        await AuthService.signOut();
        return 'This email is not on the GoRide staff list. Ask a Super Admin to invite you.';
      }
      if (!me.active) {
        await AuthService.signOut();
        state = null;
        return 'Your staff access has been removed.';
      }
      return null;
    } catch (e) {
      return AuthService.message(e);
    }
  }

  Future<StaffMember?> _claim() async {
    final row = await Backend.db.rpc('claim_staff');
    if (row == null || (row as Map)['id'] == null) return null;
    final me = StaffMember(
      id: row['id'] as String,
      name: (row['full_name'] as String?) ?? row['email'] as String,
      email: row['email'] as String,
      role: roleFromDb(row['role'] as String),
      active: row['active'] == true,
      lastActive: DateTime.now(),
    );
    if (me.active) state = me;
    return me;
  }

  void signIn(StaffMember m) => state = m;

  Future<void> signOut() async {
    state = null;
    await AuthService.signOut();
  }
}

final sessionProvider = NotifierProvider<SessionController, StaffMember?>(
  SessionController.new,
);

/// Prices that differ by city (`city_rates`); other cities use the
/// default prices.
class CityRates {
  const CityRates({this.cities = const [], this.rates = const {}});
  final List<String> cities;

  /// city -> ride type id -> prices.
  final Map<String, Map<String, RidePricing>> rates;
}

class CityRatesController extends Notifier<CityRates> {
  @override
  CityRates build() => const CityRates();
  void set(CityRates v) => state = v;
}

final cityRatesProvider = NotifierProvider<CityRatesController, CityRates>(
  CityRatesController.new,
);

/// Which city the Pricing page is editing (null = default prices).
class PricingCityController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? c) => state = c;
}

final pricingCityProvider = NotifierProvider<PricingCityController, String?>(
  PricingCityController.new,
);

/// Last server error, shown as a message by the dashboard shell.
class StoreErrorController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? e) => state = e;
}

final storeErrorProvider = NotifierProvider<StoreErrorController, String?>(
  StoreErrorController.new,
);

class AdminStore extends Notifier<AdminData> {
  final _tripIds = <String, String>{};
  final _docTypes = <String, List<String>>{};
  RealtimeChannel? _channel;
  Timer? _debounce;
  Timer? _refresh;
  int onlineDrivers = 0;

  /// Real data from Supabase once a staff member is signed in.
  @override
  AdminData build() {
    final me = ref.watch(sessionProvider);
    ref.onDispose(() {
      _channel?.unsubscribe();
      _debounce?.cancel();
      _refresh?.cancel();
    });
    final seed = _seed();
    final empty = AdminData(
      drivers: const [],
      riders: const [],
      trips: const [],
      payouts: const [],
      subscriptions: const [],
      safety: const [],
      tickets: const [],
      promos: const [],
      broadcasts: const [],
      staff: const [],
      audit: const [],
      pricing: const [],
      planPrices: const [],
      channels: seed.channels,
      settings: seed.settings,
    );
    if (me == null) return empty;
    Future.microtask(load);
    // New trips, SOS alerts, applications and tickets appear by themselves.
    _channel = Backend.db.channel('admin-live');
    for (final table in [
      'trips',
      'safety_events',
      'drivers',
      'payouts',
      'support_tickets',
      'ticket_messages',
    ]) {
      _channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _soon(),
      );
    }
    _channel!.subscribe();
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => load());
    return empty;
  }

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), load);
  }

  Future<void> load() async {
    if (ref.read(sessionProvider) == null) return;
    try {
      final j = await Backend.db.rpc('admin_snapshot');
      final snap = parseSnapshot(Map<String, dynamic>.from(j as Map), state);
      _tripIds
        ..clear()
        ..addAll(snap.tripIds);
      _docTypes
        ..clear()
        ..addAll(snap.docTypes);
      onlineDrivers = snap.onlineCount;
      state = snap.data;
      final names = {for (final p in snap.data.pricing) p.id: p.name};
      final rates = <String, Map<String, RidePricing>>{};
      for (final r in (j['city_rates'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['ride_type_id'] as String;
        (rates[m['city'] as String] ??= {})[id] = RidePricing(
          id: id,
          name: names[id] ?? id,
          baseFare: (m['base_fare'] as num).toDouble(),
          perKm: (m['per_km'] as num).toDouble(),
          perMinute: (m['per_minute'] as num).toDouble(),
          minimumFare: (m['minimum_fare'] as num).toDouble(),
        );
      }
      ref
          .read(cityRatesProvider.notifier)
          .set(
            CityRates(
              cities: [
                for (final c in (j['cities'] as List? ?? const [])) c as String,
              ],
              rates: rates,
            ),
          );
    } catch (e) {
      ref.read(storeErrorProvider.notifier).set(AuthService.message(e));
    }
  }

  /// Runs a server change, then reloads so every page shows the truth.
  Future<void> _server(Future<dynamic> Function() call, {String? audit}) async {
    try {
      await call();
      if (audit != null) {
        await Backend.db.from('audit_log').insert({
          'staff_id': Backend.user!.id,
          'action': audit,
        });
      }
    } catch (e) {
      ref.read(storeErrorProvider.notifier).set(AuthService.message(e));
    }
    await load();
  }

  /// Short-lived link to a driver's uploaded document photo.
  Future<String?> docPhotoUrl(String driverId, int index) async {
    final type = _docTypes[driverId]?.elementAtOrNull(index);
    if (type == null) return null;
    try {
      return await Backend.db.storage
          .from('driver-docs')
          .createSignedUrl('$driverId/$type.jpg', 600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _rpc(String fn, Map<String, dynamic> params) =>
      _server(() => Backend.db.rpc(fn, params: params));

  String get _me => ref.read(sessionProvider)?.name ?? 'System';

  void _log(String action, {String category = 'General'}) {
    state = state.copyWith(
      audit: [
        AuditEntry(_me, action, DateTime.now(), category: category),
        ...state.audit,
      ],
    );
  }

  // ---- Drivers ----

  void _updateDriver(String id, Driver Function(Driver d) f) {
    state = state.copyWith(
      drivers: [for (final d in state.drivers) d.id == id ? f(d) : d],
    );
  }

  void setDocState(String driverId, int index, DocState s, {String? note}) {
    final d = state.driver(driverId);
    if (d == null) return;
    _updateDriver(driverId, (d) {
      final docs = [...d.docs];
      docs[index] = docs[index].copyWith(state: s, note: note);
      return d.copyWith(docs: docs);
    });
    _log(
      '${s == DocState.approved ? 'Approved' : 'Rejected'} ${d.docs[index].title} for ${d.name}${note == null ? '' : ': $note'}',
      category: 'Drivers',
    );
    final type = _docTypes[driverId]?.elementAtOrNull(index);
    if (type != null) {
      _rpc('admin_review_doc', {
        'p_driver': driverId,
        'p_type': type,
        'p_status': s == DocState.approved
            ? 'approved'
            : s == DocState.rejected
            ? 'rejected'
            : 'pending',
        'p_note': note,
      });
    }
  }

  void approveDriver(String id) {
    final d = state.driver(id);
    if (d == null) return;
    _updateDriver(
      id,
      (d) => d.copyWith(
        status: DriverStatus.active,
        joinedAt: DateTime.now(),
        docs: [for (final x in d.docs) x.copyWith(state: DocState.approved)],
      ),
    );
    _log('Approved driver ${d.name} (${d.plate})', category: 'Drivers');
    _rpc('approve_driver', {'p_driver': id});
  }

  void rejectDriver(String id, String reason) {
    final d = state.driver(id);
    if (d == null) return;
    _updateDriver(
      id,
      (d) => d.copyWith(status: DriverStatus.rejected, suspendReason: reason),
    );
    _log('Rejected application from ${d.name}: $reason', category: 'Drivers');
    _rpc('reject_driver', {'p_driver': id, 'p_note': reason});
  }

  void suspendDriver(String id, String reason) {
    final d = state.driver(id);
    if (d == null) return;
    _updateDriver(
      id,
      (d) => d.copyWith(
        status: DriverStatus.suspended,
        online: false,
        suspendReason: reason,
      ),
    );
    _log('Suspended driver ${d.name}: $reason', category: 'Drivers');
    _rpc('admin_set_driver_status', {
      'p_driver': id,
      'p_status': 'suspended',
      'p_note': reason,
    });
  }

  void reactivateDriver(String id) {
    final d = state.driver(id);
    if (d == null) return;
    _updateDriver(
      id,
      (d) => d.copyWith(status: DriverStatus.active, clearSuspend: true),
    );
    _log('Reactivated driver ${d.name}', category: 'Drivers');
    _rpc('admin_set_driver_status', {'p_driver': id, 'p_status': 'approved'});
  }

  // ---- Riders ----

  void setRiderBlocked(String id, bool blocked) {
    final r = state.rider(id);
    if (r == null) return;
    state = state.copyWith(
      riders: [
        for (final x in state.riders)
          x.id == id ? x.copyWith(blocked: blocked) : x,
      ],
    );
    _log(
      '${blocked ? 'Blocked' : 'Unblocked'} rider ${r.name}',
      category: 'Riders',
    );
    _rpc('admin_set_blocked', {'p_user': id, 'p_blocked': blocked});
  }

  void creditRider(String id, int amount, String reason) {
    final r = state.rider(id);
    if (r == null) return;
    state = state.copyWith(
      riders: [
        for (final x in state.riders)
          x.id == id ? x.copyWith(wallet: x.wallet + amount) : x,
      ],
    );
    _log('Credited ${naira(amount)} to ${r.name}: $reason', category: 'Riders');
    _rpc('adjust_wallet', {
      'p_user': id,
      'p_amount': amount,
      'p_title': reason,
    });
  }

  // ---- Trips ----

  void refundTrip(String tripId, int amount, String reason) {
    final trip = state.trips.where((t) => t.id == tripId).firstOrNull;
    if (trip == null) return;
    state = state.copyWith(
      trips: [
        for (final t in state.trips)
          t.id == tripId ? t.copyWith(refunded: t.refunded + amount) : t,
      ],
      riders: [
        for (final r in state.riders)
          r.id == trip.riderId ? r.copyWith(wallet: r.wallet + amount) : r,
      ],
    );
    _log(
      'Refunded ${naira(amount)} on trip $tripId to ${trip.riderName}: $reason',
      category: 'Trips',
    );
    final uuid = _tripIds[tripId];
    if (uuid != null) {
      _rpc('refund_trip', {
        'p_trip': uuid,
        'p_amount': amount,
        'p_reason': reason,
      });
    }
  }

  // ---- Payouts ----

  /// Finance has sent the money (bank app or Paystack); mark it paid.
  Future<void> retryPayout(String id) async {
    await _rpc('set_payout_status', {'p_payout': id, 'p_status': 'paid'});
  }

  Future<int> payAllPending() async {
    final pending = state.payouts
        .where((p) => p.status == PayoutStatus.pending)
        .toList();
    for (final p in pending) {
      try {
        await Backend.db.rpc(
          'set_payout_status',
          params: {'p_payout': p.id, 'p_status': 'paid'},
        );
      } catch (_) {}
    }
    await load();
    return pending.length;
  }

  Future<void> failPayout(String id, String reason) => _rpc(
    'set_payout_status',
    {'p_payout': id, 'p_status': 'failed', 'p_reason': reason},
  );

  // ---- Safety ----

  void updateSafety(String id, SafetyStatus status, {String? note}) {
    final e = state.safety.where((x) => x.id == id).firstOrNull;
    if (e == null) return;
    final hasNote = note != null && note.trim().isNotEmpty;
    state = state.copyWith(
      safety: [
        for (final s in state.safety)
          s.id == id
              ? s.copyWith(
                  status: status,
                  handledBy: _me,
                  notes: hasNote
                      ? [...s.notes, '$_me: ${note.trim()}']
                      : s.notes,
                )
              : s,
      ],
    );
    _log(
      '${status.label} ${e.kind.label} alert on trip ${e.tripId}${hasNote ? ': ${note.trim()}' : ''}',
      category: 'Safety',
    );
    _rpc('admin_update_safety', {
      'p_event': id,
      'p_status': switch (status) {
        SafetyStatus.acknowledged => 'in_progress',
        SafetyStatus.resolved => 'resolved',
        _ => 'open',
      },
      'p_note': hasNote ? '$_me: ${note.trim()}' : null,
    });
  }

  // ---- Support ----

  void replyTicket(String id, String text, {TicketStatus? status}) {
    state = state.copyWith(
      tickets: [
        for (final t in state.tickets)
          t.id == id
              ? t.copyWith(
                  status: status ?? TicketStatus.pending,
                  assignee: t.assignee ?? _me,
                  messages: [
                    ...t.messages,
                    if (text.trim().isNotEmpty)
                      TicketMessage(
                        text.trim(),
                        fromStaff: true,
                        time: DateTime.now(),
                        author: _me,
                      ),
                  ],
                )
              : t,
      ],
    );
    _log(
      'Replied to ticket $id${status == TicketStatus.resolved ? ' and resolved it' : ''}',
      category: 'Support',
    );
    _rpc('admin_reply_ticket', {
      'p_ticket': id,
      'p_text': text.trim(),
      'p_status': switch (status) {
        TicketStatus.resolved => 'resolved',
        TicketStatus.open => 'open',
        _ => 'in_progress',
      },
    });
  }

  void setTicketStatus(String id, TicketStatus s) {
    state = state.copyWith(
      tickets: [
        for (final t in state.tickets) t.id == id ? t.copyWith(status: s) : t,
      ],
    );
    _log('Marked ticket $id as ${s.label.toLowerCase()}', category: 'Support');
    _rpc('admin_reply_ticket', {
      'p_ticket': id,
      'p_text': null,
      'p_status': switch (s) {
        TicketStatus.resolved => 'resolved',
        TicketStatus.open => 'open',
        _ => 'in_progress',
      },
    });
  }

  // ---- Pricing & settings ----

  void savePricing(RidePricing p) {
    state = state.copyWith(
      pricing: [for (final x in state.pricing) x.id == p.id ? p : x],
    );
    _log(
      'Updated ${p.name} prices: base ${naira(p.baseFare)}, ${naira(p.perKm)}/km, ${naira(p.perMinute)}/min, min ${naira(p.minimumFare)}',
      category: 'Pricing',
    );
    _server(
      () => Backend.db
          .from('ride_types')
          .update({
            'base_fare': p.baseFare,
            'per_km': p.perKm,
            'per_minute': p.perMinute,
            'minimum_fare': p.minimumFare,
            'active': p.active,
          })
          .eq('id', p.id),
      audit: 'Updated ${p.name} prices',
    );
  }

  /// Prices for one city (overrides the default prices there).
  void saveCityPricing(String city, RidePricing p) {
    _server(
      () => Backend.db.from('city_rates').upsert({
        'city': city,
        'ride_type_id': p.id,
        'base_fare': p.baseFare,
        'per_km': p.perKm,
        'per_minute': p.perMinute,
        'minimum_fare': p.minimumFare,
      }),
      audit: 'Updated ${p.name} prices in $city',
    );
  }

  /// Back to the default prices in this city.
  void resetCityPricing(String city, String rideTypeId) {
    _server(
      () => Backend.db
          .from('city_rates')
          .delete()
          .eq('city', city)
          .eq('ride_type_id', rideTypeId),
      audit: 'Reset $rideTypeId prices in $city to default',
    );
  }

  void savePlanPrice(PlanPrice p) {
    state = state.copyWith(
      planPrices: [for (final x in state.planPrices) x.kind == p.kind ? p : x],
    );
    _log(
      'Updated ${p.kind} subscription: ${naira(p.daily)}/day, ${naira(p.weekly)}/week, ${naira(p.monthly)}/month',
      category: 'Pricing',
    );
    _server(
      () => Backend.db
          .from('plan_prices')
          .update({'daily': p.daily, 'weekly': p.weekly, 'monthly': p.monthly})
          .eq('kind', p.kind.toLowerCase()),
      audit: 'Updated ${p.kind} subscription prices',
    );
  }

  void saveSettings(AppSettings s, String what) {
    state = state.copyWith(settings: s);
    _log(what, category: 'Settings');
    _server(
      () => Backend.db
          .from('app_settings')
          .update({
            'commission_rate': s.commissionRate,
            'debt_limit': s.debtLimit,
            'waiting_fee_per_minute': s.waitingFeePerMin,
            'waiting_free_minutes': s.freeWaitMinutes,
            'no_show_fee': s.noShowFee,
            'off_route_meters': s.offRouteMetres,
            'sos_response_seconds': s.routeAlertTimeoutSeconds,
            'surge_enabled': s.surgeEnabled,
            'max_surge': s.maxSurge > 1.3 ? 1.3 : s.maxSurge,
            'min_payout': s.minPayout,
            'rider_referral_reward': s.referralRiderReward,
            'driver_referral_reward': s.referralDriverReward,
            'maintenance_mode': s.maintenanceMode,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1),
      audit: what,
    );
  }

  void toggleChannel(String id, bool enabled) {
    final c = state.channels.firstWhere((c) => c.id == id);
    state = state.copyWith(
      channels: [
        for (final x in state.channels)
          x.id == id ? x.copyWith(enabled: enabled) : x,
      ],
    );
    _log(
      '${enabled ? 'Enabled' : 'Disabled'} ${c.name} for emergency alerts',
      category: 'Settings',
    );
  }

  // ---- Promos & broadcasts ----

  void addPromo(Promo p) {
    state = state.copyWith(promos: [p, ...state.promos]);
    _log('Created promo ${p.code} (${p.offer})', category: 'Promos');
    if (!p.percent) {
      ref
          .read(storeErrorProvider.notifier)
          .set('Only percentage promos are supported for now.');
      return;
    }
    _server(
      () => Backend.db.from('promos').insert({
        'code': p.code.toUpperCase(),
        'title': p.description,
        'percent_off': p.value,
        'max_off': p.maxDiscount,
        'usage_limit': p.limit > 0 ? p.limit : null,
        'ends_at': p.expires.toUtc().toIso8601String(),
        'new_riders_only': p.newRidersOnly,
        'active': p.active,
      }),
      audit: 'Created promo ${p.code} (${p.offer})',
    );
  }

  void togglePromo(String code, bool active) {
    state = state.copyWith(
      promos: [
        for (final p in state.promos)
          p.code == code ? p.copyWith(active: active) : p,
      ],
    );
    _log('${active ? 'Activated' : 'Paused'} promo $code', category: 'Promos');
    _server(
      () =>
          Backend.db.from('promos').update({'active': active}).eq('code', code),
      audit: '${active ? 'Activated' : 'Paused'} promo $code',
    );
  }

  void sendBroadcast(String audience, String title, String body) {
    final reach = switch (audience) {
      'Riders' => state.riders.length,
      'Drivers' =>
        state.drivers.where((d) => d.status == DriverStatus.active).length,
      _ => state.riders.length + state.drivers.length,
    };
    state = state.copyWith(
      broadcasts: [
        Broadcast(
          id: 'B${DateTime.now().millisecondsSinceEpoch}',
          audience: audience,
          title: title,
          body: body,
          sentAt: DateTime.now(),
          reach: reach,
          sentBy: _me,
        ),
        ...state.broadcasts,
      ],
    );
    _log(
      'Sent notification "$title" to $audience ($reach people)',
      category: 'Notifications',
    );
    _rpc('send_broadcast', {
      'p_audience': audience.toLowerCase(),
      'p_title': title,
      'p_body': body,
    });
  }

  // ---- Staff ----

  void saveStaff(StaffMember m) {
    final exists = state.staff.any((s) => s.id == m.id);
    state = state.copyWith(
      staff: exists
          ? [for (final s in state.staff) s.id == m.id ? m : s]
          : [...state.staff, m],
    );
    _log(
      exists
          ? 'Changed ${m.name} to ${m.role.label}'
          : 'Invited ${m.name} (${m.email}) as ${m.role.label}',
      category: 'Staff',
    );
    if (exists) {
      _server(
        () => Backend.db
            .from('staff')
            .update({'full_name': m.name, 'role': roleToDb(m.role)})
            .eq('id', m.id),
        audit: 'Changed ${m.name} to ${m.role.label}',
      );
    } else {
      _server(
        () => Backend.db.from('staff_invites').upsert({
          'email': m.email.trim().toLowerCase(),
          'full_name': m.name,
          'role': roleToDb(m.role),
          'invited_by': Backend.user!.id,
        }),
        audit: 'Invited ${m.name} (${m.email}) as ${m.role.label}',
      );
    }
  }

  void setStaffActive(String id, bool active) {
    final m = state.staff.firstWhere((s) => s.id == id);
    state = state.copyWith(
      staff: [
        for (final s in state.staff)
          s.id == id ? s.copyWith(active: active) : s,
      ],
    );
    _log(
      '${active ? 'Restored' : 'Removed'} access for ${m.name}',
      category: 'Staff',
    );
    _server(
      () => Backend.db.from('staff').update({'active': active}).eq('id', id),
      audit: '${active ? 'Restored' : 'Removed'} access for ${m.name}',
    );
  }

  // ---------------- Seed ----------------

  static AdminData _seed() {
    final r = Random(42);
    final now = DateTime.now();
    T pick<T>(List<T> l) => l[r.nextInt(l.length)];

    const first = [
      'Tunde',
      'Chidi',
      'Emeka',
      'Ibrahim',
      'Segun',
      'Kunle',
      'Musa',
      'Femi',
      'Uche',
      'Yusuf',
      'Babatunde',
      'Obinna',
      'Sola',
      'Dayo',
      'Gbenga',
      'Ade',
      'Kelechi',
      'Sani',
      'Wale',
      'Ifeanyi',
      'Rotimi',
      'Bayo',
      'Nkechi',
      'Funke',
      'Aisha',
      'Bisi',
      'Amaka',
      'Halima',
    ];
    const last = [
      'Bakare',
      'Okafor',
      'Eze',
      'Musa',
      'Adeyemi',
      'Ogunleye',
      'Bello',
      'Nwosu',
      'Adebayo',
      'Okonkwo',
      'Lawal',
      'Ibrahim',
      'Balogun',
      'Onyeka',
      'Adeleke',
      'Danjuma',
      'Afolabi',
      'Chukwu',
      'Ojo',
      'Salami',
    ];
    const riderFirst = [
      'Adaeze',
      'Bola',
      'Chinedu',
      'Damilola',
      'Emeka',
      'Funmi',
      'Ibrahim',
      'Kemi',
      'Ngozi',
      'Segun',
      'Tolu',
      'Zainab',
      'Ruth',
      'David',
      'Grace',
      'Victor',
      'Esther',
      'Samuel',
      'Joy',
      'Daniel',
      'Blessing',
      'Peter',
      'Mary',
      'John',
      'Precious',
      'Michael',
      'Favour',
      'Joseph',
    ];
    const cars = [
      'Toyota Corolla',
      'Toyota Camry',
      'Honda Accord',
      'Hyundai Elantra',
      'Kia Rio',
      'Toyota Sienna',
      'Lexus RX 350',
      'Honda Civic',
      'Nissan Altima',
    ];
    const colours = ['Silver', 'Black', 'White', 'Grey', 'Blue', 'Red'];
    const banks = [
      'GTBank',
      'Access Bank',
      'Opay',
      'Kuda',
      'Zenith Bank',
      'UBA',
      'First Bank',
      'Moniepoint',
    ];
    const plateP = [
      'KJA',
      'LND',
      'AAA',
      'EKY',
      'FKJ',
      'GGE',
      'APP',
      'KRD',
      'SMK',
      'LSR',
    ];
    String plate() =>
        '${pick(plateP)} ${100 + r.nextInt(899)} ${String.fromCharCode(65 + r.nextInt(26))}${String.fromCharCode(65 + r.nextInt(26))}';
    String phone() =>
        '+234 80${r.nextInt(10)} ${100 + r.nextInt(899)} ${1000 + r.nextInt(8999)}';

    List<DocReview> docs({
      required bool approved,
      bool bike = false,
      int? pendingSeed,
    }) {
      DocReview d(String t, {bool exp = true, String no = ''}) {
        final expiry = exp
            ? now.add(Duration(days: 10 + r.nextInt(500)))
            : null;
        return DocReview(
          title: t,
          number: no,
          expiry: expiry,
          state: approved
              ? DocState.approved
              : (r.nextInt(5) == 0 ? DocState.approved : DocState.pending),
        );
      }

      return [
        d('Driver\'s licence', no: 'LAG${10000 + r.nextInt(89999)}AB'),
        d(
          'NIN slip or National ID',
          exp: false,
          no: '${20000000000 + r.nextInt(999999999)}',
        ),
        d('Vehicle licence'),
        d('Vehicle insurance', no: 'AXA-MT-${10000 + r.nextInt(89999)}'),
        d('Road worthiness certificate'),
        if (!bike) d('LASDRI card'),
        d('Vehicle photo', exp: false),
      ];
    }

    // Drivers
    final drivers = <Driver>[];
    for (var i = 0; i < 64; i++) {
      final name = '${first[i % first.length]} ${pick(last)}';
      final type = switch (r.nextInt(10)) {
        < 5 => 'car',
        < 7 => 'comfort',
        < 8 => 'xl',
        < 9 => 'keke',
        _ => 'bike',
      };
      final status = i < 7
          ? DriverStatus.pending
          : i < 9
          ? DriverStatus.rejected
          : i < 12
          ? DriverStatus.suspended
          : DriverStatus.active;
      final applied = now.subtract(
        Duration(
          days: i < 7 ? r.nextInt(3) : 20 + r.nextInt(300),
          hours: r.nextInt(20),
        ),
      );
      final vehicle = switch (type) {
        'keke' => 'Yellow Bajaj RE',
        'bike' => 'Red Bajaj Boxer',
        'xl' => '${pick(colours)} Toyota Sienna',
        _ => '${pick(colours)} ${pick(cars)}',
      };
      final sub = r.nextInt(3) == 0;
      drivers.add(
        Driver(
          id: 'DRV-${1001 + i}',
          name: name,
          phone: phone(),
          email: '${name.toLowerCase().replaceAll(' ', '.')}@gmail.com',
          city: r.nextInt(8) == 0 ? 'Abuja' : 'Lagos',
          rideTypeId: type,
          vehicle: vehicle,
          plate: plate(),
          status: status,
          docs: docs(
            approved:
                status == DriverStatus.active ||
                status == DriverStatus.suspended,
            bike: type == 'bike',
          ),
          subscription: sub,
          rating: status == DriverStatus.pending
              ? 0
              : 4.5 + r.nextInt(50) / 100,
          trips: status == DriverStatus.pending ? 0 : 20 + r.nextInt(1400),
          appliedAt: applied,
          joinedAt:
              status == DriverStatus.active || status == DriverStatus.suspended
              ? applied.add(Duration(days: 1 + r.nextInt(2)))
              : null,
          online: status == DriverStatus.active && r.nextInt(5) < 2,
          wallet: status == DriverStatus.pending ? 0 : -4000 + r.nextInt(30000),
          lastSeen: now.subtract(Duration(minutes: r.nextInt(3000))),
          paidUntil: sub && status == DriverStatus.active
              ? now.add(Duration(days: r.nextInt(9) - 1))
              : null,
          suspendReason: status == DriverStatus.suspended
              ? pick([
                  'Rating below 4.2',
                  'Rider complaint under review',
                  'Expired insurance',
                ])
              : status == DriverStatus.rejected
              ? 'Vehicle older than 2008'
              : null,
          nin: '${20000000000 + r.nextInt(999999999)}',
        ),
      );
    }
    // One driver with expiring insurance for the "expiring soon" view.
    final active = drivers
        .where((d) => d.status == DriverStatus.active)
        .toList();

    // Riders
    final riders = <Rider>[];
    for (var i = 0; i < 180; i++) {
      final name = '${pick(riderFirst)} ${pick(last)}';
      final trips = r.nextInt(120);
      riders.add(
        Rider(
          id: 'RDR-${5001 + i}',
          name: name,
          phone: phone(),
          email:
              '${name.toLowerCase().replaceAll(' ', '')}${r.nextInt(99)}@gmail.com',
          trips: trips,
          spent: trips * (1800 + r.nextInt(3500)),
          rating: 4.3 + r.nextInt(70) / 100,
          joinedAt: now.subtract(Duration(days: r.nextInt(240))),
          wallet: r.nextInt(4) == 0 ? 0 : r.nextInt(25000),
          blocked: i % 61 == 7,
          emergencyContacts: r.nextInt(4),
        ),
      );
    }

    // Pricing (same as the apps' defaults)
    final pricing = [
      for (final t in rideTypes)
        RidePricing(
          id: t.id,
          name: t.name,
          baseFare: t.baseFare,
          perKm: t.perKm,
          perMinute: t.perMinute,
          minimumFare: t.minimumFare,
        ),
    ];

    // Trips: last 45 days, growing over time.
    final trips = <Trip>[];
    var tripNo = 300000;
    for (var d = 45; d >= 0; d--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: d));
      final growth = 1 + (45 - d) / 30;
      final weekend = day.weekday >= 6 ? 1.25 : 1.0;
      final count = (28 * growth * weekend + r.nextInt(12)).round();
      for (var i = 0; i < count; i++) {
        final at = day.add(Duration(minutes: 330 + r.nextInt(1080)));
        if (at.isAfter(now)) continue;
        final drv = pick(active);
        final rid = pick(riders);
        final from = pick(lagosPlaces);
        var to = pick(lagosPlaces);
        if (to == from)
          to =
              lagosPlaces[(lagosPlaces.indexOf(from) + 4) % lagosPlaces.length];
        final km = 2.5 + r.nextDouble() * 22;
        final mins = (km * 3 + r.nextInt(18)).round();
        final p = pricing.firstWhere((x) => x.id == drv.rideTypeId);
        final fare = roundFare(
          max(p.minimumFare, p.baseFare + p.perKm * km + p.perMinute * mins),
        );
        final roll = r.nextInt(100);
        final status = roll < 86
            ? TripStatus.completed
            : roll < 95
            ? TripStatus.riderCancelled
            : TripStatus.driverCancelled;
        final done = status == TripStatus.completed;
        trips.add(
          Trip(
            id: 'TRP-${tripNo++}',
            riderId: rid.id,
            riderName: rid.name,
            driverId: drv.id,
            driverName: drv.name,
            pickup: from.name,
            dropoff: to.name,
            rideTypeId: drv.rideTypeId,
            fare: done ? fare : 0,
            commission: done && !drv.subscription ? (fare * 0.10).round() : 0,
            payment: pick(['cash', 'cash', 'wallet', 'card']),
            status: status,
            date: at,
            km: double.parse(km.toStringAsFixed(1)),
            minutes: mins,
            rating: done ? (r.nextInt(10) == 0 ? 4 : 5) : null,
            routeAlert: done && r.nextInt(40) == 0,
          ),
        );
      }
    }
    trips.sort((a, b) => b.date.compareTo(a.date));

    // Subscription payments
    final subs = <SubscriptionPayment>[];
    for (final d in active.where((d) => d.subscription)) {
      for (var w = 0; w < 6; w++) {
        final weekly = r.nextBool();
        final kind = d.rideTypeId == 'bike' || d.rideTypeId == 'keke'
            ? d.rideTypeId
            : 'car';
        final amt = switch (kind) {
          'bike' => weekly ? 6500 : 1300,
          'keke' => weekly ? 6500 : 1300,
          _ => weekly ? 15000 : 3000,
        };
        subs.add(
          SubscriptionPayment(
            driverName: d.name,
            period: weekly ? 'Weekly' : 'Daily',
            amount: amt,
            date: now.subtract(
              Duration(days: w * 7 + r.nextInt(6), hours: r.nextInt(20)),
            ),
          ),
        );
      }
    }
    subs.sort((a, b) => b.date.compareTo(a.date));

    // Payouts
    final payouts = <Payout>[];
    for (var i = 0; i < 70; i++) {
      final d = pick(active);
      final status = i < 5
          ? PayoutStatus.pending
          : i < 7
          ? PayoutStatus.failed
          : PayoutStatus.completed;
      payouts.add(
        Payout(
          id: 'PO-${7001 + i}',
          driverId: d.id,
          driverName: d.name,
          amount: (5 + r.nextInt(60)) * 1000,
          bank: '${pick(banks)} •••• ${1000 + r.nextInt(8999)}',
          status: status,
          date: now.subtract(Duration(hours: i * 7 + r.nextInt(6))),
          reference: status == PayoutStatus.completed
              ? 'TRF_${10000000 + r.nextInt(89999999)}'
              : '',
          failReason: status == PayoutStatus.failed
              ? 'Bank could not be reached. Retry.'
              : null,
        ),
      );
    }

    // Safety events
    Place place(int i) => lagosPlaces[i % lagosPlaces.length];
    final safety = <SafetyEvent>[
      SafetyEvent(
        id: 'SOS-901',
        kind: SafetyKind.autoSos,
        tripId: trips[3].id,
        riderName: trips[3].riderName,
        driverName: trips[3].driverName,
        plate: active.first.plate,
        place: place(16).name,
        position: place(16).position,
        time: now.subtract(const Duration(minutes: 4)),
        status: SafetyStatus.open,
        detail:
            'Driver left the route near ${place(16).name}. Rider did not respond within 60 seconds, so SOS was sent automatically.',
        contactsAlerted: 2,
      ),
      SafetyEvent(
        id: 'SOS-900',
        kind: SafetyKind.routeDeviation,
        tripId: trips[8].id,
        riderName: trips[8].riderName,
        driverName: trips[8].driverName,
        plate: active[3].plate,
        place: place(13).name,
        position: place(13).position,
        time: now.subtract(const Duration(minutes: 11)),
        status: SafetyStatus.acknowledged,
        detail: 'Car went 420 m off the planned route. Rider tapped "Ask the driver". Driver said: heavy traffic on Ikorodu Road.',
        handledBy: 'Ngozi Safety',
        notes: const [
          'Ngozi Safety: Called rider, she is fine. Monitoring until drop-off.',
        ],
      ),
      SafetyEvent(
        id: 'SOS-899',
        kind: SafetyKind.sos,
        tripId: trips[30].id,
        riderName: trips[30].riderName,
        driverName: trips[30].driverName,
        plate: active[5].plate,
        place: place(5).name,
        position: place(5).position,
        time: now.subtract(const Duration(minutes: 38)),
        status: SafetyStatus.open,
        detail: 'Rider pressed SOS during the trip.',
        contactsAlerted: 1,
      ),
      for (var i = 0; i < 9; i++)
        SafetyEvent(
          id: 'SOS-${890 - i}',
          kind: [
            SafetyKind.routeDeviation,
            SafetyKind.sos,
            SafetyKind.driverSos,
            SafetyKind.routeDeviation,
          ][i % 4],
          tripId: trips[60 + i * 13].id,
          riderName: trips[60 + i * 13].riderName,
          driverName: trips[60 + i * 13].driverName,
          plate: pick(active).plate,
          place: place(i + 2).name,
          position: place(i + 2).position,
          time: now.subtract(Duration(hours: 5 + i * 19)),
          status: SafetyStatus.resolved,
          detail: [
            'Driver took a detour around a road closure. Rider accepted the new route.',
            'Rider pressed SOS by mistake.',
            'Driver reported an aggressive passenger. Trip ended safely at a petrol station.',
            'Driver avoided a flooded road. Rider was informed.',
          ][i % 4],
          handledBy: pick(['Ngozi Safety', 'Temidayo Adekunle']),
          notes: const ['Resolved: everyone safe.'],
        ),
    ];

    // Support tickets
    TicketMessage m(String t, int minsAgo) => TicketMessage(
      t,
      fromStaff: false,
      time: now.subtract(Duration(minutes: minsAgo)),
    );
    final tickets = <Ticket>[
      Ticket(
        id: 'TCK-1042',
        fromName: riders[4].name,
        fromDriver: false,
        subject: 'Charged twice for one trip',
        category: 'Payments',
        status: TicketStatus.open,
        priority: 'high',
        created: now.subtract(const Duration(minutes: 25)),
        tripId: trips[12].id,
        messages: [
          m(
            'Hello, my card was charged twice for my trip this morning. Please help.',
            25,
          ),
        ],
      ),
      Ticket(
        id: 'TCK-1041',
        fromName: active[2].name,
        fromDriver: true,
        subject: 'Payout not received',
        category: 'Payouts',
        status: TicketStatus.open,
        priority: 'high',
        created: now.subtract(const Duration(hours: 1)),
        messages: [
          m(
            'I cashed out ₦25,000 yesterday but it has not entered my Opay account.',
            60,
          ),
        ],
      ),
      Ticket(
        id: 'TCK-1040',
        fromName: riders[9].name,
        fromDriver: false,
        subject: 'Left my phone in the car',
        category: 'Lost item',
        status: TicketStatus.open,
        priority: 'normal',
        created: now.subtract(const Duration(hours: 2)),
        tripId: trips[20].id,
        messages: [
          m(
            'I left my iPhone in the back seat. Black case. Please connect me with the driver.',
            120,
          ),
        ],
      ),
      Ticket(
        id: 'TCK-1039',
        fromName: riders[15].name,
        fromDriver: false,
        subject: 'Driver asked for extra money',
        category: 'Driver behaviour',
        status: TicketStatus.pending,
        priority: 'high',
        created: now.subtract(const Duration(hours: 5)),
        tripId: trips[44].id,
        messages: [
          m('The driver demanded ₦1,000 more than the app fare.', 300),
          TicketMessage(
            'Sorry about this. We\'ve refunded ₦1,000 to your wallet and are reviewing the driver. Can you confirm the time of the trip?',
            fromStaff: true,
            time: now.subtract(const Duration(hours: 4)),
            author: 'Bisi Support',
          ),
        ],
      ),
      Ticket(
        id: 'TCK-1038',
        fromName: active[7].name,
        fromDriver: true,
        subject: 'How do I switch to subscription?',
        category: 'Account',
        status: TicketStatus.resolved,
        priority: 'low',
        created: now.subtract(const Duration(days: 1)),
        messages: [
          m('I want to pay weekly instead of commission.', 1500),
          TicketMessage(
            'Go to Account > My plan, choose Subscription and Weekly, then pay from your wallet.',
            fromStaff: true,
            time: now.subtract(const Duration(hours: 23)),
            author: 'Bisi Support',
          ),
        ],
      ),
      Ticket(
        id: 'TCK-1037',
        fromName: riders[22].name,
        fromDriver: false,
        subject: 'Promo code not working',
        category: 'Promotions',
        status: TicketStatus.open,
        priority: 'normal',
        created: now.subtract(const Duration(hours: 7)),
        messages: [m('GORIDE20 says expired but I just got it.', 420)],
      ),
      Ticket(
        id: 'TCK-1036',
        fromName: active[11].name,
        fromDriver: true,
        subject: 'Document rejected but it is clear',
        category: 'Documents',
        status: TicketStatus.open,
        priority: 'normal',
        created: now.subtract(const Duration(hours: 9)),
        messages: [
          m(
            'My road worthiness was rejected as blurry. I uploaded again, please check.',
            540,
          ),
        ],
      ),
      Ticket(
        id: 'TCK-1035',
        fromName: riders[31].name,
        fromDriver: false,
        subject: 'Route alarm went off on my trip',
        category: 'Safety',
        status: TicketStatus.resolved,
        priority: 'normal',
        created: now.subtract(const Duration(days: 2)),
        messages: [
          m(
            'The off-route alert rang but the driver said it was traffic. All good, just letting you know.',
            2900,
          ),
        ],
      ),
      for (var i = 0; i < 6; i++)
        Ticket(
          id: 'TCK-${1034 - i}',
          fromName: riders[40 + i].name,
          fromDriver: false,
          subject: [
            'Wrong fare charged',
            'App keeps logging me out',
            'Add a new card',
            'Cancel fee question',
            'Driver was rude',
            'Wallet top up pending',
          ][i],
          category: [
            'Payments',
            'App issue',
            'Payments',
            'Payments',
            'Driver behaviour',
            'Payments',
          ][i],
          status: TicketStatus.resolved,
          priority: 'normal',
          created: now.subtract(Duration(days: 3 + i)),
          messages: [m('Please help with this.', 4400 + i * 1440)],
        ),
    ];

    final promos = [
      Promo(
        code: 'GORIDE20',
        description: '20% off for everyone this month',
        percent: true,
        value: 20,
        maxDiscount: 1500,
        uses: 842,
        limit: 5000,
        expires: now.add(const Duration(days: 12)),
      ),
      Promo(
        code: 'WELCOME500',
        description: 'New riders: ₦500 off first trip',
        percent: false,
        value: 500,
        maxDiscount: 500,
        uses: 1310,
        limit: 100000,
        expires: now.add(const Duration(days: 200)),
        newRidersOnly: true,
      ),
      Promo(
        code: 'AIRPORT10',
        description: '10% off airport trips',
        percent: true,
        value: 10,
        maxDiscount: 2000,
        uses: 96,
        limit: 1000,
        expires: now.add(const Duration(days: 40)),
      ),
      Promo(
        code: 'DETTY25',
        description: 'December weekends',
        percent: true,
        value: 25,
        maxDiscount: 2500,
        uses: 0,
        limit: 3000,
        expires: now.add(const Duration(days: 75)),
        active: false,
      ),
      Promo(
        code: 'UNILAG15',
        description: 'Students at UNILAG',
        percent: true,
        value: 15,
        maxDiscount: 800,
        uses: 450,
        limit: 450,
        expires: now.subtract(const Duration(days: 5)),
      ),
    ];

    final staff = [
      StaffMember(
        id: 'ST1',
        name: 'Temidayo Adekunle',
        email: 'temidayohassanadekunle@gmail.com',
        role: AdminRole.superAdmin,
        lastActive: now,
      ),
      StaffMember(
        id: 'ST2',
        name: 'Bisi Support',
        email: 'bisi@goride.ng',
        role: AdminRole.support,
        lastActive: now.subtract(const Duration(minutes: 12)),
      ),
      StaffMember(
        id: 'ST3',
        name: 'Ngozi Safety',
        email: 'ngozi@goride.ng',
        role: AdminRole.safety,
        lastActive: now.subtract(const Duration(minutes: 3)),
      ),
      StaffMember(
        id: 'ST4',
        name: 'Kunle Ops',
        email: 'kunle@goride.ng',
        role: AdminRole.operations,
        lastActive: now.subtract(const Duration(hours: 2)),
      ),
      StaffMember(
        id: 'ST5',
        name: 'Aisha Finance',
        email: 'aisha@goride.ng',
        role: AdminRole.finance,
        lastActive: now.subtract(const Duration(days: 1)),
      ),
    ];

    final broadcasts = [
      Broadcast(
        id: 'B3',
        audience: 'Drivers',
        title: 'Weekend quest is live',
        body: 'Complete 25 trips by Sunday and earn a ₦6,000 bonus.',
        sentAt: now.subtract(const Duration(days: 1)),
        reach: active.length,
        sentBy: 'Kunle Ops',
      ),
      Broadcast(
        id: 'B2',
        audience: 'Riders',
        title: '20% off all rides',
        body: 'Use GORIDE20 for 20% off your next ride this month.',
        sentAt: now.subtract(const Duration(days: 4)),
        reach: riders.length,
        sentBy: 'Temidayo Adekunle',
      ),
      Broadcast(
        id: 'B1',
        audience: 'Everyone',
        title: 'Heavy rain in Lagos',
        body: 'Expect slower trips today. Stay safe and allow extra time.',
        sentAt: now.subtract(const Duration(days: 9)),
        reach: riders.length + drivers.length,
        sentBy: 'Temidayo Adekunle',
      ),
    ];

    final audit = [
      AuditEntry(
        'Ngozi Safety',
        'Handling Off route alert on trip ${trips[8].id}',
        now.subtract(const Duration(minutes: 9)),
        category: 'Safety',
      ),
      AuditEntry(
        'Bisi Support',
        'Replied to ticket TCK-1039',
        now.subtract(const Duration(hours: 4)),
        category: 'Support',
      ),
      AuditEntry(
        'Kunle Ops',
        'Approved driver ${active[1].name} (${active[1].plate})',
        now.subtract(const Duration(hours: 6)),
        category: 'Drivers',
      ),
      AuditEntry(
        'Aisha Finance',
        'Sent 12 pending payouts (₦318,000)',
        now.subtract(const Duration(hours: 20)),
        category: 'Payouts',
      ),
      AuditEntry(
        'Temidayo Adekunle',
        'Created promo GORIDE20 (20% off)',
        now.subtract(const Duration(days: 18)),
        category: 'Promos',
      ),
    ];

    const channels = [
      AlertChannel(
        id: 'push',
        name: 'Push notification',
        description: 'To the emergency contact if they have GoRide installed',
        free: true,
        enabled: true,
      ),
      AlertChannel(
        id: 'email',
        name: 'Email',
        description: 'Live-location link by email (Resend free tier)',
        free: true,
        enabled: true,
      ),
      AlertChannel(
        id: 'whatsapp',
        name: 'WhatsApp link',
        description:
            'Rider\'s phone opens WhatsApp with the message ready to send',
        free: true,
        enabled: true,
      ),
      AlertChannel(
        id: 'safety_team',
        name: 'GoRide safety team',
        description: 'Shows here on the Safety alerts page in real time',
        free: true,
        enabled: true,
      ),
      AlertChannel(
        id: 'sms',
        name: 'Automatic SMS',
        description: 'Sent by GoRide without the rider\'s phone (Termii)',
        free: false,
        enabled: false,
        cost: 'About ₦4 per SMS',
      ),
      AlertChannel(
        id: 'voice',
        name: 'Automatic voice call',
        description: 'Robocall to the emergency contact',
        free: false,
        enabled: false,
        cost: 'About ₦15 per minute',
      ),
    ];

    const planPrices = [
      PlanPrice('Bike', 1300, 6500, 24000),
      PlanPrice('Keke', 1300, 6500, 24000),
      PlanPrice('Car', 3000, 15000, 55000),
    ];

    return AdminData(
      drivers: drivers,
      riders: riders,
      trips: trips,
      payouts: payouts,
      subscriptions: subs,
      safety: safety,
      tickets: tickets,
      promos: promos,
      broadcasts: broadcasts,
      staff: staff,
      audit: audit,
      pricing: pricing,
      planPrices: planPrices,
      channels: channels,
      settings: const AppSettings(),
    );
  }
}

final storeProvider = NotifierProvider<AdminStore, AdminData>(AdminStore.new);

/// Small helpers used across pages.
extension LatLngLabel on LatLng {
  String get short =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}
