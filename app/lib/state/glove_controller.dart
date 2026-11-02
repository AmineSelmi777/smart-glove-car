import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/glove_state.dart';
import '../data/glove_source.dart';

class GloveController extends ChangeNotifier {
  GloveController(this._source) {
    _sub = _source.states.listen(_onState);
    _source.start();
  }

  final GloveSource _source;
  late final StreamSubscription<GloveState> _sub;

  GloveState? state;
  final List<GloveState> recent = []; // last 100 states (charts, history later)

  void _onState(GloveState s) {
    state = s;
    recent.add(s);
    if (recent.length > 100) recent.removeAt(0);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    _source.stop();
    super.dispose();
  }
}