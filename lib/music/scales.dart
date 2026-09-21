// Scales and modes: the note choices that go with each kind of chord.
//
// A mode is a scale played from one of its other notes: D to D on the white
// keys is D Dorian, the 2nd mode of C major. Each family here is the seven
// modes of one parent scale (major, melodic minor, harmonic minor) plus
// the symmetric scales jazz players use over dominant and diminished chords.
//
// Degrees are written against the major scale (♭3, ♯4 …), one letter per
// degree, so every mode spells properly in any key: D Dorian is D E F G A B C,
// and E♭ Dorian is E♭ F G♭ A♭ B♭ C D♭, never F♯ or C♯.

import 'chord.dart';

/// The scales modes are taken from.
enum ScaleFamily {
  major('Major', 'major'),
  melodicMinor('Melodic minor', 'melodic minor'),
  harmonicMinor('Harmonic minor', 'harmonic minor'),
  symmetric('Symmetric', '');

  const ScaleFamily(this.label, this.parentName);

  /// Short, for a filter chip.
  final String label;

  /// For "Mode 2 of C melodic minor".
  final String parentName;
}

class Mode {
  const Mode({
    required this.name,
    required this.family,
    required this.number,
    required this.degrees,
    required this.chord,
    required this.colour,
    required this.description,
    this.parentDegree,
    this.alsoKnownAs,
  });

  final String name;
  final ScaleFamily family;

  /// Which mode of its parent scale this is: 1 is the parent itself.
  final int number;

  /// The degrees from the root up, e.g. Dorian `['1', '2', 'b3', '4', '5',
  /// '6', 'b7']`.
  final List<String> degrees;

  /// The quality symbol of the chord it's played over, e.g. `'m7'`.
  final String chord;

  /// The degrees that give the mode its own sound (Dorian's ♮6, Lydian's
  /// ♯4), which set it apart from its neighbours.
  final List<String> colour;
  final String description;

  /// The degree of this mode that is its parent scale's root: C is the ♭7
  /// of D Dorian. Null for a first mode and the symmetric scales.
  final String? parentDegree;
  final String? alsoKnownAs;

  /// Semitones above the root of each degree, low to high.
  List<int> get semitones => [for (final d in degrees) degreeToSemitones(d)];

  /// The mode's notes from [root], spelled one letter per degree. Where
  /// that would need a double flat or sharp (D♭ Locrian's E𝄫 and B𝄫), the
  /// root is respelled instead (C♯ Locrian). See [spelledRoot].
  ///
  /// Scales that aren't one note per letter (the altered scale's ♭9 and
  /// ♯9, the eight-note diminished scales, the six-note whole tone) are
  /// spelled as players write them instead: a double sharp or flat, or an
  /// E♯, B♯, F♭ or C♭, becomes the plain note (E altered is E F G G♯ A♯ C D,
  /// not E F F𝄪 …).
  List<String> notesFrom(String root) {
    final spelled = spelledRoot(root);
    final speller = Chord.parse(spelled);
    final notes = [for (final degree in degrees) speller.noteFor(degree)];
    if (_onePerLetter) return notes;
    final flats = spelled.contains('♭') || spelled == 'F';
    return [
      for (final note in notes)
        _awkward.hasMatch(note) ? _plainName(note, flats) : note,
    ];
  }

  bool get _onePerLetter =>
      degrees.length == 7 &&
      degrees.map((d) => d.replaceAll(RegExp(r'[b#]'), '')).toSet().length == 7;

  static final _awkward = RegExp(r'𝄫|𝄪|^E♯$|^B♯$|^F♭$|^C♭$');

  /// [note] under its plain name: a natural, or one flat or sharp.
  static String _plainName(String note, bool flats) {
    const sharpNames = [
      'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B', //
    ];
    const flatNames = [
      'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
    ];
    return (flats ? flatNames : sharpNames)[_pitchOf(note) % 12];
  }

