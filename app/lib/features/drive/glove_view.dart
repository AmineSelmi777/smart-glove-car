import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/drive_math.dart';
import '../../core/models/gateway_models.dart';
import '../../core/theme/axis_colors.dart';
import 'glove_scene.dart';

const double _viewYaw = -25; // constant rotation so the hand is never seen flat

double _wrap180(double deg) {
  var x = deg % 360;
  if (x > 180) x -= 360;
  return x;
}

/// Native 3D glove: reads the live packet every frame and eases toward it.
class GloveView extends StatefulWidget {
  const GloveView({
    super.key,
    required this.source,
    required this.flexOpen,
    required this.flexClosed,
  });

  final ValueListenable<GloveData?> source;
  final int flexOpen, flexClosed;

  @override
  State<GloveView> createState() => _GloveViewState();
}

class _GloveViewState extends State<GloveView> with SingleTickerProviderStateMixin {
  static const double _smoothing = 0.05; // easing time constant, seconds
  static const int _readoutMs = 100; // labels refresh at 10 Hz

  late final Ticker _ticker;
  final _pose = ValueNotifier<GlovePose>(const GlovePose());
  final _readout = ValueNotifier<_Readout>(const _Readout());
  Duration _last = Duration.zero;
  int _lastReadout = -1000;
  bool _labels = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration t) {
    final g = widget.source.value;
    if (g == null) {
      _last = t;
      return;
    }
    final target = GlovePose(
      close: 1 - openness(g.flex, widget.flexOpen, widget.flexClosed),
      rollDeg: g.roll,
      pitchDeg: g.pitch,
      yawDeg: _wrap180(g.yaw),
    );
    if (_last == Duration.zero) {
      _last = t;
      _pose.value = target; // first frame: no easing
    } else {
      final dt = (t - _last).inMicroseconds / 1e6;
      _last = t;
      final a = 1 - exp(-dt / _smoothing);
      final cur = _pose.value;
      final next = GlovePose(
        close: cur.close + (target.close - cur.close) * a,
        rollDeg: cur.rollDeg + (target.rollDeg - cur.rollDeg) * a,
        pitchDeg: cur.pitchDeg + (target.pitchDeg - cur.pitchDeg) * a,
        yawDeg: cur.yawDeg + _wrap180(target.yawDeg - cur.yawDeg) * a,
      );
      final moved = (next.close - cur.close).abs() > 0.0005 ||
          (next.rollDeg - cur.rollDeg).abs() > 0.02 ||
          (next.pitchDeg - cur.pitchDeg).abs() > 0.02 ||
          (next.yawDeg - cur.yawDeg).abs() > 0.02;
      if (moved) _pose.value = next;
    }
    final ms = t.inMilliseconds;
    if (ms - _lastReadout >= _readoutMs) {
      _lastReadout = ms;
      _readout.value = _Readout(flex: g.flex, roll: g.roll, pitch: g.pitch, batteryV: g.batteryV);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pose.dispose();
    _readout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ax;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ColoredBox(
              color: c.bg2,
              child: CustomPaint(
                painter: _GlovePainter(
                  pose: _pose,
                  readout: _readout,
                  colors: c,
                  dark: dark,
                  showLabels: _labels,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: c.text2,
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => setState(() => _labels = !_labels),
              icon: Icon(_labels ? Icons.label_off_outlined : Icons.label_outline, size: 16),
              label: Text(_labels ? 'Hide labels' : 'Show labels'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Readout {
  const _Readout({this.flex, this.roll = 0, this.pitch = 0, this.batteryV});
  final int? flex;
  final double roll, pitch;
  final double? batteryV;
}

class _LabelSpec {
  const _LabelSpec(this.name, this.value, this.pos, this.alignRight, this.anchor);
  final String name, value;
  final Offset pos;
  final bool alignRight;
  final Offset? anchor;
}

class _GlovePainter extends CustomPainter {
  _GlovePainter({
    required this.pose,
    required this.readout,
    required this.colors,
    required this.dark,
    required this.showLabels,
  }) : super(repaint: Listenable.merge([pose, readout]));

  final ValueListenable<GlovePose> pose;
  final ValueListenable<_Readout> readout;
  final AxisColors colors;
  final bool dark, showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose.value;
    final r = readout.value;
    final shown = GlovePose(
      close: p.close,
      rollDeg: p.rollDeg,
      pitchDeg: p.pitchDeg,
      yawDeg: p.yawDeg + _viewYaw,
    );
    final cam = GloveCamera(size.width, size.height);
    final scene = buildGlove(cam, shown, dark: dark);

    for (final prim in scene.prims) {
      if (prim is PolyPrim) {
        final path = Path()..addPolygon(prim.points, true);
        canvas.drawPath(path, Paint()..color = prim.color);
        canvas.drawPath(
          path,
          Paint()
            ..color = prim.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..strokeJoin = StrokeJoin.round,
        );
      } else if (prim is CapPrim) {
        canvas.drawLine(
          prim.a,
          prim.b,
          Paint()
            ..color = const Color(0xFF14171C)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = prim.width + 2,
        );
        canvas.drawLine(
          prim.a,
          prim.b,
          Paint()
            ..color = prim.color
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = prim.width,
        );
      } else if (prim is LinePrim) {
        canvas.drawLine(
          prim.a,
          prim.b,
          Paint()
            ..color = prim.color
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = prim.width,
        );
      }
    }

    if (showLabels) {
      final a = scene.anchors;
      final specs = [
        _LabelSpec('Flex sensor', r.flex?.toString() ?? '-', Offset(8, size.height * 0.12), false, a['flex']),
        _LabelSpec('Gyroscope (MPU-6050)', '${r.roll.round()}° / ${r.pitch.round()}°',
            Offset(size.width - 8, size.height * 0.24), true, a['imu']),
        _LabelSpec('ESP32', 'CoAP', Offset(size.width - 8, size.height * 0.5), true, a['esp32']),
        _LabelSpec('Battery', r.batteryV == null ? '-' : '${r.batteryV!.toStringAsFixed(2)} V',
            Offset(size.width - 8, size.height * 0.78), true, a['battery']),
      ];
      for (final s in specs) {
        _drawLabel(canvas, s);
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      canvas.drawLine(a + dir * d, a + dir * min(d + 4, total), paint);
      d += 8;
    }
  }

  void _drawLabel(Canvas canvas, _LabelSpec l) {
    TextPainter tp(String s, TextStyle st) =>
        TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
    final name = tp(l.name, TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.text));
    final value = tp(l.value, TextStyle(fontSize: 11, color: colors.muted));
    final w = name.width + 6 + value.width + 16;
    final h = max(name.height, value.height) + 10;
    final rect = Rect.fromLTWH(l.alignRight ? l.pos.dx - w : l.pos.dx, l.pos.dy, w, h);

    final anchor = l.anchor;
    if (anchor != null) {
      final start = anchor.dx < rect.center.dx ? rect.centerLeft : rect.centerRight;
      _dashed(
        canvas,
        start,
        anchor,
        Paint()
          ..color = colors.text2.withAlpha(150)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(anchor, 2.5, Paint()..color = colors.text2);
    }
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    canvas.drawRRect(rr, Paint()..color = colors.surface2.withAlpha(235));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.lineStrong,
    );
    name.paint(canvas, Offset(rect.left + 8, rect.top + (h - name.height) / 2));
    value.paint(canvas, Offset(rect.left + 8 + name.width + 6, rect.top + (h - value.height) / 2));
  }

  @override
  bool shouldRepaint(_GlovePainter old) =>
      old.dark != dark || old.showLabels != showLabels || old.colors != colors;
}
