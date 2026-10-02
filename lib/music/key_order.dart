// Going round the twelve keys, and spelling a note so it can be read.
//
// Both of these started life inside the licks feature and outlived it:
// every round in the app (scales, patterns, changes, walking bass) counts
// the same twelve keys in the same orders, and anything that writes a note
// name has the same choice of sharp or flat to make.

import 'dart:math' as math;

const _flatKeys = {5, 10, 3, 8, 1, 6};

/// [pitch] written the way it would be read in [key].
///
/// The same sound has two names and only one of them is readable: a line
/// in E flat with a G flat in it is a line somebody has to stop and work
/// out, and the same note called F sharp in D is the same problem the
/// other way. Nothing about the sound changes; it is about whoever has to
/// read it.
///
/// This spells by the key rather than by the chord underneath, which is
/// what makes a line easy to read straight through. A chord-aware
/// spelling would get a few passing notes more nearly right and would
/// change how a note looks halfway through a phrase, which is worse.
String nameInKey(int pitch, {required int key}) {
  const sharps = [
    'C',
    'C♯',
    'D',
    'D♯',
    'E',
    'F',
    'F♯',
    'G',
    'G♯',
    'A',
    'A♯',
    'B',
  ];
  const flats = [
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
  final names = _flatKeys.contains(key % 12) ? flats : sharps;
  return names[pitch % 12];
}

/// The order the keys come round in a drill.
enum KeyOrder {
  fourths('Round the cycle'),
  chromatic('Up in semitones'),
  random('Shuffled');

  const KeyOrder(this.label);
  final String label;

  /// The twelve moves from the key a lick was played in, in this order,
  /// starting with none at all: you play it where you know it first.
  List<int> moves({int seed = 0}) => switch (this) {
    // Up a fourth each time, which is the order changes actually go in.
    fourths => [for (var i = 0; i < 12; i++) (i * 5) % 12],
    chromatic => [for (var i = 0; i < 12; i++) i],
    random => () {
      final rest = [for (var i = 1; i < 12; i++) i]..shuffle(math.Random(seed));
      return [0, ...rest];
    }(),
  };
}
