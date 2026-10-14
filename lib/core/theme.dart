import 'package:flutter/material.dart';

/// JBF brand colours: green, gold and white.
abstract final class BrandColors {
  static const green = Color(0xFF0B6B3A);
  static const greenDark = Color(0xFF064A27);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFF3E3A6);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.green,
    brightness: brightness,
    primary: dark ? const Color(0xFF6FD39A) : BrandColors.green,
    secondary: BrandColors.gold,
    onSecondary: Colors.black,
    surface: dark ? const Color(0xFF111714) : BrandColors.white,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0E1A13) : BrandColors.green,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    // Large, easy-to-tap buttons for use at meetings.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BrandColors.gold,
      foregroundColor: Colors.black,
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}
