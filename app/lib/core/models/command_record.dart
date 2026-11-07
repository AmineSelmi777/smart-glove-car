import 'gesture.dart';
import 'glove_state.dart';

class CommandRecord {
  final int ts;
  final CarCommand command;
  final Gesture gesture;
  final double confidence;
  final int speed;

  const CommandRecord({
    required this.ts,
    required this.command,
    required this.gesture,
    required this.confidence,
    required this.speed,
  });

  factory CommandRecord.fromState(GloveState s) => CommandRecord(
        ts: s.ts,
        command: s.command,
        gesture: s.gesture,
        confidence: s.confidence,
        speed: s.speed,
      );
}