// Comping in three. The figures were written for a bar of four and
// halved for any other, so in a waltz Twice a Bar came out as the
// Charleston and nearly every new chord landed on 1 and the "and" of 2.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';

void main() {
  /// Where the chord lands in each of [bars] bars of three, a new chord
  /// every bar, as beats rounded to a hundredth.
  List<String> landings({int bars = 400}) {
    final comper = Comper(math.Random(3));
    final chords = ['Fm7', 'Bb7', 'EbΔ7', 'C7'];
    return [
      for (var bar = 0; bar < bars; bar++)
        {
          for (final hit in comper.comp(
            Chord.parse(chords[bar % chords.length]),
            3,
            Feel.jazzWaltz,
            beatsPerBar: 3,
            bar: bar,
            swing: tripletSwing,
          ))
            hit.beat.toStringAsFixed(2),
        }.join(' '),
    ];
  }

  test('a waltz is comped in more than one place', () {
    final heard = landings();
    final counts = <String, int>{};
    for (final landing in heard) {
      counts[landing] = (counts[landing] ?? 0) + 1;
    }
    final commonest = counts.values.reduce(math.max);
    expect(commonest, lessThan(heard.length * 0.4), reason: '$counts');
  });

  test('and sometimes on 2 and 3, with the bass on 1', () {
    expect(landings(), contains('1.00 2.00'));
  });
}
