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
  test('one reading is not named; two the same are', () {
    final reader = ChordReader();
    reader.hear(notes([48, 52, 55], 0.05)); // the strum: louder
    expect(reader.hear(notes([48, 52, 55], 0.05)), isFalse);
    expect(reader.hear(notes([48, 52, 55], 0.05)), isTrue);
    expect(reader.guesses.first.display, 'C');
  });

  test('a chord dying away keeps its name', () {
    final reader = ChordReader();
    for (var i = 0; i < 3; i++) {
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
    for (var i = 0; i < 3; i++) {
      reader.hear(notes([48, 52, 55, 59], 0.05)); // CΔ7
    }
    expect(reader.guesses.first.display, 'CΔ7');
    // The same strings less one, struck again: a C, louder.
    reader.hear(notes([48, 52, 55], 0.08));
    reader.hear(notes([48, 52, 55], 0.08));
    reader.hear(notes([48, 52, 55], 0.08));
    expect(reader.guesses.first.display, 'C');
  });
}
