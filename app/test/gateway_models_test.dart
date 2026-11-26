import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/models/gateway_models.dart';

// Real messages captured from the AXIS gateway running with the fake glove and car.
const statusJson =
    '{"type":"status","glove":{"online":true,"address":"127.0.0.1","port":57525,"rate":50,"lastSeen":1794663216641},"car":{"online":true,"address":"127.0.0.1","port":5684,"rate":20,"lastSeen":1794663216615},"coapPort":5683,"db":"axis.db","recording":null,"ips":["192.0.2.2"]}';
const gloveJson =
    '{"type":"glove","t":1794663216662,"d":{"f":1245,"r":12.47,"p":7.96,"y":23.8,"gx":-12,"gy":-0.2,"gz":3.2,"g":"none","c":0.97,"b":4.046,"s":391}}';
const carJson =
    '{"type":"car","t":1794663219631,"d":{"m":[151,156,152,150],"pw":[122,122,122,122],"v":8.3,"spd":1.87,"rssi":-62,"lt":1,"e":0,"s":216}}';

Map<String, dynamic> parse(String s) => jsonDecode(s) as Map<String, dynamic>;

void main() {
  test('status message', () {
    final s = GatewayStatus.fromJson(parse(statusJson));
    expect(s.glove.online, isTrue);
    expect(s.glove.rate, 50);
    expect(s.car.rate, 20);
    expect(s.car.address, '127.0.0.1');
    expect(s.ips, ['192.0.2.2']);
    expect(s.recordingLabel, isNull);
  });

  test('glove packet', () {
    final m = parse(gloveJson);
    final g = GloveData.fromJson(m['t'] as int, m['d'] as Map<String, dynamic>);
    expect(g.flex, 1245);
    expect(g.roll, 12.47);
    expect(g.gx, -12.0);
    expect(g.gesture, 'none');
    expect(g.batteryV, 4.046);
  });

  test('car packet', () {
    final m = parse(carJson);
    final c = CarData.fromJson(m['t'] as int, m['d'] as Map<String, dynamic>);
    expect(c.rpm, [151, 156, 152, 150]);
    expect(c.pwm, [122, 122, 122, 122]);
    expect(c.volts, 8.3);
    expect(c.speedKmh, 1.87);
    expect(c.rssi, -62);
    expect(c.lights, isTrue);
    expect(c.estop, isFalse);
  });

  test('a car packet with missing fields does not crash', () {
    final c = CarData.fromJson(0, <String, dynamic>{});
    expect(c.rpm, [0, 0, 0, 0]);
    expect(c.volts, isNull);
    expect(c.lights, isFalse);
  });

  test('drive command matches what the gateway expects', () {
    const c = DriveCommand(left: 0.6, right: 0.6, lights: true, seq: 2);
    expect(c.toJson(), {
      'type': 'drive',
      'l': 0.6,
      'r': 0.6,
      'e': false,
      'lights': true,
      'boost': false,
      'seq': 2,
    });
  });

  test('drive values are clamped to -1..1', () {
    final j = const DriveCommand(left: 1.7, right: -3).toJson();
    expect(j['l'], 1.0);
    expect(j['r'], -1.0);
  });
}