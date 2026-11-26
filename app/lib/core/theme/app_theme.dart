import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'axis_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(AxisColors.dark, Brightness.dark);
  static ThemeData light() => _build(AxisColors.light, Brightness.light);

    /// Applies IBM Plex Sans to every text style, without using the google_fonts TextTheme helper.
  static TextTheme _plex(TextTheme t) {
    TextStyle? f(TextStyle? s) => s == null ? null : GoogleFonts.ibmPlexSans(textStyle: s);
    return t.copyWith(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }

  static ThemeData _build(AxisColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.amber,
      onPrimary: const Color(0xFF1A1205),
      primaryContainer: c.amber.withAlpha(36),
      onPrimaryContainer: c.amber,
      secondary: c.cyan,
      onSecondary: const Color(0xFF04141B),
      secondaryContainer: c.cyan.withAlpha(36),
      onSecondaryContainer: c.cyan,
      error: c.red,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.text2,
      outline: c.lineStrong,
      outlineVariant: c.line,
      surfaceContainerHighest: c.surface3,
    );
    final base = ThemeData(
      brightness: b,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
    );
    return base.copyWith(
      textTheme: _plex(base.textTheme.apply(bodyColor: c.text, displayColor: c.text)),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg2,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: axisDisplay(size: 16, color: c.text),
        shape: Border(bottom: BorderSide(color: c.line)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bg2,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.amber.withAlpha(36),
      ),
    );
  }
}