import 'dart:math';
import 'dart:ui';


/// Colour as (red, green, blue).
typedef Rgb = (int, int, int);

class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(dot(this));
  V3 get unit {
    final l = length;
    return V3(x / l, y / l, z / l);
  }
}

/// 4x4 matrix, row-major, acting on column vectors (like the three.js scene graph).
class M4 {
  M4(this.m);
  final List<double> m;

  factory M4.translation(double x, double y, double z) =>
      M4(<double>[1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z, 0, 0, 0, 1]);
  factory M4.scale(double s) => M4(<double>[s, 0, 0, 0, 0, s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1]);
  factory M4.rotX(double a) {
    final c = cos(a), s = sin(a);
    return M4(<double>[1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0, 0, 0, 0, 1]);
  }
  factory M4.rotY(double a) {
    final c = cos(a), s = sin(a);
    return M4(<double>[c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0, 0, 0, 0, 1]);
  }
  factory M4.rotZ(double a) {
    final c = cos(a), s = sin(a);
    return M4(<double>[c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  }

  M4 operator *(M4 o) {
    final r = List<double>.filled(16, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        var s = 0.0;
        for (var k = 0; k < 4; k++) {
          s += m[i * 4 + k] * o.m[k * 4 + j];
        }
        r[i * 4 + j] = s;
      }
    }
    return M4(r);
  }

  V3 point(V3 v) => V3(
        m[0] * v.x + m[1] * v.y + m[2] * v.z + m[3],
        m[4] * v.x + m[5] * v.y + m[6] * v.z + m[7],
        m[8] * v.x + m[9] * v.y + m[10] * v.z + m[11],
      );

  /// Rotation and scale only (for directions and normals).
  V3 dir(V3 v) => V3(
        m[0] * v.x + m[1] * v.y + m[2] * v.z,
        m[4] * v.x + m[5] * v.y + m[6] * v.z,
        m[8] * v.x + m[9] * v.y + m[10] * v.z,
      );
}

/// Same camera as the web viewer: fov 34 degrees, position (0, 2.4, 3.3), looking at (0, 0.05, -0.15).
class GloveCamera {
  GloveCamera(this.width, this.height) : focal = (height / 2) / tan(34 * pi / 180 / 2) {
    _fwd = (target - eye).unit;
    _right = _fwd.cross(const V3(0, 1, 0)).unit;
    _up = _right.cross(_fwd);
  }

  static const eye = V3(0, 2.4, 3.3);
  static const target = V3(0, 0.05, -0.15);

  final double width, height, focal;
  late final V3 _fwd, _right, _up;

