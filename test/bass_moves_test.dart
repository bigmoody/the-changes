// The shapes a walking bassist plays through a chord.
//
// These are the band's own shapes, asked for by name. The point of the
// tests is that the names really do line up with what the bassist plays:
// if they drift, the Walking Bass screen teaches something the band does
// not do, which is worse than teaching nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/bass_moves.dart';
import 'package:play_along/music/chord.dart';

final dm7 = Chord.parse('Dm7');
final g7 = Chord.parse('G7');
final cMaj = Chord.parse('CΔ7');

List<int> move(BassMove move, {Chord? from, Chord? to, int beats = 4}) =>
    bassMoveLine(move, chord: from ?? dm7, next: to ?? g7, beats: beats);

/// Semitones above the chord's root, so a line reads as degrees.
List<int> degreesOf(List<int> line, Chord chord) => [
  for (final pitch in line) (pitch - chord.root) % 12,
];

void main() {
  group('every move', () {
    test('plays as many notes as there are beats', () {
      for (final one in BassMove.values) {
        expect(move(one), hasLength(4), reason: one.label);
        expect(move(one, beats: 3), hasLength(3), reason: one.label);
      }
    });

    test('stays on the instrument', () {
      for (final one in BassMove.values) {
        for (final pitch in move(one)) {
          expect(
            pitch,
            inInclusiveRange(bassLowest, bassHighest),
            reason: one.label,
          );
        }
      }
    });

    test('starts on the root of the chord it is on', () {
      // The first beat of a change is what tells everybody it happened.
      for (final one in BassMove.values) {
        expect((move(one).first - dm7.root) % 12, 0, reason: one.label);
      }
    });

    test('can be told apart from every other one somewhere', () {
      // Not over every chord pair: over Dm7 going to G7, scale up and
      // chromatic run up are the same four notes, because a tone apart
      // with a minor 3rd on top makes them coincide. That is a fact
      // about those two chords and not two names for one shape, so what
      // is asked is that each pair differs somewhere.
      final pairs = [(dm7, g7), (g7, cMaj), (cMaj, dm7)];
      for (final a in BassMove.values) {
        for (final b in BassMove.values) {
          if (a == b) continue;
          final differs = pairs.any(
            (pair) =>
                move(a, from: pair.$1, to: pair.$2).join(',') !=
                move(b, from: pair.$1, to: pair.$2).join(','),
          );
          expect(differs, isTrue, reason: '${a.label} is ${b.label}');
        }
      }
    });

    test('and scale up really is chromatic up over that one pair', () {
      // Written down so the coincidence above is a known thing rather
      // than something that looks wrong next time somebody reads it.
      expect(
        move(BassMove.scaleUp),
        move(BassMove.chromaticUp),
        reason: 'D E F F sharp, arrived at two ways',
      );
      expect(
        move(BassMove.scaleUp, from: g7, to: cMaj),
        isNot(move(BassMove.chromaticUp, from: g7, to: cMaj)),
      );
    });

    test('has a name and an explanation, and no two share a name', () {
      for (final one in BassMove.values) {
        expect(one.label, isNotEmpty);
        expect(one.about, isNotEmpty, reason: one.label);
      }
      expect(
        BassMove.values.map((m) => m.label).toSet(),
        hasLength(BassMove.values.length),
      );
    });
  });

  group('the shapes are what they are called', () {
    test('arpeggio up is the root, the 3rd and the 5th', () {
      final degrees = degreesOf(move(BassMove.arpeggioUp), dm7);
      expect(degrees.take(3).toList(), [0, 3, 7], reason: 'Dm7: D F A');
    });

    test('arpeggio down is the same notes, underneath', () {
      final line = move(BassMove.arpeggioDown);
      expect(degreesOf(line, dm7).take(3).toList(), [0, 7, 3]);
      expect(line[1], lessThan(line[0]), reason: 'the 5th below, not above');
    });

    test('scale up is the root, 2nd and 3rd', () {
      expect(degreesOf(move(BassMove.scaleUp), dm7).take(3).toList(), [
        0,
        2,
        3,
      ]);
    });

    test('scale down goes down', () {
      final line = move(BassMove.scaleDown);
      expect(line[1], lessThan(line[0]));
      expect(line[2], lessThan(line[1]));
    });

    test('the octave leap really leaps an octave', () {
      final line = move(BassMove.octaveLeap);
      expect(line[1] - line[0], 12);
    });

    test('the repeated root repeats it', () {
      final line = move(BassMove.repeatedRoot);
      expect(line[1], line[0]);
    });

    test('up to the 7th is the whole chord and nothing else', () {
      expect(degreesOf(move(BassMove.upToTheSeventh), dm7), [
        0,
        3,
        7,
        10,
      ], reason: 'Dm7: D F A C');
    });
  });

  group('the ones that aim at the next chord', () {
    test('are the four that say they are', () {
      final aiming = [
        for (final one in BassMove.values)
          if (one.aimsAtTheNext) one,
      ];
      expect(aiming, hasLength(4));
      expect(aiming, contains(BassMove.chromaticDown));
      expect(aiming, contains(BassMove.encloseBelow));
    });

    test('a chromatic run down arrives from above, one semitone at a time', () {
      final line = move(BassMove.chromaticDown);
      expect(line[2] - line[1], -1);
      expect(line[3] - line[2], -1);
      expect((line[3] - g7.root) % 12, 1, reason: 'a semitone above the G');
    });

    test('a chromatic run up arrives from below', () {
      final line = move(BassMove.chromaticUp);
      expect(line[2] - line[1], 1);
      expect(line[3] - line[2], 1);
      expect((line[3] - g7.root) % 12, 11, reason: 'a semitone under the G');
    });

    test('an enclosure goes past the target and comes back', () {
      final above = move(BassMove.encloseAbove);
      final target = above[1] - 2;
      expect(above[1], greaterThan(target), reason: 'above first');
      expect(above[3], lessThan(target), reason: 'then below');

      final below = move(BassMove.encloseBelow);
      expect(below[3] - below[1], 3, reason: 'below, then above');
    });

    test('and they all finish next door to the chord they are going to', () {
      for (final one in BassMove.values.where((m) => m.aimsAtTheNext)) {
        final last = move(one).last;
        final away = ((last - g7.root) % 12 + 12) % 12;
        expect(
          away == 1 || away == 11,
          isTrue,
          reason: '${one.label} finished $away semitones off',
        );
      }
    });
  });

  group('the last note before a change', () {
    test('is next door or a step away, for every shape but one', () {
      // What makes an arrival sound chosen rather than stumbled into.
      for (final one in BassMove.values) {
        if (one == BassMove.upToTheSeventh) continue;
        final last = move(one).last;
        final away = ((last - g7.root) % 12 + 12) % 12;
        expect(
          [1, 2, 10, 11, 7].contains(away),
          isTrue,
          reason: '${one.label} finished $away semitones from the next root',
        );
      }
    });

    test('and Up to the 7th is the one, on purpose', () {
      // It ends on the 7th of the chord it is on and leaves the arriving
      // to the next root. Written down because it looks like an
      // oversight and is not.
      final line = move(BassMove.upToTheSeventh);
      expect(degreesOf(line, dm7).last, 10, reason: 'the 7th of Dm7');
      expect(
        BassMove.upToTheSeventh.about,
        contains('no approach note'),
        reason: 'the screen has to say so too',
      );
    });
  });

  group('over other chords', () {
    test('the shapes follow the chord they are on', () {
      // The same shape over a dominant has a major 3rd in it.
      expect(
        degreesOf(
          move(BassMove.arpeggioUp, from: g7, to: cMaj),
          g7,
        ).take(3).toList(),
        [0, 4, 7],
        reason: 'G7: G B D',
      );
    });

    test('and they aim at whatever comes next', () {
      final line = move(BassMove.chromaticUp, from: g7, to: cMaj);
      expect((line.last - cMaj.root) % 12, 11);
    });
  });
}
