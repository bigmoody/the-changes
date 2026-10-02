// Recognising a file before trying to read it.
//
// The point is not detection for its own sake: it is that every door can
// name what it was handed rather than only refusing it.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/what_file.dart';

import 'soundfont_test.dart' show buildFont, sample, zone;

Uint8List bytesOf(List<int> head, {int pad = 64}) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

Uint8List riff(String kind) =>
    bytesOf([...'RIFF'.codeUnits, 0, 0, 0, 0, ...kind.codeUnits]);

void main() {
  test('a real SoundFont is recognised', () {
    // Built by the same fixture the parser's own tests use, so this is
    // not a guess about what one looks like.
    final font = buildFont(samples: [sample()], zones: [zone(0)]);
    expect(whatIsThisFile(font), FileKind.soundFont);
  });

  test('a WAV is told apart from it, though both are RIFF', () {
    expect(whatIsThisFile(riff('WAVE')), FileKind.wav);
    expect(whatIsThisFile(riff('sfbk')), FileKind.soundFont);
  });

  test('a MIDI file is recognised', () {
    expect(whatIsThisFile(bytesOf('MThd'.codeUnits)), FileKind.midi);
  });

  test('anything else is simply unknown, not an error', () {
    // The readers have the last word on what is wrong with a file; this
    // only says what it claims to be.
    expect(whatIsThisFile(bytesOf('JFIF'.codeUnits)), FileKind.unknown);
    expect(whatIsThisFile(riff('AVI ')), FileKind.unknown);
  });

  test('something too short to have a tag does not throw', () {
    expect(whatIsThisFile(Uint8List(0)), FileKind.unknown);
    expect(whatIsThisFile(Uint8List.fromList([1, 2, 3])), FileKind.unknown);
  });

  group('what it says when the file is at the wrong door', () {
    test('it names what the file is, not just what it is not', () {
      expect(
        wrongKind(FileKind.midi, wanted: FileKind.soundFont),
        'That is a MIDI file, not a SoundFont.',
      );
    });

    test('and can say where it should have gone', () {
      expect(
        wrongKind(
          FileKind.midi,
          wanted: FileKind.soundFont,
          instead: 'Add it as a part from the tune you want it on.',
        ),
        'That is a MIDI file, not a SoundFont. '
        'Add it as a part from the tune you want it on.',
      );
    });

    test('something it does not know is refused without inventing a name', () {
      expect(
        wrongKind(FileKind.unknown, wanted: FileKind.soundFont),
        'That is not a SoundFont.',
      );
    });
  });
}
