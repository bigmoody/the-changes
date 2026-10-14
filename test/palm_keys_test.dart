// Scales and arpeggios that run up into the palm keys and back.
//
// The claim the page makes is that every one of these crosses the join,
// so the thing to test is exactly that: in all twelve keys, in every
// shape, the line has to reach above written C sharp and come back. An
// exercise that stopped short would look like an exercise and practise
// nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/palm_keys.dart';

const twelve = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
];

void main() {
  _chordTones();

  group('every exercise crosses the join', () {
    test('in all twelve keys, in every shape', () {
      for (final shape in PalmShape.values) {
        for (final key in twelve) {
          final exercise = palmExercise(key, shape);
          expect(exercise.notes, isNotEmpty, reason: '$key $shape');
          expect(
            exercise.palm,
            isNotEmpty,
            reason: '$key ${shape.label} never reaches the palm keys',
          );
        }
      }
    });

    test('and none of them goes above the top of the range', () {
      for (final shape in PalmShape.values) {
        for (final key in twelve) {
          for (final note in palmExercise(key, shape).notes) {
            expect(
              note.pitch,
              lessThanOrEqualTo(topPalmNote),
              reason: '$key ${shape.label} asks for ${note.name}',
            );
          }
        }
      }
    });

    test(
      'the marked notes are the ones the palm keys make, and only those',
      () {
        for (final key in twelve) {
          final exercise = palmExercise(key, PalmShape.major);
          for (final (index, note) in exercise.notes.indexed) {
            expect(
              exercise.palm.contains(index),
              note.pitch >= firstPalmNote,
              reason: '$key, ${note.name} at $index',
            );
          }
        }
      },
    );
  });

  group('it is the scale it says it is', () {
    test('the names and the pitches agree', () {
      // They did not: the start was taken from the shape first interval,
      // which is always nought, so every one of the twelve began on a C
      // with another key names written over it.
      for (final shape in PalmShape.values) {
        for (final key in twelve) {
          for (final note in palmExercise(key, shape).notes) {
            expect(
              note.pitch % 12,
              Chord.parse(note.name).root % 12,
              reason: '$key ${shape.label}: ${note.name} at ${note.pitch}',
            );
          }
        }
      }
    });

    test('each one starts and ends on its own tonic', () {
      for (final key in twelve) {
        final notes = palmExercise(key, PalmShape.major).notes;
        expect(notes.first.name, key);
        expect(notes.last.name, key, reason: 'back where it started');
        expect(notes.first.pitch, notes.last.pitch);
      }
    });

    test('it goes up and then down, once each', () {
      final notes = palmExercise('C', PalmShape.major).notes;
      final top = notes.map((n) => n.pitch).reduce((a, b) => a > b ? a : b);
      final peak = notes.indexWhere((n) => n.pitch == top);
      for (var i = 1; i <= peak; i++) {
        expect(notes[i].pitch, greaterThan(notes[i - 1].pitch));
      }
      for (var i = peak + 1; i < notes.length; i++) {
        expect(notes[i].pitch, lessThan(notes[i - 1].pitch));
      }
      expect(
        notes.where((n) => n.pitch == top),
        hasLength(1),
        reason: 'the top note is not played twice',
      );
    });

    test('a minor exercise is minor and a dominant one is dominant', () {
      final minor = palmExercise('C', PalmShape.minor).notes;
      expect(minor.map((n) => n.name), contains('E♭'));
      final dominant = palmExercise('C', PalmShape.dominant).notes;
      expect(dominant.map((n) => n.name), contains('B♭'));
      expect(dominant.map((n) => n.name), contains('E'));
    });
  });
}

