import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune.dart';

/// A bar of [feel], leaning the way that feel leans by default: the
/// triplet for the ones that swing, even for the ones that do not. The
/// slider can move any of them now, so what it is given has to say so.
List<DrumHit> bar(Feel feel, int index, [int seed = 1, double? swing]) =>
    drumBar(
      feel: feel,
      bar: index,
      beatsPerBar: 4,
      random: math.Random(seed),
      swing: swing ?? (feel.swings ? tripletSwing : straight),
    );

List<double> beatsOf(List<DrumHit> hits, Drum drum) =>
    [for (final h in hits.where((h) => h.drum == drum)) h.beat]..sort();

void main() {
  group('calypso groove', () {
    test('a rim click says where the backbeat is', () {
      for (var index = 0; index < 16; index++) {
        final hits = bar(Feel.calypso, index, index);
        expect(beatsOf(hits, Drum.crossStick), [1.0, 3.0]);
        expect(beatsOf(hits, Drum.snare), isEmpty, reason: 'rim, not snare');
      }
    });

    test('the bell keeps a steady pulse, accented on the 3-3-2', () {
      final hits = bar(
        Feel.calypso,
        0,
      ).where((h) => h.drum == Drum.cowbell).toList();
      expect(
        [for (final h in hits) h.beat],
        [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5],
      );
      // Said as a ratio, not a level: what matters is that the figure
      // stands well clear of the notes between it, and that the bell as a
      // whole sits under the hi-hat a bossa keeps time on.
      final figure = hits.where((h) => [0.0, 1.5, 3.0].contains(h.beat));
      final between = hits.where((h) => ![0.0, 1.5, 3.0].contains(h.beat));
      final quietestAccent = figure
          .map((h) => h.velocity)
          .reduce((a, b) => a < b ? a : b);
      final loudestGhost = between
          .map((h) => h.velocity)
          .reduce((a, b) => a > b ? a : b);
      expect(quietestAccent, greaterThan(loudestGhost * 2));
      expect(quietestAccent, lessThan(0.4), reason: 'a bell carries');
    });

    test('the toms only turn a phrase around, never every bar', () {
      var barsWithToms = 0;
      for (var index = 0; index < 32; index++) {
        final hits = bar(Feel.calypso, index, index);
        final toms = [
          ...beatsOf(hits, Drum.tomHigh),
          ...beatsOf(hits, Drum.tomLow),
        ];
        if (toms.isNotEmpty) {
          barsWithToms++;
          expect(index % 8, 7, reason: 'bar $index is not a turnaround');
        }
      }
      expect(barsWithToms, greaterThan(0), reason: 'and some bars have them');
    });

    test('everything that carries weight lands on the 3-3-2', () {
      // The complaint this guards against: the bell on every off-beat, the
      // kick on the 3-3-2 and the toms on a third figure, so nothing agreed
      // where the weight was and the groove sounded like a pile-up.
      for (var index = 0; index < 16; index++) {
        // The turnaround is a fill, and a fill is meant to cut across it.
        if (index % 8 == 7) continue;
        for (final hit in bar(Feel.calypso, index, index)) {
          if (!hit.hard && hit.velocity < 0.4) continue;
          if (hit.drum == Drum.crossStick) continue; // the backbeat
          expect(
            [0.0, 1.5, 3.0],
            contains(hit.beat),
            reason: '${hit.drum.name} at ${hit.beat} in bar $index',
          );
        }
      }
    });

    test('the kick plays the 3-3-2 with the bass, and nothing on 3', () {
      for (var index = 0; index < 16; index++) {
        expect(beatsOf(bar(Feel.calypso, index, index), Drum.kick), [
          0,
          1.5,
          3,
        ]);
      }
    });

    test('the bass plays the 3-3-2 and leaves beat 3 empty', () {
      for (final chords in [
        [(Chord.parse('C6'), 4), (Chord.parse('G7'), 4)],
        // Two chords to a bar, as in most of St. Thomas.
        [
          (Chord.parse('C6'), 4),
          (Chord.parse('Em7b5'), 2),
          (Chord.parse('A7'), 2),
          (Chord.parse('Dm7'), 2),
          (Chord.parse('G7'), 2),
        ],
      ]) {
        final line = calypsoBassLine(
          chords,
          choruses: 8,
          random: math.Random(3),
          swing: tripletSwing,
        );
        final places = {for (final note in line) note.beat % 4};
        expect(
          places.map((p) => (p * 2).round() / 2),
          everyElement(isIn([0.0, 1.5, 3.0, 3.5])),
        );
      }
    });

    test('with two chords a bar, the second comes in on the "and" of 2', () {
      final line = calypsoBassLine(
        [(Chord.parse('Dm7'), 2), (Chord.parse('G7'), 2)],
        choruses: 4,
        random: math.Random(1),
        swing: tripletSwing,
      );
      // A G (7) sounding from the "and" of 2 of every bar but the last.
      final early = line.where((n) => (n.beat % 4 - 1.5).abs() < 0.05);
      expect(early.length, greaterThanOrEqualTo(3));
      expect(early.map((n) => n.pitch % 12), everyElement(7));
    });

    test('the piano strums, accenting the off-beats', () {
      final comper = Comper(math.Random(2));
      final hits = [
        for (var i = 0; i < 20; i++)
          ...comper.comp(
            Chord.parse(i.isEven ? 'C6' : 'G7'),
            4,
            Feel.bossa,
            calypso: true,
            swing: tripletSwing,
          ),
      ];
      expect(hits.length, greaterThan(40), reason: 'a strum, not sparse jazz');
      double loudness(bool offBeat) {
        final some = hits.where((h) => (h.beat % 1 != 0) == offBeat);
        return some.map((h) => h.velocity).reduce((a, b) => a + b) /
            some.length;
      }

      expect(loudness(true), greaterThan(loudness(false)));
    });
  });

  group('swing groove', () {
    test('ride on every beat, with the swung note after 2 and 4', () {
      final hits = bar(Feel.swing, 0);
      expect(beatsOf(hits, Drum.ride), [0, 1, 1 + 2 / 3, 2, 3, 3 + 2 / 3]);
      expect(beatsOf(hits, Drum.hiHatPedal), [1, 3]);
      expect(beatsOf(hits, Drum.crossStick), isEmpty);
    });

    test('the kick is feathered, never loud', () {
      for (var seed = 0; seed < 30; seed++) {
        for (final hit in bar(Feel.swing, 0, seed)) {
          if (hit.drum == Drum.kick && hit.beat % 1 == 0) {
            expect(hit.velocity, lessThan(0.4));
          }
        }
      }
    });

    test('fills only land at the end of an eight-bar phrase', () {
      var fillBars = 0;
      for (var index = 0; index < 32; index++) {
        final snares = beatsOf(bar(Feel.swing, index, index), Drum.snare);
        if (snares.length >= 4) {
          expect(index % 8, 7, reason: 'fill in bar $index');
          fillBars++;
        }
      }
      expect(fillBars, greaterThan(0));
    });
  });

  group('bossa groove', () {
    test('cross-stick plays the two-bar clave, not a backbeat', () {
      expect(beatsOf(bar(Feel.bossa, 0), Drum.crossStick), [0, 1.5, 3]);
      expect(beatsOf(bar(Feel.bossa, 1), Drum.crossStick), [1, 2.5]);
      expect(beatsOf(bar(Feel.bossa, 2), Drum.crossStick), [0, 1.5, 3]);
    });

    test('the bossa stays on one cymbal for a whole section', () {
      // The ride used to be a coin toss every bar, so it wandered in and
      // out. It may only change at an eight-bar phrase.
      String cymbal(int index) {
        final hits = bar(Feel.bossa, index, index);
        return hits.any((h) => h.drum == Drum.ride) ? 'ride' : 'hats';
      }

      for (var phrase = 0; phrase < 6; phrase++) {
        final within = {for (var i = 0; i < 8; i++) cymbal(phrase * 8 + i)};
        expect(within, hasLength(1), reason: 'phrase $phrase switches cymbal');
      }
      final phrases = {for (var p = 0; p < 6; p++) cymbal(p * 8)};
      expect(phrases, hasLength(2), reason: 'never moves to the ride');
      // No snare backbeat anywhere.
      for (var index = 0; index < 8; index++) {
        expect(beatsOf(bar(Feel.bossa, index, index), Drum.snare), isEmpty);
      }
    });

    test('even eighths above, kick on 1 and 3', () {
      final hits = bar(Feel.bossa, 0);
      final eighths = [
        ...beatsOf(hits, Drum.hiHatClosed),
        ...beatsOf(hits, Drum.ride),
      ]..sort();
      expect(eighths, [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]);
      expect(beatsOf(hits, Drum.kick).take(2), [0, 2]);
    });
  });

  group('funk groove', () {
    test('backbeat on 2 and 4 in every bar', () {
      for (var index = 0; index < 8; index++) {
        final snares = beatsOf(bar(Feel.funk, index, index), Drum.snare);
        expect(snares, containsAll([1.0, 3.0]), reason: 'bar $index');
        expect(snares.first, 1.0);
      }
    });

    test('kick figures change from bar to bar', () {
      final figures = {
        for (var index = 0; index < 12; index++)
          beatsOf(bar(Feel.funk, index, index), Drum.kick).join(','),
      };
      expect(figures.length, greaterThan(2));
    });
  });

  group('a groove brings its tempo with it', () {
    test('a samba will not be played at a ballad tempo', () {
      expect(Feel.samba.tempoFor(90), 150);
      expect(Feel.funk.tempoFor(240), 140);
      expect(Feel.calypso.tempoFor(60), 100);
    });

    test('a tempo the feel is happy with is left alone', () {
      expect(Feel.samba.tempoFor(200), 200);
      expect(Feel.shuffle.tempoFor(120), 120);
      // Swing is a ballad and a burner both, so it never moves one.
      for (final tempo in [40, 60, 160, 300]) {
        expect(Feel.swing.tempoFor(tempo), tempo);
      }
    });
  });

  group('shuffle groove', () {
    test('every beat carries its "a": the triplet, out loud', () {
      final rides = beatsOf(bar(Feel.shuffle, 0), Drum.ride);
      expect(rides, containsAll([0.0, 1.0, 2.0, 3.0]));
      for (final beat in [0, 1, 2, 3]) {
        expect(
          rides.any((r) => (r - (beat + 2 / 3)).abs() < 0.001),
          isTrue,
          reason: 'the "a" after beat ${beat + 1}',
        );
      }
    });

    test('the snare cracks on 2 and 4 in every bar', () {
      for (var index = 0; index < 16; index++) {
        final hits = bar(Feel.shuffle, index, index);
        final snares = hits.where((h) => h.drum == Drum.snare);
        for (final beat in [1.0, 3.0]) {
          final hit = snares.where((h) => h.beat == beat);
          expect(hit, hasLength(1), reason: 'bar $index, beat $beat');
          expect(hit.single.velocity, greaterThan(0.6));
        }
      }
    });

    test('which is what makes it a shuffle and not a swing', () {
      // Swing answers the soloist on the snare; a shuffle sits on 2 and 4
      // whatever else is happening.
      var swingBackbeats = 0;
      for (var index = 0; index < 16; index++) {
        final snares = beatsOf(bar(Feel.swing, index, index), Drum.snare);
        if (snares.contains(1.0) && snares.contains(3.0)) swingBackbeats++;
      }
      expect(swingBackbeats, lessThan(16));
    });

    test('its eighths are long-short, like swing and unlike the rest', () {
      expect(Feel.shuffle.swings, isTrue);
      expect(Feel.shuffle.andOfBeat, closeTo(2 / 3, 0.001));
      expect(Feel.samba.swings, isFalse);
      expect(Feel.samba.andOfBeat, closeTo(0.5, 0.001));
    });
  });

  group('samba groove', () {
    test('the surdo lands every other beat, quiet on one', () {
      for (var index = 0; index < 8; index++) {
        final surdo = bar(
          Feel.samba,
          index,
          index,
        ).where((h) => h.drum == Drum.tomLow).toList();
        // Every other beat, not every beat: on every one it ran at twice
        // the speed a samba is actually played at.
        expect(beatsOf(bar(Feel.samba, index, index), Drum.tomLow), [0.0, 2.0]);
        double at(double beat) =>
            surdo.firstWhere((h) => h.beat == beat).velocity;
        expect(at(2), greaterThan(at(0)), reason: 'bar $index leans on three');
      }
    });

    test('the shaker runs in eighths, not sixteenths', () {
      final hats = bar(Feel.samba, 0).where((h) => h.drum == Drum.hiHatClosed);
      expect(hats, hasLength(8));
      for (final hit in hats) {
        final onBeat = hit.beat % 1 == 0;
        expect(hit.velocity, onBeat ? greaterThan(0.2) : lessThan(0.2));
      }
    });

    test('at the tempo a samba is counted off, nothing runs away with it', () {
      // The complaint this guards against: written as a 2/4 dance straight
      // into a 4/4 bar, a samba comes out at double speed. These are hits a
      // second at 200 to the bar, against what the real thing does.
      const beatsASecond = 200 / 60;
      double rate(Drum drum) =>
          beatsOf(bar(Feel.samba, 0), drum).length / 4 * beatsASecond;
      expect(
        rate(Drum.hiHatClosed),
        lessThan(8),
        reason: 'a shaker, not a buzz',
      );
      expect(
        rate(Drum.tomLow),
        lessThan(2.5),
        reason: 'a surdo is not a pulse',
      );
    });

    test('the tamborim is syncopated and never lands on beat one', () {
      for (var index = 0; index < 8; index++) {
        final figure = beatsOf(bar(Feel.samba, index, index), Drum.crossStick);
        expect(figure, isNotEmpty);
        expect(figure, isNot(contains(0.0)));
        expect(
          figure.every((beat) => (beat * 2) % 1 == 0),
          isTrue,
          reason: 'eighths, bar $index',
        );
      }
      // Two bars long, so it doesn't sit still.
      expect(
        beatsOf(bar(Feel.samba, 0), Drum.crossStick),
        isNot(beatsOf(bar(Feel.samba, 1), Drum.crossStick)),
      );
    });

    test('it is not a bossa: a bossa has no surdo and plays the clave', () {
      expect(beatsOf(bar(Feel.bossa, 0), Drum.tomLow), isEmpty);
      expect(
        beatsOf(bar(Feel.samba, 0), Drum.crossStick),
        isNot([0.0, 1.5, 3.0]),
      );
    });
  });

  group('piano comping', () {
    final chords = [
      Chord.parse('Dm7'),
      Chord.parse('G7'),
      Chord.parse('CΔ7'),
      Chord.parse('Aø7'),
    ];

    test('rhythms vary, and every new chord is played', () {
      final comper = Comper(math.Random(2));
      final rhythms = <String>{};
      for (var i = 0; i < 40; i++) {
        final hits = comper.comp(
          chords[i % chords.length],
          4,
          Feel.swing,
          swing: tripletSwing,
        );
        expect(hits, isNotEmpty, reason: 'skipped a chord change');
        rhythms.add(hits.map((h) => h.beat.toStringAsFixed(2)).join(','));
      }
      expect(rhythms.length, greaterThan(4), reason: 'distinct rhythms');
    });

    test('pushes land on the "and" of 4, where the bass anticipates', () {
      // In swing the "and" of 4 is beat 3⅔ of the bar before, a third of a
      // beat ahead of the chord. In straight feels it's half a beat.
      for (final (feel, expected) in [
        (Feel.swing, -1 / 3),
        (Feel.bossa, -0.5),
        (Feel.funk, -0.5),
      ]) {
        final comper = Comper(math.Random(5));
        final early = <double>{};
        for (var i = 0; i < 200; i++) {
          for (final hit in comper.comp(
            chords[i % chords.length],
            i.isEven ? 4 : 2,
            feel,
            // Each feel leaning its own way: an even groove is handed an
            // even value, which is what the band hands it.
            swing: feel.swings ? tripletSwing : straight,
          )) {
            if (hit.beat < 0) early.add(hit.beat);
          }
        }
        expect(early, isNotEmpty, reason: '$feel never pushes');
        for (final beat in early) {
          expect(beat, closeTo(expected, 1e-9), reason: '$feel push at $beat');
        }
      }
    });

    test('a held chord is mostly left alone, and keeps its voicing', () {
      // "C6 | C6 | C6 | C6": the same chord bar after bar, as in the first
      // bars of "Take the 'A' Train".
      final comper = Comper(math.Random(2));
      final c6 = Chord.parse('C6');
      final first = comper.comp(c6, 4, Feel.swing, swing: tripletSwing);
      expect(first, isNotEmpty, reason: 'the chord must be stated once');
      var rests = 0;
      var reattacksOnOne = 0;
      for (var i = 0; i < 30; i++) {
        final hits = comper.comp(c6, 4, Feel.swing, swing: tripletSwing);
        if (hits.isEmpty) {
          rests++;
          continue;
        }
        if (hits.first.beat == 0) reattacksOnOne++;
        expect(
          hits.first.notes,
          first.first.notes,
          reason: 'a held chord should not be re-voiced',
        );
      }
      expect(rests, greaterThan(12), reason: 'hammers a chord that is held');
      expect(reattacksOnOne, lessThan(6), reason: 'too many downbeats');
    });

    test('voicings stay in the comping range and move smoothly', () {
      final comper = Comper(math.Random(7));
      int? previousTop;
      var bigMoves = 0;
      for (var i = 0; i < 40; i++) {
        for (final hit in comper.comp(
          chords[i % chords.length],
          4,
          Feel.swing,
          swing: tripletSwing,
        )) {
          expect(hit.notes, isNotEmpty);
          for (final note in hit.notes) {
            expect(note, inInclusiveRange(compLowest, compHighest));
          }
          if (previousTop != null && (hit.notes.last - previousTop).abs() > 7) {
            bigMoves++;
          }
          previousTop = hit.notes.last;
        }
      }
      expect(bigMoves, lessThan(10), reason: 'voicings jump around');
    });

    test('uses the standard rootless shapes', () {
      // Dm7 "A form": 3rd, 5th, ♭7th, 9th → F A C E.
      final dm7 = voicingsFor(Chord.parse('Dm7'));
      expect(dm7.first.map((n) => n % 12), [5, 9, 0, 4]);
      // Dm7 "B form": ♭7th, 9th, 3rd, 5th → C E F A.
      expect(dm7.last.map((n) => n % 12), [0, 4, 5, 9]);
      // G7 uses the 13th rather than a plain 5th: F A B E.
      expect(voicingsFor(Chord.parse('G7')).last.map((n) => n % 12), [
        5,
        9,
        11,
        4,
      ]);
      // A plain triad doesn't invent a ♭7th.
      expect(
        voicingsFor(Chord.parse('C')).first.map((n) => n % 12),
        isNot(contains(10)),
      );
    });

    test('plain triads are comped as 6/9 chords', () {
      // C → E G A D, the 6/9 shape, not a bare C E G.
      expect(voicingsFor(Chord.parse('C')).first.map((n) => n % 12), [
        4,
        7,
        9,
        2,
      ]);
      // Cm → E♭ G A D.
      expect(voicingsFor(Chord.parse('Cm')).first.map((n) => n % 12), [
        3,
        7,
        9,
        2,
      ]);
      // Sus, diminished and augmented chords are left as written.
      for (final symbol in ['Csus4', 'C°', 'C+']) {
        final notes = voicingsFor(Chord.parse(symbol)).first.map((n) => n % 12);
        expect(notes, isNot(contains(9)), reason: '$symbol gained a 6th');
      }
    });

    test('a dominant heading for a minor chord is altered', () {
      // E7 → Am7 is voiced E7♭9♭13: G♯ C D F.
      final toMinor = voicingsFor(
        Chord.parse('E7'),
        resolvingTo: Chord.parse('Am7'),
      );
      expect(toMinor.first.map((n) => n % 12), [8, 0, 2, 5]);
      // The same chord going somewhere else keeps its natural 9th and 13th.
      final toMajor = voicingsFor(
        Chord.parse('E7'),
        resolvingTo: Chord.parse('AΔ7'),
      );
      expect(toMajor.first.map((n) => n % 12), [8, 1, 2, 6]);
      // A symbol that already says what it wants is left alone.
      final written = voicingsFor(
        Chord.parse('E7♯9'),
        resolvingTo: Chord.parse('Am7'),
      );
      expect(written.first.map((n) => n % 12), contains(7));
    });

    test('a ii–V–I barely moves the hand', () {
      final comper = Comper(math.Random(3));
      final voicings = [
        for (final symbol in ['Dm7', 'G7', 'CΔ7'])
          comper
              .comp(Chord.parse(symbol), 4, Feel.swing, swing: tripletSwing)
              .first
              .notes,
      ];
      for (var i = 1; i < voicings.length; i++) {
        var movement = 0;
        for (final note in voicings[i]) {
          var nearest = 99;
          for (final previous in voicings[i - 1]) {
            nearest = math.min(nearest, (note - previous).abs());
          }
          movement += nearest;
        }
        expect(movement, lessThanOrEqualTo(6), reason: "chord $i jumps");
      }
    });

    test('voicings leave the root to the bass', () {
      for (final chord in chords) {
        for (final shape in voicingsFor(chord)) {
          expect(
            shape.map((n) => n % 12),
            isNot(contains(chord.root)),
            reason: chord.display,
          );
        }
      }
    });
  });
}
