import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF1F3A5F); // deep navy

  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light).copyWith(
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFE8ECF1),
        ),
        const Color(0xFFF3F5F8),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark)
            .copyWith(surface: const Color(0xFF161D26)),
        const Color(0xFF0F141A),
      );

  static ThemeData _build(ColorScheme cs, Color background) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: background,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
        shape: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1, thickness: 1),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.primaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
      ),
    );
  }
}