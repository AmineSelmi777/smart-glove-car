import 'package:flutter_test/flutter_test.dart';
import 'package:smart_glove_app/core/battery.dart';

void main() {
  test('8.3 V on 2S is 95 %, like the web dashboard shows', () {
    expect(lipoPercent(8.3), closeTo(95, 0.01));
  });

  test('empty and full are clamped', () {
    expect(lipoPercent(6.0), 0);
    expect(lipoPercent(8.5), 100);
  });
}