import 'gesture.dart';

class GloveState {
  final int ts;
  final Gesture gesture;
  final double confidence; // 0..1
  final int flex; // raw ADC, 0..4095
  final int speed; // 0..255
  final CarCommand command;
  final bool online;
  final int? batteryPct;

  const GloveState({
    required this.ts,
    required this.gesture,
    required this.confidence,
    required this.flex,
    required this.speed,
    required this.command,
    this.online = true,
    this.batteryPct,
  });

  factory GloveState.fromJson(Map<String, dynamic> j) => GloveState(
        ts: j['ts'] as int,
        gesture: Gesture.fromWire(j['gesture'] as String),
        confidence: (j['confidence'] as num).toDouble(),
        flex: j['flex'] as int,
        speed: j['speed'] as int,
        command: CarCommand.fromWire(j['command'] as String),
        online: j['online'] as bool? ?? true,
        batteryPct: j['battery_pct'] as int?,
      );
}