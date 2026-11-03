import 'gesture.dart';

class GloveConfig {
  final Map<Gesture, CarCommand> mappings;
  final double confidenceThreshold;

  const GloveConfig({
    required this.mappings,
    this.confidenceThreshold = 0.70,
  });

  static const defaults = GloveConfig(mappings: {
    Gesture.openHand: CarCommand.forward,
    Gesture.closedHand: CarCommand.stop,
    Gesture.turnLeft: CarCommand.turnLeft,
    Gesture.turnRight: CarCommand.turnRight,
    Gesture.unknown: CarCommand.stop,
  });

  /// The unknown gesture always stops, whatever is stored.
  CarCommand commandFor(Gesture g) =>
      g == Gesture.unknown ? CarCommand.stop : (mappings[g] ?? CarCommand.stop);

  GloveConfig withMapping(Gesture g, CarCommand c) => GloveConfig(
        mappings: {...mappings, g: c},
        confidenceThreshold: confidenceThreshold,
      );

  GloveConfig withThreshold(double t) => GloveConfig(
        mappings: mappings,
        confidenceThreshold: t.clamp(0.5, 0.95).toDouble(),
      );

  // Local storage format (not the wire format of the contract).
  Map<String, dynamic> toJson() => {
        'mappings': {for (final e in mappings.entries) e.key.name: e.value.name},
        'threshold': confidenceThreshold,
      };

  /// Tolerant parsing: anything missing or invalid falls back to the defaults.
  factory GloveConfig.fromJson(Map<String, dynamic> j) {
    final raw = (j['mappings'] as Map?)?.cast<String, dynamic>() ?? {};
    final m = Map<Gesture, CarCommand>.of(defaults.mappings);
    for (final g in Gesture.values) {
      final v = raw[g.name];
      if (v is String) {
        final match = CarCommand.values.where((c) => c.name == v);
        if (match.isNotEmpty) m[g] = match.first;
      }
    }
    final t = (j['threshold'] as num?)?.toDouble() ?? 0.70;
    return GloveConfig(
      mappings: m,
      confidenceThreshold: t.clamp(0.5, 0.95).toDouble(),
    );
  }
}