// A chord held for a line: FΔ7 and three bars of repeat signs.
//
// The comper backs off a chord that is still sounding, and it backed off
// so far that the piano all but left after the first bar: bars 2 to 4
// rested one time in three and were struck at under two thirds of bar 1.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune.dart';

void main() {
  test('the piano is still there in bars 2 to 4 of a held chord', () {
    final chord = Chord.parse('Fmaj7');
    final played = List.filled(4, 0);
    final peak = List.filled(4, 0.0);
    const seeds = 400;
    for (var seed = 0; seed < seeds; seed++) {
      final comper = Comper(math.Random(seed));
      comper.comp(Chord.parse('C7'), 4, Feel.swing, swing: 0.62);
      for (var bar = 0; bar < 4; bar++) {
        final hits = comper.comp(chord, 4, Feel.swing, swing: 0.62);
        if (hits.isEmpty) continue;
        played[bar]++;
        peak[bar] += hits.map((hit) => hit.velocity).reduce(math.max);
      }
    }
    for (var bar = 1; bar < 4; bar++) {
      expect(played[bar] / seeds, greaterThan(0.65), reason: 'bar ${bar + 1}');
      expect(
        peak[bar] / played[bar],
        greaterThan(peak[0] / played[0] * 0.75),
        reason: 'bar ${bar + 1} against bar 1',
      );
    }
    // Still backing off, a little, the longer it sits.
    expect(played[3], lessThan(played[1]));
  });
}
