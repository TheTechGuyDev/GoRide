import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goride_core/goride_core.dart';

import 'plans.dart';

/// Where the driver's application stands.
enum ApprovalStatus { inProgress, pending, approved, rejected }

class PersonalDetails {
  const PersonalDetails({
    this.fullName = '',
    this.email = '',
    this.city = 'Lagos',
    this.gender,
    this.dateOfBirth,
    this.photo,
    this.referralCode = '',
  });

  final String fullName;
  final String email;
  final String city;
  final String? gender;
  final DateTime? dateOfBirth;
  final Uint8List? photo;
  final String referralCode;

  bool get isComplete =>
      fullName.trim().split(' ').length >= 2 && dateOfBirth != null;

  String get firstName =>
      fullName.trim().isEmpty ? 'Driver' : fullName.trim().split(' ').first;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'GD';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class VehicleDetails {
  const VehicleDetails({
    this.rideTypeId = 'car',
    this.make = '',
    this.model = '',
    this.year,
    this.color = '',
    this.plate = '',
    this.seats = 4,
    this.hasAc = true,
  });

  final String rideTypeId;
  final String make;
  final String model;
  final int? year;
  final String color;
  final String plate;
  final int seats;
  final bool hasAc;

  RideType get rideType => rideTypes.firstWhere((r) => r.id == rideTypeId);
  VehicleKind get kind => rideType.kind;

  bool get isComplete =>
      make.isNotEmpty && model.isNotEmpty && year != null && plate.length >= 7;

  String get title => '$color $make $model'.trim();

  /// Other services this vehicle can also take requests for.
  List<RideType> get eligibleTypes => switch (rideTypeId) {
    'comfort' =>
      rideTypes.where((r) => r.id == 'comfort' || r.id == 'car').toList(),
    'xl' => rideTypes.where((r) => r.id == 'xl' || r.id == 'car').toList(),
    _ => [rideType],
  };
}

enum DocType {
  licence,
  nin,
  vehiclePapers,
  insurance,
  roadWorthiness,
  lasdri,
  vehiclePhoto,
}

extension DocTypeX on DocType {
  String get title => switch (this) {
    DocType.licence => 'Driver\'s licence',
    DocType.nin => 'NIN slip or National ID',
    DocType.vehiclePapers => 'Vehicle licence (proof of ownership)',
    DocType.insurance => 'Vehicle insurance',
    DocType.roadWorthiness => 'Road worthiness certificate',
    DocType.lasdri => 'LASDRI card',
    DocType.vehiclePhoto => 'Vehicle photo',
  };

  String get hint => switch (this) {
    DocType.licence => 'Front of your valid FRSC driver\'s licence',
    DocType.nin => 'We verify your NIN with NIMC',
    DocType.vehiclePapers => 'Vehicle licence from the state licensing office',
    DocType.insurance => 'Third-party insurance or better',
    DocType.roadWorthiness => 'Valid road worthiness certificate',
    DocType.lasdri => 'Lagos drivers only (optional for bikes)',
    DocType.vehiclePhoto => 'Clear photo showing the front and plate number',
  };

  IconData get icon => switch (this) {
    DocType.licence => Icons.badge_outlined,
    DocType.nin => Icons.perm_identity,
    DocType.vehiclePapers => Icons.description_outlined,
    DocType.insurance => Icons.verified_user_outlined,
    DocType.roadWorthiness => Icons.build_circle_outlined,
    DocType.lasdri => Icons.credit_card,
    DocType.vehiclePhoto => Icons.directions_car_outlined,
  };

  /// Whether the document has an expiry date to enter.
  bool get expires => switch (this) {
    DocType.nin || DocType.vehiclePhoto => false,
    _ => true,
  };

  /// Whether the document needs an ID number.
  String? get numberLabel => switch (this) {
    DocType.licence => 'Licence number',
    DocType.nin => 'NIN (11 digits)',
    DocType.insurance => 'Policy number',
    _ => null,
  };
}

enum DocStatus { missing, inReview, approved, rejected }

class DriverDocument {
  const DriverDocument({
    required this.type,
    this.image,
    this.number = '',
    this.expiry,
    this.status = DocStatus.missing,
    this.note,
  });

