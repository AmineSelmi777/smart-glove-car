import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_glove_app/core/calibration.dart';
import 'package:smart_glove_app/core/drive_math.dart';
import 'package:smart_glove_app/core/models/gateway_models.dart';

GloveData _g(int flex) => GloveData(
      t: 0, flex: flex, roll: 0, pitch: 0, yaw: 0, gx: 0, gy: 0, gz: 0,
      gesture: 'none', confidence: 0, seq: 0,
    );

void main() {
  test('medianOf odd and even', () {
    expect(medianOf([5, 1, 3]), 3);
    expect(medianOf([1, 2, 3, 4]), 3);
  });

  test('captureFlex ignores a spike', () async {
    final n = ValueNotifier<GloveData?>(null);
    final f = captureFlex(n, duration: const Duration(milliseconds: 200));
    for (final v in [1000, 1010, 5000, 1005, 1002]) {
      n.value = _g(v);
    }
    expect(await f, 1005);
  });

  test('captureFlex returns null without data', () async {
    final n = ValueNotifier<GloveData?>(null);
    expect(await captureFlex(n, duration: const Duration(milliseconds: 50)), isNull);
  });
}
