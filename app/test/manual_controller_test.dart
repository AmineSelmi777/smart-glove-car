import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/models/control_mode.dart';
import 'package:smart_glove_app/core/models/gesture.dart';
import 'package:smart_glove_app/core/models/glove_config.dart';
import 'package:smart_glove_app/core/models/glove_state.dart';
import 'package:smart_glove_app/data/glove_source.dart';
import 'package:smart_glove_app/state/manual_controller.dart';

class RecordingSource implements GloveSource {
  final calls = <String>[];

  @override
  Stream<GloveState> get states => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateConfig(GloveConfig config) async {}
  @override
  Future<void> setMode(ControlMode mode) async {
    calls.add('mode:${mode.name}');
  }

  @override
  Future<void> sendManual(CarCommand command, int speed) async {
    calls.add('manual:${command.name}:$speed');
  }
}

void main() {
  test('pressing does nothing in gesture mode', () {
    final src = RecordingSource();
    final c = ManualController(src);
    c.press(CarCommand.forward);
    expect(src.calls, isEmpty);
    c.dispose();
  });

  test('press sends the command at the chosen speed, release sends stop', () async {
    final src = RecordingSource();
    final c = ManualController(src);
    await c.setMode(ControlMode.manual);
    c.setSpeed(120);
    c.press(CarCommand.forward);
    c.release();
    expect(src.calls, ['mode:manual', 'manual:forward:120', 'manual:stop:0']);
    c.dispose();
  });

  test('a stop command is always sent at speed 0', () async {
    final src = RecordingSource();
    final c = ManualController(src);
    await c.setMode(ControlMode.manual);
    c.setSpeed(200);
    c.press(CarCommand.stop);
    c.release();
    final stops = src.calls.where((x) => x.startsWith('manual:stop'));
    expect(stops.every((x) => x == 'manual:stop:0'), isTrue);
    c.dispose();
  });

  test('emergency stop takes manual control and stops the car', () async {
    final src = RecordingSource();
    final c = ManualController(src);
    await c.emergencyStop();
    expect(c.mode, ControlMode.manual);
    expect(src.calls, ['mode:manual', 'manual:stop:0']);
    c.dispose();
  });

  test('a lost key-up is detected by the stillHeld check', () async {
    final src = RecordingSource();
    final c = ManualController(src);
    await c.setMode(ControlMode.manual);
    var held = true;
    c.press(CarCommand.forward, stillHeld: () => held);
    held = false;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(c.pressed, isNull);
    expect(src.calls.last, 'manual:stop:0');
    c.dispose();
  });
}