  final DocType type;
  final Uint8List? image;
  final String number;
  final DateTime? expiry;
  final DocStatus status;

  /// Reason when rejected.
  final String? note;

  bool get uploaded => status != DocStatus.missing;

  bool get isExpired => expiry != null && expiry!.isBefore(DateTime.now());

  bool get expiresSoon =>
      expiry != null &&
      !isExpired &&
      expiry!.difference(DateTime.now()).inDays <= 30;

  DriverDocument copyWith({DocStatus? status, String? note}) => DriverDocument(
    type: type,
    image: image,
    number: number,
    expiry: expiry,
    status: status ?? this.status,
    note: note ?? this.note,
  );
}

class BankDetails {
  const BankDetails({
    required this.bank,
    required this.accountNumber,
    required this.accountName,
  });

  final String bank;
  final String accountNumber;
  final String accountName;

  String get masked =>
      '$bank •••• ${accountNumber.substring(accountNumber.length - 4)}';
}

class RegistrationState {
  const RegistrationState({
    this.phone = '',
    this.personal = const PersonalDetails(),
    this.vehicle,
    this.documents = const {},
    this.plan,
    this.bank,
    this.status = ApprovalStatus.inProgress,
    this.submittedAt,
    this.joinedAt,
  });

  final String phone;
  final PersonalDetails personal;
  final VehicleDetails? vehicle;
  final Map<DocType, DriverDocument> documents;
  final DriverPlan? plan;
  final BankDetails? bank;
  final ApprovalStatus status;
  final DateTime? submittedAt;
  final DateTime? joinedAt;

  /// Documents this driver must upload, based on their vehicle.
  List<DocType> get requiredDocs {
    final bike = vehicle?.kind == VehicleKind.bike;
    return [
      DocType.licence,
      DocType.nin,
      DocType.vehiclePapers,
      DocType.insurance,
      DocType.roadWorthiness,
      if (!bike) DocType.lasdri,
      DocType.vehiclePhoto,
    ];
  }

  DriverDocument doc(DocType t) => documents[t] ?? DriverDocument(type: t);

  int get docsUploaded => requiredDocs.where((t) => doc(t).uploaded).length;

  bool get docsComplete => docsUploaded == requiredDocs.length;

  bool get readyToSubmit =>
      personal.isComplete &&
      (vehicle?.isComplete ?? false) &&
      docsComplete &&
      plan != null &&
      bank != null;

  int get stepsDone => [
    personal.isComplete,
    vehicle?.isComplete ?? false,
    docsComplete,
    plan != null,
    bank != null,
  ].where((d) => d).length;

