import 'dart:math';

import 'models/gateway_models.dart';

/// Top of the speedometer: same rule as the web dashboard.
double speedGaugeTop(double maxSpeedKmh) => max(10.0, ((maxSpeedKmh * 1.25) / 5).ceil() * 5.0);

enum Gear { park, reverse, neutral, drive, boost }

Set<Gear> activeGears({
  required bool estop,
  required bool reverse,
  required bool boost,
  required double speedKmh,
}) =>
    {
      if (estop) Gear.park,
      if (!estop && reverse) Gear.reverse,
      if (!estop && !reverse && speedKmh < 0.2) Gear.neutral,
      if (!estop && !reverse && speedKmh >= 0.2 && !boost) Gear.drive,
      if (boost) Gear.boost,
    };

/// Control values rebuilt from the car telemetry (the gateway does not send them).
class DerivedControl {
  const DerivedControl({
    this.throttle = 0,
    this.steer = 0,
    this.left = 0,
    this.right = 0,
    this.reverse = false,
  });
  final double throttle; // 0..1
  final double steer; // -1..1, positive = right
  final double left, right; // -1..1
  final bool reverse;
}

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

DerivedControl deriveControl(CarData? car) {
  if (car == null) return const DerivedControl();
  double side(int a, int b) {
    final rpm = (car.rpm[a] + car.rpm[b]) / 2;
    final duty = (car.pwm[a] + car.pwm[b]) / 2 / 255;
    return rpm < 0 ? -duty : duty;
  }

  final l = side(0, 2); // FL, RL
  final r = side(1, 3); // FR, RR
  final mean = (l + r) / 2;
  return DerivedControl(
    left: _clamp(l, -1, 1),
    right: _clamp(r, -1, 1),
    throttle: _clamp(mean.abs(), 0, 1),
    steer: _clamp((l - r) / 2, -1, 1),
    reverse: mean < -0.02,
  );
}

/// 1 = hand fully open, 0 = fist, from the raw flex value and its calibration.
double openness(int flex, int open, int closed) {
  if (closed == open) return 1;
  return 1 - _clamp((flex - open) / (closed - open), 0, 1);
}

/// Median of a list of integers (robust against single spikes).
int medianOf(List<int> values) {
  final s = [...values]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : ((s[n ~/ 2 - 1] + s[n ~/ 2]) / 2).round();
}
