import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin palette, in the style of the Vast School dashboard:
/// deep green dark mode by default, with a light mode.
class AC {
  static bool _dark = true;
  static bool get isDark => _dark;
  static void useDark(bool v) => _dark = v;

  // Brand
  static const primary = Color(0xFF0CC25F);
  static const primaryDeep = Color(0xFF079A4A);
  static const lime = Color(0xFFA6E84A);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const teal = Color(0xFF14B8A6);

  static Color get bg =>
      _dark ? const Color(0xFF07140D) : const Color(0xFFF2F6F3);
  static Color get sidebar => _dark ? const Color(0xFF09180F) : Colors.white;
  static Color get card => _dark ? const Color(0xFF0D1E14) : Colors.white;
  static Color get cardHigh =>
      _dark ? const Color(0xFF12281B) : const Color(0xFFF5F8F6);
  static Color get border =>
      _dark ? const Color(0xFF1C3626) : const Color(0xFFE2EAE5);
  static Color get text =>
      _dark ? const Color(0xFFEAF4EE) : const Color(0xFF0F1D15);
  static Color get muted =>
      _dark ? const Color(0xFF8BA596) : const Color(0xFF5E7166);
  static Color get faint =>
      _dark ? const Color(0xFF557063) : const Color(0xFF9AAAA1);
  static Color get field =>
      _dark ? const Color(0xFF0A1A11) : const Color(0xFFF2F6F3);
  static Color get selected =>
      _dark ? const Color(0xFF143A24) : const Color(0xFFE3F7EC);
}

class AdminTheme {
  static ThemeData build(bool dark) {
    final prev = AC.isDark;
    AC.useDark(dark);
    final t = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: 'Urbanist',
      fontFamilyFallback: const ['Naira'],
      scaffoldBackgroundColor: AC.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AC.primary,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: AC.primary,
        surface: AC.card,
      ),
      dividerColor: AC.border,
      dividerTheme: DividerThemeData(color: AC.border, space: 1),
      cardColor: AC.card,
      dialogTheme: DialogThemeData(
        backgroundColor: AC.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AC.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AC.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AC.text,
        contentTextStyle: TextStyle(color: AC.bg, fontFamily: 'Urbanist'),
        width: 420,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AC.field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: AC.faint),
        labelStyle: TextStyle(color: AC.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AC.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AC.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AC.primary, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AC.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AC.primary : AC.field,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AC.field,
        selectedColor: AC.primary,
        side: BorderSide(color: AC.border),
        labelStyle: TextStyle(color: AC.text, fontFamily: 'Urbanist'),
        shape: const StadiumBorder(),
      ),
      textTheme:
          ThemeData(brightness: dark ? Brightness.dark : Brightness.light)
              .textTheme
              .apply(
                fontFamily: 'Urbanist',
                bodyColor: AC.text,
                displayColor: AC.text,
              ),
      iconTheme: IconThemeData(color: AC.text),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AC.text,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: AC.bg, fontSize: 12),
      ),
    );
    AC.useDark(prev);
    return t;
  }
}

/// Dark by default, like the Vast School dashboard.
class AdminThemeMode extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final adminDarkProvider = NotifierProvider<AdminThemeMode, bool>(
  AdminThemeMode.new,
);
