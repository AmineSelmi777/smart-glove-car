import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/gateway_models.dart';
import '../data/gateway.dart';
import '../data/gateway_client.dart';
import '../data/mock_gateway.dart';

enum LinkMode { demo, gateway }

/// Owns the connection to the gateway (real or demo) and the latest telemetry.
/// Telemetry arrives at 50 Hz, so the UI is notified at most about 15 times per second.
class LinkController extends ChangeNotifier {
  Gateway _gw = MockGateway();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _flush;
  bool _dirty = false;

  LinkMode mode = LinkMode.demo;
  String host = 'localhost';
  int port = 8080;
  bool secure = false;

  LinkState link = LinkState.disconnected;
  GatewayStatus status = const GatewayStatus();
  GloveData? glove;
  CarData? car;
  int? latencyMs;

  /// Latest packets at full rate (about 50/s), for widgets that animate every frame.
  final ValueNotifier<GloveData?> gloveLive = ValueNotifier(null);
  final ValueNotifier<CarData?> carLive = ValueNotifier(null);
  final List<GatewayEvent> events = []; // newest first

  Gateway get gateway => _gw;
  GatewayConfig get config => GatewayConfig(host: host, port: port, secure: secure);
  GatewayApi? get api => mode == LinkMode.gateway ? GatewayApi(config) : null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode = p.getString('link_mode') == 'gateway' ? LinkMode.gateway : LinkMode.demo;
    host = p.getString('link_host') ?? 'localhost';
    port = p.getInt('link_port') ?? 8080;
    secure = p.getBool('link_secure') ?? false;
    await _use(_build());
  }

  Future<void> apply({LinkMode? mode, String? host, int? port, bool? secure}) async {
    this.mode = mode ?? this.mode;
    this.host = host ?? this.host;
    this.port = port ?? this.port;
    this.secure = secure ?? this.secure;
    final p = await SharedPreferences.getInstance();
    await p.setString('link_mode', this.mode == LinkMode.gateway ? 'gateway' : 'demo');
    await p.setString('link_host', this.host);
    await p.setInt('link_port', this.port);
    await p.setBool('link_secure', this.secure);
    await _use(_build());
  }

  Gateway _build() => mode == LinkMode.gateway ? GatewayClient(config) : MockGateway();

  Future<void> _use(Gateway next) async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final old = _gw;
    _gw = next;
    await old.dispose();

    link = LinkState.disconnected;
    status = const GatewayStatus();
    glove = null;
    car = null;
    gloveLive.value = null;
    carLive.value = null;
    latencyMs = null;
    events.clear();

    _subs.addAll([
      next.linkState.listen((s) {
        link = s;
        _touch();
      }),
      next.status.listen((s) {
        status = s;
        _touch();
      }),
      next.glove.listen((d) {
        glove = d;
        gloveLive.value = d;
        _touch();
      }),
      next.car.listen((d) {
        car = d;
        carLive.value = d;
        _touch();
      }),
      next.events.listen((e) {
        events.insert(0, e);
        if (events.length > 200) events.removeLast();
        _touch();
      }),
      next.latencyMs.listen((ms) {
        latencyMs = ms;
        _touch();
      }),
    ]);
    await next.connect();
    notifyListeners();
  }

  void _touch() {
    _dirty = true;
    _flush ??= Timer.periodic(const Duration(milliseconds: 66), (_) {
      if (_dirty) {
        _dirty = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _flush?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _gw.dispose();
    gloveLive.dispose();
    carLive.dispose();
    super.dispose();
  }
}