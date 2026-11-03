import 'package:flutter/material.dart';

import '../data/models.dart';
import 'admin/admin_pages.dart';
import 'admin/integrations_page.dart';
import 'care/care_pages.dart';
import 'drivers/drivers_pages.dart';
import 'finance/finance_pages.dart';
import 'overview/overview_page.dart';
import 'trips/trips_pages.dart';

export 'drivers/drivers_pages.dart' show DriverDetailPage;
export 'trips/trips_pages.dart' show RiderDetailPage, TripsPage;

Widget pageFor(Section s) => switch (s) {
  Section.overview => const OverviewPage(),
  Section.liveMap => const LiveMapPage(),
  Section.drivers => const DriversPage(),
  Section.applications => const ApplicationsPage(),
  Section.riders => const RidersPage(),
  Section.trips => const TripsPage(),
  Section.revenue => const RevenuePage(),
  Section.payouts => const PayoutsPage(),
  Section.pricing => const PricingPage(),
  Section.safety => const SafetyPage(),
  Section.support => const SupportPage(),
  Section.promos => const PromosPage(),
  Section.broadcasts => const BroadcastsPage(),
  Section.staff => const StaffPage(),
  Section.settings => const SettingsPage(),
  Section.audit => const AuditPage(),
  Section.integrations => const IntegrationsPage(),
};
