// When the chord identifier names a chord: once the strum has settled,
// and not again while it dies away (chord_reader.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/chord_ear.dart';
import 'package:play_along/audio/chord_reader.dart';

HeardNotes notes(List<int> pitches, double level) {
  final chroma = List.filled(12, 0.0);
  for (final pitch in pitches) {
    chroma[pitch % 12] += 1 / pitches.length;
  }
  return HeardNotes(pitches: pitches, chroma: chroma, level: level);
}

void main() {
  test('the same three readings running are named; fewer are not', () {
    final reader = ChordReader();
    reader.hear(notes([48, 52, 55], 0.05)); // the strum: louder
    expect(reader.hear(notes([48, 52, 55], 0.05)), isFalse);
    expect(reader.hear(notes([48, 52, 55], 0.05)), isFalse);
    expect(reader.hear(notes([48, 52, 55], 0.05)), isTrue);
    expect(reader.guesses.first.display, 'C');
  });

  test('a chord dying away keeps its name', () {
    final reader = ChordReader();
    for (var i = 0; i < 4; i++) {
      reader.hear(notes([48, 52, 58, 62], 0.05)); // C9: C E B♭ D
    }
    expect(reader.guesses.first.display, 'C9');
    // The B flat gone: C, D and E left, which alone would be read another
    // way.
    for (var i = 0; i < 4; i++) {
      reader.hear(notes([48, 52, 62], 0.04 - i * 0.005));
    }
    expect(reader.guesses.first.display, 'C9');
  });

  test('a new chord strummed is named, even one inside the last', () {
    final reader = ChordReader();
    for (var i = 0; i < 4; i++) {
      reader.hear(notes([48, 52, 55, 59], 0.05)); // CΔ7
    }
    expect(reader.guesses.first.display, 'CΔ7');
    // The same strings less one, struck again: a C, louder.
    for (var i = 0; i < 4; i++) {
      reader.hear(notes([48, 52, 55], 0.08));
    }
    expect(reader.guesses.first.display, 'C');
  });

  test('a seventh that dies at once still names the chord', () {
    // A note fretted on the G string, heard through an iPad, is gone in
    // a fifth of a second: the C7's B flat, here, after one reading.
    final reader = ChordReader();
    reader.hear(notes([48, 52, 55, 58], 0.05)); // the strum
    reader.hear(notes([48, 52, 55, 58], 0.05));
    for (var i = 0; i < 4; i++) {
      reader.hear(notes([48, 52, 55], 0.045 - i * 0.004));
    }
    expect(reader.guesses.first.display, 'C7');
  });

  test('once settled, the name holds until the next strum', () {
    final reader = ChordReader();
    for (var i = 0; i < 10; i++) {
      reader.hear(notes([44, 48, 51, 53], 0.05)); // A♭6, half a second
    }
    expect(reader.guesses.first.display, 'A♭6');
    // Half a second later, the ring throws up a B flat, steadily: no.
    for (var i = 0; i < 12; i++) {
      reader.hear(notes([44, 48, 51, 53, 58], 0.05 - i * 0.001));
    }
    expect(reader.guesses.first.display, 'A♭6');
  });
}
