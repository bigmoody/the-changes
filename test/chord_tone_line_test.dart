// Chord tones through a form: whether the line is the exercise it says it
// is, and whether the thing the screen claims about it is true.
//
// The claim is the interesting part. The screen says that starting each
// chord from its nearest note instead of its root makes the line stop
// leaping, and it says it by putting two measurements next to each other.
// So there is a test that the nearest-note line is smooth, and a test
// that the from-the-root line really is not, because a comparison where
// both sides come out the same would be a comparison that teaches nothing
// while looking exactly like one that works.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_tone_line.dart';
import 'package:play_along/music/guide_tones.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

Tune get _blues =>
    practiceProgressions.firstWhere((t) => t.title == 'Jazz blues in F');
Tune get _rhythm =>
    practiceProgressions.firstWhere((t) => t.title == 'Rhythm changes in B♭');

List<ToneNote> _line(Tune tune, ToneExercise exercise) => chordToneLine(
  tune.slots,
  exercise: exercise,
  beatsPerBar: tune.beatsPerBar,
);

void main() {
  group('the notes a chord offers', () {
    test('a 7th chord offers its four', () {
      expect(arpeggioDegrees(Chord.parse('Dm7')), ['1', 'b3', '5', 'b7']);
      expect(arpeggioDegrees(Chord.parse('G7')), ['1', '3', '5', 'b7']);
    });

    test('a 6th chord offers its 6th where the 7th would be', () {
      expect(arpeggioDegrees(Chord.parse('Bb6')), ['1', '3', '5', '6']);
    });

    test('a sus chord offers the 4th it put in place of its 3rd', () {
      expect(arpeggioDegrees(Chord.parse('C7sus4')), ['1', '4', '5', 'b7']);
    });

    test('extensions are left out: this is an arpeggio, not a voicing', () {
      expect(arpeggioDegrees(Chord.parse('C13')), ['1', '3', '5', 'b7']);
      expect(arpeggioDegrees(Chord.parse('C^9')), ['1', '3', '5', '7']);
    });

    test('a chord with no 5th in it simply has three', () {
      expect(arpeggioDegrees(Chord.parse('C7alt')), ['1', '3', 'b7']);
    });

    test('they come out lowest first, whatever order the formula is in', () {
      for (final symbol in ['Co7', 'C+7', 'Cm6', 'C7sus4', 'Ch7']) {
        final degrees = arpeggioDegrees(Chord.parse(symbol));
        final pitches = [for (final d in degrees) degreeToSemitones(d)];
        expect(
          pitches,
          [...pitches]..sort(),
          reason: '$symbol came out of order',
        );
      }
    });
  });

  group('one note per beat', () {
    test('the running exercises fill every beat of the form', () {
      final tune = _blues;
      final beats = tune.slots.fold(0, (sum, slot) => sum + slot.beats);
      for (final exercise in [
        ToneExercise.fromTheRoot,
        ToneExercise.nearest,
        ToneExercise.upAndDown,
      ]) {
        expect(
          _line(tune, exercise).length,
          beats,
          reason: '${exercise.label} did not fill the chorus',
        );
      }
    });

    test('a waltz gets three to the bar without being told', () {
      final waltz = practiceProgressions.firstWhere((t) => t.beatsPerBar == 3);
      final line = chordToneLine(
        waltz.slots,
        exercise: ToneExercise.nearest,
        beatsPerBar: 3,
      );
      expect(line.length, waltz.barCount * 3);
      expect(line.map((n) => n.beat).toSet(), {0, 1, 2});
    });

    test('the landing exercises play once per chord and hold it', () {
      final tune = _blues;
      for (final exercise in [
        ToneExercise.landOnTheThird,
        ToneExercise.landOnTheSeventh,
      ]) {
        final line = _line(tune, exercise);
        expect(line.length, tune.slots.length);
        expect(
          [for (final note in line) note.beats],
          [for (final slot in tune.slots) slot.beats],
        );
        expect(line.every((note) => note.opens), isTrue);
      }
    });

    test('nothing in, nothing out', () {
      expect(chordToneLine(const [], exercise: ToneExercise.nearest), isEmpty);
    });
  });

  group('what it plays', () {
    test('every note is a chord tone of the chord it is on', () {
      for (final exercise in ToneExercise.values) {
        for (final note in _line(_rhythm, exercise)) {
          expect(
            note.pitch % 12,
            note.chord.pitchClassFor(note.degree),
            reason:
                '${note.name} is not the ${note.degree} of '
                '${note.chord.display}',
          );
        }
      }
    });

    test('notes are spelled the way their chord spells them', () {
      final line = chordToneLine(
        Tune.fromChart(
          title: 'x',
          key: 'B♭ minor',
          chart: '| Bbm7 | Eb7 |',
          defaultTempo: 120,
        ).slots,
        exercise: ToneExercise.fromTheRoot,
      );
      expect(line.map((n) => n.name), [
        'B♭',
        'D♭',
        'F',
        'A♭',
        'E♭',
        'G',
        'B♭',
        'D♭',
      ]);
    });

    test('the landing exercises land where they say they do', () {
      for (final note in _line(_blues, ToneExercise.landOnTheThird)) {
        expect(
          note.pitch % 12,
          note.chord.pitchClassFor(thirdDegreeOf(note.chord)),
          reason: 'not the 3rd of ${note.chord.display}',
        );
      }
      for (final note in _line(_blues, ToneExercise.landOnTheSeventh)) {
        expect(
          note.pitch % 12,
          note.chord.pitchClassFor(seventhDegreeOf(note.chord)),
          reason: 'not the 7th of ${note.chord.display}',
        );
      }
    });

    test('bars and beats follow the chart', () {
      final line = _line(_blues, ToneExercise.nearest);
      expect(line.first.bar, 0);
      expect(line.first.beat, 0);
      expect(line.last.bar, _blues.barCount - 1);
      // Bar 4 of this blues is Cm7 F7, two beats each.
      final bar4 = line.where((note) => note.bar == 3).toList();
      expect(
        [for (final n in bar4) n.chord.display],
        ['Cm7', 'Cm7', 'F7', 'F7'],
      );
      expect([for (final n in bar4) n.beat], [0, 1, 2, 3]);
      expect([for (final n in bar4) n.opens], [true, false, true, false]);
    });
  });

  group('staying on the horn', () {
    test('the connected lines never leave the range', () {
      for (final exercise in [ToneExercise.nearest, ToneExercise.upAndDown]) {
        for (final tune in [_blues, _rhythm]) {
          final line = chordToneLine(
            tune.slots,
            exercise: exercise,
            low: 55,
            high: 79,
            beatsPerBar: tune.beatsPerBar,
          );
          final (low, high) = rangeOf(line);
          expect(low, greaterThanOrEqualTo(55));
          expect(high, lessThanOrEqualTo(79));
        }
      }
    });

    test('a narrow range makes it turn round more, not give up', () {
      final line = chordToneLine(
        _blues.slots,
        exercise: ToneExercise.nearest,
        low: 60,
        high: 72,
      );
      final beats = _blues.slots.fold(0, (sum, slot) => sum + slot.beats);
      expect(line.length, beats);
      final (low, high) = rangeOf(line);
      expect(low, greaterThanOrEqualTo(60));
      expect(high, lessThanOrEqualTo(72));
    });

    test('up and down turns round at every chord', () {
      final line = _line(_blues, ToneExercise.upAndDown);
      // Within a chord the run only goes one way, and the way alternates.
      final runs = <int>[];
      for (final note in line) {
        if (note.opens) {
          runs.add(0);
        } else if (runs.last == 0) {
          runs[runs.length - 1] = note.step.sign;
        }
      }
      final ways = runs.where((way) => way != 0).toList();
      for (var i = 1; i < ways.length; i++) {
        expect(
          ways[i],
          isNot(ways[i - 1]),
          reason: 'two runs in a row went the same way',
        );
      }
    });
  });

  group('the claim the screen makes', () {
    test('the nearest note keeps the changes to a step', () {
      for (final tune in [_blues, _rhythm]) {
        final line = _line(tune, ToneExercise.nearest);
        final changes = changesIn(line);
        expect(biggestJumpAtChanges(line), lessThanOrEqualTo(4));
        // "Nearly all of them" is the claim, so nearly all of them is what
        // gets checked, rather than a number that happens to be right for
        // one tune today.
        expect(
          changesWithin(line, 2),
          greaterThan(changes.length * 0.8),
          reason:
              '${tune.title}: only ${changesWithin(line, 2)} of '
              '${changes.length} changes were within a tone',
        );
      }
    });

    test('from the root really does leap, or there is nothing to show', () {
      for (final tune in [_blues, _rhythm]) {
        final naive = _line(tune, ToneExercise.fromTheRoot);
        final connected = _line(tune, ToneExercise.nearest);
        expect(
          biggestJumpAtChanges(naive),
          greaterThan(biggestJumpAtChanges(connected) * 2),
          reason:
              '${tune.title}: the two exercises came out alike, so the '
              'comparison on the screen is not showing anything',
        );
        expect(changesWithin(naive, 2), lessThan(changesWithin(connected, 2)));
      }
    });

    test('the measurements are of the line they are given', () {
      final line = _line(_blues, ToneExercise.nearest);
      expect(changesIn(line).length, _blues.slots.length - 1);
      expect(changesIn(line).every((note) => note.opens), isTrue);
      expect(
        biggestJump(line),
        greaterThanOrEqualTo(biggestJumpAtChanges(line)),
      );
    });
  });
}
