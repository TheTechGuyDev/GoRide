import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light, dark, or follow the phone. Later saved in the rider's settings.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// App language. English is complete; the others need translator review.
enum AppLanguage {
  english('English', 'English', true),
  pidgin('Nigerian Pidgin', 'Naijá', false),
  yoruba('Yoruba', 'Yorùbá', false),
  igbo('Igbo', 'Igbo', false),
  hausa('Hausa', 'Hausa', false),
  french('French', 'Français', false);

  const AppLanguage(this.label, this.nativeName, this.ready);
  final String label;
  final String nativeName;
  final bool ready;
}

class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppLanguage.english;

  void set(AppLanguage l) => state = l;
}

final languageProvider = NotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);
