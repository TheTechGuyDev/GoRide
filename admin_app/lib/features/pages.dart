import 'package:flutter/material.dart';

import '../data/models.dart';
import 'drivers/drivers_pages.dart';
import 'overview/overview_page.dart';
import 'placeholders.dart';

export 'drivers/drivers_pages.dart' show DriverDetailPage;
export 'placeholders.dart';

Widget pageFor(Section s) => switch (s) {
  Section.overview => const OverviewPage(),
  Section.drivers => const DriversPage(),
  Section.applications => const ApplicationsPage(),
  _ => ComingPage(section: s),
};
