import 'package:flutter/material.dart';

import '../../core/theme/axis_colors.dart';

/// Top view of the car with the rpm of each wheel (green forward, amber reverse).
class WheelsView extends StatelessWidget {
  const WheelsView({super.key, required this.rpm});
  final List<int> rpm;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: AspectRatio(
          aspectRatio: 240 / 200,
          child: CustomPaint(painter: _WheelsPainter(rpm, context.ax)),
        ),
      );
}

class _WheelsPainter extends CustomPainter {
  _WheelsPainter(this.rpm, this.c);
  final List<int> rpm;
  final AxisColors c;

  static const _pos = [Offset(48, 26), Offset(162, 26), Offset(48, 118), Offset(162, 118)];
  static const _names = ['FL', 'FR', 'RL', 'RR'];

  void _label(Canvas canvas, String s, Offset at, Color color, bool? startAligned) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: axisDisplay(size: 11, color: color, weight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = startAligned == null ? -tp.width / 2 : (startAligned ? 0.0 : -tp.width);
    tp.paint(canvas, Offset(at.dx + dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240);

    final chassis = RRect.fromRectAndRadius(const Rect.fromLTWH(74, 20, 92, 150), const Radius.circular(14));
    canvas.drawRRect(chassis, Paint()..color = c.surface2);
    canvas.drawRRect(
      chassis,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = c.lineStrong,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(104, 28, 32, 10), const Radius.circular(3)),
      Paint()..color = c.cyan.withAlpha(180),
    );
    final axle = Paint()
      ..color = c.lineStrong
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(78, 49), const Offset(162, 49), axle);
    canvas.drawLine(const Offset(78, 141), const Offset(162, 141), axle);

    for (var i = 0; i < 4; i++) {
      final p = _pos[i];
      final r = i < rpm.length ? rpm[i] : 0;
      final color = r.abs() < 5 ? c.lineStrong : (r > 0 ? c.green : c.amber);
      final wheel = RRect.fromRectAndRadius(Rect.fromLTWH(p.dx, p.dy, 30, 46), const Radius.circular(6));
      canvas.save();
      canvas.clipRRect(wheel);
      canvas.drawRect(wheel.outerRect, Paint()..color = c.bg2);
      for (var y = p.dy; y < p.dy + 46; y += 12) {
        canvas.drawRect(Rect.fromLTWH(p.dx, y, 30, 5), Paint()..color = c.lineStrong);
      }
      canvas.restore();
      canvas.drawRRect(
        wheel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
      final rightSide = i.isOdd;
      final x = rightSide ? p.dx + 40 : p.dx - 10;
      _label(canvas, _names[i], Offset(x, p.dy + 20), c.muted, rightSide);
      _label(canvas, '$r', Offset(x, p.dy + 35), color, rightSide);
    }
    _label(canvas, 'rpm', const Offset(120, 192), c.muted, null);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelsPainter old) => old.rpm != rpm || old.c != c;
}