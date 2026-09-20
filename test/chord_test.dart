import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';

void main() {
  test('parses roots, qualities and slash basses', () {
    final chord = Chord.parse('Bbm7');
    expect(chord.root, 10);
    expect(chord.quality.name, 'Minor 7th');
    expect(chord.display, 'B♭m7');

    expect(Chord.parse('C7/G').bass, 7);
    expect(Chord.parse('C6/9').quality.name, 'Six-nine');
  });

  test('understands shorthand symbols', () {
    expect(Chord.parse('CΔ7').quality.name, 'Major 7th');
    expect(Chord.parse('C^7').display, 'CΔ7');
    expect(Chord.parse('Dø7').quality.name, 'Half-diminished');
    expect(Chord.parse('Dm7b5').quality.name, 'Half-diminished');
    expect(Chord.parse('Bo7').display, 'B°7');
    expect(Chord.parse('C-7').quality.name, 'Minor 7th');
    expect(Chord.parse('G7b9').display, 'G7♭9');
  });

  test('spells notes by letter, not just pitch', () {
    expect(Chord.parse('Cm7').noteNames, ['C', 'E♭', 'G', 'B♭']);
    expect(Chord.parse('Bo7').noteNames, ['B', 'D', 'F', 'A♭']);
    expect(Chord.parse('F#7').noteNames, ['F♯', 'A♯', 'C♯', 'E']);
    expect(Chord.parse('Ebo7').noteNames, ['E♭', 'G♭', 'B𝄫', 'D𝄫']);
  });

  test('every quality in the reference parses and has valid degrees', () {
    for (final quality in chordQualities) {
      for (final symbol in quality.symbols) {
        expect(Chord.parse('C$symbol').quality, same(quality), reason: symbol);
      }
      expect(quality.intervals, hasLength(quality.formula.length));
    }
  });

  test('rejects nonsense', () {
    expect(() => Chord.parse('H7'), throwsFormatException);
    expect(() => Chord.parse('Cwibble'), throwsFormatException);
  });
}
