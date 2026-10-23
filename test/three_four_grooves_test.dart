// Grooves in a bar of three. Bossa, samba, funk and calypso were taken
// for figures that need a bar of four, and swing stood in for every one
// of them, so whichever was chosen on a waltz-time tune the band swung.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/swing.dart';

void main() {
  const three = Meter(3, 4);

  test('the band plays the groove chosen, not swing', () {
    for (final feel in [Feel.bossa, Feel.samba, Feel.funk, Feel.calypso]) {
      expect(BandStyle.of(feel).inMeter(three).drums, feel, reason: feel.name);
    }
    // The street beat has no bar of three, and still hands over.
    expect(BandStyle.of(Feel.secondLine).inMeter(three).drums, Feel.swing);
  });

  test('a calypso bass in three plays each bar its own chord', () {
    // One chord a bar. In four, a short chord's root is played early on
    // the "and" of 2; a bar of three has no room for that, and doing it
    // anyway put the next chord's root under this one.
    final chords = [
      for (final name in ['C', 'F', 'G7', 'C']) (Chord.parse(name), 3),
    ];
    final notes = calypsoBassLine(
      chords,
      choruses: 8,
      random: math.Random(4),
      swing: straight,
      beatsPerBar: 3,
    );
    for (var bar = 0; bar < chords.length * 8; bar++) {
      final (chord, _) = chords[bar % chords.length];
      final first = notes.firstWhere((note) => note.beat >= bar * 3 - 0.01);
      expect(first.beat, closeTo(bar * 3, 0.01), reason: 'bar $bar');
      expect(
        first.pitch % 12,
        chord.bass,
        reason: 'bar $bar: ${chord.display}',
      );
    }
  });
}
