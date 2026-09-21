// Passing chords: the ones that go in the gaps.
//
// A chart gives you the chords that have to be there. Between any two of
// them there is usually room for one that does not, and putting it in is
// most of what people mean by reharmonising: not rewriting the tune,
// just filling the space between two chords that were already going to
// happen.
//
// Nearly all of it comes down to the bass. Two chords a whole tone apart
// leave a gap you can walk through, and a passing chord is a chord built
// on the note in that gap. Once you hear it that way the devices below
// stop being five separate tricks and become one idea used five times.
//
// The tritone substitution is the sixth, and it has a screen of its own
// because it works differently: it replaces a chord rather than adding
// one.

import 'chord.dart';

/// A chord you can put between two chords.
typedef PassingMove = ({
  String name,
  String about,

  /// The changes as the chart writes them: semitones above the key, and
  /// a quality.
  List<(int, String)> plain,

  /// The same changes with the passing chord put in.
  List<(int, String)> filled,

  /// Which of [filled] is the one that was added.
  int at,
});

/// The ones worth knowing, easiest first.
const passingMoves = <PassingMove>[
  (
    name: 'Passing Diminished',
    at: 1,
    about:
        'The I and the ii are a whole tone apart, so there is a note in '
        'between and you can build a chord on it. A diminished 7th is '
        'what fits: every note of it is a semitone from something in the '
        'chord either side, so it leans both ways and settles nowhere. '
        'This is the single most common passing chord in the music.',
    plain: [(0, '6'), (2, 'm7')],
    filled: [(0, '6'), (1, 'o7'), (2, 'm7')],
  ),
  (
    name: 'Adding The ii',
    at: 0,
    about:
        'A lone V7 sitting in a bar of its own is a bar half empty. Put '
        'its ii in front of it and the same two beats say the same thing '
        'with somewhere to have come from. Nothing about the harmony '
        'changes: the ii and the V share three of their four notes.',
    plain: [(7, '7'), (0, '^7')],
    filled: [(2, 'm7'), (7, '7'), (0, '^7')],
  ),
  (
    name: 'Secondary Dominant',
    at: 1,
    about:
        'Any chord can be arrived at rather than simply reached. Put the '
        'dominant a fourth below it in front, and the ii becomes '
        'something the music was heading for. The A7 is borrowed: its C♯ '
        'is not in the key at all, which is exactly why it pulls.',
    plain: [(0, '6'), (2, 'm7')],
    filled: [(0, '6'), (9, '7'), (2, 'm7')],
  ),
  (
    name: 'Chromatic Approach',
    at: 1,
    about:
        'Slide into the chord from a semitone above with the same shape. '
        'Nothing clever is happening harmonically, which is the point: '
        'the ear hears one chord moved rather than a new one, so you can '
        'do it almost anywhere and it sounds deliberate.',
    plain: [(0, '6'), (2, 'm7')],
    filled: [(0, '6'), (3, 'm7'), (2, 'm7')],
  ),
  (
    name: 'Coming Back From The IV',
    at: 1,
    about:
        'Bar six of a jazz blues, and the reason bar six has a '
        'diminished in it. The bass climbs out of the IV a semitone at a '
        'time and the I is waiting when it arrives. Every blues chart in '
        'this app already has this one written into it.',
    plain: [(5, '7'), (0, '7')],
    filled: [(5, '7'), (6, 'o7'), (0, '7')],
  ),
];

/// How a key's twelve notes are spelled here: flats, as charts mostly
/// are.
const steps = ['C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B'];

/// The same notes spelled sharp, for a chord on its way up.
const sharpSteps = [
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

/// [changes] written out in [key].
///
/// A chord a semitone above the one before it is spelled sharp, because
/// that is how it is written and read: a passing chord climbing from C
/// to Dm7 is C♯°7, never D♭°7. Anything else takes the flat spelling
/// charts mostly use. Worked out from the shape rather than stored with
/// each move, so it stays right in every key.
List<Chord> chordsIn(List<(int, String)> changes, String key) {
  final root = steps.indexOf(key);
  final chords = <Chord>[];
  int? previous;
  for (final (step, quality) in changes) {
    final at = (root + step) % 12;
    final climbing = previous != null && (at - previous + 12) % 12 == 1;
    final names = climbing ? sharpSteps : steps;
    chords.add(Chord.parse('${names[at]}$quality'));
    previous = at;
  }
  return chords;
}

/// Whether the passing chord sits on a note the bass was going to walk
/// past anyway.
///
/// The claim the whole screen rests on: a passing chord is not squeezed
/// in, it is built on a note already in the gap. True where the two
/// chords it goes between are a whole tone apart and it lands on the
/// semitone in the middle.
bool fillsTheGap(PassingMove move, String key) {
  final filled = chordsIn(move.filled, key);
  if (move.at < 1 || move.at >= filled.length - 1) return false;
  final before = filled[move.at - 1].root;
  final added = filled[move.at].root;
  final after = filled[move.at + 1].root;
  int up(int from, int to) => (to - from + 12) % 12;
  return up(before, after) == 2 &&
      up(before, added) == 1 &&
      up(added, after) == 1;
}

/// What the passing chord adds, as a sentence: which note the bass gains.
String gapNote(PassingMove move, String key) =>
    chordsIn(move.filled, key)[move.at].rootName;
