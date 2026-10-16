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

/// Neutral colours shared by every screen; the brand colours come from the
/// organisation's [BrandPalette].
class Tones {
  const Tones._(this.bg, this.surface, this.border, this.text, this.muted);
  final Color bg;
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;

  static const light = Tones._(
    Color(0xFFF3F5F2),
    Colors.white,
    Color(0xFFE2E7E1),
    Color(0xFF131C17),
    Color(0xFF5B685F),
  );
  static const dark = Tones._(
    Color(0xFF0C120E),
    Color(0xFF151D18),
    Color(0xFF26332B),
    Color(0xFFE9EEE9),
    Color(0xFF9FAEA4),
  );

  static Tones of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const fontFamily = 'Inter';

ThemeData buildTheme(
  Brightness brightness, [
  BrandPalette palette = const BrandPalette(),
]) {
  final isDark = brightness == Brightness.dark;
  final ink = isDark ? Tones.dark : Tones.light;
  final primary = isDark ? palette.primaryOnDark : palette.primary;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: brightness,
        primary: primary,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: palette.accent,
        onSecondary: Colors.black,
        surface: ink.surface,
      ).copyWith(
        onSurface: ink.text,
        onSurfaceVariant: ink.muted,
        outlineVariant: ink.border,
        surfaceContainerLowest: ink.surface,
        surfaceContainerLow: ink.surface,
        surfaceContainer: ink.bg,
        surfaceContainerHigh: ink.bg,
        surfaceContainerHighest: ink.bg,
        primaryContainer: primary.withValues(alpha: isDark ? .22 : .10),
        onPrimaryContainer: primary,
        secondaryContainer: palette.accent.withValues(
          alpha: isDark ? .25 : .20,
        ),
        onSecondaryContainer: ink.text,
        tertiaryContainer: palette.accent.withValues(alpha: isDark ? .25 : .20),
        onTertiaryContainer: ink.text,
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: brightness,
  );
  final text = base.textTheme.apply(
    fontFamily: fontFamily,
    bodyColor: ink.text,
    displayColor: ink.text,
  );
  OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );
  return base.copyWith(
    scaffoldBackgroundColor: ink.bg,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ink.surface,
      foregroundColor: ink.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: ink.border)),
      titleTextStyle: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink.text,
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: ink.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: ink.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: ink.border, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      iconColor: ink.muted,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: ink.muted),
    ),
    // Large, easy-to-tap buttons for use at meetings.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // Not Size.fromHeight: an infinite minimum width breaks buttons in
        // dialogs and rows. Full-width buttons sit in stretched columns.
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: primary,
        side: BorderSide(color: ink.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ink.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: field(ink.border),
      enabledBorder: field(ink.border),
      focusedBorder: field(primary, 2),
      errorBorder: field(scheme.error),
      focusedErrorBorder: field(scheme.error, 2),
      labelStyle: TextStyle(color: ink.muted),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.accent,
      foregroundColor: Colors.black,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ink.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: primary.withValues(alpha: isDark ? .28 : .14),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? primary : ink.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? primary : ink.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: ink.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w500,
        color: ink.text,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ink.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ink.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? const Color(0xFF2B3A31)
          : const Color(0xFF1B2A21),
      contentTextStyle: const TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: ink.muted,
      indicatorColor: palette.accent,
      dividerColor: ink.border,
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w700,
      ),
    ),
    splashFactory: InkSparkle.splashFactory,
    focusColor: primary.withValues(alpha: .12),
    hoverColor: primary.withValues(alpha: .06),
    highlightColor: Colors.transparent,
    dividerColor: ink.border,
  );
}
