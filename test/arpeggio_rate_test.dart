// How fast the arpeggio goes by.
//
// It was eighths and only eighths, which is the rate a line is actually
// played at and is not the only rate worth practising at: quarters give
// you time to see the next chord coming and sixteenths give you none.
//
// The thing most worth guarding is that eighths did not change when the
// others were added. It is the default, it is what every existing
// performance was rendered at, and the band sound goldens would have
// caught it moving, which is the point of them.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/swing.dart';

List<ArpeggioNote> over(ArpeggioRate rate, {double swing = 0.62}) =>
    arpeggioLine(
      [(Chord.parse('Cm7'), 4), (Chord.parse('F7'), 4)],
      choruses: 1,
      swing: swing,
      rate: rate,
    ).notes;

void main() {
  group('how many notes', () {
    test('one a beat, two, three or four', () {
      for (final rate in ArpeggioRate.values) {
        // Eight beats of chord.
        expect(over(rate), hasLength(8 * rate.perBeat), reason: rate.label);
      }
    });

    test('and the four rates are what they say they are', () {
      expect(ArpeggioRate.quarters.perBeat, 1);
      expect(ArpeggioRate.eighths.perBeat, 2);
      expect(ArpeggioRate.triplets.perBeat, 3);
      expect(ArpeggioRate.sixteenths.perBeat, 4);
    });
  });

  group('where they land', () {
    test('quarters are on the beats, with nothing to lean', () {
      for (final note in over(ArpeggioRate.quarters)) {
        expect(note.beat % 1, 0, reason: 'a quarter at ${note.beat}');
      }
    });

    test('eighths lean, and exactly as they always did', () {
      // The old code added the swing itself. This goes through swungBeat
      // instead, so the arpeggio leans the way the rest of the band does,
      // and the two have to agree or every existing performance changes.
      const swing = 0.62;
      final notes = over(ArpeggioRate.eighths, swing: swing);
      for (final (i, note) in notes.indexed) {
        final expected = i ~/ 2 + (i.isEven ? 0.0 : swing);
        expect(note.beat, closeTo(expected, 1e-9), reason: 'note $i');
      }
    });

    test('and their lengths too: long then short', () {
      const swing = 0.62;
      final notes = over(ArpeggioRate.eighths, swing: swing);
      expect(notes[0].length, closeTo(swing * 0.95, 1e-9));
      expect(notes[1].length, closeTo((1 - swing) * 0.95, 1e-9));
    });

    test('triplets are even thirds, because they are the swing already', () {
      // Leaning a triplet is swinging a swing: the triplet is what a
      // swung eighth is leaning towards.
      final notes = over(ArpeggioRate.triplets);
      for (final (i, note) in notes.indexed) {
        expect(note.beat, closeTo(i / 3, 1e-9), reason: 'note $i');
      }
      expect(ArpeggioRate.triplets.swings, isFalse);
    });

    test('sixteenths lean the sixteenths, not the eighths', () {
      // Which is what swungBeat means by the word, and what the funk feel
      // does: the halves stay where they are and the quarters inside them
      // move.
      const swing = 0.62;
      final notes = over(ArpeggioRate.sixteenths, swing: swing);
      expect(notes[0].beat, closeTo(0, 1e-9));
      expect(notes[1].beat, closeTo(swing / 2, 1e-9));
      expect(notes[2].beat, closeTo(0.5, 1e-9));
      expect(notes[3].beat, closeTo(0.5 + swing / 2, 1e-9));
    });
  });

  group('whatever the rate', () {
    test('every note has somewhere to be and something to last', () {
      for (final rate in ArpeggioRate.values) {
        for (final note in over(rate)) {
          expect(note.beat, greaterThanOrEqualTo(0), reason: rate.label);
          expect(note.length, greaterThan(0), reason: rate.label);
        }
      }
    });

    test('nothing overlaps the note after it', () {
      // A broken chord is one note at a time: that is what makes it
      // teach anything.
      for (final rate in ArpeggioRate.values) {
        final notes = over(rate);
        for (var i = 1; i < notes.length; i++) {
          expect(
            notes[i - 1].beat + notes[i - 1].length,
            lessThanOrEqualTo(notes[i].beat + 1e-9),
            reason: '${rate.label} at $i',
          );
        }
      }
    });

    test('and it still walks up the chord and back', () {
      // The shape is the shape at any speed: 1 3 5 7 8 and down again.
      final notes = over(ArpeggioRate.quarters);
      expect(notes[1].pitch, greaterThan(notes[0].pitch));
      expect(notes[2].pitch, greaterThan(notes[1].pitch));
      final sixteenths = over(ArpeggioRate.sixteenths);
      final top = sixteenths.take(9).map((n) => n.pitch).toList();
      expect(top[4], greaterThan(top[0]), reason: 'up to the octave');
      expect(top[8], lessThan(top[4]), reason: 'and back down');
    });

    test('an even feel leaves even rates alone', () {
      for (final note in over(ArpeggioRate.eighths, swing: straight)) {
        expect(note.beat % 0.5, closeTo(0, 1e-9));
      }
    });
  });
}
