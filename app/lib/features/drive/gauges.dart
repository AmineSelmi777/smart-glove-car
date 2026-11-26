import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/drive_math.dart';
import '../../core/theme/axis_colors.dart';

void _arc(Canvas canvas, double cx, double cy, double r, double a0, double a1, Paint paint) {
  canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), (a0 - 90) * pi / 180,
      (a1 - a0) * pi / 180, false, paint);
}

Offset _polar(double cx, double cy, double r, double deg) {
  final a = (deg - 90) * pi / 180;
  return Offset(cx + r * cos(a), cy + r * sin(a));
}

/// Draws text centered on [at].
void _text(Canvas canvas, String s, Offset at, TextStyle style) {
  final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
}

Paint _stroke(Color color, double width, {bool round = false}) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = round ? StrokeCap.round : StrokeCap.butt
  ..color = color;

// ───────────── speedometer ─────────────

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({
    super.key,
    required this.speedKmh,
    required this.top,
    required this.throttle,
    required this.gears,
  });

  final double speedKmh, top, throttle;
  final Set<Gear> gears;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AspectRatio(
            aspectRatio: 300 / 220,
            child: CustomPaint(painter: _SpeedPainter(speedKmh, top, throttle, c)),
          ),
        ),
        const SizedBox(height: 6),
        _GearRow(gears: gears),
      ],
    );
  }
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter(this.v, this.top, this.thr, this.c);
  final double v, top, thr;
  final AxisColors c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);
    const cx = 150.0, cy = 150.0, radius = 118.0, a0 = -125.0, a1 = 125.0;
    double ang(double x) => a0 + (min(x, top) / top) * (a1 - a0);

    _arc(canvas, cx, cy, radius, a0, a1, _stroke(c.lineStrong, 10, round: true));
    final va = ang(v);
    _arc(canvas, cx, cy, radius, a0, max(a0 + 0.5, va), _stroke(c.amber, 10, round: true));
    // throttle demand ring
    _arc(canvas, cx, cy, radius - 16, a0, a0 + max(0.5, thr * (a1 - a0)),
        _stroke(c.cyan.withAlpha(128), 2, round: true));

    final step = top <= 10 ? 1.0 : (top <= 20 ? 2.0 : 5.0);
    for (var x = 0.0; x <= top + 0.001; x += step / 2) {
      final major = ((x / step) - (x / step).round()).abs() < 0.001;
      final tick = Paint()
        ..color = major ? c.text2 : c.lineStrong
        ..strokeWidth = major ? 2 : 1;
      canvas.drawLine(_polar(cx, cy, radius - 24, ang(x)),
          _polar(cx, cy, radius - (major ? 38 : 31), ang(x)), tick);
      if (major && x > 0) {
        _text(canvas, x.round().toString(), _polar(cx, cy, radius - 52, ang(x)),
            axisDisplay(size: 11, color: c.muted, weight: FontWeight.w500));
      }
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(va * pi / 180);
    canvas.drawPath(
      Path()
        ..moveTo(-3.5, 0)
        ..lineTo(0, -(radius - 18))
        ..lineTo(3.5, 0)
        ..close(),
      Paint()..color = c.amber,
    );
    canvas.restore();
    canvas.drawCircle(const Offset(cx, cy), 9, Paint()..color = c.surface2);
    canvas.drawCircle(const Offset(cx, cy), 9, _stroke(c.amber, 2));

    _text(canvas, v.toStringAsFixed(1), const Offset(cx, 184), axisDisplay(size: 40, color: c.text));
    _text(canvas, 'km/h', const Offset(cx, 211), TextStyle(fontSize: 12.5, color: c.muted));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpeedPainter old) => old.v != v || old.top != top || old.thr != thr || old.c != c;
}

class _GearRow extends StatelessWidget {
  const _GearRow({required this.gears});
  final Set<Gear> gears;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    Widget cell(String label, Gear gear, Color on) {
      final active = gears.contains(gear);
      return Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? on : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? on : c.line),
        ),
        child: Text(
          label,
          style: axisDisplay(size: 13, color: active ? const Color(0xFF1A1205) : c.muted),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        cell('P', Gear.park, c.red),
        cell('R', Gear.reverse, c.cyan),
        cell('N', Gear.neutral, c.amber),
        cell('D', Gear.drive, c.amber),
        cell('B', Gear.boost, c.amber),
      ],
    );
  }
}

// ───────────── battery (fuel) gauge ─────────────

class FuelGauge extends StatelessWidget {
  const FuelGauge({super.key, required this.percent, this.volts, this.gloveVolts, this.simulated = false});

  final double percent;
  final double? volts;
  final double? gloveVolts;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    final muted = TextStyle(fontSize: 12, color: c.muted);
    final low = percent < 20;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: AspectRatio(
            aspectRatio: 200 / 120,
            child: CustomPaint(painter: _FuelPainter(percent, c)),
          ),
        ),
        Text('${percent.round()}%', style: axisDisplay(size: 28, color: low ? c.red : c.text)),
        if (volts != null)
          Text('${volts!.toStringAsFixed(2)} V · 2S LiPo${simulated ? ' · simulated' : ''}', style: muted),
        if (gloveVolts != null) Text('Glove ${gloveVolts!.toStringAsFixed(2)} V', style: muted),
      ],
    );
  }
}

class _FuelPainter extends CustomPainter {
  _FuelPainter(this.pct, this.c);
  final double pct;
  final AxisColors c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200);
    const cx = 100.0, cy = 100.0, radius = 78.0, a0 = -90.0, a1 = 90.0;
    _arc(canvas, cx, cy, radius, a0, a1, _stroke(c.lineStrong, 8));
    _arc(canvas, cx, cy, radius, a0, -54, _stroke(c.red.withAlpha(140), 8));
    final tick = Paint()
      ..color = c.text2
      ..strokeWidth = 2;
    for (final p in const [0, 25, 50, 75, 100]) {
      final a = a0 + p / 100 * 180;
      canvas.drawLine(_polar(cx, cy, radius - 10, a), _polar(cx, cy, radius - 18, a), tick);
    }
    final label = axisDisplay(size: 11, color: c.muted, weight: FontWeight.w500);
    _text(canvas, 'E', const Offset(18, 112), label);
    _text(canvas, 'F', const Offset(184, 112), label);

    final a = a0 + (min(100.0, max(0.0, pct)) / 100) * (a1 - a0);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(a * pi / 180);
    canvas.drawPath(
      Path()
        ..moveTo(-3, 0)
        ..lineTo(0, -(radius - 14))
        ..lineTo(3, 0)
        ..close(),
      Paint()..color = pct < 20 ? c.red : c.text,
    );
    canvas.restore();
    canvas.drawCircle(const Offset(cx, cy), 6, Paint()..color = c.surface2);
    canvas.drawCircle(const Offset(cx, cy), 6, _stroke(c.text2, 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FuelPainter old) => old.pct != pct || old.c != c;
}