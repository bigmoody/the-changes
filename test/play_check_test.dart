// Checking what you played against what you were asked for: which changes
// you landed on, which you missed, and which can't be asked at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord_drill.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tuning.dart';
import 'package:play_along/practice/play_check.dart';

/// A ii–V–I in C, a bar each.
Tune _twoFiveOne() => Tune.fromChart(
  title: 'ii V I',
  key: 'C',
  defaultTempo: 120,
  chart: '| Dm7 | G7 | CΔ7 | CΔ7 |',
);

PlayCheck _check([DrillTarget target = DrillTarget.third]) =>
    PlayCheck(tune: _twoFiveOne(), target: target);

/// Plays [note] (a pitch class) somewhere in the middle of the instrument.
double _midi(int pitchClass, {int octave = 4}) =>
    (12 * (octave + 1) + pitchClass).toDouble();

void main() {
  group('landing on the note', () {
    test('the 3rd of each chord, in any octave', () {
      final check = _check();
      // Bar 1, Dm7: the 3rd is F.
      check.moveTo(0, 0);
      expect(check.current!.chord.display, 'Dm7');
      expect(check.current!.asked, 'F (♭3)');
      check.note(_midi(5)); // F, low down
      check.moveTo(4, 0);
      // Bar 2, G7: the 3rd is B, played two octaves higher.
      check.note(_midi(11, octave: 6));
      check.moveTo(8, 0);
      // Bar 3, CΔ7: the 3rd is E — play a D instead.
      check.note(_midi(2));
      check.moveTo(12, 0);
      check.finish();

      expect(check.asked, 3);
      expect(check.hits, 2);
      expect(check.misses, 1);
      expect(check.accuracy, closeTo(2 / 3, 0.001));
      expect([for (final c in check.done) c.hit], [true, true, false]);
      expect(check.describe(), '2 of 3');
    });

    test('a note nobody could name is dropped', () {
      final check = _check();
      check.moveTo(0, 0);
      // Halfway between E and F: too vague to call either way.
      check.note(_midi(5) - 0.5);
      expect(check.current!.played, isFalse);
      // A little flat of F is still F.
      check.note(_midi(5) - 0.3);
      expect(check.current!.hit, isTrue);
    });

    test('playing nothing at all is a miss, not a pass', () {
      final check = _check();
      check.moveTo(0, 0);
      check.moveTo(4, 0);
      check.finish();
      expect(check.asked, 1);
      expect(check.hits, 0);
      expect(check.done.single.played, isFalse);
    });
  });

  group('the seams between chords', () {
    test('anticipating the change counts towards the chord coming', () {
      final check = _check();
      check.moveTo(0, 0); // Dm7, bar 1
      check.moveTo(3, 0); // still Dm7, its last beat
      check.note(_midi(11)); // B — the 3rd of the G7 about to arrive
      check.moveTo(4, 0); // G7
      check.moveTo(8, 0);
      check.finish();
      // The CΔ7 was never played on and was cut off by Stop, so it isn't
      // marked either way: only the two that finished are.
      expect([for (final c in check.done) c.hit], [false, true]);
    });

    test('a note read a moment late still counts for the chord it was on', () {
      final check = _check();
      check.moveTo(0, 0);
      check.moveTo(4, 0); // G7 has just arrived
      // F, the 3rd of the Dm7 that has only this instant finished: the
      // detector is always a little behind the player.
      check.note(_midi(5));
      check.moveTo(8, 0);
      check.finish();
      expect(check.done.first.chord.display, 'Dm7');
      expect(check.done.first.hit, isTrue, reason: 'the lag is forgiven');
    });

    test('but not a note played well inside the chord before', () {
      final check = _check();
      check.moveTo(0, 0);
      check.moveTo(1, 0);
      check.note(_midi(11)); // B, early in the Dm7 bar
      check.moveTo(4, 0);
      check.moveTo(8, 0);
      check.finish();
      // It didn't count for the G7 two beats later.
      expect([for (final c in check.done) c.hit], [false, false]);
    });
  });

  group('chords that cannot be asked', () {
    test('a 6th chord has no 7th, so it is skipped', () {
      final check = PlayCheck(
        tune: Tune.fromChart(
          title: 'Sixes',
          key: 'C',
          defaultTempo: 120,
          chart: '| C6 | G7 |',
        ),
        target: DrillTarget.seventh,
      );
      check.moveTo(0, 0);
      // A 6th chord's 6th stands in for its 7th, so it is asked after all.
      expect(check.current, isNotNull);
      expect(check.current!.asked, 'A (6)');

      final noSeventh = PlayCheck(
        tune: Tune.fromChart(
          title: 'Triads',
          key: 'C',
          defaultTempo: 120,
          chart: '| C | G7 |',
        ),
        target: DrillTarget.seventh,
      );
      noSeventh.moveTo(0, 0);
      expect(noSeventh.current, isNull, reason: 'a triad has no 7th');
      noSeventh.note(_midi(4)); // nothing to land on; nothing recorded
      noSeventh.moveTo(4, 0);
      noSeventh.finish();
      expect(noSeventh.asked, 0, reason: 'it was never asked');
    });

    test('guide tones: either one counts', () {
      final check = _check(DrillTarget.guideTones);
      check.moveTo(0, 0);
      expect(check.current!.asked, 'F (♭3) · C (♭7)');
      check.note(_midi(0)); // the ♭7 alone
      expect(check.current!.hit, isTrue);
    });
  });

  group('round and round', () {
    test('each chorus is scored again', () {
      final check = _check();
      for (var chorus = 0; chorus < 2; chorus++) {
        check.moveTo(0, chorus);
        if (chorus == 1) check.note(_midi(5)); // found it the second time
        check.moveTo(4, chorus);
        check.moveTo(8, chorus);
        check.moveTo(12, chorus);
      }
      check.finish();
      // Three changes the first time round (bars 3 and 4 are one chord),
      // two the second — its last chord was still sounding at the end.
      expect(check.asked, 5);
      expect(check.hits, 1);
      expect([for (final c in check.done) c.chorus], [0, 0, 0, 1, 1]);
    });

    test('a bar repeating the same chord is one change, not two', () {
      final check = _check();
      check.moveTo(8, 0); // CΔ7, bar 3
      check.moveTo(12, 0); // CΔ7 again, bar 4 — the same chord
      check.finish();
      expect(check.asked, 0, reason: 'nothing was played on it');
      expect(check.done, isEmpty);
    });
  });

  test('it reads the pitch the microphone actually hears', () {
    // Concert pitch throughout: a trumpeter reading D sounds C, and it is
    // the C that has to match the chart's C chord.
    final check = _check();
    check.moveTo(8, 0); // CΔ7, the 3rd is E
    check.note(hzToMidi(329.63)); // E4
    expect(check.current!.hit, isTrue);
  });
}
