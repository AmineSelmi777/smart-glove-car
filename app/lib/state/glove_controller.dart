import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/command_record.dart';
import '../core/models/control_mode.dart';
import '../core/models/gesture.dart';
import '../core/models/glove_state.dart';
import '../data/glove_source.dart';

class GloveController extends ChangeNotifier {
  GloveController(this._source) {
    _sub = _source.states.listen(_onState);
    _source.start();
  }

  static const maxHistory = 200;
  static const maxRecent = 100;

  final GloveSource _source;
  late final StreamSubscription<GloveState> _sub;

  GloveState? state;
  final List<GloveState> recent = []; // last 100 states, used by the chart
  final List<CommandRecord> history = []; // newest first, command or mode changes only
  CarCommand? _lastCommand;
  ControlMode? _lastMode;

  void _onState(GloveState s) {
    state = s;

    recent.add(s);
    if (recent.length > maxRecent) recent.removeAt(0);

    if (s.command != _lastCommand || s.mode != _lastMode) {
      _lastCommand = s.command;
      _lastMode = s.mode;
      history.insert(0, CommandRecord.fromState(s));
      if (history.length > maxHistory) history.removeLast();
    }
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _lastCommand = null;
    _lastMode = null; // the current state is logged again on the next update
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    _source.stop();
    super.dispose();
  }
}