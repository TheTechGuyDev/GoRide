import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/admin_theme.dart';

// ---------- Access control ----------

/// Every page in the dashboard. Roles grant a set of these.
enum Section {
  overview('Overview', Icons.dashboard_outlined),
  liveMap('Live map', Icons.map_outlined),
  drivers('Drivers', Icons.badge_outlined),
  applications('Applications', Icons.how_to_reg_outlined),
  riders('Riders', Icons.people_outline),
  trips('Trips', Icons.route_outlined),
  revenue('Revenue', Icons.query_stats),
  payouts('Payouts', Icons.account_balance_outlined),
  pricing('Pricing & plans', Icons.sell_outlined),
  safety('Safety alerts', Icons.shield_outlined),
  support('Support', Icons.support_agent),
  promos('Promo codes', Icons.local_offer_outlined),
  broadcasts('Notifications', Icons.campaign_outlined),
  staff('Staff & roles', Icons.admin_panel_settings_outlined),
  settings('Settings', Icons.settings_outlined),
  audit('Audit log', Icons.history);

  const Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum AdminRole {
  superAdmin('Super Admin', 'Everything, including staff and settings'),
  operations('Operations', 'Drivers, applications, riders, trips, live map'),
  finance('Finance', 'Revenue, payouts, pricing, promo codes'),
  safety('Safety', 'Safety alerts, live map, trips, drivers'),
  support('Support', 'Support tickets, riders, trips');

  const AdminRole(this.label, this.description);
  final String label;
  final String description;

  Set<Section> get sections => switch (this) {
    AdminRole.superAdmin => Section.values.toSet(),
    AdminRole.operations => {
      Section.overview,
      Section.liveMap,
      Section.drivers,
      Section.applications,
      Section.riders,
      Section.trips,
      Section.safety,
      Section.broadcasts,
    },
    AdminRole.finance => {
      Section.overview,
      Section.revenue,
      Section.payouts,
      Section.pricing,
      Section.promos,
      Section.trips,
    },
    AdminRole.safety => {
      Section.overview,
      Section.safety,
      Section.liveMap,
      Section.trips,
      Section.drivers,
      Section.riders,
    },
    AdminRole.support => {
      Section.overview,
      Section.support,
      Section.riders,
      Section.trips,
      Section.drivers,
    },
  };
}

class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
    this.lastActive,
  });

  final String id;
  final String name;
  final String email;
  final AdminRole role;
  final bool active;
  final DateTime? lastActive;

  StaffMember copyWith({AdminRole? role, bool? active}) => StaffMember(
    id: id,
    name: name,
    email: email,
    role: role ?? this.role,
    active: active ?? this.active,
    lastActive: lastActive,
  );
}

// ---------- Drivers ----------

enum DriverStatus {
  pending('In review', AC.orange),
  active('Active', AC.primary),
  suspended('Suspended', AC.red),
  rejected('Rejected', Color(0xFF94A3B8));

  const DriverStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum DocState {
  pending('Pending', AC.orange),
  approved('Approved', AC.primary),
  rejected('Rejected', AC.red);

  const DocState(this.label, this.color);
  final String label;
  final Color color;
}

class DocReview {
  const DocReview({
    required this.title,
    this.number = '',
    this.expiry,
    this.state = DocState.pending,
    this.note,
  });

  final String title;
  final String number;
  final DateTime? expiry;
  final DocState state;
  final String? note;

  bool get expired => expiry != null && expiry!.isBefore(DateTime.now());
  bool get expiresSoon =>
      expiry != null &&
      !expired &&
      expiry!.difference(DateTime.now()).inDays <= 30;

  DocReview copyWith({DocState? state, String? note}) => DocReview(
    title: title,
    number: number,
    expiry: expiry,
    state: state ?? this.state,
    note: note ?? this.note,
  );
}

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.city,
    required this.rideTypeId,
    required this.vehicle,
    required this.plate,
    required this.status,
    required this.docs,
    required this.subscription,
    required this.rating,
    required this.trips,
    required this.appliedAt,
    this.joinedAt,
    this.online = false,
    this.wallet = 0,
    this.lastSeen,
    this.paidUntil,
    this.suspendReason,
    this.nin = '',
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String city;
  final String rideTypeId;
  final String vehicle;
  final String plate;
  final DriverStatus status;
  final List<DocReview> docs;

  /// True = subscription plan, false = commission.
  final bool subscription;
  final double rating;
  final int trips;
  final DateTime appliedAt;
  final DateTime? joinedAt;
  final bool online;

  /// Positive = GoRide owes driver; negative = driver owes commission.
  final int wallet;
  final DateTime? lastSeen;
  final DateTime? paidUntil;
  final String? suspendReason;
  final String nin;

