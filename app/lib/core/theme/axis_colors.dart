import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The AXIS design tokens (client/src/styles.css).
@immutable
class AxisColors extends ThemeExtension<AxisColors> {
  const AxisColors({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.text2,
    required this.muted,
    required this.amber,
    required this.cyan,
    required this.green,
    required this.red,
  });

  final Color bg, bg2, surface, surface2, surface3;
  final Color line, lineStrong, text, text2, muted;
  final Color amber, cyan, green, red;

  static const dark = AxisColors(
    bg: Color(0xFF0B1220),
    bg2: Color(0xFF0F1828),
    surface: Color(0xFF131E30),
    surface2: Color(0xFF1A273D),
    surface3: Color(0xFF22314B),
    line: Color(0xFF263652),
    lineStrong: Color(0xFF344868),
    text: Color(0xFFE7EDF6),
    text2: Color(0xFFA7B4C9),
    muted: Color(0xFF7586A0),
    amber: Color(0xFFFFB547),
    cyan: Color(0xFF4CC9F0),
    green: Color(0xFF3DDC97),
    red: Color(0xFFFF5D5D),
  );

  static const light = AxisColors(
    bg: Color(0xFFE8EDF3),
    bg2: Color(0xFFDFE5ED),
    surface: Color(0xFFF8FAFC),
    surface2: Color(0xFFFFFFFF),
    surface3: Color(0xFFEEF2F7),
    line: Color(0xFFD2DAE5),
    lineStrong: Color(0xFFB8C3D2),
    text: Color(0xFF121C2C),
    text2: Color(0xFF3F4C61),
    muted: Color(0xFF637289),
    amber: Color(0xFFC97A00),
    cyan: Color(0xFF0A7FA6),
    green: Color(0xFF12925E),
    red: Color(0xFFD93636),
  );

  @override
  AxisColors copyWith() => this;

  @override
  AxisColors lerp(ThemeExtension<AxisColors>? other, double t) =>
      other is AxisColors ? (t < 0.5 ? this : other) : this;
}

extension AxisContext on BuildContext {
  AxisColors get ax => Theme.of(this).extension<AxisColors>()!;
}

/// Numbers and headings use the display font, like the web dashboard.
TextStyle axisDisplay({double size = 14, FontWeight weight = FontWeight.w600, Color? color}) =>
    GoogleFonts.chakraPetch(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );