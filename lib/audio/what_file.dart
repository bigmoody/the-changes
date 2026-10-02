// What somebody just handed us.
//
// Every reader in the app already checks a signature before it does
// anything: a SoundFont says sfbk, a MIDI file says MThd, a WAV says RIFF
// and then WAVE. Asking that question once, in front of all of them, is
// the difference between "that is not a SoundFont" and "that is a MIDI
// file, and here is where it goes".
//
// A dead end is the worst answer a file picker can give. Somebody who has
// found the right file and brought it to the wrong door should be told
// which door, not told no.

import 'dart:typed_data';

/// What a file turns out to be.
enum FileKind {
  soundFont('SoundFont', 'a SoundFont'),
  midi('MIDI file', 'a MIDI file'),
  // Named as WAV rather than as audio: the recording template asks for
  // WAV by name, and somebody who brought an MP3 needs to be told that is
  // the thing that is wrong with it.
  wav('WAV', 'a WAV'),

  /// Nothing we read. Not an error on its own: the readers still have the
  /// last word, and they say far more about what is wrong with a file
  /// than a four-letter tag at the front can.
  unknown('file', 'a file');

  const FileKind(this.name, this.asThing);

  /// For "That is a MIDI file".
  final String name;

  /// For "You can only use a SoundFont here", with its article.
  final String asThing;
}

/// What [bytes] is, by the tag it starts with.
///
/// Signatures only. It says what a file claims to be, not whether it is
/// any good: a truncated SoundFont still says sfbk, and the reader is the
/// one that finds out it is truncated.
FileKind whatIsThisFile(Uint8List bytes) {
  if (bytes.length < 12) return FileKind.unknown;
  if (_tag(bytes, 0) == 'MThd') return FileKind.midi;
  if (_tag(bytes, 0) != 'RIFF') return FileKind.unknown;
  // Both a SoundFont and a WAV are RIFF files; what they hold is written
  // four bytes later.
  return switch (_tag(bytes, 8)) {
    'sfbk' => FileKind.soundFont,
    'WAVE' => FileKind.wav,
    _ => FileKind.unknown,
  };
}

/// What to say when a file is the wrong kind for the job in hand.
///
/// Named rather than refused: "that is not a SoundFont" leaves somebody
/// looking at a file picker wondering what they got wrong.
String wrongKind(FileKind got, {required FileKind wanted, String? instead}) {
  if (got == FileKind.unknown) {
    return 'That is not ${wanted.asThing}.';
  }
  return 'That is ${got.asThing}, not ${wanted.asThing}.'
      '${instead == null ? '' : ' $instead'}';
}

String _tag(Uint8List bytes, int at) =>
    String.fromCharCodes(bytes.sublist(at, at + 4));
