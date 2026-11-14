import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/control_mode.dart';
import '../core/models/gesture.dart';
import '../data/glove_source.dart';

/// Manual piloting: hold a button to move, release to stop.
class ManualController extends ChangeNotifier {
  ManualController(this._source);

  final GloveSource _source;

  ControlMode _mode = ControlMode.gesture;
  int _speed = 150;
  CarCommand? _pressed;
  Timer? _timer;

  ControlMode get mode => _mode;
  int get speed => _speed;
  CarCommand? get pressed => _pressed;

  Future<void> setMode(ControlMode m) async {
    if (m == _mode) return;
    release(); // stops the car if we are leaving manual mode
    _mode = m;
    notifyListeners();
    await _source.setMode(m);
  }

  void setSpeed(int v) {
    _speed = v.clamp(0, 255).toInt();
    notifyListeners();
  }

  void press(CarCommand c, {bool Function()? stillHeld}) {
    if (_mode != ControlMode.manual || _pressed == c) return;
    _pressed = c;
    _timer?.cancel();
    _send(c);
    // The car stops by itself when commands stop arriving, so keep refreshing while held.
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (stillHeld != null && !stillHeld()) {
        release(); // the key-up event was lost (window switch, screenshot tool...)
        return;
      }
      _send(c);
    });
    notifyListeners();
  }

  void release() {
    _timer?.cancel();
    _timer = null;
    if (_pressed != null) {
      _pressed = null;
      notifyListeners();
    }
    if (_mode == ControlMode.manual) {
      _source.sendManual(CarCommand.stop, 0);
    }
  }

  /// Always available: takes manual control (if needed) and stops the car.
  Future<void> emergencyStop() async {
    if (_mode != ControlMode.manual) {
      await setMode(ControlMode.manual);
    }
    release();
  }

  void _send(CarCommand c) =>
      _source.sendManual(c, c == CarCommand.stop ? 0 : _speed);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}