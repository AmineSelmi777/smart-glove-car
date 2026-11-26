import 'dart:async';

import 'package:flutter/foundation.dart';

import 'drive_math.dart';
import 'models/gateway_models.dart';

/// Collects flex samples for [duration] and returns their median, or null if no data arrived.
Future<int?> captureFlex(
  ValueListenable<GloveData?> source, {
  Duration duration = const Duration(seconds: 1),
}) async {
  final samples = <int>[];
  void onData() {
    final d = source.value;
    if (d != null) samples.add(d.flex);
  }

  source.addListener(onData);
  await Future<void>.delayed(duration);
  source.removeListener(onData);
  return samples.isEmpty ? null : medianOf(samples);
}
