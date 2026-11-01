import 'package:flutter/material.dart';

import '../data/models.dart';
import 'drivers/drivers_pages.dart';
import 'overview/overview_page.dart';
import 'placeholders.dart';
import 'trips/trips_pages.dart';

export 'drivers/drivers_pages.dart' show DriverDetailPage;
export 'placeholders.dart';
export 'trips/trips_pages.dart' show RiderDetailPage, TripsPage;

Widget pageFor(Section s) => switch (s) {
  Section.overview => const OverviewPage(),
  Section.liveMap => const LiveMapPage(),
  Section.drivers => const DriversPage(),
  Section.applications => const ApplicationsPage(),
  Section.riders => const RidersPage(),
  Section.trips => const TripsPage(),
  _ => ComingPage(section: s),
};