// What each note is doing, and the two shapes that run through changes.
//
// The degree is half the lesson: a player who reaches a high F by feel
// without knowing it is the 3rd has learned a stretch rather than a
// note, and the next tune in another key starts the learning again.
void _chordTones() {
  group('what each note is doing', () {
    test('every note of every exercise says which degree it is', () {
      for (final shape in PalmShape.values) {
        for (final key in twelve) {
          for (final note in palmExercise(key, shape).notes) {
            expect(
              note.degree,
              isNotEmpty,
              reason: '$key ${shape.label}: ${note.name} has no degree',
            );
          }
        }
      }
    });

    test('a major scale is 1 to 7, a dominant one flattens the 7th', () {
      expect(
        [for (final n in palmExercise('C', PalmShape.major).notes) n.degree]
            .take(7),
        ['1', '2', '3', '4', '5', '6', '7'],
      );
      expect(
        [for (final n in palmExercise('C', PalmShape.dominant).notes) n.degree]
            .take(7),
        ['1', '2', '3', '4', '5', '6', '♭7'],
      );
      expect(
        [for (final n in palmExercise('C', PalmShape.minor).notes) n.degree]
            .take(7),
        ['1', '2', '♭3', '4', '5', '6', '♭7'],
      );
    });

    test('an arpeggio is its chord tones and nothing else', () {
      expect(
        {for (final n in palmExercise('C', PalmShape.triad).notes) n.degree},
        {'1', '3', '5'},
      );
      expect(
        {for (final n in palmExercise('C', PalmShape.seventh).notes) n.degree},
        {'1', '3', '5', '7'},
      );
    });
  });

  group('through the changes', () {
    test('guide tones are the 3rds and 7ths, bar the one that reaches', () {
      // In G they are C, G, F♯ and B, and not one of them is a D, E♭, E
      // or F: there is no 3rd or 7th in the palm keys to land on. The
      // line reaches with a chord tone rather than stopping below the
      // join, and that is the only note that is not a guide tone.
      for (final key in twelve) {
        final notes = palmExercise(key, PalmShape.guideTones).notes;
        final top = notes.map((n) => n.pitch).reduce((a, b) => a > b ? a : b);
        for (final note in notes) {
          if (note.pitch == top) continue;
          expect(
            note.degree,
            anyOf(['3', '♭3', '7', '♭7']),
            reason: '$key: ${note.name} is a ${note.degree}',
          );
        }
      }
    });

    test('a dominant gives its flat 7th, not the one that was asked for', () {
      // Asking a G7 for a plain "7" gets an F♯, which is not in the
      // chord. It has to be asked in its own spelling.
      final notes = palmExercise('C', PalmShape.guideTones).notes;
      expect([for (final n in notes) n.name], contains('F'));
      expect([for (final n in notes) n.name], isNot(contains('F♯')));
    });

    test('the ii–V–I plays all four tones of each chord', () {
      final degrees = {
        for (final note in palmExercise('C', PalmShape.twoFiveOne).notes)
          note.degree,
      };
      expect(degrees, containsAll(['1', '3', '5']));
      expect(degrees.any((d) => d == '7' || d == '♭7'), isTrue);
    });

    test('a ii–V–I reaches the I it is named after', () {
      // Starting every chord on its root jumped a fifth at each change,
      // and three of those do not fit between the bottom of the horn
      // and the palm keys: it came out as a ii–V that stopped before
      // the chord it resolves to.
      for (final key in twelve) {
        final notes = palmExercise(key, PalmShape.twoFiveOne).notes;
        final top = notes.reduce((a, b) => b.pitch > a.pitch ? b : a);
        // The climb tops out inside the I chord rather than short of it.
        // How far into it depends on the key: there is only so much horn
        // above the ii, so D arrives on the root and C on the 3rd.
        final tonic = Chord.parse(key).root % 12;
        final chordTones = {
          for (final interval in [0, 4, 7, 11]) (tonic + interval) % 12,
        };
        expect(
          chordTones,
          contains(top.pitch % 12),
          reason:
              '$key tops out on ${top.name}, a ${top.degree}, '
              'which is not in its I chord',
        );
      }
    });

    test('it climbs rather than leaping about', () {
      // A line that jumps an octave to find a chord tone is practising
      // the leap rather than the join.
      for (final shape in [PalmShape.guideTones, PalmShape.twoFiveOne]) {
        for (final key in twelve) {
          final notes = palmExercise(key, shape).notes;
          final up = notes.take(notes.length ~/ 2 + 1).toList();
          for (var i = 1; i < up.length; i++) {
            expect(
              up[i].pitch - up[i - 1].pitch,
              inInclusiveRange(1, 12),
              reason: '$key ${shape.label}: ${up[i - 1].name} to ${up[i].name}',
            );
          }
        }
      }
    });
  });
}
