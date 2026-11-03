import 'package:flutter/foundation.dart';

import '../core/models/gesture.dart';
import '../core/models/glove_config.dart';
import '../data/config_store.dart';
import '../data/glove_source.dart';

class ConfigController extends ChangeNotifier {
  ConfigController(this._store, this._source);

  final ConfigStore _store;
  final GloveSource _source;

  GloveConfig _config = GloveConfig.defaults;
  bool _loaded = false;

  GloveConfig get config => _config;
  bool get loaded => _loaded;

  Future<void> load() async {
    _config = await _store.load();
    _loaded = true;
    notifyListeners();
    await _source.updateConfig(_config);
  }

  Future<void> setMapping(Gesture g, CarCommand c) =>
      _apply(_config.withMapping(g, c));

  Future<void> setThreshold(double t) => _apply(_config.withThreshold(t));

  Future<void> reset() => _apply(GloveConfig.defaults);

  Future<void> _apply(GloveConfig next) async {
    _config = next;
    notifyListeners();
    await _store.save(next);
    await _source.updateConfig(next);
  }
}