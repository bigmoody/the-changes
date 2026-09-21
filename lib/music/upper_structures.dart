// Upper structure triads: a plain triad on top of a dominant.
//
// A C7♯9♭13 is four alterations to think about and a shape most people
// have to work out. An A♭ major triad is three notes you have known
// since you were eleven. Play the A♭ triad over a C in the bass and you
// have the C7♯9♭13, note for note, without having spelled anything.
//
// That is the whole idea, and it is worth more than it sounds. The hard
// part of playing altered dominants is not knowing which notes are
// available, it is finding them quickly enough to use them. An upper
// structure turns that into recalling a triad, which is a thing your
// hands already do without being asked.
//
// Which triads work is not a matter of taste. A dominant leaves certain
// notes free and objects to others, so only a handful of triads sit on
// it cleanly, and they are listed here by where their root falls above
// the chord. What each one adds is worked out from the notes rather
// than written beside them.

import 'chord.dart';

/// A triad you can put on top of a dominant, named by where its root
/// sits above the chord's root.
typedef UpperStructure = ({
  /// Semitones above the dominant's root.
  int above,

  /// What players call it: the triad's degree, in roman numerals.
  String roman,

  /// The chord symbol the whole thing comes out as.
  String symbol,

  String about,
});

/// The ones that work, in the order they are usually taught.
const upperStructures = <UpperStructure>[
  (
    above: 2,
    roman: 'II',
    symbol: '13♯11',
    about:
        'The bright one. Nothing in it is flattened, so it does not sound '
        'altered so much as lit from above: this is the Lydian dominant '
        'sound, and it suits a dominant that is not resolving anywhere in '
        'a hurry.',
  ),
  (
    above: 3,
    roman: '♭III',
    symbol: '7♯9',
    about:
        'The one everybody knows without knowing its name. It keeps the '
        '5th and the ♭7 of the chord underneath it and adds a single '
        'alteration, so it is the gentlest of them and the easiest to '
        'drop in anywhere.',
  ),
  (
    above: 6,
    roman: '♯IV',
    symbol: '7♭9♯11',
    about:
        'The triad a tritone away from the II, and it is no coincidence: '
        'this is the tritone substitution wearing a different hat. If you '
        'already play a D♭ triad over a G7 you have been using this one '
        'for years.',
  ),
  (
    above: 9,
    roman: 'VI',
    symbol: '13♭9',
    about:
        'A ♭9 and a natural 13 together, which is the sound of a dominant '
        'going to a major chord rather than a minor one. It keeps the 3rd '
        'of the chord in it, so it stays firmly the chord it is.',
  ),
  (
    above: 8,
    roman: '♭VI',
    symbol: '7♯9♭13',
    about:
        'The darkest of them, and the one that sounds most like the '
        'altered scale. It contains the root, which is unusual for an '
        'upper structure and is why it sits so solidly.',
  ),
];

/// What a note [above] semitones over the root is called on a dominant.
///
/// Written as a player reads them: the 11th is sharp and the 13th flat,
/// never a ♭5 or a ♯5, because that is how an altered dominant is
/// spelled and half the point is being able to read it back.
const tensionNames = {
  0: 'root',
  1: '♭9',
  2: '9',
  3: '♯9',
  4: '3rd',
  5: '11',
  6: '♯11',
  7: '5th',
  8: '♭13',
  9: '13',
  10: '♭7',
  11: '7th',
};

/// The three notes of [structure]'s triad over [dominant], lowest first,
/// as MIDI pitches from [from].
List<int> triadOver(Chord dominant, UpperStructure structure, {int from = 60}) {
  final root = from + (dominant.root + structure.above - from) % 12;
  return [root, root + 4, root + 7];
}

/// What each note of the triad is, over the dominant underneath it.
List<String> tensionsOf(Chord dominant, UpperStructure structure) => [
  for (final pitch in triadOver(dominant, structure))
    tensionNames[(pitch - dominant.root) % 12] ?? '',
];

/// The triad's own name: "A♭", "D", the thing you actually think.
String triadName(Chord dominant, UpperStructure structure) =>
    _names[(dominant.root + structure.above) % 12];

/// Everything the triad adds that the plain dominant has not got, in the
/// order a chord symbol writes them.
///
/// Derived rather than read off [UpperStructure.symbol], so the name and
/// the notes cannot come apart: anything that is already a root, 3rd,
/// 5th or ♭7 of the chord is not an addition, and the rest are sorted by
/// how far up they are.
List<String> additionsOf(Chord dominant, UpperStructure structure) {
  const plain = {'root', '3rd', '5th', '♭7'};
  final order = {
    '♭9': 0,
    '9': 1,
    '♯9': 2,
    '11': 3,
    '♯11': 4,
    '♭13': 5,
    '13': 6,
  };
  final added = [
    for (final tension in tensionsOf(dominant, structure))
      if (!plain.contains(tension)) tension,
  ];
  added.sort((a, b) => (order[a] ?? 9).compareTo(order[b] ?? 9));
  return added;
}

/// The whole thing written as a chord: "C13♯11".
String symbolOver(Chord dominant, UpperStructure structure) =>
    '${dominant.rootName}${structure.symbol}';

const _names = [
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
