import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_drill.dart';
import 'package:play_along/settings/app_settings.dart';

void main() {
  test('the degree asked for is the one the chord actually has', () {
    expect(degreeFor(Chord.parse('Cm7'), 3), 'b3');
    expect(degreeFor(Chord.parse('C7'), 7), 'b7');
    expect(degreeFor(Chord.parse('CΔ7'), 7), '7');
    expect(degreeFor(Chord.parse('Cø7'), 5), 'b5');
    // A 6th chord's 6th does the 7th's job.
    expect(degreeFor(Chord.parse('Cm6'), 7), '6');
    // Extensions count: the 9th of a minor 7th is one of its colours.
    expect(degreeFor(Chord.parse('Cm7'), 9), '9');
    // An altered chord has two 9ths, so "the 9th" has no answer.
    expect(degreeFor(Chord.parse('C7alt'), 9), isNull);
    // And no 5th at all.
    expect(degreeFor(Chord.parse('C7alt'), 5), isNull);
  });

  test('answers are spelled properly and marked by sound', () {
    final question = DrillQuestion(
      chord: Chord.parse('Bbm7'),
      degrees: const ['b3'],
      mode: DrillMode.aim,
    );
    expect(question.solution.single.note, 'D♭');
    expect(question.degreeLabel, '♭3rd');
    // D♭ and C♯ are the same key on the piano: either is the right note.
    expect(question.isRight({1}), isTrue);
    expect(question.isRight({2}), isFalse);
    expect(question.isRight({1, 5}), isFalse, reason: 'extra notes');
  });

  test('spelling a chord asks for every chord tone', () {
    final question = DrillQuestion(
      chord: Chord.parse('Eb7'),
      degrees: Chord.parse('Eb7').quality.formula,
      mode: DrillMode.spell,
    );
    expect(question.solution.map((n) => n.note), ['E♭', 'G', 'B♭', 'D♭']);
    expect(question.answer, {3, 7, 10, 1});
  });

  test('guide tones ask for the 3rd and the 7th together', () {
    final drill = ChordDrill(
      mode: DrillMode.aim,
      source: DrillSource.twoFiveOne,
      target: DrillTarget.guideTones,
      random: math.Random(1),
    );
    final question = drill.next();
    expect(question.degrees, hasLength(2));
    expect(question.degreeLabel, contains('&'));
  });

  test('a ii–V–I is asked in order, then moves to a new key', () {
    final drill = ChordDrill(
      mode: DrillMode.spell,
      source: DrillSource.twoFiveOne,
      random: math.Random(2),
    );
    final keys = <String>[];
    for (var i = 0; i < 36; i++) {
      final question = drill.next();
      expect(question.position, i % 3);
      final [ii, v, one] = question.progression;
      // ii–V–I: minor 7th a whole step above the tonic, then its dominant.
      expect(ii.quality.name, 'Minor 7th');
      expect(v.quality.name, 'Dominant 7th');
      expect(one.quality.name, 'Major 7th');
      expect((ii.root - one.root) % 12, 2);
      expect((v.root - one.root) % 12, 7);
      if (i % 3 == 0) keys.add(question.keyName!);
    }
    // Twelve keys, each once, before any comes round again.
    expect(keys.take(12).toSet(), hasLength(12));
  });

  test('a minor ii–V–i uses ø7, 7♭9 and a minor tonic', () {
    final drill = ChordDrill(
      mode: DrillMode.aim,
      source: DrillSource.minorTwoFiveOne,
      target: DrillTarget.seventh,
      random: math.Random(3),
    );
    final question = drill.next();
    expect(question.progression.map((c) => c.quality.name), [
      'Half-diminished',
      'Dominant 7th flat 9',
      'Minor 6th',
    ]);
    expect(question.keyName, endsWith('minor'));
  });

  test('keys are spelled the way they are written', () {
    for (final source in [
      DrillSource.twoFiveOne,
      DrillSource.minorTwoFiveOne,
    ]) {
      final drill = ChordDrill(
        mode: DrillMode.spell,
        source: source,
        random: math.Random(4),
      );
      for (var i = 0; i < 36; i++) {
        for (final chord in drill.next().progression) {
          // No double sharps or flats anywhere in any key's changes.
          for (final note in chord.noteNames) {
            expect(note, isNot(contains('𝄪')), reason: chord.display);
          }
          expect(chord.display, isNot(contains('𝄫')), reason: chord.display);
        }
      }
    }
  });

  test('every level, target and source keeps producing questions', () {
    for (final mode in DrillMode.values) {
      for (final source in DrillSource.values) {
        for (final level in DrillLevel.values) {
          for (final target in DrillTarget.values) {
            // The screen only offers targets a level has.
            if (mode == DrillMode.aim &&
                source == DrillSource.anyChord &&
                !level.offers(target)) {
              continue;
            }
            final drill = ChordDrill(
              mode: mode,
              source: source,
              level: level,
              target: target,
              random: math.Random(5),
            );
            String? previous;
            for (var i = 0; i < 20; i++) {
              final question = drill.next();
              expect(question.answer, isNotEmpty);
              if (source == DrillSource.anyChord) {
                expect(question.chord.display, isNot(previous));
                previous = question.chord.display;
              }
            }
          }
        }
      }
    }
  });

  test('triads offer no 7th to aim for, 7th chords do', () {
    expect(DrillLevel.triads.offers(DrillTarget.seventh), isFalse);
    expect(DrillLevel.triads.offers(DrillTarget.guideTones), isFalse);
    expect(DrillLevel.triads.offers(DrillTarget.third), isTrue);
    expect(DrillLevel.sevenths.offers(DrillTarget.guideTones), isTrue);
  });

  test('instrument transpositions spell notes the way the player reads', () {
    final concertEb7 = Chord.parse('Eb7');
    expect(
      concertEb7.transposed(ChartInstrument.bFlat.transposition).display,
      'F7',
    );
    expect(
      concertEb7.transposed(ChartInstrument.eFlat.transposition).display,
      'C7',
    );
    expect(
      concertEb7.transposed(ChartInstrument.f.transposition).display,
      'B♭7',
    );
  });
}
