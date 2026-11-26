double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
int _i(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
double _r3(double v) => (v * 1000).round() / 1000;
double _unit(double v) => v < -1 ? -1 : (v > 1 ? 1 : v);

class DeviceInfo {
  const DeviceInfo({this.online = false, this.address, this.rate = 0});
  final bool online;
  final String? address;
  final int rate; // packets per second

  factory DeviceInfo.fromJson(Object? j) {
    if (j is! Map) return const DeviceInfo();
    return DeviceInfo(
      online: j['online'] == true,
      address: j['address'] as String?,
      rate: _i(j['rate']),
    );
  }
}

class GatewayStatus {
  const GatewayStatus({
    this.glove = const DeviceInfo(),
    this.car = const DeviceInfo(),
    this.ips = const [],
    this.recordingLabel,
  });
  final DeviceInfo glove;
  final DeviceInfo car;
  final List<String> ips;
  final String? recordingLabel;

  factory GatewayStatus.fromJson(Map<String, dynamic> j) {
    final rec = j['recording'];
    return GatewayStatus(
      glove: DeviceInfo.fromJson(j['glove']),
      car: DeviceInfo.fromJson(j['car']),
      ips: (j['ips'] as List?)?.whereType<String>().toList() ?? const [],
      recordingLabel: rec is Map ? rec['label'] as String? : null,
    );
  }
}

class GloveData {
  const GloveData({
    required this.t,
    required this.flex,
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.gesture,
    required this.confidence,
    required this.seq,
    this.batteryV,
  });
  final int t; // gateway timestamp, ms
  final int flex; // raw ADC 0..4095
  final double roll, pitch, yaw; // degrees
  final double gx, gy, gz; // deg/s
  final String gesture; // none | estop | boost | lights
  final double confidence;
  final double? batteryV;
  final int seq;

  factory GloveData.fromJson(int t, Map<String, dynamic> d) => GloveData(
        t: t,
        flex: _i(d['f']),
        roll: _d(d['r']),
        pitch: _d(d['p']),
        yaw: _d(d['y']),
        gx: _d(d['gx']),
        gy: _d(d['gy']),
        gz: _d(d['gz']),
        gesture: (d['g'] as String?) ?? 'none',
        confidence: _d(d['c']),
        batteryV: d['b'] is num ? _d(d['b']) : null,
        seq: _i(d['s']),
      );
}

class CarData {
  const CarData({
    required this.t,
    required this.rpm,
    required this.pwm,
    required this.speedKmh,
    required this.lights,
    required this.estop,
    required this.seq,
    this.volts,
    this.rssi,
  });
  final int t;
  final List<int> rpm; // FL FR RL RR
  final List<int> pwm; // 0..255
  final double speedKmh;
  final double? volts;
  final int? rssi; // dBm
  final bool lights;
  final bool estop;
  final int seq;

  factory CarData.fromJson(int t, Map<String, dynamic> d) {
    List<int> four(Object? v) {
      final l = v is List ? v.map((e) => _i(e)).toList() : <int>[];
      while (l.length < 4) {
        l.add(0);
      }
      return l.take(4).toList();
    }

    return CarData(
      t: t,
      rpm: four(d['m']),
      pwm: four(d['pw']),
      speedKmh: _d(d['spd']).abs(),
      volts: d['v'] is num ? _d(d['v']) : null,
      rssi: d['rssi'] is num ? _i(d['rssi']) : null,
      lights: _i(d['lt']) != 0 || d['lt'] == true,
      estop: _i(d['e']) != 0 || d['e'] == true,
      seq: _i(d['s']),
    );
  }
}

class GatewayEvent {
  const GatewayEvent({
    required this.ts,
    required this.level,
    required this.source,
    required this.code,
    this.message = '',
  });
  final int ts;
  final String level; // info | ok | warn | error
  final String source; // server | glove | car | app
  final String code;
  final String message;

  factory GatewayEvent.fromJson(Map<String, dynamic> e) => GatewayEvent(
        ts: _i(e['ts']),
        level: (e['level'] as String?) ?? 'info',
        source: (e['source'] as String?) ?? 'server',
        code: (e['code'] as String?) ?? 'event',
        message: (e['message'] as String?) ?? '',
      );
}

/// Command sent to the car through the gateway: left/right duty -1..1.
class DriveCommand {
  const DriveCommand({
    this.left = 0,
    this.right = 0,
    this.estop = false,
    this.lights = false,
    this.boost = false,
    this.seq = 0,
  });
  final double left, right;
  final bool estop, lights, boost;
  final int seq;

  static const stop = DriveCommand();

  Map<String, dynamic> toJson() => {
        'type': 'drive',
        'l': _r3(_unit(left)),
        'r': _r3(_unit(right)),
        'e': estop,
        'lights': lights,
        'boost': boost,
        'seq': seq,
      };
}