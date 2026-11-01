import 'package:flutter/material.dart';

import '../data/models.dart';
import 'overview/overview_page.dart';
import 'placeholders.dart';

export 'placeholders.dart';

Widget pageFor(Section s) => switch (s) {
  Section.overview => const OverviewPage(),
  _ => ComingPage(section: s),
};