  RegistrationState copyWith({
    String? phone,
    PersonalDetails? personal,
    VehicleDetails? vehicle,
    Map<DocType, DriverDocument>? documents,
    DriverPlan? plan,
    BankDetails? bank,
    ApprovalStatus? status,
    DateTime? submittedAt,
    DateTime? joinedAt,
  }) {
    return RegistrationState(
      phone: phone ?? this.phone,
      personal: personal ?? this.personal,
      vehicle: vehicle ?? this.vehicle,
      documents: documents ?? this.documents,
      plan: plan ?? this.plan,
      bank: bank ?? this.bank,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

/// The driver's application and profile, stored in Supabase:
/// `profiles` (name, phone), `drivers` (vehicle, city, bank, status),
/// `driver_documents` + the private `driver-docs` storage bucket.
/// Applications are reviewed from the admin dashboard.
class RegistrationController extends Notifier<RegistrationState> {
  RealtimeChannel? _channel;

  @override
  RegistrationState build() {
    ref.onDispose(() => _channel?.unsubscribe());
    return const RegistrationState();
  }

  String? get _uid => Backend.user?.id;

  /// Loads everything about this driver; watches for approval changes.
  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    final results = await Future.wait(<Future<dynamic>>[
      Backend.db.from('profiles').select().eq('id', uid).single(),
      Backend.db.from('drivers').select().eq('id', uid).single(),
      Backend.db.from('driver_documents').select().eq('driver_id', uid),
    ]);
    final p = results[0] as Map<String, dynamic>;
    final d = results[1] as Map<String, dynamic>;
    final docs = results[2] as List;
    state = _fromRows(p, d, docs);
    _watch(uid);
    // The photo is stored in Supabase Storage; fetch it so it shows everywhere.
    if (p['avatar_url'] != null) {
      try {
        final bytes = await Backend.db.storage
            .from('avatars')
            .download('$uid/avatar.jpg');
        final x = state.personal;
        state = state.copyWith(
          personal: PersonalDetails(
            fullName: x.fullName,
            email: x.email,
            city: x.city,
            gender: x.gender,
            dateOfBirth: x.dateOfBirth,
            photo: bytes,
            referralCode: x.referralCode,
          ),
        );
      } catch (_) {}
    }
  }

  RegistrationState _fromRows(
    Map<String, dynamic> p,
    Map<String, dynamic> d,
    List docs,
  ) {
    final rideTypeId = d['ride_type_id'] as String?;
    final plan = d['plan'] == 'subscription'
        ? DriverPlan(
            type: PlanType.subscription,
            period: SubscriptionPeriod.values.byName(
              d['plan_period'] as String,
            ),
            paidUntil: parseTime(d['paid_until']),
            commissionFreeUntil: parseTime(d['commission_free_until']),
          )
        : DriverPlan(
            commissionFreeUntil: parseTime(d['commission_free_until']),
          );
    return RegistrationState(
      phone: (p['phone'] as String?) ?? '',
      personal: PersonalDetails(
        fullName: (p['full_name'] as String?) ?? '',
        email: (p['email'] as String?) ?? Backend.user?.email ?? '',
        city: (d['city'] as String?) ?? 'Ibadan',
        gender: p['gender'] as String?,
        dateOfBirth: p['date_of_birth'] == null
            ? null
            : DateTime.tryParse(p['date_of_birth'] as String),
        referralCode: (p['referral_code'] as String?) ?? '',
      ),
      vehicle: rideTypeId == null
          ? null
          : VehicleDetails(
              rideTypeId: rideTypeId,
              make: (d['make'] as String?) ?? '',
              model: (d['model'] as String?) ?? '',
              year: d['year'] as int?,
              color: (d['color'] as String?) ?? '',
              plate: (d['plate'] as String?) ?? '',
            ),
      documents: {
        for (final r in docs)
          // ignore: use_null_aware_elements
          if (_docType(r['type'] as String) case final t?)
            t: DriverDocument(
              type: t,
              number: (r['number'] as String?) ?? '',
              expiry: r['expiry'] == null
                  ? null
                  : DateTime.tryParse(r['expiry'] as String),
              status: switch (r['status']) {
                'approved' => DocStatus.approved,
                'rejected' => DocStatus.rejected,
                'missing' => DocStatus.missing,
                _ => DocStatus.inReview,
              },
              note: r['note'] as String?,
            ),
      },
      // A plan choice is only stored once the driver reaches that step.
      plan: d['status'] == 'draft' && state.plan == null ? null : plan,
      bank: d['account_number'] == null
          ? null
          : BankDetails(
              bank: d['bank_name'] as String,
              accountNumber: d['account_number'] as String,
              accountName: (d['account_name'] as String?) ?? '',
            ),
      status: switch (d['status']) {
        'approved' => ApprovalStatus.approved,
        'pending' => ApprovalStatus.pending,
        'rejected' || 'suspended' => ApprovalStatus.rejected,
        _ => ApprovalStatus.inProgress,
      },
      submittedAt: parseTime(d['submitted_at']),
      joinedAt: parseTime(d['approved_at']),
    );
  }

  static DocType? _docType(String db) => switch (db) {
    'licence' => DocType.licence,
    'nin' => DocType.nin,
    'vehicle_papers' => DocType.vehiclePapers,
    'insurance' => DocType.insurance,
    'road_worthiness' => DocType.roadWorthiness,
    'lasdri' => DocType.lasdri,
    'vehicle_photo' => DocType.vehiclePhoto,
    _ => null,
  };

  static String dbDocType(DocType t) => switch (t) {
    DocType.licence => 'licence',
    DocType.nin => 'nin',
    DocType.vehiclePapers => 'vehicle_papers',
    DocType.insurance => 'insurance',
    DocType.roadWorthiness => 'road_worthiness',
    DocType.lasdri => 'lasdri',
    DocType.vehiclePhoto => 'vehicle_photo',
  };

  /// Approval, rejection and document reviews arrive live from the admin.
  void _watch(String uid) {
    _channel?.unsubscribe();
    _channel = Backend.db
        .channel('driver-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (_) => load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_documents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: uid,
          ),
          callback: (_) => load(),
        )
        .subscribe();
  }

  void startFresh(String phone) => state = RegistrationState(phone: phone);

  /// Name, gender, birthday, city and (first time) phone.
  Future<void> savePersonal(PersonalDetails p, {String? phone}) async {
    state = state.copyWith(personal: p, phone: phone);
    final uid = _uid;
    if (uid == null) return;
    String? avatar;
    if (p.photo != null) {
      final path = '$uid/avatar.jpg';
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
      avatar =
          '${Backend.db.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    }
    await Backend.db
        .from('profiles')
        .update({
          'full_name': p.fullName,
          'gender': p.gender,
          'date_of_birth': p.dateOfBirth?.toIso8601String().substring(0, 10),
          'avatar_url': ?avatar,
          if (phone != null && phone.startsWith('+')) 'phone': phone,
        })
        .eq('id', uid);
    if (state.status == ApprovalStatus.inProgress) {
      await Backend.db.from('drivers').update({'city': p.city}).eq('id', uid);
    }
  }

  Future<void> saveVehicle(VehicleDetails v) async {
    state = state.copyWith(vehicle: v);
    final uid = _uid;
    if (uid == null) return;
    await Backend.db
        .from('drivers')
        .update({
          'ride_type_id': v.rideTypeId,
          'make': v.make,
          'model': v.model,
          'year': v.year,
          'color': v.color,
          'plate': v.plate.toUpperCase(),
        })
        .eq('id', uid);
  }

  /// Uploads the photo to private storage and records it for review.
  Future<void> saveDocument(DriverDocument d) async {
    final uid = _uid;
    if (uid == null) return;
    final type = dbDocType(d.type);
    String? path;
    if (d.image != null) {
      path = '$uid/$type.jpg';
      await Backend.db.storage
          .from('driver-docs')
          .uploadBinary(
            path,
            d.image!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
    }
    await Backend.db.from('driver_documents').upsert({
      'driver_id': uid,
      'type': type,
      'number': d.number,
      'expiry': d.expiry?.toIso8601String().substring(0, 10),
      'file_path': ?path,
    }, onConflict: 'driver_id,type');
    state = state.copyWith(documents: {...state.documents, d.type: d});
  }

  void savePlan(DriverPlan p) => state = state.copyWith(plan: p);

  Future<void> saveBank(BankDetails b) async {
    state = state.copyWith(bank: b);
    if (_uid == null) return;
    await Backend.db.rpc(
      'set_bank',
      params: {
        'p_bank': b.bank,
        'p_number': b.accountNumber,
        'p_name': b.accountName,
      },
    );
  }

  Future<void> submit() async {
    final uid = _uid;
    if (uid == null) return;
    await Backend.db
        .from('drivers')
        .update({'status': 'pending'})
        .eq('id', uid);
    state = state.copyWith(
      status: ApprovalStatus.pending,
      submittedAt: DateTime.now(),
    );
  }

  /// After fixing rejected documents.
  Future<void> resubmit() => submit();

  void reset() {
    _channel?.unsubscribe();
    _channel = null;
    state = const RegistrationState();
  }
}

final registrationProvider =
    NotifierProvider<RegistrationController, RegistrationState>(
      RegistrationController.new,
    );

/// Nigerian banks for payouts. Account names are checked with Paystack's
/// free "resolve account" API once the backend is added.
const nigerianBanks = [
  'Access Bank',
  'Ecobank',
  'Fidelity Bank',
  'First Bank',
  'FCMB',
  'GTBank',
  'Kuda',
  'Moniepoint',
  'Opay',
  'PalmPay',
  'Polaris Bank',
  'Stanbic IBTC',
  'Sterling Bank',
  'UBA',
  'Union Bank',
  'Wema Bank',
  'Zenith Bank',
];