  static int _pitchOf(String note) {
    var pitch = const {
      'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11, //
    }[note[0]]!;
    for (final rune in note.substring(1).runes) {
      pitch += switch (String.fromCharCode(rune)) {
        '♭' => -1,
        '♯' => 1,
        '𝄫' => -2,
        '𝄪' => 2,
        _ => 0,
      };
    }
    return pitch;
  }

  /// [root], or the same note under its other name if that spells the mode
  /// with fewer double flats and sharps.
  String spelledRoot(String root) {
    int doubles(String r) {
      final speller = Chord.parse(r);
      return degrees
          .map(speller.noteFor)
          .where((n) => n.contains('𝄫') || n.contains('𝄪'))
          .length;
    }

    final other = _enharmonics[root];
    if (other == null) return root;
    return doubles(other) < doubles(root) ? other : root;
  }

  /// "Mode 2 of C major", or what the scale is if it's a first mode.
  String parentFrom(String root) {
    if (parentDegree == null) {
      return family == ScaleFamily.symmetric
          ? 'Symmetric scale'
          : 'Mode 1: the ${family.parentName} scale itself';
    }
    final parent = Chord.parse(spelledRoot(root)).noteFor(parentDegree!);
    return 'Mode $number of $parent ${family.parentName}';
  }

  /// The chord this mode goes with, on [root].
  Chord chordOn(String root) => Chord.parse('${spelledRoot(root)}$chord');
}

const _enharmonics = {
  'D♭': 'C♯', 'C♯': 'D♭', 'E♭': 'D♯', 'D♯': 'E♭', 'F♯': 'G♭', 'G♭': 'F♯', //
  'A♭': 'G♯', 'G♯': 'A♭', 'B♭': 'A♯', 'A♯': 'B♭', 'B': 'C♭', 'E': 'F♭',
};

const _major = ScaleFamily.major;
const _melodic = ScaleFamily.melodicMinor;
const _harmonic = ScaleFamily.harmonicMinor;
const _symmetric = ScaleFamily.symmetric;