  /// Screen position and depth (distance along the view axis).
  (Offset, double) project(V3 p) {
    final d = p - eye;
    final depth = _fwd.dot(d);
    return (
      Offset(width / 2 + focal * _right.dot(d) / depth, height / 2 - focal * _up.dot(d) / depth),
      depth,
    );
  }
}

sealed class Prim {
  const Prim(this.depth);
  final double depth;
}

class PolyPrim extends Prim {
  const PolyPrim(this.points, this.color, super.depth);
  final List<Offset> points;
  final Color color;
}

class CapPrim extends Prim {
  const CapPrim(this.a, this.b, this.width, this.color, super.depth);
  final Offset a, b;
  final double width;
  final Color color;
}

class LinePrim extends Prim {
  const LinePrim(this.a, this.b, this.width, this.color, super.depth);
  final Offset a, b;
  final double width;
  final Color color;
}

class GlovePose {
  const GlovePose({this.close = 0, this.rollDeg = 0, this.pitchDeg = 0, this.yawDeg = 0});
  final double close; // 0 = open hand, 1 = fist
  final double rollDeg, pitchDeg, yawDeg;
}

class GloveScene {
  const GloveScene(this.prims, this.anchors);
  final List<Prim> prims; // sorted far to near
  final Map<String, Offset> anchors; // flex, imu, esp32, battery
}

final V3 _light = const V3(2, 4, 3).unit;

int _byte(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());
Color _shade(Rgb c, double k) => Color.fromARGB(255, _byte(c.$1 * k), _byte(c.$2 * k), _byte(c.$3 * k));
Rgb _mix(Rgb a, Rgb b, double t) => (
      a.$1 + ((b.$1 - a.$1) * t).round(),
      a.$2 + ((b.$2 - a.$2) * t).round(),
      a.$3 + ((b.$3 - a.$3) * t).round(),
    );

class _Face {
  const _Face(this.idx, this.normal);
  final List<int> idx;
  final V3 normal;
}

const _faces = [
  _Face([0, 1, 3, 2], V3(-1, 0, 0)),
  _Face([4, 6, 7, 5], V3(1, 0, 0)),
  _Face([0, 4, 5, 1], V3(0, -1, 0)),
  _Face([2, 3, 7, 6], V3(0, 1, 0)),
  _Face([0, 2, 6, 4], V3(0, 0, -1)),
  _Face([1, 5, 7, 3], V3(0, 0, 1)),
];

/// A box (width, height, depth) placed by [m]; only the faces turned toward the camera are added.
void _box(GloveCamera cam, List<Prim> out, M4 m, double w, double h, double d, Rgb rgb,
    {double ambient = 0.55}) {
  final hx = w / 2, hy = h / 2, hz = d / 2;
  final corners = <V3>[
    for (final x in [-hx, hx])
      for (final y in [-hy, hy])
        for (final z in [-hz, hz]) V3(x, y, z),
  ];
  for (final f in _faces) {
    final pts = [for (final i in f.idx) m.point(corners[i])];
    final n = m.dir(f.normal).unit;
    final center = (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25;
    if (n.dot(GloveCamera.eye - center) <= 0) continue; // back face
    final k = ambient + 0.55 * max(0.0, n.dot(_light));
    final scr = [for (final p in pts) cam.project(p)];
    out.add(PolyPrim(
      [for (final s in scr) s.$1],
      _shade(rgb, k),
      (scr[0].$2 + scr[1].$2 + scr[2].$2 + scr[3].$2) / 4,
    ));
  }
}

class _Finger {
  const _Finger(this.x, this.z, this.lens, this.radius, this.thumb);
  final double x, z;
  final List<double> lens;
  final double radius;
  final bool thumb;
}

// Same numbers as client/src/three/gloveModel.js
const _fingers = [
  _Finger(-0.44, -0.05, [0.3, 0.24, 0.2], 0.092, true),
  _Finger(-0.29, -0.52, [0.4, 0.25, 0.19], 0.083, false),
  _Finger(-0.095, -0.55, [0.44, 0.29, 0.2], 0.086, false),
  _Finger(0.1, -0.53, [0.41, 0.26, 0.19], 0.082, false),
  _Finger(0.285, -0.47, [0.32, 0.2, 0.16], 0.074, false),
];
const _maxBend = [1.35, 1.65, 1.15];

GloveScene buildGlove(GloveCamera cam, GlovePose pose, {bool dark = true}) {
  final prims = <Prim>[];
  final anchors = <String, Offset>{};
  double lim(double v) => (v < -75 ? -75 : (v > 75 ? 75 : v)) * pi / 180;

  // pivot at the wrist, rotation order Y X Z, like the web viewer
  final hand = M4.scale(1.2) *
      M4.translation(0, 0, 0.55) *
      M4.rotY(lim(pose.yawDeg) * 0.5) *
      M4.rotX(-lim(pose.pitchDeg)) *
      M4.rotZ(-lim(pose.rollDeg));
  final body = hand * M4.translation(0, 0, -0.55);
  final Rgb fabric = dark ? (0x2b, 0x31, 0x3b) : (0x3c, 0x44, 0x52);
  final close = pose.close;

  // palm
  _box(cam, prims, body, 0.92, 0.3, 1.04, fabric);

  // cuff: elliptical prism
  const n = 18;
  final ring = [for (var i = 0; i < n; i++) (0.43 * cos(2 * pi * i / n), -0.01 + 0.29 * sin(2 * pi * i / n))];
  for (var i = 0; i < n; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % n];
    final pts = [
      body.point(V3(a.$1, a.$2, 0.51)),
      body.point(V3(b.$1, b.$2, 0.51)),
      body.point(V3(b.$1, b.$2, 1.13)),
      body.point(V3(a.$1, a.$2, 1.13)),
    ];
    final ctr = (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25;
    final outward = body.dir(V3(a.$1 + b.$1, a.$2 + b.$2 + 0.02, 0));
    if (outward.dot(GloveCamera.eye - ctr) <= 0) continue;
    final k = 0.45 + 0.5 * max(0.0, outward.unit.dot(_light));
    final scr = [for (final p in pts) cam.project(p)];
    prims.add(PolyPrim(
      [for (final s in scr) s.$1],
      _shade((0x1c, 0x21, 0x29), k * 1.6),
      (scr[0].$2 + scr[1].$2 + scr[2].$2 + scr[3].$2) / 4,
    ));
  }

  // fingers: three capsules each, bending from the base
  for (var fi = 0; fi < _fingers.length; fi++) {
    final fg = _fingers[fi];
    var m = body * M4.translation(fg.x, fg.thumb ? -0.04 : 0.02, fg.z);
    if (fg.thumb) m = m * M4.rotY(0.85) * M4.rotZ(0.35);
    for (var si = 0; si < 3; si++) {
      final len = fg.lens[si];
      final c = close * (fi == 0 ? 0.8 : 1.0);
      m = fi == 0
          ? m * M4.rotX(-c * (si == 0 ? 0.3 : 0.7)) * M4.rotY(-c * (si == 0 ? 0.55 : 0.5))
          : m * M4.rotX(-c * _maxBend[si]);
      final r = fg.radius * (1 - si * 0.1);
      final s0 = cam.project(m.point(const V3(0, 0, 0)));
      final s1 = cam.project(m.point(V3(0, 0, -len)));
      final up = m.dir(const V3(0, 1, 0));
      final k = 0.62 + 0.55 * max(0.0, up.dot(_light));
      final depth = (s0.$2 + s1.$2) / 2;
      prims.add(CapPrim(s0.$1, s1.$1, 2 * r * 1.2 * cam.focal / depth, _shade(fabric, k), depth));

      if (fi == 2) {
        // flex strip on the middle finger, glowing as the hand closes
        final strip = m * M4.translation(0, r + 0.004, -len / 2);
        final glow = _mix((0x1d, 0x1d, 0x1d), (0xff, 0xb5, 0x47), 0.15 + 0.7 * close);
        _box(cam, prims, strip, 0.06, 0.014, len * 0.96, glow, ambient: 0.9);
        if (si == 1) anchors['flex'] = cam.project(strip.point(const V3(0, 0.02, 0))).$1;
      }
      m = m * M4.translation(0, 0, -len);
    }
  }

  // flex strip on the back of the hand
  final glow = _mix((0x1d, 0x1d, 0x1d), (0xff, 0xb5, 0x47), 0.15 + 0.7 * close);
  _box(cam, prims, body * M4.translation(-0.095, 0.158, -0.33), 0.06, 0.014, 0.42, glow, ambient: 0.9);

  // ESP32
  final esp = body * M4.translation(0.08, 0.17, 0.12);
  _box(cam, prims, esp, 0.44, 0.03, 0.58, (0x14, 0x20, 0x2c));
  _box(cam, prims, esp * M4.translation(0, 0.032, -0.1), 0.24, 0.035, 0.27, (0xb8, 0xc0, 0xcc));
  _box(cam, prims, esp * M4.translation(0, 0.02, -0.25), 0.3, 0.012, 0.08, (0xc9, 0xa2, 0x27));
  _box(cam, prims, esp * M4.translation(0.15, 0.025, 0.2), 0.03, 0.02, 0.03, (0x4c, 0xc9, 0xf0), ambient: 1.4);
  _box(cam, prims, esp * M4.translation(0, 0.02, 0.28), 0.09, 0.03, 0.05, (0xb8, 0xc0, 0xcc));
  anchors['esp32'] = cam.project(esp.point(const V3(0.18, 0.06, 0.05))).$1;

  // IMU with its axes
  final imu = body * M4.translation(0.27, 0.165, -0.3);
  _box(cam, prims, imu, 0.16, 0.025, 0.2, (0x4c, 0x3a, 0x9e));
  _box(cam, prims, imu * M4.translation(0, 0.02, 0), 0.06, 0.018, 0.06, (0x11, 0x11, 0x11));
  final origin = imu.point(const V3(0, 0.03, 0));
  for (final (dir, color) in [
    (const V3(1, 0, 0), const Color(0xFFFF5D5D)),
    (const V3(0, 1, 0), const Color(0xFF3DDC97)),
    (const V3(0, 0, -1), const Color(0xFF4CC9F0)),
  ]) {
    final end = origin + imu.dir(dir * 0.22);
    final a = cam.project(origin);
    final b = cam.project(end);
    prims.add(LinePrim(a.$1, b.$1, 2.2, color, min(a.$2, b.$2) - 0.3));
  }
  anchors['imu'] = cam.project(imu.point(const V3(0, 0.05, 0))).$1;

  // battery on the cuff
  final bat = body * M4.translation(0, 0.3, 0.84);
  _box(cam, prims, bat, 0.42, 0.1, 0.28, (0x2a, 0x5e, 0xa8));
  _box(cam, prims, bat, 0.2, 0.102, 0.282, (0xe8, 0xe8, 0xe8));
  anchors['battery'] = cam.project(bat.point(const V3(0.1, 0.06, 0))).$1;

  prims.sort((a, b) => b.depth.compareTo(a.depth)); // painter's algorithm: far first
  return GloveScene(prims, anchors);
}