import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/drive_math.dart';
import 'package:smart_glove_app/core/models/gateway_models.dart';

CarData car(List<int> rpm, List<int> pwm) =>
    CarData(t: 0, rpm: rpm, pwm: pwm, speedKmh: 0, lights: false, estop: false, seq: 0);

void main() {
  test('speedometer scale follows the web rule', () {
    expect(speedGaugeTop(12), 15);
    expect(speedGaugeTop(8), 10);
    expect(speedGaugeTop(30), 40);
  });

  test('gears', () {
    expect(activeGears(estop: true, reverse: false, boost: false, speedKmh: 3), {Gear.park});
    expect(activeGears(estop: false, reverse: false, boost: false, speedKmh: 0), {Gear.neutral});
    expect(activeGears(estop: false, reverse: false, boost: false, speedKmh: 3), {Gear.drive});
    expect(activeGears(estop: false, reverse: false, boost: true, speedKmh: 3), {Gear.boost});
    expect(activeGears(estop: false, reverse: true, boost: false, speedKmh: 3), {Gear.reverse});
  });

  test('real packet from the gateway: straight driving', () {
    final d = deriveControl(car([151, 156, 152, 150], [122, 122, 122, 122]));
    expect(d.left, closeTo(0.478, 0.001));
    expect(d.right, closeTo(0.478, 0.001));
    expect(d.throttle, closeTo(0.478, 0.001));
    expect(d.steer, closeTo(0, 0.001));
    expect(d.reverse, isFalse);
  });

  test('left side faster means a right turn', () {
    final d = deriveControl(car([200, 100, 200, 100], [200, 100, 200, 100]));
    expect(d.steer, closeTo(0.196, 0.001));
    expect(d.throttle, closeTo(0.588, 0.001));
  });

  test('negative rpm means reverse', () {
    final d = deriveControl(car([-100, -100, -100, -100], [100, 100, 100, 100]));
    expect(d.reverse, isTrue);
    expect(d.left, lessThan(0));
    expect(d.throttle, closeTo(0.392, 0.001));
  });

  test('no car data gives zeros', () {
    final d = deriveControl(null);
    expect(d.throttle, 0);
    expect(d.left, 0);
  });

  test('openness from the flex calibration', () {
    expect(openness(1250, 1250, 2750), 1);
    expect(openness(2000, 1250, 2750), 0.5);
    expect(openness(2750, 1250, 2750), 0);
    expect(openness(4000, 1250, 2750), 0);
    expect(openness(0, 1250, 2750), 1);
  });
}