import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/features/drive/glove_scene.dart';

GloveScene scene(GlovePose pose) => buildGlove(GloveCamera(360, 330), pose);

void main() {
  test('matrix maths', () {
    final p = M4.rotZ(pi / 2).point(const V3(1, 0, 0));
    expect(p.x, closeTo(0, 1e-9));
    expect(p.y, closeTo(1, 1e-9));
    final t = (M4.translation(1, 2, 3) * M4.scale(2)).point(const V3(1, 1, 1));
    expect([t.x, t.y, t.z], [3, 4, 5]);
  });

  test('camera looks at the target', () {
    final cam = GloveCamera(360, 330);
    final (screen, depth) = cam.project(GloveCamera.target);
    expect(screen.dx, closeTo(180, 0.01));
    expect(screen.dy, closeTo(165, 0.01));
    expect(depth, closeTo(4.174, 0.001));
    expect(cam.focal, closeTo(539.69, 0.01));
  });

  test('open hand has the expected shapes', () {
    final s = scene(const GlovePose());
    expect(s.prims.whereType<CapPrim>().length, 15); // 5 fingers x 3 segments
    expect(s.prims.whereType<LinePrim>().length, 3); // IMU axes
    expect(s.prims.whereType<PolyPrim>().length, inInclusiveRange(40, 46));
  });

  test('shapes are sorted far to near', () {
    final p = scene(const GlovePose(close: 0.5, rollDeg: 20)).prims;
    for (var i = 0; i + 1 < p.length; i++) {
      expect(p[i].depth, greaterThanOrEqualTo(p[i + 1].depth));
    }
  });

  test('anchors match the prototype', () {
    final a = scene(const GlovePose()).anchors;
    expect(a['flex']!.dx, closeTo(168.0, 1.0));
    expect(a['flex']!.dy, closeTo(84.8, 1.0));
    expect(a['esp32']!.dx, closeTo(224.8, 1.0));
    expect(a['esp32']!.dy, closeTo(166.8, 1.0));
    expect(a['battery']!.dx, closeTo(201.6, 1.0));
    expect(a['battery']!.dy, closeTo(225.4, 1.0));
  });

  test('closing the hand bends the middle finger down', () {
    final open = scene(const GlovePose()).anchors['flex']!;
    final fist = scene(const GlovePose(close: 1)).anchors['flex']!;
    expect(fist.dy - open.dy, greaterThan(80)); // about 113 px in the prototype
    expect(fist.dy, closeTo(198.0, 1.5));
  });

  test('rolling the hand moves the IMU', () {
    final flat = scene(const GlovePose()).anchors['imu']!;
    final rolled = scene(const GlovePose(rollDeg: 30)).anchors['imu']!;
    expect((rolled - flat).distance, greaterThan(10));
  });

  test('every anchor stays inside the canvas', () {
    for (final pose in const [ 
      GlovePose(),
      GlovePose(close: 1),
      GlovePose(close: 0.5, rollDeg: 25, pitchDeg: -10, yawDeg: -35),
    ]) {
      for (final o in scene(pose).anchors.values) {
        expect(o.dx, inInclusiveRange(0, 360));
        expect(o.dy, inInclusiveRange(0, 330));
      }
    }
  });
}