const modes = [
  // The major scale.
  Mode(
    name: 'Ionian',
    family: _major,
    number: 1,
    degrees: ['1', '2', '3', '4', '5', '6', '7'],
    chord: '^7',
    colour: ['7'],
    description:
        'Bright and settled. Over a Δ7 the 4th clashes: pass through '
        'it rather than landing on it.',
  ),
  Mode(
    name: 'Dorian',
    family: _major,
    number: 2,
    parentDegree: 'b7',
    degrees: ['1', '2', 'b3', '4', '5', '6', 'b7'],
    chord: 'm7',
    colour: ['6'],
    description:
        'The jazz minor sound: minor, with a bright natural 6th. '
        'The first choice over a ii chord.',
  ),
  Mode(
    name: 'Phrygian',
    family: _major,
    number: 3,
    parentDegree: 'b6',
    degrees: ['1', 'b2', 'b3', '4', '5', 'b6', 'b7'],
    chord: 'm7',
    colour: ['b2'],
    description:
        'Dark, with a Spanish edge from the ♭2. Over sus♭9 chords '
        'and minor vamps.',
  ),
  Mode(
    name: 'Lydian',
    family: _major,
    number: 4,
    parentDegree: '5',
    degrees: ['1', '2', '3', '#4', '5', '6', '7'],
    chord: '^7',
    colour: ['#4'],
    description:
        'Major with a raised 4th: floating and modern. Every note '
        'sounds good over a Δ7♯11.',
  ),
  Mode(
    name: 'Mixolydian',
    family: _major,
    number: 5,
    parentDegree: '4',
    degrees: ['1', '2', '3', '4', '5', '6', 'b7'],
    chord: '7',
    colour: ['b7'],
    description:
        'Major with a ♭7: the plain dominant sound, and the blues. '
        'Over a V7 that isn\'t altered.',
  ),
  Mode(
    name: 'Aeolian',
    alsoKnownAs: 'the natural minor scale',
    family: _major,
    number: 6,
    parentDegree: 'b3',
    degrees: ['1', '2', 'b3', '4', '5', 'b6', 'b7'],
    chord: 'm7',
    colour: ['b6'],
    description:
        'Minor with a ♭6: darker than Dorian. Over a minor i or vi '
        'chord.',
  ),
  Mode(
    name: 'Locrian',
    family: _major,
    number: 7,
    parentDegree: 'b2',
    degrees: ['1', 'b2', 'b3', '4', 'b5', 'b6', 'b7'],
    chord: 'h7',
    colour: ['b2', 'b5'],
    description:
        'The half-diminished sound: the ii of a minor ii–V. The ♭5 '
        'is the chord\'s own.',
  ),

  // Melodic minor: minor with a major 6th and 7th.
  Mode(
    name: 'Melodic minor',
    alsoKnownAs: 'jazz minor',
    family: _melodic,
    number: 1,
    degrees: ['1', '2', 'b3', '4', '5', '6', '7'],
    chord: 'm^7',
    colour: ['6', '7'],
    description:
        'Minor with a major 6th and 7th: the tonic minor sound, '
        'over mΔ7 and m6 chords.',
  ),
  Mode(
    name: 'Dorian ♭2',
    alsoKnownAs: 'Phrygian ♮6',
    family: _melodic,
    number: 2,
    parentDegree: 'b7',
    degrees: ['1', 'b2', 'b3', '4', '5', '6', 'b7'],
    chord: '7sus4',
    colour: ['b2', '6'],
    description: 'Over sus♭9 chords: the suspended sound of modal jazz.',
  ),
  Mode(
    name: 'Lydian augmented',
    family: _melodic,
    number: 3,
    parentDegree: '6',
    degrees: ['1', '2', '3', '#4', '#5', '6', '7'],
    chord: '+',
    colour: ['#4', '#5'],
    description: 'Lydian with a raised 5th, over Δ7♯5 chords.',
  ),
  Mode(
    name: 'Lydian dominant',
    alsoKnownAs: 'Lydian ♭7',
    family: _melodic,
    number: 4,
    parentDegree: '5',
    degrees: ['1', '2', '3', '#4', '5', '6', 'b7'],
    chord: '7#11',
    colour: ['#4', 'b7'],
    description:
        'Mixolydian with a ♯4: over a 7♯11, and a dominant that '
        'doesn\'t resolve down a 5th, like the IV7 in a blues.',
  ),
  Mode(
    name: 'Mixolydian ♭6',
    alsoKnownAs: 'Aeolian dominant',
    family: _melodic,
    number: 5,
    parentDegree: '4',
    degrees: ['1', '2', '3', '4', '5', 'b6', 'b7'],
    chord: '7',
    colour: ['b6'],
    description: 'A dominant with a ♭13: over a V7 going to a minor chord.',
  ),
  Mode(
    name: 'Locrian ♮2',
    alsoKnownAs: 'half-diminished scale',
    family: _melodic,
    number: 6,
    parentDegree: 'b3',
    degrees: ['1', '2', 'b3', '4', 'b5', 'b6', 'b7'],
    chord: 'h7',
    colour: ['2'],
    description:
        'Locrian with a natural 9th: the usual modern choice over '
        'a ø7, smoother than Locrian.',
  ),
  Mode(
    name: 'Altered',
    alsoKnownAs: 'super Locrian',
    family: _melodic,
    number: 7,
    parentDegree: 'b2',
    degrees: ['1', 'b2', '#2', '3', '#4', 'b6', 'b7'],
    chord: '7alt',
    colour: ['b2', '#2', '#4', 'b6'],
    description:
        'Every tension a dominant can have (♭9 ♯9 ♯11 ♭13) over '
        'a 7alt resolving to the I. Played as the 7th mode of melodic minor '
        'a half step up.',
  ),

  // Harmonic minor: minor with a major 7th.
  Mode(
    name: 'Harmonic minor',
    family: _harmonic,
    number: 1,
    degrees: ['1', '2', 'b3', '4', '5', 'b6', '7'],
    chord: 'm^7',
    colour: ['b6', '7'],
    description:
        'Minor with a major 7th, and a wide leap from the ♭6 up to '
        'it: an exotic, classical minor.',
  ),
  Mode(
    name: 'Locrian ♮6',
    family: _harmonic,
    number: 2,
    parentDegree: 'b7',
    degrees: ['1', 'b2', 'b3', '4', 'b5', '6', 'b7'],
    chord: 'h7',
    colour: ['6'],
    description: 'Half-diminished with a natural 6th.',
  ),
  Mode(
    name: 'Ionian ♯5',
    family: _harmonic,
    number: 3,
    parentDegree: '6',
    degrees: ['1', '2', '3', '4', '#5', '6', '7'],
    chord: '+',
    colour: ['#5'],
    description: 'Major with a raised 5th, over Δ7♯5 chords.',
  ),
  Mode(
    name: 'Dorian ♯4',
    family: _harmonic,
    number: 4,
    parentDegree: '5',
    degrees: ['1', '2', 'b3', '#4', '5', '6', 'b7'],
    chord: 'm7',
    colour: ['#4'],
    description:
        'Dorian with a raised 4th: a minor sound with a bluesy, '
        'Eastern European edge.',
  ),
  Mode(
    name: 'Phrygian dominant',
    family: _harmonic,
    number: 5,
    parentDegree: '4',
    degrees: ['1', 'b2', '3', '4', '5', 'b6', 'b7'],
    chord: '7b9',
    colour: ['b2', '3'],
    description:
        'The V7♭9 of a minor key: the classic sound of a minor '
        'ii–V resolving.',
  ),
  Mode(
    name: 'Lydian ♯2',
    family: _harmonic,
    number: 6,
    parentDegree: '3',
    degrees: ['1', '#2', '3', '#4', '5', '6', '7'],
    chord: '^7',
    colour: ['#2', '#4'],
    description: 'Lydian with a raised 2nd: bright, and a little strange.',
  ),
  Mode(
    name: 'Ultralocrian',
    alsoKnownAs: 'altered 𝄫7',
    family: _harmonic,
    number: 7,
    parentDegree: 'b2',
    degrees: ['1', 'b2', 'b3', 'b4', 'b5', 'b6', 'bb7'],
    chord: 'o7',
    colour: ['b4', 'bb7'],
    description: 'Over a diminished 7th chord leading up a half step.',
  ),

  // Symmetric scales: the same pattern of steps all the way up.
  Mode(
    name: 'Whole tone',
    family: _symmetric,
    number: 1,
    degrees: ['1', '2', '3', '#4', '#5', 'b7'],
    chord: '+7',
    colour: ['#4', '#5'],
    description:
        'Six notes, all whole steps apart: dreamy and unresolved. '
        'Over a 7♯5 (augmented 7th).',
  ),
  Mode(
    name: 'Half-whole diminished',
    alsoKnownAs: 'dominant diminished',
    family: _symmetric,
    number: 1,
    degrees: ['1', 'b2', '#2', '3', '#4', '5', '6', 'b7'],
    chord: '7b9',
    colour: ['b2', '#2', '#4'],
    description:
        'Half step, whole step, repeating: over a 7♭9 or 13♭9, '
        '♭9 and ♯9 with a natural 5th and 13th.',
  ),
  Mode(
    name: 'Whole-half diminished',
    alsoKnownAs: 'diminished scale',
    family: _symmetric,
    number: 1,
    degrees: ['1', '2', 'b3', '4', 'b5', 'b6', '6', '7'],
    chord: 'o7',
    colour: ['2', '4', 'b6', '7'],
    description:
        'Whole step, half step, repeating: over a °7 chord, adding '
        'a note a whole step above each chord tone.',
  ),
];
