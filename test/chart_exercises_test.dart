// Exercises generated from whatever chart is in front of you.
//
// The point of generating them is that they work on any tune, including
// one somebody typed in this morning, so most of what is checked here is
// checked against every chart in the library and then against a chart
// invented for the test. Nothing in the generator may know a tune's name.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chart_exercises.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

/// A chart nobody has ever played, to stand in for one somebody writes or
/// imports: chords the library does not use, in a bar length it does not
/// use either.
Tune invented() => Tune.fromChart(
  title: 'Something Somebody Typed In',
  key: 'E',
  defaultTempo: 120,
  chart: '| [A] E7#11 | Abh7 | Co7 | F#m6 Bsus4 | DbΔ7 | G+ |',
);

void main() {
  group('it works on any chart at all', () {
    test('every tune in the library, every exercise', () {
      for (final tune in standards) {
        for (final which in ChartExercise.values) {
          expect(
            exerciseOver(tune, which),
            isNotEmpty,
            reason: '${tune.title} / ${which.label}',
          );
        }
      }
    });

    test('and a chart invented for the occasion', () {
      // The whole reason for generating rather than writing: a tune that
      // did not exist when this was built has to work as well as one that
      // did.
      for (final which in ChartExercise.values) {
        expect(
          exerciseOver(invented(), which),
          isNotEmpty,
          reason: which.label,
        );
      }
    });

    test('nothing lands before the tune starts', () {
      for (final tune in standards) {
        for (final which in ChartExercise.values) {
          for (final note in exerciseOver(tune, which)) {
            expect(
              note.beat,
              greaterThanOrEqualTo(0),
              reason: '${tune.title} / ${which.label}',
            );
          }
        }
      }
    });

    test('and the notes come in order', () {
      for (final tune in standards) {
        for (final which in ChartExercise.values) {
          final line = exerciseOver(tune, which);
          for (var i = 1; i < line.length; i++) {
            expect(
              line[i].beat,
              greaterThanOrEqualTo(line[i - 1].beat),
              reason: '${tune.title} / ${which.label} at $i',
            );
          }
        }
      }
    });

    test('and all of it is playable and readable', () {
      // One range, so the line is one line rather than a row of shapes
      // in whatever octave each chord happened to land in.
      for (final tune in [...standards, invented()]) {
        for (final which in ChartExercise.values) {
          for (final note in exerciseOver(tune, which)) {
            expect(note.pitch, greaterThanOrEqualTo(exerciseLowest));
            expect(note.pitch, lessThanOrEqualTo(exerciseHighest));
          }
        }
      }
    });

    test('every note is spelled, so every note can be written', () {
      // A letter and its accidentals, which is what the stave reads. Not
      // parseNoteName: a diminished chord's ♭♭7 is spelled G𝄫 and that is
      // correct, the stave draws a double flat, and parseNoteName does
      // not take one. Checking with it failed nine tunes for being right.
      for (final tune in [...standards, invented()]) {
        for (final which in ChartExercise.values) {
          for (final note in exerciseOver(tune, which)) {
            expect(note.name, isNotEmpty);
            expect(
              'ABCDEFG'.contains(note.name[0]),
              isTrue,
              reason: 'a note called "${note.name}"',
            );
          }
        }
      }
    });
  });

  group('arpeggios', () {
    test('every note is in the chord', () {
      // Nothing else going on: that is what makes it the first one.
      for (final tune in [...standards, invented()]) {
        for (final note in exerciseOver(tune, ChartExercise.arpeggio)) {
          final tones = {
            for (final interval in note.chord.quality.intervals) interval % 12,
          };
          expect(
            tones.contains((note.pitch - note.chord.root) % 12),
            isTrue,
            reason: '${tune.title}: ${note.name} over ${note.chord.display}',
          );
        }
      }
    });

    test('and it turns round at each chord rather than climbing away', () {
      // Up through one, down through the next, which is how it is
      // practised and what keeps a chorus inside one register. By beat
      // and not by chord: the same chord turns up in several bars, so
      // grouping by it mixes a bar going up with one coming down.
      final line = exerciseOver(
        standards.firstWhere((t) => t.title == 'Autumn Leaves'),
        ChartExercise.arpeggio,
      );
      final up = line.where((n) => n.beat < 4).toList();
      final down = line.where((n) => n.beat >= 4 && n.beat < 8).toList();
      expect(up.last.pitch, greaterThan(up.first.pitch));
      expect(down.last.pitch, lessThan(down.first.pitch));
    });
  });

  group('guide tones', () {
    test('one note a chord, held for the whole of it', () {
      for (final tune in standards) {
        final slots = slotsOf(tune);
        final line = exerciseOver(tune, ChartExercise.guideTones);
        expect(line.length, slots.length, reason: tune.title);
        for (final (i, note) in line.indexed) {
          expect(note.length, slots[i].beats, reason: tune.title);
        }
      }
    });

    test('and it is the 3rd or the 7th every time', () {
      for (final tune in [...standards, invented()]) {
        for (final note in exerciseOver(tune, ChartExercise.guideTones)) {
          final above = (note.pitch - note.chord.root) % 12;
          // 3rds and 7ths, major or minor, and the stand-ins guide_tones
          // falls back on for a chord with neither.
          expect(
            const [3, 4, 10, 11, 9, 5, 8, 0].contains(above),
            isTrue,
            reason: '${note.chord.display} got ${note.degree}',
          );
        }
      }
    });

    test('they barely move, which is the whole idea', () {
      // Not a claim about any one tune: over the library, most changes
      // should move the line by a tone or less.
      var small = 0, all = 0;
      for (final tune in standards) {
        final line = exerciseOver(tune, ChartExercise.guideTones);
        for (var i = 1; i < line.length; i++) {
          all++;
          if ((line[i].pitch - line[i - 1].pitch).abs() <= 2) small++;
        }
      }
      expect(small / all, greaterThan(0.75));
    });
  });

  group('3 to 7', () {
    test('the 3rd, then the 7th, on every chord', () {
      for (final tune in [...standards, invented()]) {
        final line = exerciseOver(tune, ChartExercise.threeToSeven);
        for (var i = 0; i + 1 < line.length; i += 2) {
          final third = (line[i].pitch - line[i].chord.root) % 12;
          final seventh = (line[i + 1].pitch - line[i + 1].chord.root) % 12;
          expect(
            const [3, 4, 5, 2].contains(third),
            isTrue,
            reason: '${line[i].chord.display} opened on ${line[i].degree}',
          );
          expect(
            // 8 is the ♯5, which guide_tones hands back for a chord with
            // no 7th at all: an augmented triad has one of those.
            const [10, 11, 9, 8, 0].contains(seventh),
            isTrue,
            reason:
                '${line[i + 1].chord.display} answered with '
                '${line[i + 1].degree}',
          );
        }
      }
    });

    test('and in a ii–V–I the hand-over is a semitone, every time', () {
      // The crisp version of the claim, on the progression it is named
      // for: the 7th of the ii falls a semitone to the 3rd of the V, and
      // the 7th of the V falls a semitone to the 3rd of the I.
      final line = exerciseOver(
        Tune.fromChart(
          title: 'A ii–V–I',
          key: 'C',
          defaultTempo: 120,
          chart: '| Dm7 | G7 | CΔ7 | CΔ7 |',
        ),
        ChartExercise.threeToSeven,
      );
      expect(line[2].pitch - line[1].pitch, -1);
      expect(line[4].pitch - line[3].pitch, -1);
    });

    test('and a semitone is what it mostly is over a whole book', () {
      // Measured rather than asserted: of 6188 hand-overs in the library
      // 2625 are a semitone, which is 42 per cent and nearly three times
      // the next most common step. Charts are not all ii–Vs, so the rest
      // are whatever the harmony asks for.
      final steps = <int, int>{};
      for (final tune in standards) {
        final line = exerciseOver(tune, ChartExercise.threeToSeven);
        for (var i = 1; i + 1 < line.length; i += 2) {
          final step = (line[i + 1].pitch - line[i].pitch).abs();
          steps[step] = (steps[step] ?? 0) + 1;
        }
      }
      final all = steps.values.reduce((a, b) => a + b);
      final commonest = steps.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      expect(commonest.key, 1);
      expect(steps[1]! / all, greaterThan(0.33));
    });
  });

  group('bebop scales', () {
    test('eight notes to a four-beat bar, not seven', () {
      // The whole trick, and the reason the scale has a note added to it.
      final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
      final line = exerciseOver(tune, ChartExercise.bebop);
      for (final slot in slotsOf(tune)) {
        if (slot.beats != 4) continue;
        final run = line.where(
          (n) => n.beat >= slot.startBeat && n.beat < slot.startBeat + 4,
        );
        expect(run.length, 8, reason: slot.chord.display);
      }
    });

    test('and the chord tones land on the beats', () {
      // What the added note is *for*, checked on every chord of every
      // tune that has a scale to build one from, ascending and
      // descending alike.
      for (final tune in [...standards, invented()]) {
        final line = exerciseOver(tune, ChartExercise.bebop);
        for (final slot in slotsOf(tune)) {
          if (slot.beats != 4) continue;
          final run = line
              .where(
                (n) => n.beat >= slot.startBeat && n.beat < slot.startBeat + 4,
              )
              .toList();
          if (run.length != 8) continue; // a chord with no scale: held
          final onBeats = bebopBeatTonesOf(slot.chord);
          expect(onBeats, hasLength(4), reason: slot.chord.display);
          for (var i = 0; i < run.length; i += 2) {
            expect(
              onBeats.contains((run[i].pitch - slot.chord.root) % 12),
              isTrue,
              reason:
                  '${tune.title}: ${slot.chord.display} has '
                  '${run[i].name} on beat ${i ~/ 2 + 1}',
            );
          }
        }
      }
    });

    test('and they are the chord\'s own notes, bar one case', () {
      // The claim, said once rather than restated loosely by the test
      // above. Over a major 7th there is no eight-note scale that keeps
      // the 7th on a beat, because the 7th is a semitone under the root
      // and there is no room for a note between them. The 6th stands in,
      // which is the major bebop scale and is why a major tune so often
      // wants a 6 where you expected a Δ7.
      for (final tune in [...standards, invented()]) {
        for (final slot in slotsOf(tune)) {
          final chord = slot.chord;
          final onBeats = bebopBeatTonesOf(chord);
          if (onBeats.isEmpty) continue;
          final own = {for (final i in chord.quality.intervals.take(4)) i % 12};
          if (onBeats.containsAll(own)) continue;
          // The only allowed difference: a 6th where the major 7th was.
          expect(own.difference(onBeats), {11}, reason: chord.display);
          expect(onBeats.difference(own), {9}, reason: chord.display);
        }
      }
    });

    test('the added note is found rather than looked up', () {
      // A half-diminished is not one of the three named bebop scales, and
      // it gets the same treatment anyway: locrian with a natural 7th on
      // top, and the ♭5 still lands on a beat.
      final half = Chord.parse('Ch7');
      final degrees = bebopDegreesOf(half);
      expect(degrees, isNotNull);
      expect(degrees!.length, 8);
      expect(degrees, containsAllInOrder([0, 3, 6, 10, 11]));
    });

    test('and the three it does know come out as themselves', () {
      expect(
        bebopNameOf(Chord.parse('C7'), bebopDegreesOf(Chord.parse('C7'))!),
        'Dominant Bebop',
      );
      expect(
        bebopNameOf(Chord.parse('Cm7'), bebopDegreesOf(Chord.parse('Cm7'))!),
        'Minor Bebop',
      );
    });
  });

  group('enclosures', () {
    test('the target is the 3rd and it lands on the chord', () {
      // Arriving a beat late is the one thing this exercise must not do,
      // so the way in sits in the beats before the change.
      for (final tune in standards) {
        final line = exerciseOver(tune, ChartExercise.enclosure);
        final starts = {for (final slot in slotsOf(tune)) slot.startBeat};
        for (final note in line.where((n) => n.target)) {
          expect(
            starts.contains(note.beat.round()),
            isTrue,
            reason: '${tune.title}: a target at ${note.beat}',
          );
          final above = (note.pitch - note.chord.root) % 12;
          expect(const [3, 4, 5, 2].contains(above), isTrue);
        }
      }
    });

    test('and every target is gone round, not walked up to', () {
      final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
      final line = exerciseOver(tune, ChartExercise.enclosure);
      // Every target but the first, whose way in falls before the tune
      // starts and is dropped.
      final targets = line.where((n) => n.target).toList();
      expect(targets.length, greaterThan(4));
      for (final target in targets.skip(1)) {
        final before = line.where(
          (n) => n.beat < target.beat && n.beat >= target.beat - 1.5,
        );
        expect(before, isNotEmpty, reason: 'nothing leads into ${target.name}');
      }
    });
  });

  group('the levels', () {
    test('there are five, in the order they are worth learning', () {
      expect(ChartExercise.values.map((e) => e.label), [
        'Arpeggios',
        'Guide Tones',
        '3 to 7',
        'Bebop Scales',
        'Enclosures',
      ]);
      expect(ChartExercise.values.map((e) => e.level), [1, 2, 3, 4, 5]);
    });

    test('and each says what it is for', () {
      for (final which in ChartExercise.values) {
        expect(which.about, isNotEmpty);
        expect(which.label, isNotEmpty);
      }
    });
  });
}
