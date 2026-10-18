// Handing on a barline only when two looks of Beat This! agree on it.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/other_apps.dart';

void main() {
  test('a barline is handed on the second time it is heard, once', () {
    final filter = BarlineFilter();
    expect(filter.take([10.0, 11.16]), isEmpty);
    expect(filter.take([10.02, 11.16, 12.32]), [10.01, 11.16]);
    expect(filter.take([11.16, 12.30, 13.48]), [12.31]);
  });

  test('one said only once is never handed on', () {
    final filter = BarlineFilter();
    filter.take([10.0, 11.16]);
    // A beat early at 12.03, then not again.
    expect(filter.take([10.0, 11.16, 12.03]), [10.0, 11.16]);
    expect(filter.take([11.16, 12.32]), isEmpty);
  });
}
