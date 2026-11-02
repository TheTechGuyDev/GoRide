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

/// The driver's application and profile.
/// Later: `drivers`, `vehicles`, `driver_documents` (files in Supabase
/// Storage) and `driver_bank_accounts` tables, reviewed from the admin
/// dashboard.
class RegistrationController extends Notifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  void startFresh(String phone) => state = RegistrationState(phone: phone);

  void savePersonal(PersonalDetails p) => state = state.copyWith(personal: p);

  void saveVehicle(VehicleDetails v) => state = state.copyWith(vehicle: v);

  void saveDocument(DriverDocument d) =>
      state = state.copyWith(documents: {...state.documents, d.type: d});

  void savePlan(DriverPlan p) => state = state.copyWith(plan: p);

  void saveBank(BankDetails b) => state = state.copyWith(bank: b);

  Future<void> submit() async {
    await Future.delayed(const Duration(milliseconds: 900));
    state = state.copyWith(
      status: ApprovalStatus.pending,
      submittedAt: DateTime.now(),
    );
  }

  /// Preview only: what the admin "Approve" button will do.
  void simulateApproval() {
    state = state.copyWith(
      status: ApprovalStatus.approved,
      joinedAt: DateTime.now(),
      // New drivers join as founding drivers: 0% commission for 30 days.
      plan: state.plan?.copyWith(
        commissionFreeUntil: DateTime.now().add(
          const Duration(days: PlanPricing.foundingFreeDays),
        ),
      ),
      documents: {
        for (final e in state.documents.entries)
          e.key: e.value.copyWith(status: DocStatus.approved),
      },
    );
  }

  /// Preview only: what the admin "Reject document" button will do.
  void simulateRejection() {
    state = state.copyWith(
      status: ApprovalStatus.rejected,
      documents: {
        ...state.documents,
        DocType.roadWorthiness: state
            .doc(DocType.roadWorthiness)
            .copyWith(
              status: DocStatus.rejected,
              note: 'The photo is blurry. Please upload a clearer one.',
            ),
      },
    );
  }

  /// After fixing rejected documents.
  void resubmit() => state = state.copyWith(
    status: ApprovalStatus.pending,
    submittedAt: DateTime.now(),
  );

  /// Preview: sign in loads an approved demo driver.
  void loadDemoDriver(String phone) {
    final now = DateTime.now();
    DriverDocument ok(DocType t, {int expiresInDays = 400, String no = ''}) =>
        DriverDocument(
          type: t,
          number: no,
          expiry: t.expires ? now.add(Duration(days: expiresInDays)) : null,
          status: DocStatus.approved,
        );
    state = RegistrationState(
      phone: phone,
      personal: PersonalDetails(
        fullName: 'Tunde Bakare',
        email: 'tunde.bakare@gmail.com',
        city: 'Lagos',
        gender: 'Male',
        dateOfBirth: DateTime(1988, 4, 12),
      ),
      vehicle: const VehicleDetails(
        rideTypeId: 'comfort',
        make: 'Toyota',
        model: 'Corolla',
        year: 2016,
        color: 'Silver',
        plate: 'KJA 482 GD',
      ),
      documents: {
        DocType.licence: ok(DocType.licence, no: 'LAG84729AB12'),
        DocType.nin: ok(DocType.nin, no: '21948372615'),
        DocType.vehiclePapers: ok(DocType.vehiclePapers),
        DocType.insurance: ok(
          DocType.insurance,
          expiresInDays: 18,
          no: 'AXA-MT-77310',
        ),
        DocType.roadWorthiness: ok(DocType.roadWorthiness, expiresInDays: 150),
        DocType.lasdri: ok(DocType.lasdri, expiresInDays: 220),
        DocType.vehiclePhoto: ok(DocType.vehiclePhoto),
      },
      plan: const DriverPlan(),
      bank: const BankDetails(
        bank: 'GTBank',
        accountNumber: '0123456789',
        accountName: 'TUNDE BAKARE',
      ),
      status: ApprovalStatus.approved,
      submittedAt: now.subtract(const Duration(days: 240)),
      joinedAt: now.subtract(const Duration(days: 238)),
    );
  }

  void reset() => state = const RegistrationState();
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
