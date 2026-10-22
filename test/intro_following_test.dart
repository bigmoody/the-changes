// Following a band by ear through a tune with an intro, in three: Valse
// Hot's shape. The band plays the intro once and goes round the A
// section; the count, and the search for which bar the band is in, have
// to go round with it, not back to an intro that never comes again.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/form_finder.dart';
import 'package:play_along/practice/tap_follower.dart';

/// Eight bars of intro, then a sixteen bar A, in three.
final _valse = Tune.fromChart(
  title: 'A Waltz With an Intro',
  key: 'Ab',
  defaultTempo: 180,
  beatsPerBar: 3,
  chart:
      '| [Intro] Bbm7 | Eb7 | AbΔ7 | AbΔ7 | Ebm7 | Ab7 | DbΔ7 | DbΔ7 '
      '| [A] AbΔ7 | DbΔ7 | Cm7 | F7 | Bbm7 | Eb7 | AbΔ7 | F7 '
      '| Bbm7 | Dbm6 | Cm7 | F7 | Bbm7 | Eb7 | AbΔ7 | Eb7 |',
);

void main() {
  final intro = introOf(_valse);

  test('past the end, the count goes round from after the intro', () {
    expect(_valse.barCount, 24);
    expect(wrapBar(_valse, 23, intro: intro), 23);
    expect(wrapBar(_valse, 24, intro: intro), 8, reason: 'the A again');
    expect(wrapBar(_valse, 39, intro: intro), 23);
    expect(wrapBar(_valse, 40, intro: intro), 8);
    expect(wrapBeat(_valse, 72, intro: intro), 24);
    // Without an intro, round from the top as it always was.
    expect(wrapBar(_valse, 24), 0);
  });

  test('the tapped count runs through the intro and round the A', () {
    var now = Duration.zero;
    final taps = TapFollower(tune: _valse, clock: () => now);
    addTearDown(taps.dispose);
    const beat = Duration(microseconds: 333333); // 180 to the minute
    taps.placeAtBar(0);
    for (var i = 0; i < 4; i++) {
      now += beat;
      taps.tapBeat();
    }
    taps.placeAtBar(0);
    // The whole tune once: 24 bars of three.
    now += beat * 72;
    expect(taps.barAt(now), 8, reason: 'into the A, not the intro');
    now += beat * 48;
    expect(taps.barAt(now), 8, reason: 'and round the A again');
    taps.stop();
  });

  test('the bar is found on the second time round the A', () {
    // What sounds in bar [index]: its chord, harmony and bass, for each
    // half of a bar of three (the first beat, then the other two).
    List<double> soundOf(int index) {
      final out = <double>[];
      for (var half = 0; half < 2; half++) {
        final chord = _valse.slotAtBeat(index * 3 + half * (3 ~/ 2)).chord;
        final harmony = List<double>.filled(12, 0.1);
        for (final pc in chord.pitchClasses) {
          harmony[pc] = 1;
        }
        final bass = List<double>.filled(12, 0.1)..[chord.bass] = 1;
        out
          ..addAll(harmony)
          ..addAll(bass);
      }
      return out;
    }

    const bar = Duration(seconds: 1);
    final form = FormFinder(tune: _valse);
    // The band is twelve bars into its second time round the A; the
    // count, started by ear, calls that bar 1.
    for (var i = 0; i < 14; i++) {
      form.heard(bar * i, soundOf(wrapBar(_valse, 28 + i, intro: intro)));
    }
    final shift = form.shift(
      (at) => wrapBar(_valse, at.inSeconds, intro: intro),
    );
    expect(shift, isNotNull);
    expect(wrapBar(_valse, 0 + shift!, intro: intro), 12);
  });

  test('a quick waltz starts its count from the barlines heard', () {
    // At 240 a bar of three is three quarters of a second, under the
    // shortest bar of four the count used to take (0.8 s), so its bars
    // were turned away as half bars and it never started.
    var now = Duration.zero;
    final taps = TapFollower(tune: _valse, clock: () => now);
    addTearDown(taps.dispose);
    const bar = Duration(milliseconds: 750);
    for (var i = 0; i < 6; i++) {
      now += bar;
      taps.heardBarline(Duration.zero);
    }
    expect(taps.counting, isTrue);
    expect(taps.tempo, closeTo(240, 1));
    taps.stop();
  });
}