  String get plan => subscription ? 'Subscription' : 'Commission';

  int get docIssues => docs
      .where((d) => d.state != DocState.approved || d.expired || d.expiresSoon)
      .length;

  Driver copyWith({
    DriverStatus? status,
    List<DocReview>? docs,
    DateTime? joinedAt,
    bool? online,
    int? wallet,
    String? suspendReason,
    bool clearSuspend = false,
  }) {
    return Driver(
      id: id,
      name: name,
      phone: phone,
      email: email,
      city: city,
      rideTypeId: rideTypeId,
      vehicle: vehicle,
      plate: plate,
      status: status ?? this.status,
      docs: docs ?? this.docs,
      subscription: subscription,
      rating: rating,
      trips: trips,
      appliedAt: appliedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      online: online ?? this.online,
      wallet: wallet ?? this.wallet,
      lastSeen: lastSeen,
      paidUntil: paidUntil,
      suspendReason: clearSuspend ? null : suspendReason ?? this.suspendReason,
      nin: nin,
    );
  }
}

// ---------- Riders ----------

class Rider {
  const Rider({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.trips,
    required this.spent,
    required this.rating,
    required this.joinedAt,
    this.wallet = 0,
    this.blocked = false,
    this.emergencyContacts = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final int trips;
  final int spent;
  final double rating;
  final DateTime joinedAt;
  final int wallet;
  final bool blocked;
  final int emergencyContacts;

  Rider copyWith({bool? blocked, int? wallet}) => Rider(
    id: id,
    name: name,
    phone: phone,
    email: email,
    trips: trips,
    spent: spent,
    rating: rating,
    joinedAt: joinedAt,
    wallet: wallet ?? this.wallet,
    blocked: blocked ?? this.blocked,
    emergencyContacts: emergencyContacts,
  );
}

// ---------- Trips ----------

enum TripStatus {
  completed('Completed', AC.primary),
  inProgress('In progress', AC.blue),
  riderCancelled('Rider cancelled', AC.orange),
  driverCancelled('Driver cancelled', AC.red);

  const TripStatus(this.label, this.color);
  final String label;
  final Color color;
}

class Trip {
  const Trip({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.driverId,
    required this.driverName,
    required this.pickup,
    required this.dropoff,
    required this.rideTypeId,
    required this.fare,
    required this.commission,
    required this.payment,
    required this.status,
    required this.date,
    required this.km,
    required this.minutes,
    this.refunded = 0,
    this.rating,
    this.routeAlert = false,
  });

  final String id;
  final String riderId;
  final String riderName;
  final String driverId;
  final String driverName;
  final String pickup;
  final String dropoff;
  final String rideTypeId;
  final int fare;
  final int commission;

  /// cash, wallet, card
  final String payment;
  final TripStatus status;
  final DateTime date;
  final double km;
  final int minutes;
  final int refunded;
  final int? rating;

  /// The rider got an off-route alert on this trip.
  final bool routeAlert;

  Trip copyWith({int? refunded}) => Trip(
    id: id,
    riderId: riderId,
    riderName: riderName,
    driverId: driverId,
    driverName: driverName,
    pickup: pickup,
    dropoff: dropoff,
    rideTypeId: rideTypeId,
    fare: fare,
    commission: commission,
    payment: payment,
    status: status,
    date: date,
    km: km,
    minutes: minutes,
    refunded: refunded ?? this.refunded,
    rating: rating,
    routeAlert: routeAlert,
  );
}

// ---------- Money ----------

enum PayoutStatus {
  completed('Paid', AC.primary),
  pending('Pending', AC.orange),
  failed('Failed', AC.red);

  const PayoutStatus(this.label, this.color);
  final String label;
  final Color color;
}

class Payout {
  const Payout({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.amount,
    required this.bank,
    required this.status,
    required this.date,
    this.reference = '',
    this.failReason,
  });

  final String id;
  final String driverId;
  final String driverName;
  final int amount;
  final String bank;
  final PayoutStatus status;
  final DateTime date;
  final String reference;
  final String? failReason;

  Payout copyWith({PayoutStatus? status, String? reference}) => Payout(
    id: id,
    driverId: driverId,
    driverName: driverName,
    amount: amount,
    bank: bank,
    status: status ?? this.status,
    date: date,
    reference: reference ?? this.reference,
    failReason: failReason,
  );
}

class SubscriptionPayment {
  const SubscriptionPayment({
    required this.driverName,
    required this.period,
    required this.amount,
    required this.date,
  });

  final String driverName;
  final String period;
  final int amount;
  final DateTime date;
}

// ---------- Safety & support ----------

enum SafetyKind {
  sos('SOS', Icons.sos, AC.red),
  autoSos('Auto SOS', Icons.timer_off_outlined, AC.red),
  routeDeviation('Off route', Icons.alt_route, AC.orange),
  driverSos('Driver SOS', Icons.local_police_outlined, AC.purple);

  const SafetyKind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

enum SafetyStatus {
  open('Open', AC.red),
  acknowledged('Handling', AC.orange),
  resolved('Resolved', AC.primary);

  const SafetyStatus(this.label, this.color);
  final String label;
  final Color color;
}

class SafetyEvent {
  const SafetyEvent({
    required this.id,
    required this.kind,
    required this.tripId,
    required this.riderName,
    required this.driverName,
    required this.plate,
    required this.place,
    required this.position,
    required this.time,
    required this.status,
    required this.detail,
    this.contactsAlerted = 0,
    this.notes = const [],
    this.handledBy,
  });

  final String id;
  final SafetyKind kind;
  final String tripId;
  final String riderName;
  final String driverName;
  final String plate;
  final String place;
  final LatLng position;
  final DateTime time;
  final SafetyStatus status;
  final String detail;
  final int contactsAlerted;
  final List<String> notes;
  final String? handledBy;

  SafetyEvent copyWith({
    SafetyStatus? status,
    List<String>? notes,
    String? handledBy,
  }) => SafetyEvent(
    id: id,
    kind: kind,
    tripId: tripId,
    riderName: riderName,
    driverName: driverName,
    plate: plate,
    place: place,
    position: position,
    time: time,
    status: status ?? this.status,
    detail: detail,
    contactsAlerted: contactsAlerted,
    notes: notes ?? this.notes,
    handledBy: handledBy ?? this.handledBy,
  );
}

enum TicketStatus {
  open('Open', AC.red),
  pending('Waiting on user', AC.orange),
  resolved('Resolved', AC.primary);

  const TicketStatus(this.label, this.color);
  final String label;
  final Color color;
}

class TicketMessage {
  const TicketMessage(
    this.text, {
    required this.fromStaff,
    required this.time,
    this.author = '',
  });
  final String text;
  final bool fromStaff;
  final DateTime time;
  final String author;
}

class Ticket {
  const Ticket({
    required this.id,
    required this.fromName,
    required this.fromDriver,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.created,
    required this.messages,
    this.tripId,
    this.assignee,
  });

  final String id;
  final String fromName;
  final bool fromDriver;
  final String subject;
  final String category;
  final TicketStatus status;

  /// high, normal, low
  final String priority;
  final DateTime created;
  final List<TicketMessage> messages;
  final String? tripId;
  final String? assignee;

  Ticket copyWith({
    TicketStatus? status,
    List<TicketMessage>? messages,
    String? assignee,
  }) => Ticket(
    id: id,
    fromName: fromName,
    fromDriver: fromDriver,
    subject: subject,
    category: category,
    status: status ?? this.status,
    priority: priority,
    created: created,
    messages: messages ?? this.messages,
    tripId: tripId,
    assignee: assignee ?? this.assignee,
  );
}

// ---------- Marketing ----------

class Promo {
  const Promo({
    required this.code,
    required this.description,
    required this.percent,
    required this.value,
    required this.maxDiscount,
    required this.uses,
    required this.limit,
    required this.expires,
    this.active = true,
    this.newRidersOnly = false,
  });

  final String code;
  final String description;

  /// True = percent off, false = flat naira off.
  final bool percent;
  final int value;
  final int maxDiscount;
  final int uses;
  final int limit;
  final DateTime expires;
  final bool active;
  final bool newRidersOnly;

  bool get expired => expires.isBefore(DateTime.now());

  String get offer => percent ? '$value% off' : '₦$value off';

  Promo copyWith({bool? active}) => Promo(
    code: code,
    description: description,
    percent: percent,
    value: value,
    maxDiscount: maxDiscount,
    uses: uses,
    limit: limit,
    expires: expires,
    active: active ?? this.active,
    newRidersOnly: newRidersOnly,
  );
}

class Broadcast {
  const Broadcast({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    required this.sentAt,
    required this.reach,
    required this.sentBy,
  });

  final String id;
  final String audience;
  final String title;
  final String body;
  final DateTime sentAt;
  final int reach;
  final String sentBy;
}

class AuditEntry {
  const AuditEntry(
    this.who,
    this.action,
    this.time, {
    this.category = 'General',
  });
  final String who;
  final String action;
  final DateTime time;
  final String category;
}

// ---------- Settings ----------

class RidePricing {
  const RidePricing({
    required this.id,
    required this.name,
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
    required this.minimumFare,
    this.active = true,
  });

  final String id;
  final String name;
  final double baseFare;
  final double perKm;
  final double perMinute;
  final double minimumFare;
  final bool active;

  RidePricing copyWith({
    double? baseFare,
    double? perKm,
    double? perMinute,
    double? minimumFare,
    bool? active,
  }) => RidePricing(
    id: id,
    name: name,
    baseFare: baseFare ?? this.baseFare,
    perKm: perKm ?? this.perKm,
    perMinute: perMinute ?? this.perMinute,
    minimumFare: minimumFare ?? this.minimumFare,
    active: active ?? this.active,
  );
}

class PlanPrice {
  const PlanPrice(this.kind, this.daily, this.weekly, this.monthly);
  final String kind;
  final int daily;
  final int weekly;
  final int monthly;

  PlanPrice copyWith({int? daily, int? weekly, int? monthly}) => PlanPrice(
    kind,
    daily ?? this.daily,
    weekly ?? this.weekly,
    monthly ?? this.monthly,
  );
}

/// An emergency alert channel. Free ones are on; paid ones can be enabled
/// later once there's budget.
class AlertChannel {
  const AlertChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.free,
    required this.enabled,
    this.cost,
  });

  final String id;
  final String name;
  final String description;
  final bool free;
  final bool enabled;
  final String? cost;

  AlertChannel copyWith({bool? enabled}) => AlertChannel(
    id: id,
    name: name,
    description: description,
    free: free,
    enabled: enabled ?? this.enabled,
    cost: cost,
  );
}

class AppSettings {
  const AppSettings({
    this.commissionRate = 15,
    this.debtLimit = 5000,
    this.waitingFeePerMin = 30,
    this.freeWaitMinutes = 3,
    this.noShowFee = 500,
    this.requestTimeoutSeconds = 15,
    this.offRouteMetres = 300,
    this.routeAlertTimeoutSeconds = 60,
    this.surgeEnabled = true,
    this.maxSurge = 1.5,
    this.paystackPublicKey = '',
    this.paystackSecretSet = false,
    this.paystackLive = false,
    this.minPayout = 1000,
    this.referralRiderReward = 500,
    this.referralDriverReward = 5000,
    this.maintenanceMode = false,
  });

