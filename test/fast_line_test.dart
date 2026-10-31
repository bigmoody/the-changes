// The Playing Fast example: eight bars of running eighths in F.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/practice/licks.dart';

void main() {
  test('eight bars, eighths all the way to the last note', () {
    expect(fastLine.beats, 32);
    final line = lickIn(fastLine, 'F', floor: 58);
    for (var i = 0; i < line.length - 1; i++) {
      expect(line[i].at, i * 0.5, reason: 'note ${i + 1}');
    }
    expect(line.last.at, 28);
    // Nothing leaps more than a sixth, and it stays where a horn plays.
    for (var i = 1; i < line.length; i++) {
      expect((line[i].pitch - line[i - 1].pitch).abs(), lessThanOrEqualTo(9));
    }
    for (final note in line) {
      expect(note.pitch, inInclusiveRange(60, 82));
    }
  });

  test('it spells what it plays', () {
    final names = [for (final n in lickIn(fastLine, 'F', floor: 58)) n.name];
    expect(names.take(8), ['G', 'A', 'B♭', 'C', 'D', 'F', 'E', 'D']);
    // Over the D7, its ♭9.
    expect(names[29], 'E♭');
    expect(names.last, 'A');
  });
}
