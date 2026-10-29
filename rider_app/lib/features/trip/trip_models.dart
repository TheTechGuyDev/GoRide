import 'package:latlong2/latlong.dart';

import '../../core/services/routing_service.dart';
import '../booking/place.dart';
import '../booking/ride_types.dart';

class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.maskedPhone,
    required this.rating,
    required this.trips,
    required this.years,
    required this.memberSince,
    required this.carModel,
    required this.carColor,
    required this.plate,
  });

  final String id;
  final String name;

  /// Riders never see the driver's real number; calls go through GoRide.
  final String maskedPhone;
  final double rating;
  final int trips;
  final int years;
  final DateTime memberSince;
  final String carModel;
  final String carColor;
  final String plate;

  String get firstName => name.split(' ').first;
  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join();
  String get vehicleLine => '$carModel, $carColor · $plate';
}

enum TripPhase {
  /// Looking for a driver.
  searching,

  /// Driver accepted and is driving to the pickup.
  driverEnRoute,

  /// Driver is at the pickup; rider shares the ride PIN.
  driverArrived,

  /// Ride in progress.
  onTrip,

  /// Dropped off at the destination.
  completed,

  cancelled,
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.fromRider,
    required this.time,
  });

  final String text;
  final bool fromRider;
  final DateTime time;
}

class TripState {
  const TripState({
    required this.id,
    required this.phase,
    required this.pickup,
    required this.pickupName,
    required this.destination,
    required this.pickupNote,
    required this.rideType,
    required this.paymentId,
    required this.fare,
    required this.discount,
    required this.tripRoute,
    required this.pin,
    this.driver,
    this.approachRoute,
    this.driverPosition,
    this.driverHeading = 0,
    this.progress = 0,
    this.messages = const [],
    this.unreadMessages = 0,
    this.startedAt,
    this.endedAt,
    this.cancelReason,
  });

  final String id;
  final TripPhase phase;
  final LatLng pickup;
  final String pickupName;
  final Place destination;
  final String pickupNote;
  final RideType rideType;
  final String paymentId;
  final int fare;
  final int discount;

  /// Pickup -> destination.
  final RouteInfo tripRoute;

  /// Driver start -> pickup.
  final RouteInfo? approachRoute;

  /// 4-digit code the rider tells the driver before getting in.
  final String pin;
  final Driver? driver;
  final LatLng? driverPosition;
  final double driverHeading;

  /// 0..1 along the current leg (approach or trip).
  final double progress;
  final List<ChatMessage> messages;
  final int unreadMessages;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? cancelReason;

  int get total => fare - discount;

  /// Minutes left on the current leg, based on the real route time.
  int get minutesLeft {
    final leg = phase == TripPhase.driverEnRoute ? approachRoute : tripRoute;
    if (leg == null) return 0;
    final left = (leg.minutes * (1 - progress)).ceil();
    return left < 1 ? 1 : left;
  }

  TripState copyWith({
    TripPhase? phase,
    Driver? driver,
    RouteInfo? approachRoute,
    LatLng? driverPosition,
    double? driverHeading,
    double? progress,
    List<ChatMessage>? messages,
    int? unreadMessages,
    DateTime? startedAt,
    DateTime? endedAt,
    String? cancelReason,
  }) {
    return TripState(
      id: id,
      phase: phase ?? this.phase,
      pickup: pickup,
      pickupName: pickupName,
      destination: destination,
      pickupNote: pickupNote,
      rideType: rideType,
      paymentId: paymentId,
      fare: fare,
      discount: discount,
      tripRoute: tripRoute,
      pin: pin,
      driver: driver ?? this.driver,
      approachRoute: approachRoute ?? this.approachRoute,
      driverPosition: driverPosition ?? this.driverPosition,
      driverHeading: driverHeading ?? this.driverHeading,
      progress: progress ?? this.progress,
      messages: messages ?? this.messages,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }
}
