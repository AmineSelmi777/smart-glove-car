import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/gateway_models.dart';
import '../core/models/gesture.dart';
import '../data/gateway.dart';

/// Manual driving through the gateway: hold to move, release to stop.
/// Commands are forward-only (the real car cannot reverse): the inner wheel slows down, never goes negative.
class DriveController extends ChangeNotifier {
  DriveController(this._gateway);

  final Gateway Function() _gateway;

  static const refresh = Duration(milliseconds: 100); // the gateway stops the car after 400 ms of silence
  static const innerWheel = 0.25; // inner wheel speed while turning, as a fraction of the speed

  double speed = 0.6; // duty 0..1
  CarCommand? pressed;
  bool boost = false;
  bool lights = false;
  bool estop = false;

  Timer? _timer;
  bool Function()? _stillHeld;
  int _seq = 0;

  DriveCommand _build() {
    if (estop) return DriveCommand(estop: true, lights: lights, boost: boost, seq: _seq++);
    double l = 0;
    double r = 0;
    switch (pressed) {
      case CarCommand.forward:
        l = speed;
        r = speed;
      case CarCommand.turnLeft:
        l = speed * innerWheel;
        r = speed;
      case CarCommand.turnRight:
        l = speed;
        r = speed * innerWheel;
      case CarCommand.stop:
      case null:
        break;
    }
    return DriveCommand(left: l, right: r, lights: lights, boost: boost, seq: _seq++);
  }

  void _send() => _gateway().sendDrive(_build());

  void _tick() {
    final held = _stillHeld;
    if (pressed != null && held != null && !held()) {
      release(); // the key-up event was lost (window switch, screenshot tool...)
      return;
    }
    _send();
  }

  void _startTimer() => _timer ??= Timer.periodic(refresh, (_) => _tick());

  void _stopTimerIfIdle() {
    if (pressed == null && !estop) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void setSpeed(double v) {
    speed = v < 0 ? 0 : (v > 1 ? 1 : v);
    notifyListeners();
  }

  void press(CarCommand c, {bool Function()? stillHeld}) {
    if (estop || pressed == c) return;
    pressed = c;
    _stillHeld = stillHeld;
    _send();
    _startTimer();
    notifyListeners();
  }

  void release() {
    if (pressed == null) return;
    pressed = null;
    _stillHeld = null;
    _send(); // one command with zero duty
    _stopTimerIfIdle();
    notifyListeners();
  }

  void toggleBoost() {
    boost = !boost;
    _send();
    notifyListeners();
  }

  void toggleLights() {
    lights = !lights;
    _send();
    notifyListeners();
  }

  void toggleEstop() {
    estop = !estop;
    if (estop) {
      pressed = null;
      _stillHeld = null;
      _send();
      _startTimer();
    } else {
      _send();
      _stopTimerIfIdle();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}