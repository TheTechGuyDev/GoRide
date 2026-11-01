import 'package:goride_core/goride_core.dart';

/// How a driver pays GoRide.
enum PlanType { commission, subscription }

enum SubscriptionPeriod { daily, weekly, monthly }

extension SubscriptionPeriodX on SubscriptionPeriod {
  String get label => switch (this) {
    SubscriptionPeriod.daily => 'Daily',
    SubscriptionPeriod.weekly => 'Weekly',
    SubscriptionPeriod.monthly => 'Monthly',
  };

  String get per => switch (this) {
    SubscriptionPeriod.daily => 'day',
    SubscriptionPeriod.weekly => 'week',
    SubscriptionPeriod.monthly => 'month',
  };

  Duration get length => switch (this) {
    SubscriptionPeriod.daily => const Duration(days: 1),
    SubscriptionPeriod.weekly => const Duration(days: 7),
    SubscriptionPeriod.monthly => const Duration(days: 30),
  };
}

/// Plan prices. Later these come from a `driver_plans` table so you can
/// change them from the admin dashboard without an app update.
class PlanPricing {
  /// GoRide's cut of each fare on the commission plan.
  static const commissionRate = 0.15;

  static int subscriptionPrice(VehicleKind kind, SubscriptionPeriod period) {
    final (daily, weekly, monthly) = switch (kind) {
      VehicleKind.bike => (700, 4000, 14000),
      VehicleKind.keke => (800, 4500, 16000),
      VehicleKind.car => (2000, 11000, 38000),
    };
    return switch (period) {
      SubscriptionPeriod.daily => daily,
      SubscriptionPeriod.weekly => weekly,
      SubscriptionPeriod.monthly => monthly,
    };
  }
}

class DriverPlan {
  const DriverPlan({
    this.type = PlanType.commission,
    this.period = SubscriptionPeriod.weekly,
    this.paidUntil,
  });

  final PlanType type;
  final SubscriptionPeriod period;

  /// Subscription only: when the current paid period ends.
  final DateTime? paidUntil;

  bool get isSubscription => type == PlanType.subscription;

  bool get subscriptionActive =>
      isSubscription && paidUntil != null && paidUntil!.isAfter(DateTime.now());

  /// GoRide's share of a fare under this plan.
  int commissionOn(int fare) =>
      isSubscription ? 0 : (fare * PlanPricing.commissionRate).round();

  String get title => isSubscription
      ? '${period.label} subscription'
      : 'Commission (${(PlanPricing.commissionRate * 100).round()}% per trip)';

  DriverPlan copyWith({
    PlanType? type,
    SubscriptionPeriod? period,
    DateTime? paidUntil,
    bool clearPaidUntil = false,
  }) {
    return DriverPlan(
      type: type ?? this.type,
      period: period ?? this.period,
      paidUntil: clearPaidUntil ? null : paidUntil ?? this.paidUntil,
    );
  }
}
