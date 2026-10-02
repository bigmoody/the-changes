// Colouring the key a tune is in.
//
// A different thing from the chord colours next door, and worth keeping
// apart from them. Those follow the root of each chord, so the colour
// changes bar to bar. This one does not change at all: the whole tune is
// the colour of the key it is in, and "Autumn Leaves" is that colour from
// the title down.
//
// For many people with chromesthesia the colour is attached to the key
// rather than to single pitches, and it is the better documented of the
// two: Scriabin and Rimsky-Korsakov both published their key colours and
// disagreed with each other almost everywhere, which is the usual story.
// So somebody's C major need not be their C, and the two are separate
// maps rather than one map used twice.
//
// Twelve keys to begin with, with a switch that gives the minor keys
// their own. A minor key with nothing of its own follows the major, which
// means the switch costs nothing to try and nothing to undo: the same
// bargain the sharps and flats got.

import 'package:flutter/painting.dart';

import '../music/tune.dart';

/// How each key is usually written, which is how somebody choosing a
/// colour for it would expect to read it. Flat keys for major (D♭, not
/// C♯), sharps where minor keys are normally sharp (F♯ minor).
const majorKeyNames = [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];
const minorKeyNames = [
  'C',
  'C♯',
  'D',
  'E♭',
  'E',
  'F',
  'F♯',
  'G',
  'G♯',
  'A',
  'B♭',
  'B',
];

/// What colour each key is, for the person using the app.
class KeyColours {
  const KeyColours([this.byKey = const {}, this.byMinorKey = const {}]);

  /// Pitch class of the tonic (0 = C) to the colour that key looks like.
  /// Used for both majors and minors until the two are split.
  final Map<int, Color> byKey;

  /// The minor keys that have a colour of their own, where that differs
  /// from the major on the same note.
  final Map<int, Color> byMinorKey;

  bool get isEmpty => byKey.isEmpty && byMinorKey.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// How many colours somebody has chosen, counted the way they would
  /// count them: every answer they gave, split or not.
  int get chosen => byKey.length + byMinorKey.length;

  /// The colour of [key].
  ///
  /// [split] is whether the minor keys are being kept apart. With it off
  /// the minors are left where they are rather than thrown away, so the
  /// switch can go back and forth without costing anybody their answers.
  Color? of(KeyOf key, {bool split = true}) {
    if (split && key.minor) {
      if (byMinorKey[key.pitchClass % 12] case final theirs?) return theirs;
    }
    return byKey[key.pitchClass % 12];
  }

  /// The same again with one key set to [colour], or cleared when null.
  KeyColours set(int pitchClass, Color? colour, {bool minor = false}) {
    final out = {...(minor ? byMinorKey : byKey)};
    if (colour == null) {
      out.remove(pitchClass % 12);
    } else {
      out[pitchClass % 12] = colour;
    }
    return minor ? KeyColours(byKey, out) : KeyColours(out, byMinorKey);
  }

  /// One flat map, with the majors under their number and the minors
  /// under the same number and an m. The two cannot collide, and anything
  /// saved before the minors existed still reads back as it did.
  Map<String, int> toJson() => {
    for (final entry in byKey.entries) '${entry.key}': entry.value.toARGB32(),
    for (final entry in byMinorKey.entries)
      '${entry.key}m': entry.value.toARGB32(),
  };

  static KeyColours fromJson(Map<String, Object?> json) {
    final majors = <int, Color>{};
    final minors = <int, Color>{};
    for (final entry in json.entries) {
      if (entry.value case final int argb) {
        final minor = entry.key.endsWith('m');
        final number = int.tryParse(
          minor ? entry.key.substring(0, entry.key.length - 1) : entry.key,
        );
        if (number == null || number < 0 || number > 11) continue;
        (minor ? minors : majors)[number] = Color(argb);
      }
    }
    return KeyColours(majors, minors);
  }
}
