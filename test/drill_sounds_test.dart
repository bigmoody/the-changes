import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drill_sounds.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_drill.dart';

void main() {
  DrillQuestion aimAtThird(String symbol) {
    final chord = Chord.parse(symbol);
    return DrillQuestion(
      chord: chord,
      degrees: [degreeFor(chord, 3)!],
      mode: DrillMode.aim,
    );
  }

  test('a transposing player hears concert pitch', () {
    // A trumpeter's written D7 is a concert C7: the bass plays C.
    final notes = drillSnippet(
      aimAtThird('D7'),
      concertShift: -2,
      withAnswer: false,
    );
    final bass = notes.where((n) => n.bass).single;
    expect(bass.pitch % 12, 0);
  });

  test('before answering, only the chord is played', () {
    final question = aimAtThird('Bbm7');
    final notes = drillSnippet(question, concertShift: 0, withAnswer: false);
    // Bass plus the four chord tones, all at once.
    expect(notes, hasLength(5));
    expect(notes.every((n) => n.start == 0), isTrue);
  });

  test('the answer to aim for sounds on top of the chord', () {
    final question = aimAtThird('Bbm7');
    final notes = drillSnippet(question, concertShift: 0, withAnswer: true);
    final chord = notes.where((n) => n.start == 0 && !n.bass);
    final target = notes.where((n) => n.start > 0).single;
    expect(target.pitch % 12, 1, reason: 'D♭, the ♭3 of B♭m7');
    expect(
      target.pitch,
      greaterThan(chord.map((n) => n.pitch).reduce((a, b) => a > b ? a : b)),
    );
  });

  test('spelling plays the chord tones one by one, rising', () {
    final chord = Chord.parse('Eb7');
    final question = DrillQuestion(
      chord: chord,
      degrees: chord.quality.formula,
      mode: DrillMode.spell,
    );
    final arpeggio = drillSnippet(
      question,
      concertShift: 0,
      withAnswer: true,
    ).where((n) => n.start > 0).toList();
    expect(arpeggio.map((n) => n.pitch % 12), [3, 7, 10, 1]);
    for (var i = 1; i < arpeggio.length; i++) {
      expect(arpeggio[i].pitch, greaterThan(arpeggio[i - 1].pitch));
      expect(arpeggio[i].start, greaterThan(arpeggio[i - 1].start));
    }
  });

  test('every note stays where the recordings sound good', () {
    for (final level in DrillLevel.values) {
      for (final symbol in level.symbols) {
        for (final root in ['C', 'F#', 'Bb', 'B']) {
          final chord = Chord.parse('$root$symbol');
          for (final mode in DrillMode.values) {
            final question = DrillQuestion(
              chord: chord,
              degrees: mode == DrillMode.spell
                  ? chord.quality.formula
                  : [chord.quality.formula.last],
              mode: mode,
            );
            for (final note in drillSnippet(
              question,
              concertShift: 0,
              withAnswer: true,
            )) {
              if (note.bass) {
                expect(note.pitch, inInclusiveRange(28, 52), reason: '$chord');
              } else {
                expect(note.pitch, inInclusiveRange(48, 84), reason: '$chord');
              }
            }
          }
        }
      }
    }
  });
}
