import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/models/gesture.dart';
import 'package:smart_glove_app/core/models/glove_config.dart';
import 'package:smart_glove_app/core/models/glove_state.dart';
import 'package:smart_glove_app/data/glove_source.dart';
import 'package:smart_glove_app/state/glove_controller.dart';

class FakeSource implements GloveSource {
  final c = StreamController<GloveState>.broadcast();

  @override
  Stream<GloveState> get states => c.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateConfig(GloveConfig config) async {}
}

GloveState st(CarCommand cmd) => GloveState(
      ts: 0,
      gesture: Gesture.openHand,
      confidence: 0.9,
      flex: 3300,
      speed: 100,
      command: cmd,
    );

void main() {
  test('logs only command changes, newest first', () async {
    final src = FakeSource();
    final ctrl = GloveController(src);
    src.c.add(st(CarCommand.stop));
    src.c.add(st(CarCommand.stop));
    src.c.add(st(CarCommand.forward));
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.history.map((r) => r.command).toList(),
        [CarCommand.forward, CarCommand.stop]);
    ctrl.dispose();
  });

  test('history is capped at 200 entries', () async {
    final src = FakeSource();
    final ctrl = GloveController(src);
    for (var i = 0; i < 250; i++) {
      src.c.add(st(i.isEven ? CarCommand.stop : CarCommand.forward));
    }
    await Future<void>.delayed(Duration.zero);

    expect(ctrl.history.length, 200);
    ctrl.dispose();
  });

  test('clearHistory empties the list', () async {
    final src = FakeSource();
    final ctrl = GloveController(src);
    src.c.add(st(CarCommand.forward));
    await Future<void>.delayed(Duration.zero);
    ctrl.clearHistory();

    expect(ctrl.history, isEmpty);
    ctrl.dispose();
  });
}