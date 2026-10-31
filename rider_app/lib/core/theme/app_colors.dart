import 'package:flutter/material.dart';

/// GoRide palette, sampled from the UI kit.
///
/// Brand colours are constant. Neutral colours (text, surfaces, borders)
/// switch with light/dark mode: [GoRideApp] calls [AppColors.useDark] and
/// rebuilds the screens whenever the theme changes.
class AppColors {
  AppColors._();

  static bool _dark = false;
  static bool get isDark => _dark;
  static void useDark(bool dark) => _dark = dark;

  // Brand (same in both modes)
  static const Color primary = Color(0xFF0CC25F);
  static const Color primaryDark = Color(0xFF0A9F4E);
  static const Color error = Color(0xFFF75555);
  static const Color warning = Color(0xFFFF9800);
  static const Color star = Color(0xFFFB9400);

  // Neutrals (switch with the theme)
  static Color get primaryLight =>
      _dark ? const Color(0xFF173A28) : const Color(0xFFE7F9EF);
  static Color get textPrimary =>
      _dark ? const Color(0xFFF5F5F5) : const Color(0xFF212121);
  static Color get textSecondary =>
      _dark ? const Color(0xFFB0B3BA) : const Color(0xFF616161);
  static Color get textHint =>
      _dark ? const Color(0xFF7C8089) : const Color(0xFF9E9E9E);
  static Color get background =>
      _dark ? darkBackground : const Color(0xFFFFFFFF);

  /// Cards, sheets and panels.
  static Color get surface => _dark ? darkSurface : Colors.white;
  static Color get fieldFill =>
      _dark ? const Color(0xFF262A34) : const Color(0xFFFAFAFA);
  static Color get border => _dark ? darkBorder : const Color(0xFFEEEEEE);
  static Color get divider => border;

  // Raw dark values (used by the theme)
  static const Color darkBackground = Color(0xFF181A20);
  static const Color darkSurface = Color(0xFF1F222A);
  static const Color darkField = Color(0xFF262A34);
  static const Color darkBorder = Color(0xFF35383F);
}
