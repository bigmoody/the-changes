// Tritone substitution: playing a different dominant and getting away
// with it.
//
// Any dominant 7th can be swapped for the dominant a tritone away: G7
// for D♭7, and back. It is the one reharmonisation everybody learns
// first, and it is usually explained as though it were a trick. It is
// not. The two chords are made of the same two notes in the middle.
//
// G7's 3rd is B and its ♭7 is F. D♭7's 3rd is F and its ♭7 is C♭, which
// is B under another name. The pair that makes a dominant sound like
// itself, the tritone between the 3rd and the ♭7, is the same tritone
// in both chords, with the two notes swapped over. Nothing that matters
// has changed, so the ear lets it pass.
//
// What has changed is the bass. A ii–V–I walks D–G–C, a fourth and a
// fourth; with the sub it walks D–D♭–C, downhill by semitones. That is
// what you actually hear, and why the substitution sounds smoother
// rather than merely different.

import 'chord.dart';
import 'guide_tones.dart';

/// Six semitones: half an octave, and the same distance whichever way you
/// count it, which is the whole reason the substitution works in both
/// directions at once.
const tritone = 6;

/// The dominant a tritone from [chord].
///
/// Only dominants have a tritone between their 3rd and ♭7, so only
/// dominants can be swapped this way: anything else comes back unchanged
/// rather than pretending.
Chord? subFor(Chord chord) {
  if (!isDominant(chord)) return null;
  final root = (chord.root + tritone) % 12;
  // Spelled flat, because the substitute is nearly always read as a ♭II
  // going down to the I: D♭7 to C, not C♯7 to C.
  return Chord.parse('${_flatNames[root]}7');
}

/// Whether [chord] is a dominant 7th: a major 3rd and a minor 7th.
bool isDominant(Chord chord) {
  final intervals = chord.quality.intervals.map((i) => i % 12).toSet();
  return intervals.contains(4) && intervals.contains(10);
}

const _flatNames = [
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

/// The pitch classes of [chord]'s 3rd and 7th, which is what the ear is
/// actually listening to.
Set<int> guideToneClasses(Chord chord) {
  final tones = guideTonesThrough([chord]).single;
  return {
    pitchClassOf(parseNoteName(tones.upper)!),
    pitchClassOf(parseNoteName(tones.lower)!),
  };
}

/// Whether two chords are held up by the same two notes.
///
/// This is the claim the whole exercise rests on, so it is worth being
/// able to ask it directly rather than trusting the picture.
bool shareGuideTones(Chord a, Chord b) =>
    guideToneClasses(a).length == 2 &&
    guideToneClasses(a).difference(guideToneClasses(b)).isEmpty;

/// A progression to show the swap in, as steps above the key's root and
/// which chord (if any) is the one to substitute.
typedef SubChanges = ({
  String name,
  String about,
  List<(int, String)> chords,

  /// Which of [chords] the substitution is made on.
  int at,
});

const subChanges = <SubChanges>[
  (
    name: 'ii–V–I',
    at: 1,
    about:
        'The plainest place to hear it. The bass stops leaping a fourth '
        'and walks down by semitones instead.',
    chords: [(2, 'm7'), (7, '7'), (0, '^7')],
  ),
  (
    name: 'Turnaround',
    at: 3,
    about:
        'The V at the end of a turnaround, on its way back round. This is '
        'where you will play it most often without thinking about it.',
    chords: [(0, '6'), (9, 'm7'), (2, 'm7'), (7, '7')],
  ),
  (
    name: 'The V Of The V',
    at: 0,
    about:
        'Substituting earlier, on the II7 rather than the V. Do both and '
        'the bass walks down four semitones in a row.',
    chords: [(2, '7'), (7, '7'), (0, '^7')],
  ),
];

/// How the bass moves through [chords], in semitones, the short way round.
///
/// The substitution's whole audible advantage is here: a run of −1s
/// instead of the fourths.
List<int> bassMoves(List<Chord> chords) => [
  for (var i = 1; i < chords.length; i++)
    (chords[i].root - chords[i - 1].root + 6) % 12 - 6,
];
