import 'package:goride_core/goride_core.dart' show parseTime;
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'store.dart' show AdminData;

/// Turns the `admin_snapshot` JSON from Supabase into dashboard models.
class Snapshot {
  Snapshot(this.data, this.tripIds, this.docTypes, this.onlineCount);

  final AdminData data;

  /// Trip code (shown to staff) -> trip uuid (used by the server).
  final Map<String, String> tripIds;

  /// Driver id -> document types, in the same order as [Driver.docs].
  final Map<String, List<String>> docTypes;
  final int onlineCount;
}

const docTitles = {
  'licence': 'Driver\'s licence',
  'nin': 'NIN slip or National ID',
  'vehicle_papers': 'Vehicle licence',
  'insurance': 'Vehicle insurance',
  'road_worthiness': 'Road worthiness certificate',
  'lasdri': 'LASDRI card',
  'vehicle_photo': 'Vehicle photo',
};

DateTime _t(Object? v) => parseTime(v) ?? DateTime.now();
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
String _s(Object? v, [String fallback = '']) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? fallback : s;
}

Snapshot parseSnapshot(Map<String, dynamic> j, AdminData base) {
  List<Map<String, dynamic>> list(String k) => [
    for (final x in (j[k] as List? ?? const []))
      Map<String, dynamic>.from(x as Map),
  ];

  final docTypes = <String, List<String>>{};
  final drivers = [
    for (final d in list('drivers'))
      () {
        final docs = [
          for (final x in (d['docs'] as List? ?? const []))
            Map<String, dynamic>.from(x as Map),
        ];
        docTypes[d['id'] as String] = [
          for (final x in docs) x['type'] as String,
        ];
        return Driver(
          id: d['id'] as String,
          name: _s(d['name'], 'New driver'),
          phone: _s(d['phone']),
          email: _s(d['email']),
          city: _s(d['city'], 'Ibadan'),
          rideTypeId: _s(d['ride_type_id'], 'car'),
          vehicle: _s(d['vehicle'], 'Vehicle not added'),
          plate: _s(d['plate'], '-'),
          status: switch (d['status']) {
            'approved' => DriverStatus.active,
            'suspended' => DriverStatus.suspended,
            'rejected' => DriverStatus.rejected,
            _ => DriverStatus.pending,
          },
          docs: [
            for (final x in docs)
              DocReview(
                title: docTitles[x['type']] ?? x['type'] as String,
                number: _s(x['number']),
                expiry: parseTime(x['expiry']),
                state: switch (x['status']) {
                  'approved' => DocState.approved,
                  'rejected' => DocState.rejected,
                  _ => DocState.pending,
                },
                note: x['note'] as String?,
              ),
          ],
          subscription: d['plan'] == 'subscription',
          rating: _d(d['rating']),
          trips: _i(d['trips']),
          appliedAt: _t(d['applied_at']),
          joinedAt: parseTime(d['approved_at']),
          online: d['online'] == true,
          wallet: _i(d['wallet']),
          lastSeen: parseTime(d['last_seen']),
          paidUntil: parseTime(d['paid_until']),
          suspendReason: d['note'] as String?,
          nin: _s(docs.where((x) => x['type'] == 'nin').firstOrNull?['number']),
        );
      }(),
  ];

  final riders = [
    for (final r in list('riders'))
      Rider(
        id: r['id'] as String,
        name: _s(r['name'], 'New rider'),
        phone: _s(r['phone']),
        email: _s(r['email']),
        trips: _i(r['trips']),
        spent: _i(r['spent']),
        rating: _d(r['rating']),
        joinedAt: _t(r['joined']),
        wallet: _i(r['wallet']),
        blocked: r['blocked'] == true,
        emergencyContacts: _i(r['contacts']),
      ),
  ];

  final tripIds = <String, String>{};
  final trips = [
    for (final t in list('trips'))
      () {
        tripIds[t['code'] as String] = t['id'] as String;
        return Trip(
          id: t['code'] as String,
          riderId: t['rider_id'] as String,
          riderName: _s(t['rider'], 'Rider'),
          driverId: _s(t['driver_id']),
          driverName: _s(
            t['driver'],
            t['driver_id'] == null ? 'No driver' : 'Driver',
          ),
          pickup: _s(t['pickup']),
          dropoff: _s(t['dropoff']),
          rideTypeId: _s(t['ride_type_id'], 'car'),
          fare: _i(t['fare']),
          commission: _i(t['commission']),
          payment: _s(t['payment'], 'wallet'),
          status: switch (t['status']) {
            'completed' => TripStatus.completed,
            'cancelled' =>
              t['cancelled_by'] == 'driver'
                  ? TripStatus.driverCancelled
                  : TripStatus.riderCancelled,
            _ => TripStatus.inProgress,
          },
          date: _t(t['date']),
          km: _d(t['km']),
          minutes: _i(t['minutes']),
          refunded: _i(t['refunded']),
          rating: (t['rating'] as num?)?.toInt(),
          routeAlert: t['route_alert'] == true,
        );
      }(),
  ];

  final payouts = [
    for (final p in list('payouts'))
      Payout(
        id: p['id'] as String,
        driverId: p['driver_id'] as String,
        driverName: _s(p['driver'], 'Driver'),
        amount: _i(p['amount']),
        bank: _s(p['bank']),
        status: switch (p['status']) {
          'paid' => PayoutStatus.completed,
          'failed' => PayoutStatus.failed,
          _ => PayoutStatus.pending,
        },
        date: _t(p['date']),
        reference: _s(p['reference']),
        failReason: p['reason'] as String?,
      ),
  ];

  final subscriptions = [
    for (final s in list('subscriptions'))
      SubscriptionPayment(
        driverName: _s(s['driver'], 'Driver'),
        period: switch (s['period']) {
          'daily' => 'Daily',
          'monthly' => 'Monthly',
          _ => 'Weekly',
        },
        amount: _i(s['amount']),
        date: _t(s['date']),
      ),
  ];

  final safety = [
    for (final e in list('safety'))
      SafetyEvent(
        id: e['id'] as String,
        kind: switch (e['kind']) {
          'auto_sos' => SafetyKind.autoSos,
          'route_deviation' => SafetyKind.routeDeviation,
          _ =>
            e['user_role'] == 'driver' ? SafetyKind.driverSos : SafetyKind.sos,
        },
        tripId: _s(e['trip'], '-'),
        riderName: _s(e['rider'], 'Rider'),
        driverName: _s(e['driver'], 'Driver'),
        plate: _s(e['plate'], '-'),
        place: _s(e['place']),
        position: LatLng(_d(e['lat']), _d(e['lng'])),
        time: _t(e['time']),
        status: switch (e['status']) {
          'in_progress' => SafetyStatus.acknowledged,
          'resolved' => SafetyStatus.resolved,
          _ => SafetyStatus.open,
        },
        detail: _s(e['detail']),
        contactsAlerted: _i(e['contacts']),
        notes: [
          for (final n in _s(e['notes']).split('\n'))
            if (n.trim().isNotEmpty) n.trim(),
        ],
        handledBy: e['handled_by'] as String?,
      ),
  ];

  final tickets = [
    for (final k in list('tickets'))
      Ticket(
        id: k['id'] as String,
        fromName: _s(k['from'], 'User'),
        fromDriver: k['driver'] == true,
        subject: _s(k['subject']),
        category: _s(k['category'], 'General'),
        status: switch (k['status']) {
          'in_progress' => TicketStatus.pending,
          'resolved' => TicketStatus.resolved,
          _ => TicketStatus.open,
        },
        priority: k['category'] == 'safety' ? 'High' : 'Normal',
        created: _t(k['created']),
        messages: [
          for (final m in (k['messages'] as List? ?? const []))
            TicketMessage(
              (m as Map)['text'] as String,
              fromStaff: m['staff'] == true,
              time: _t(m['time']),
              author: _s(m['author']),
            ),
        ],
        tripId: k['trip'] as String?,
        assignee: k['assignee'] as String?,
      ),
  ];

  final promos = [
    for (final p in list('promos'))
      Promo(
        code: p['code'] as String,
        description: _s(p['title']),
        percent: true,
        value: _i(p['percent_off']),
        maxDiscount: _i(p['max_off']),
        uses: _i(p['used']),
        limit: _i(p['usage_limit']),
        expires:
            parseTime(p['ends_at']) ??
            DateTime.now().add(const Duration(days: 3650)),
        active: p['active'] == true,
        newRidersOnly: p['new_riders_only'] == true,
      ),
  ];

  final broadcasts = [
    for (final b in list('broadcasts'))
      Broadcast(
        id: b['id'] as String,
        audience: switch (b['audience']) {
          'drivers' => 'Drivers',
          'everyone' => 'Everyone',
          _ => 'Riders',
        },
        title: _s(b['title']),
        body: _s(b['body']),
        sentAt: _t(b['date']),
        reach: _i(b['reach']),
        sentBy: _s(b['by'], 'Staff'),
      ),
  ];

  final staff = [
    for (final s in list('staff'))
      StaffMember(
        id: s['id'] as String,
        name: _s(s['full_name'], s['email'] as String),
        email: s['email'] as String,
        role: roleFromDb(s['role'] as String),
        active: s['active'] == true,
        lastActive: parseTime(s['last_seen_at']),
      ),
  ];

  final audit = [
    for (final a in list('audit'))
      AuditEntry(
        _s(a['who'], 'System'),
        _s(a['action']),
        _t(a['time']),
        category: _category(_s(a['action'])),
      ),
  ];

  final pricing = [
    for (final r in list('pricing'))
      RidePricing(
        id: r['id'] as String,
        name: r['name'] as String,
        baseFare: _d(r['base_fare']),
        perKm: _d(r['per_km']),
        perMinute: _d(r['per_minute']),
        minimumFare: _d(r['minimum_fare']),
        active: r['active'] == true,
      ),
  ];

  final plans =
      [
        for (final p in list('plans'))
          PlanPrice(
            switch (p['kind']) {
              'bike' => 'Bike',
              'keke' => 'Keke',
              _ => 'Car',
            },
            _i(p['daily']),
            _i(p['weekly']),
            _i(p['monthly']),
          ),
      ]..sort(
        (a, b) => [
          'Bike',
          'Keke',
          'Car',
        ].indexOf(a.kind).compareTo(['Bike', 'Keke', 'Car'].indexOf(b.kind)),
      );

  final st = Map<String, dynamic>.from(j['settings'] as Map? ?? const {});
  final settings = base.settings.copyWith(
    commissionRate: _i(st['commission_rate']),
    debtLimit: _i(st['debt_limit']),
    waitingFeePerMin: _i(st['waiting_fee_per_minute']),
    freeWaitMinutes: _i(st['waiting_free_minutes']),
    noShowFee: _i(st['no_show_fee']),
    offRouteMetres: _i(st['off_route_meters']),
    routeAlertTimeoutSeconds: _i(st['sos_response_seconds']),
    surgeEnabled: st['surge_enabled'] == true,
    maxSurge: _d(st['max_surge']),
    minPayout: _i(st['min_payout']),
    referralRiderReward: _i(st['rider_referral_reward']),
    referralDriverReward: _i(st['driver_referral_reward']),
    maintenanceMode: st['maintenance_mode'] == true,
    demoDriveAllowed: st['demo_drive_allowed'] == true,
  );

  return Snapshot(
    AdminData(
      drivers: drivers,
      riders: riders,
      trips: trips,
      payouts: payouts,
      subscriptions: subscriptions,
      safety: safety,
      tickets: tickets,
      promos: promos,
      broadcasts: broadcasts,
      staff: staff,
      audit: audit,
      pricing: pricing,
      planPrices: plans,
      channels: base.channels,
      settings: settings,
    ),
    tripIds,
    docTypes,
    _i(j['online']),
  );
}

AdminRole roleFromDb(String r) => switch (r) {
  'super_admin' => AdminRole.superAdmin,
  'operations' => AdminRole.operations,
  'finance' => AdminRole.finance,
  'safety' => AdminRole.safety,
  _ => AdminRole.support,
};

String roleToDb(AdminRole r) => switch (r) {
  AdminRole.superAdmin => 'super_admin',
  AdminRole.operations => 'operations',
  AdminRole.finance => 'finance',
  AdminRole.safety => 'safety',
  AdminRole.support => 'support',
};

String _category(String action) {
  final a = action.toLowerCase();
  if (a.contains('driver') || a.contains('document')) return 'Drivers';
  if (a.contains('refund')) return 'Trips';
  if (a.contains('payout')) return 'Payouts';
  if (a.contains('safety') || a.contains('sos')) return 'Safety';
  if (a.contains('price') || a.contains('subscription')) return 'Pricing';
  if (a.contains('promo')) return 'Promos';
  if (a.contains('notification')) return 'Notifications';
  if (a.contains('wallet') || a.contains('block')) return 'Riders';
  return 'General';
}