  final int commissionRate;
  final int debtLimit;
  final int waitingFeePerMin;
  final int freeWaitMinutes;
  final int noShowFee;
  final int requestTimeoutSeconds;
  final int offRouteMetres;
  final int routeAlertTimeoutSeconds;
  final bool surgeEnabled;
  final double maxSurge;
  final String paystackPublicKey;
  final bool paystackSecretSet;
  final bool paystackLive;
  final int minPayout;
  final int referralRiderReward;
  final int referralDriverReward;
  final bool maintenanceMode;

  AppSettings copyWith({
    int? commissionRate,
    int? debtLimit,
    int? waitingFeePerMin,
    int? freeWaitMinutes,
    int? noShowFee,
    int? requestTimeoutSeconds,
    int? offRouteMetres,
    int? routeAlertTimeoutSeconds,
    bool? surgeEnabled,
    double? maxSurge,
    String? paystackPublicKey,
    bool? paystackSecretSet,
    bool? paystackLive,
    int? minPayout,
    int? referralRiderReward,
    int? referralDriverReward,
    bool? maintenanceMode,
  }) {
    return AppSettings(
      commissionRate: commissionRate ?? this.commissionRate,
      debtLimit: debtLimit ?? this.debtLimit,
      waitingFeePerMin: waitingFeePerMin ?? this.waitingFeePerMin,
      freeWaitMinutes: freeWaitMinutes ?? this.freeWaitMinutes,
      noShowFee: noShowFee ?? this.noShowFee,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      offRouteMetres: offRouteMetres ?? this.offRouteMetres,
      routeAlertTimeoutSeconds:
          routeAlertTimeoutSeconds ?? this.routeAlertTimeoutSeconds,
      surgeEnabled: surgeEnabled ?? this.surgeEnabled,
      maxSurge: maxSurge ?? this.maxSurge,
      paystackPublicKey: paystackPublicKey ?? this.paystackPublicKey,
      paystackSecretSet: paystackSecretSet ?? this.paystackSecretSet,
      paystackLive: paystackLive ?? this.paystackLive,
      minPayout: minPayout ?? this.minPayout,
      referralRiderReward: referralRiderReward ?? this.referralRiderReward,
      referralDriverReward: referralDriverReward ?? this.referralDriverReward,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
    );
  }
}
