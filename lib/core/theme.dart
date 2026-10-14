import 'package:flutter/material.dart';

import 'org_config.dart';

/// An organisation's brand colours, loaded from `org_settings`.
/// JBF uses green and gold on white.
class BrandPalette {
  const BrandPalette({
    this.primary = const Color(OrgDefaults.primaryColor),
    this.accent = const Color(OrgDefaults.accentColor),
  });

  final Color primary;
  final Color accent;

  /// A lighter primary that stays readable on dark backgrounds.
  Color get primaryOnDark {
    final hsl = HSLColor.fromColor(primary);
    return hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 0.75)).toColor();
  }
}

ThemeData buildTheme(
  Brightness brightness, [
  BrandPalette palette = const BrandPalette(),
]) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
    primary: dark ? palette.primaryOnDark : palette.primary,
    onPrimary: dark ? Colors.black : Colors.white,
    secondary: palette.accent,
    onSecondary: Colors.black,
    surface: dark ? const Color(0xFF111714) : Colors.white,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF0E1A13) : palette.primary,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    // Large, easy-to-tap buttons for use at meetings.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Not Size.fromHeight: an infinite minimum width breaks buttons in
        // dialogs and rows. Full-width buttons sit in stretched columns.
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: false,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: Colors.black,
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
  );
}
