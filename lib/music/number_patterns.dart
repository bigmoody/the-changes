// Number patterns: four numbers, played off every chord that goes by.
//
// "1235" is not a lick. It is a shape (the 1st, 2nd, 3rd and 5th of
// whatever scale the chord is asking for), and the whole point is that it
// comes out different over every chord while your hand does the same
// thing. Over a Dm7 it is D E F A; over the G7 after it, G A B D. You
// practise the number, not the notes, and the changes do the rest.
//
// This is how a great deal of bebop was actually learned: a handful of
// shapes, run round the cycle until the fingers stop asking which key it
// is. It is also the quickest way to stop playing scales up and down,
// because a pattern has a shape of its own that a scale has not.
//
// The books call these digital patterns, meaning "of the digits": the
// fingers you count on, nothing to do with computers. That reading of
// the word has not survived, so they are called what they are here.
//
// The numbers are scale degrees, not chord degrees. The 3rd of a pattern
// over a minor chord is the ♭3, because that is what the 3rd note of its
// scale is; nothing here needs a special case for it.

import 'chord.dart';
import 'enclosures.dart' show scaleFor;

/// A pattern, as the numbers you say to yourself while playing it.
///
/// Numbers run past 7 into the octave above (9 is the 2nd, up an octave)
/// and below 1 into the one below (0 is the 7th, down an octave), because
/// that is how the useful ones are shaped.
class NumberPattern {
  const NumberPattern({
    required this.degrees,
    required this.name,
    required this.about,
  });

  final List<int> degrees;
  final String name;
  final String about;

  /// "1 2 3 5", for a chip.
  String get written => degrees.join(' ');
}

const numberPatterns = <NumberPattern>[
  NumberPattern(
    degrees: [1, 2, 3, 5],
    name: 'Up From the Root',
    about:
        'The one everybody starts on, and the one you will hear most. It '
        'steps up and then skips, which is what keeps it from sounding '
        'like a scale.',
  ),
  NumberPattern(
    degrees: [3, 4, 5, 7],
    name: 'Up From the 3rd',
    about:
        'The same shape started higher up. Beginning on the 3rd rather '
        'than the root is most of what makes a line sound like it knows '
        'the chord.',
  ),
  NumberPattern(
    degrees: [1, 3, 5, 7],
    name: 'The Arpeggio',
    about:
        'Nothing but chord tones. Dull on its own and the thing every '
        'other pattern is measured against: you have to be able to play '
        'this one in your sleep before the rest are worth anything.',
  ),
  NumberPattern(
    degrees: [3, 5, 7, 9],
    name: 'From the 3rd, Up',
    about:
        'The arpeggio moved up a notch, so it reaches the 9th. The top '
        'note is the one outside the chord, which is why it sounds like '
        'bebop and the plain arpeggio does not.',
  ),
  NumberPattern(
    degrees: [5, 3, 2, 1],
    name: 'Down to the Root',
    about:
        'Coming down lands you somewhere to go next. Most lines that '
        'sound finished are descending, and this is the plainest one.',
  ),
  NumberPattern(
    degrees: [7, 5, 3, 1],
    name: 'Arpeggio Down',
    about:
        'From the 7th down through the chord. Start it on the beat over a '
        'V and the ♭7 is the first thing anyone hears, which is the whole '
        'sound of the chord.',
  ),
  NumberPattern(
    degrees: [3, 2, 1, 0],
    name: 'Over the Bar',
    about:
        'Ends on the 7th below the root, which is a semitone or a tone '
        'from the next chord almost every time. The only one here that is '
        'written to lead somewhere rather than to sit still.',
  ),
];

/// A progression to run a pattern through, as steps above the key's root.
typedef PatternChanges = ({
  String name,
  String about,
  List<(int, String)> chords,
});

const patternChanges = <PatternChanges>[
  (
    name: 'ii–V–I',
    about: 'The move most of the music is made of. Start here.',
    chords: [(2, 'm7'), (7, '7'), (0, '^7')],
  ),
  (
    name: 'Minor ii–V–i',
    about: 'The same move in minor, where the ii is half-diminished.',
    chords: [(2, 'm7b5'), (7, '7b9'), (0, 'm7')],
  ),
  (
    name: 'Turnaround',
    about: 'The last two bars of nearly everything: I–vi–ii–V.',
    chords: [(0, '6'), (9, 'm7'), (2, 'm7'), (7, '7')],
  ),
  (
    name: 'Round the Cycle',
    about:
        'Dominants a fourth apart, which is where every V is going. Four '
        'of the twelve; move the key on and you have the rest.',
    chords: [(0, '7'), (5, '7'), (10, '7'), (3, '7')],
  ),
];

/// One note of a pattern: which number it is, and what that comes out as.
typedef PatternNote = ({int degree, String name, int pitch, int octave});

/// [pattern] played off [chord], from [octave].
///
/// The numbers index the chord's own scale, so a 3 over a minor chord is
/// its ♭3 without anything here having to know that. A chord with no scale
/// in the book comes back empty rather than guessing.
List<PatternNote> patternOn(List<int> degrees, Chord chord, {int octave = 4}) {
  final scale = scaleFor(chord);
  if (scale.isEmpty) return const [];
  final rootLetter = _letters.indexOf(scale.first[0]);
  return [
    for (final degree in degrees)
      () {
        // Dart's % is never negative but its ~/ truncates towards zero,
        // so the octave is worked out from the remainder rather than by
        // dividing; otherwise a 0 (the 7th below) lands in the wrong one.
        final index = (degree - 1) % 7;
        final octaves = ((degree - 1) - index) ~/ 7;
        final name = scale[index];
        // One letter per degree, so the octave turns over exactly when
        // the letters wrap past B.
        final at = octave + (rootLetter + index) ~/ 7 + octaves;
        final spelling = parseNoteName(name)!;
        return (
          degree: degree,
          name: name,
          // MIDI: C4 is 60.
          pitch: (at + 1) * 12 + pitchClassOf(spelling),
          octave: at,
        );
      }(),
  ];
}

const _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// Whether every note of [degrees] can be played off [chord].
bool fits(List<int> degrees, Chord chord) =>
    patternOn(degrees, chord).length == degrees.length;
