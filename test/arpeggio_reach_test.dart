// How far up the chord the arpeggio goes.
//
// Plain is 1 3 5 7 and the octave, which is what you learn the shape of a
// chart from because every note of it is unarguably the chord. The
// extensions are the 9th, 11th and 13th of the chord's *own scale*, which
// is what gets the alterations right without a table of them.
//
// The one real rule is the 11th. A natural 11th sits a semitone above a
// major 3rd, which is the avoid note of the whole system, so on a major
// or a dominant chord it is either raised to a ♯11 or it is not played.
// On a minor chord there is no major 3rd to clash with, and the 11th
// there is one of the better sounds in the music.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune_library.dart';

List<int> rungs(String symbol, ArpeggioReach reach) =>
    arpeggioRungsOf(Chord.parse(symbol), reach);

void main() {
  group('plain is the chord and nothing else', () {
    test('four rungs, all of them in it', () {
      for (final symbol in ['Cm7', 'C7', 'CΔ7', 'C13', 'C6', 'Cø7']) {
        final chord = Chord.parse(symbol);
        final tones = {
          for (final interval in chord.withoutExtensions.quality.intervals)
            interval % 12,
        };
        for (final rung in rungs(symbol, ArpeggioReach.plain)) {
          expect(tones.contains(rung % 12), isTrue, reason: symbol);
        }
      }
    });

    test('and it is what every chart played until now', () {
      // The default, so the band sound goldens cover it and would have
      // caught it moving.
      expect(ArpeggioReach.values.first, ArpeggioReach.plain);
    });
  });

  group('the 9th', () {
    test('one more rung, a ninth above the root', () {
      for (final symbol in ['Cm7', 'C7', 'CΔ7', 'Cm6']) {
        final plain = rungs(symbol, ArpeggioReach.plain);
        final ninth = rungs(symbol, ArpeggioReach.ninth);
        expect(ninth.length, plain.length + 1, reason: symbol);
        expect(ninth.last, 14, reason: symbol);
      }
    });

    test('and the chord\'s own 9th where it has been given one', () {
      // A ♯9 is written for a reason and is not to be replaced with a
      // natural one.
      expect(rungs('C7#9', ArpeggioReach.ninth).last, 15);
    });

    test('a flat 9th where the scale has one', () {
      // Locrian's 2nd is a ♭2, so a half-diminished chord's 9th is flat
      // without anybody having to say so.
      expect(rungs('Cø7', ArpeggioReach.ninth).last, 13);
    });
  });

  group('the 11th, which is the whole question', () {
    test('a minor chord keeps its natural 11th', () {
      expect(rungs('Cm7', ArpeggioReach.thirteenth), contains(17));
    });

    test('a dominant does not', () {
      // A semitone above the major 3rd: the avoid note.
      expect(rungs('C7', ArpeggioReach.thirteenth), isNot(contains(17)));
    });

    test('nor does a major 7th', () {
      expect(rungs('CΔ7', ArpeggioReach.thirteenth), isNot(contains(17)));
    });

    test('but a chord written with a ♯11 plays it', () {
      // Raised, it is a colour rather than a clash, and the chord asked.
      expect(rungs('C7#11', ArpeggioReach.thirteenth), contains(18));
    });

    test('and nothing ever gets both', () {
      for (final tune in standards) {
        for (final bar in tune.bars) {
          for (final slot in bar) {
            final ladder = arpeggioRungsOf(
              slot.chord,
              ArpeggioReach.thirteenth,
            );
            expect(
              ladder.contains(17) && ladder.contains(18),
              isFalse,
              reason: '${slot.chord.display} has an 11th and a ♯11',
            );
          }
        }
      }
    });
  });

  group('over any chart at all', () {
    test('every chord gives a climb that climbs', () {
      for (final tune in standards) {
        for (final reach in ArpeggioReach.values) {
          for (final bar in tune.bars) {
            for (final slot in bar) {
              final ladder = arpeggioRungsOf(slot.chord, reach);
              expect(ladder, isNotEmpty, reason: slot.chord.display);
              expect(ladder.first, 0, reason: slot.chord.display);
              for (var i = 1; i < ladder.length; i++) {
                expect(
                  ladder[i],
                  greaterThan(ladder[i - 1]),
                  reason: '${slot.chord.display}: $ladder',
                );
              }
            }
          }
        }
      }
    });

    test('and reaching further never reaches less far', () {
      for (final tune in standards) {
        for (final bar in tune.bars) {
          for (final slot in bar) {
            final plain = arpeggioRungsOf(slot.chord, ArpeggioReach.plain);
            final ninth = arpeggioRungsOf(slot.chord, ArpeggioReach.ninth);
            final full = arpeggioRungsOf(slot.chord, ArpeggioReach.thirteenth);
            expect(ninth.length, greaterThanOrEqualTo(plain.length));
            expect(full.length, greaterThanOrEqualTo(ninth.length));
          }
        }
      }
    });
  });

  group('the line it makes', () {
    test('plain closes on the octave, extended does not', () {
      // Plain is the shape everybody practises, up to the same note an
      // octave higher. With extensions the top rung is already above that
      // octave, so there is nothing to close.
      final plain = arpeggioLine(
        [(Chord.parse('Cm7'), 4)],
        choruses: 1,
        swing: 0.5,
      ).notes;
      expect(plain[4].pitch - plain[0].pitch, 12);

      final full = arpeggioLine(
        [(Chord.parse('Cm7'), 8)],
        choruses: 1,
        swing: 0.5,
        reach: ArpeggioReach.thirteenth,
      ).notes;
      // 1 ♭3 5 ♭7 9 11 13, climbing all the way.
      expect(
        [for (final note in full.take(7)) note.pitch - full.first.pitch],
        [0, 3, 7, 10, 14, 17, 21],
      );
    });

    test('and it still comes back down', () {
      final full = arpeggioLine(
        [(Chord.parse('Cm7'), 8)],
        choruses: 1,
        swing: 0.5,
        reach: ArpeggioReach.thirteenth,
      ).notes;
      expect(full[7].pitch, lessThan(full[6].pitch));
    });

    test('an inversion still starts on a note of the chord', () {
      // Inversions are of the chord and not of its extensions: starting
      // an arpeggio on the 11th is not an inversion of anything.
      for (final from in ArpeggioStart.values) {
        final line = arpeggioLine(
          [(Chord.parse('Cm7'), 8)],
          choruses: 1,
          swing: 0.5,
          from: from,
          reach: ArpeggioReach.thirteenth,
        ).notes;
        final chord = Chord.parse('Cm7');
        final tones = {
          for (final interval in chord.quality.intervals) interval % 12,
        };
        expect(
          tones.contains((line.first.pitch - chord.root) % 12),
          isTrue,
          reason: 'started on ${line.first.pitch} from ${from.name}',
        );
      }
    });
  });
}
