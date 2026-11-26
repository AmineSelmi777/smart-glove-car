import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/models/gateway_models.dart';
import 'package:smart_glove_app/core/models/gesture.dart';
import 'package:smart_glove_app/data/gateway.dart';
import 'package:smart_glove_app/state/drive_controller.dart';

class FakeGateway implements Gateway {
  final sent = <DriveCommand>[];

  @override
  Stream<LinkState> get linkState => const Stream.empty();
  @override
  Stream<GatewayStatus> get status => const Stream.empty();
  @override
  Stream<GloveData> get glove => const Stream.empty();
  @override
  Stream<CarData> get car => const Stream.empty();
  @override
  Stream<GatewayEvent> get events => const Stream.empty();
  @override
  Stream<int> get latencyMs => const Stream.empty();
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {}
  @override
  void sendDrive(DriveCommand command) => sent.add(command);
  @override
  void sendEvent(String level, String code, [String? message]) {}
}

void main() {
  test('forward sends both sides at the chosen speed', () {
    final g = FakeGateway();
    final d = DriveController(() => g)..setSpeed(0.6);
    d.press(CarCommand.forward);
    expect(g.sent.last.left, 0.6);
    expect(g.sent.last.right, 0.6);
    d.dispose();
  });

  test('turning slows the inner wheel but never reverses it', () {
    final g = FakeGateway();
    final d = DriveController(() => g)..setSpeed(0.6);
    d.press(CarCommand.turnLeft);
    expect(g.sent.last.left, closeTo(0.15, 0.001));
    expect(g.sent.last.right, 0.6);
    d.dispose();
  });

  test('release sends a zero command', () {
    final g = FakeGateway();
    final d = DriveController(() => g);
    d.press(CarCommand.forward);
    d.release();
    expect(g.sent.last.left, 0);
    expect(g.sent.last.right, 0);
    expect(d.pressed, isNull);
    d.dispose();
  });

  test('e-stop sends e=true and blocks the pad', () {
    final g = FakeGateway();
    final d = DriveController(() => g);
    d.toggleEstop();
    expect(g.sent.last.estop, isTrue);
    final before = g.sent.length;
    d.press(CarCommand.forward);
    expect(g.sent.length, before);
    expect(d.pressed, isNull);
    d.dispose();
  });

  test('boost and lights ride along with the command', () {
    final g = FakeGateway();
    final d = DriveController(() => g);
    d.toggleBoost();
    d.toggleLights();
    d.press(CarCommand.forward);
    expect(g.sent.last.boost, isTrue);
    expect(g.sent.last.lights, isTrue);
    d.dispose();
  });

  test('commands are refreshed while held', () async {
    final g = FakeGateway();
    final d = DriveController(() => g);
    d.press(CarCommand.forward);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(g.sent.length, greaterThanOrEqualTo(4));
    d.release();
    d.dispose();
  });

  test('a lost key-up is detected', () async {
    final g = FakeGateway();
    final d = DriveController(() => g);
    var held = true;
    d.press(CarCommand.forward, stillHeld: () => held);
    held = false;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(d.pressed, isNull);
    expect(g.sent.last.left, 0);
    d.dispose();
  });

  test('no command is ever negative', () {
    final g = FakeGateway();
    final d = DriveController(() => g);
    for (final c in CarCommand.values) {
      d.press(c);
      d.release();
    }
    expect(g.sent.every((x) => x.left >= 0 && x.right >= 0), isTrue);
    d.dispose();
  });
}