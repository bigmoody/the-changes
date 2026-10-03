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
