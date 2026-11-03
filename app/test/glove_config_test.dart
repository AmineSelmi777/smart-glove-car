import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/models/gesture.dart';
import 'package:smart_glove_app/core/models/glove_config.dart';

void main() {
  test('defaults map gestures to matching commands', () {
    expect(GloveConfig.defaults.commandFor(Gesture.openHand), CarCommand.forward);
    expect(GloveConfig.defaults.commandFor(Gesture.closedHand), CarCommand.stop);
  });

  test('unknown gesture always stops, even if forced in the map', () {
    final c = GloveConfig.defaults.withMapping(Gesture.unknown, CarCommand.forward);
    expect(c.commandFor(Gesture.unknown), CarCommand.stop);
  });

  test('json round trip keeps mappings and threshold', () {
    final c = GloveConfig.defaults
        .withMapping(Gesture.closedHand, CarCommand.turnLeft)
        .withThreshold(0.8);
    final back = GloveConfig.fromJson(c.toJson());
    expect(back.commandFor(Gesture.closedHand), CarCommand.turnLeft);
    expect(back.confidenceThreshold, 0.8);
  });

  test('invalid json falls back to defaults and clamps the threshold', () {
    final c = GloveConfig.fromJson({
      'mappings': {'openHand': 'nonsense'},
      'threshold': 5,
    });
    expect(c.commandFor(Gesture.openHand), CarCommand.forward);
    expect(c.confidenceThreshold, 0.95);
  });
}