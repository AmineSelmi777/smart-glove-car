import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/speed.dart';

void main() {
  test('open hand gives max speed', () => expect(flexToSpeed(3200), 255));
  test('closed fist gives 0', () => expect(flexToSpeed(3900), 0));
  test('out-of-range values are clamped', () {
    expect(flexToSpeed(0), 255);
    expect(flexToSpeed(4095), 0);
  });
}