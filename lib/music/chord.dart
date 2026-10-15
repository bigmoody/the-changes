// Chord symbols: turning text like "Cm7" or "B♭Δ7" into real notes.
//
// A chord symbol has up to three parts:
//   root    – the letter the chord is built on (C, B♭, F♯ …)
//   quality – everything after the root, saying what *kind* of chord it is
//             (m7 = minor 7th, Δ7 = major 7th, ø7 = half-diminished …)
//   bass    – an optional "/G" at the end, meaning "put G in the bass".
//
// The [chordQualities] list below also powers the in-app chord symbol
// reference, so the playback and the reference can never disagree.

/// One kind of chord (e.g. "Minor 7th") and every common way of writing it.
class ChordQuality {
  const ChordQuality({
    required this.name,
    required this.symbols,
    required this.formula,
    required this.description,
    this.extensions = const [],
  });

  final String name;

  /// How musicians write this quality after the root, most common first.
  /// Stored in plain ASCII: `^` = Δ, `h` = ø, `o` = °, `b` = ♭, `#` = ♯.
  /// An empty string means "nothing after the root" (a plain major chord).
  final List<String> symbols;

  /// Scale degrees above the root, e.g. `['1', 'b3', '5', 'b7']`.
  final List<String> formula;

  final String description;

  /// Notes that aren't part of the chord itself but sound good over it: the
  /// tensions a player adds for colour, e.g. the 9th on a minor 7th.
  final List<String> extensions;

  /// Semitones above the root for each degree in [formula].
  List<int> get intervals => formula.map(degreeToSemitones).toList();
}

const chordQualities = <ChordQuality>[
  ChordQuality(
    name: 'Major',
    symbols: ['', 'maj', 'M'],
    formula: ['1', '3', '5'],
    description: 'A letter on its own means a major triad: bright and stable.',
    extensions: ['9', '13'],
  ),
  ChordQuality(
    name: 'Major 7th',
    symbols: ['^7', 'maj7', '^', 'M7'],
    formula: ['1', '3', '5', '7'],
    description:
        'The triangle (Δ) means major 7th: a major chord plus the note a '
        'semitone below the root. Usually the home (I) chord in a major key.',
    extensions: ['9', '13'],
  ),
  ChordQuality(
    name: 'Major 6th',
    symbols: ['6'],
    formula: ['1', '3', '5', '6'],
    description: 'A softer alternative to Δ7 on a home chord.',
    extensions: ['9'],
  ),
  ChordQuality(
    name: 'Six-nine',
    symbols: ['69', '6/9'],
    formula: ['1', '3', '5', '6', '9'],
    description: 'A major 6th with an added 9th. A warm, open ending chord.',
  ),
  ChordQuality(
    name: 'Major 9th',
    symbols: ['^9', 'maj9'],
    formula: ['1', '3', '5', '7', '9'],
    description: 'A major 7th chord with an added 9th.',
    extensions: ['13'],
  ),
  ChordQuality(
    name: 'Dominant 7th',
    symbols: ['7'],
    formula: ['1', '3', '5', 'b7'],
    description:
        'A bare "7" means dominant 7th: major chord plus a flat 7th. It pulls '
        'strongly down a fifth (G7 → C). The V chord.',
    extensions: ['9', '13'],
  ),
  ChordQuality(
    name: 'Dominant 9th',
    symbols: ['9'],
    formula: ['1', '3', '5', 'b7', '9'],
    description: 'A dominant 7th with an added 9th.',
    extensions: ['13'],
  ),
  ChordQuality(
    name: 'Dominant 13th',
    symbols: ['13'],
    formula: ['1', '3', '5', 'b7', '9', '13'],
    description:
        'A dominant 7th with added 9th and 13th. Often played '
        'without the 5th.',
  ),
  ChordQuality(
    name: 'Dominant 7th flat 9',
    symbols: ['7b9'],
    formula: ['1', '3', '5', 'b7', 'b9'],
    description: 'A tense V chord, typically resolving to a minor chord.',
    extensions: ['b13'],
  ),
  ChordQuality(
    name: 'Dominant 7th sharp 9',
    symbols: ['7#9'],
    formula: ['1', '3', '5', 'b7', '#9'],
    description:
        'Contains both a major 3rd and a "minor 3rd" (the ♯9). '
        'Bluesy and gritty.',
    extensions: ['b13'],
  ),
  ChordQuality(
    name: 'Dominant 7th sharp 11',
    symbols: ['7#11'],
    formula: ['1', '3', '5', 'b7', '#11'],
    description: 'The "Lydian dominant" sound. Try the Lydian ♭7 scale.',
    extensions: ['9', '13'],
  ),
  ChordQuality(
    name: 'Altered dominant',
    symbols: ['7alt', 'alt'],
    formula: ['1', '3', 'b7', 'b9', '#9', 'b13'],
    description:
        'A dominant chord with every tension altered. Improvise '
        'with the altered scale (7th mode of melodic minor).',
  ),
  ChordQuality(
    name: 'Dominant 7th suspended 4th',
    symbols: ['7sus4', '7sus', 'sus7'],
    formula: ['1', '4', '5', 'b7'],
    description:
        'The 3rd is replaced by the 4th, so the chord floats '
        'instead of pulling to resolve.',
    extensions: ['9', '13'],
  ),
  ChordQuality(
    name: 'Suspended 4th',
    symbols: ['sus4', 'sus'],
    formula: ['1', '4', '5'],
    description: 'A triad with the 4th instead of the 3rd.',
    extensions: ['9'],
  ),
  ChordQuality(
    name: 'Minor',
    symbols: ['m', '-', 'min'],
    formula: ['1', 'b3', '5'],
    description: 'A lowercase "m" or a minus sign (−) means minor.',
    extensions: ['9', '11'],
  ),
  ChordQuality(
    name: 'Minor 7th',
    symbols: ['m7', '-7', 'min7'],
    formula: ['1', 'b3', '5', 'b7'],
    description: 'The ii chord in a major key (Dm7 in C major).',
    extensions: ['9', '11', '13'],
  ),
  ChordQuality(
    name: 'Minor 6th',
    symbols: ['m6', '-6'],
    formula: ['1', 'b3', '5', '6'],
    description: 'A common home (i) chord in minor-key jazz tunes.',
    extensions: ['9', '11'],
  ),
  ChordQuality(
    name: 'Minor 9th',
    symbols: ['m9', '-9'],
    formula: ['1', 'b3', '5', 'b7', '9'],
    description: 'A minor 7th chord with an added 9th.',
    extensions: ['11', '13'],
  ),
  ChordQuality(
    name: 'Minor-major 7th',
    symbols: ['m^7', '-^7', 'mmaj7', 'mM7'],
    formula: ['1', 'b3', '5', '7'],
    description:
        'A minor chord with a *major* 7th. Dark and dramatic; often '
        'a passing chord in a descending line (Cm, CmΔ7, Cm7).',
    extensions: ['9', '11'],
  ),
  ChordQuality(
    name: 'Half-diminished',
    symbols: ['h7', 'h', 'm7b5', '-7b5'],
    formula: ['1', 'b3', 'b5', 'b7'],
    description:
        'The circle with a slash (ø) means half-diminished: a minor '
        '7th chord with a flat 5th. The ii chord in a minor key (Dø7 → G7 → Cm).',
    extensions: ['11', 'b13'],
  ),
  ChordQuality(
    name: 'Diminished 7th',
    symbols: ['o7', 'dim7'],
    formula: ['1', 'b3', 'b5', 'bb7'],
    description:
        'The small circle (°) means diminished. Built entirely from '
        'minor 3rds, so the shape repeats every three semitones.',
    extensions: ['9', '11'],
  ),
  ChordQuality(
    name: 'Diminished',
    symbols: ['o', 'dim'],
    formula: ['1', 'b3', 'b5'],
    description: 'A diminished triad: two stacked minor 3rds.',
    extensions: ['9', '11'],
  ),
  ChordQuality(
    name: 'Augmented',
    symbols: ['+', 'aug'],
    formula: ['1', '3', '#5'],
    description: 'A plus sign means augmented: a major chord with a sharp 5th.',
    extensions: ['9'],
  ),
  ChordQuality(
    name: 'Augmented 7th',
    symbols: ['+7', '7#5', 'aug7'],
    formula: ['1', '3', '#5', 'b7'],
    description: 'A dominant 7th with a sharp 5th.',
    extensions: ['9'],
  ),
];

/// Lookup from a written quality ("m7", "^7" …) to its [ChordQuality].
final Map<String, ChordQuality> _qualityBySymbol = {
  for (final quality in chordQualities)
    for (final symbol in quality.symbols) symbol: quality,
};

const _majorScaleSemitones = {
  1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11, 9: 14, 11: 17, 13: 21, //
};

/// Converts a scale degree such as "b3" or "#11" into semitones above the root.
int degreeToSemitones(String degree) {
  final match = RegExp(r'^([b#]*)(\d+)$').firstMatch(degree);
  final base = match == null
      ? null
      : _majorScaleSemitones[int.parse(match[2]!)];
  if (match == null || base == null) {
    throw FormatException('Unknown scale degree "$degree"');
  }
  var offset = 0;
  for (final accidental in match[1]!.split('')) {
    offset += accidental == '#' ? 1 : -1;
  }
  return base + offset;
}

const _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
const _letterPitchClasses = [0, 2, 4, 5, 7, 9, 11];

String _accidentalGlyph(int accidental) => switch (accidental) {
  -2 => '𝄫',
  -1 => '♭',
  1 => '♯',
  2 => '𝄪',
  _ => '',
};

/// Converts typed shorthand (Δ, ø, °, ♭, ♯, −) to the ASCII form used in
/// [ChordQuality.symbols].
String _normalise(String text) => text
    .trim()
    .replaceAll('Δ', '^')
    .replaceAll('ø', 'h')
    .replaceAll('°', 'o')
    .replaceAll('♭', 'b')
    .replaceAll('♯', '#')
    .replaceAll('−', '-');

/// The display form of a quality symbol, e.g. "^7" → "Δ7", "7b9" → "7♭9".
String prettyQuality(String symbol) => symbol
    .replaceAll('^', 'Δ')
    .replaceAll('h', 'ø')
    .replaceAll(RegExp(r'^o'), '°')
    .replaceAllMapped(RegExp(r'b(?=\d)'), (_) => '♭')
    .replaceAll('#', '♯');

/// The display form of a formula degree, e.g. "b3" → "♭3".
String prettyDegree(String degree) =>
    degree.replaceAll('b', '♭').replaceAll('#', '♯');

/// A note name as a letter (0 = C … 6 = B) plus an accidental
/// (-1 = flat, 0 = natural, +1 = sharp).
typedef Spelling = ({int letter, int accidental});

/// Parses a note name such as "B♭", "F#" or "C". Returns null if it isn't one.
Spelling? parseNoteName(String text) {
  final match = RegExp(r'^([A-G])([b#]?)$').firstMatch(_normalise(text));
  if (match == null) return null;
  return (
    letter: _letters.indexOf(match[1]!),
    accidental: switch (match[2]) {
      'b' => -1,
      '#' => 1,
      _ => 0,
    },
  );
}

int pitchClassOf(Spelling note) =>
    (_letterPitchClasses[note.letter] + note.accidental) % 12;

String noteNameOf(Spelling note) =>
    _letters[note.letter] + _accidentalGlyph(note.accidental);

/// How to move every note when changing key: up [semitones], and up
/// [letterSteps] letter names, so the spelling follows the new key
/// (B♭ → C is 2 semitones and 1 letter; A♯ → C would be 2 letters).
class Transposition {
  const Transposition({required this.letterSteps, required this.semitones});

  static const none = Transposition(letterSteps: 0, semitones: 0);

  final int letterSteps;
  final int semitones;

  Spelling apply(Spelling note) {
    final letter = (note.letter + letterSteps) % 7;
    final pitch = (pitchClassOf(note) + semitones) % 12;
    final accidental = _accidentalFor(letter, pitch);
    if (accidental.abs() <= 1) return (letter: letter, accidental: accidental);

    // A double flat or sharp (e.g. B𝄫): respell it as a plain note if
    // possible, otherwise with a single accidental in the same direction.
    for (final wanted in [0, accidental.sign]) {
      for (var candidate = 0; candidate < 7; candidate++) {
        if (_accidentalFor(candidate, pitch) == wanted) {
          return (letter: candidate, accidental: wanted);
        }
      }
    }
    return (letter: letter, accidental: accidental);
  }

  static int _accidentalFor(int letter, int pitchClass) =>
      (pitchClass - _letterPitchClasses[letter] + 6) % 12 - 6;
}

/// A single chord symbol from a chart, e.g. `Chord.parse('Bbm7')`.
class Chord {
  const Chord._({
    required this.rootLetter,
    required this.rootAccidental,
    required this.qualitySymbol,
    required this.quality,
    this.bassLetter,
    this.bassAccidental = 0,
  });

  /// Throws a [FormatException] if the symbol isn't recognised.
  factory Chord.parse(String text) {
    final match = RegExp(r'^([A-G])([b#]?)(.*?)(?:/([A-G])([b#]?))?$')
        .firstMatch(_normalise(text));
    final quality = match == null ? null : _qualityBySymbol[match[3]!];
    if (match == null || quality == null) {
      throw FormatException('Unrecognised chord symbol "$text"');
    }
    int accidental(String? sign) => switch (sign) {
      'b' => -1,
      '#' => 1,
      _ => 0,
    };
    return Chord._(
      rootLetter: _letters.indexOf(match[1]!),
      rootAccidental: accidental(match[2]),
      qualitySymbol: match[3]!,
      quality: quality,
      bassLetter: match[4] == null ? null : _letters.indexOf(match[4]!),
      bassAccidental: accidental(match[5]),
    );
  }

  /// Index into C D E F G A B.
  final int rootLetter;

  /// -1 for flat, +1 for sharp, 0 for natural.
  final int rootAccidental;
  final String qualitySymbol;
  final ChordQuality quality;
  final int? bassLetter;
  final int bassAccidental;

  /// Pitch class of the root: 0 = C, 1 = C♯/D♭ … 11 = B.
  int get root => (_letterPitchClasses[rootLetter] + rootAccidental) % 12;

  /// Pitch class of the lowest note (the slash bass if there is one).
  int get bass => bassLetter == null
      ? root
      : (_letterPitchClasses[bassLetter!] + bassAccidental) % 12;

  String get rootName =>
      _letters[rootLetter] + _accidentalGlyph(rootAccidental);

  /// How the chord is shown on the chart, e.g. "B♭Δ7" or "C7/G".
  String get display {
    final slash = bassLetter == null
        ? ''
        : '/${_letters[bassLetter!]}${_accidentalGlyph(bassAccidental)}';
    return '$rootName${prettyQuality(qualitySymbol)}$slash';
  }

  /// This chord moved to a new key, e.g. Cm7 up a whole step → Dm7.
  Chord transposed(Transposition transposition) {
    final root = _readable(
      transposition.apply((letter: rootLetter, accidental: rootAccidental)),
    );
    final bass = bassLetter == null
        ? null
        : _readable(
            transposition.apply((
              letter: bassLetter!,
              accidental: bassAccidental,
            )),
          );
    return Chord._(
      rootLetter: root.letter,
      rootAccidental: root.accidental,
      qualitySymbol: qualitySymbol,
      quality: quality,
      bassLetter: bass?.letter,
      bassAccidental: bass?.accidental ?? 0,
    );
  }

  /// A chord root as players write it: C♭7 is theoretically right as the
  /// ♭VI7 of E♭ minor, but every chart calls it B7. (Inside a chord it's a
  /// different matter, the 3rd of A♭m really is C♭, so this is only
  /// for roots and bass notes.)
  static Spelling _readable(Spelling note) => switch (note) {
    (letter: 0, accidental: -1) => (letter: 6, accidental: 0), // C♭ → B
    (letter: 3, accidental: -1) => (letter: 2, accidental: 0), // F♭ → E
    (letter: 2, accidental: 1) => (letter: 3, accidental: 0), // E♯ → F
    (letter: 6, accidental: 1) => (letter: 0, accidental: 0), // B♯ → C
    // D♯ → E♭ and A♯ → B♭. Nobody writes a chord on D♯ or A♯, whatever
    // the quality: the roots the drill deals out are E♭ and B♭ for major,
    // dominant and minor alike, and D♯ is the spelling its own comment
    // says stops a player dead. Transposing a letter at a time will
    // otherwise land on them, which is how an E♭ part of The Girl from
    // Ipanema came to read E♭Δ7 in bar 17 and D♯m7 in bar 21: the same
    // note, because the concert chart writes G♭Δ7 there and F♯m7 here,
    // and the two spellings move to different letters.
    //
    // Only these two. C♯, F♯ and G♯ are all real chord roots and which
    // way they are written depends on where the chord is going, which is
    // a judgement this cannot make from one chord at a time.
    (letter: 1, accidental: 1) => (letter: 2, accidental: -1), // D♯ → E♭
    (letter: 5, accidental: 1) => (letter: 6, accidental: -1), // A♯ → B♭
    _ => note,
  };

  /// The same chord written with a different quality symbol, e.g. "Cmaj7".
  String displayWith(String symbol) => '$rootName${prettyQuality(symbol)}';

  /// Pitch classes of every chord tone, in formula order.
  List<int> get pitchClasses => [
    for (final interval in quality.intervals) (root + interval) % 12,
  ];

  /// Correctly spelled note names, e.g. B°7 → B D F A♭ (not G♯).
  List<String> get noteNames => [
    for (final degree in quality.formula) _spell(degree),
  ];

  /// The notes players add for colour, each with the degree it is:
  /// e.g. Dm7 → [(E, 9), (G, 11), (B, 13)].
  List<({String note, String degree})> get extensionNotes => [
    for (final degree in quality.extensions)
      (note: _spell(degree), degree: prettyDegree(degree)),
  ];

  /// The note that is [degree] of this chord, correctly spelled: the ♭3 of
  /// B♭m7 is D♭, not C♯.
  String noteFor(String degree) => _spell(degree);

  /// The pitch class (0 = C … 11 = B) of [degree] of this chord.
  int pitchClassFor(String degree) => (root + degreeToSemitones(degree)) % 12;

  String _spell(String degree) {
    final number = int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));
    final letter = (rootLetter + number - 1) % 7;
    final target = (root + degreeToSemitones(degree)) % 12;
    // How far the target pitch is from the plain letter, in -6..5.
    final accidental = (target - _letterPitchClasses[letter] + 6) % 12 - 6;
    return _letters[letter] + _accidentalGlyph(accidental);
  }

  /// The chord without its extensions: only the root, 3rd, 5th and 7th (or
  /// 6th), e.g. D7♯11 → D7, C13 → C7, Fm9 → Fm7, C6/9 → C6. The simpler
  /// shape to play when reading at tempo. Altered 5ths stay (C7♯5 is still
  /// C7♯5); a 7alt, which has no 5th, becomes a plain 7.
  Chord get withoutExtensions {
    int numberOf(String degree) =>
        int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));
    final core = [
      for (final degree in quality.formula)
        if (numberOf(degree) <= 7) degree,
    ];
    if (core.length == quality.formula.length) return this;

    bool same(List<String> a, List<String> b) =>
        a.length == b.length && a.toSet().containsAll(b);
    final withFifth = core.any((d) => numberOf(d) == 5) ? core : [...core, '5'];
    for (final candidate in [core, withFifth]) {
      for (final other in chordQualities) {
        if (same(other.formula, candidate)) {
          return Chord._(
            rootLetter: rootLetter,
            rootAccidental: rootAccidental,
            qualitySymbol: other.symbols.first,
            quality: other,
            bassLetter: bassLetter,
            bassAccidental: bassAccidental,
          );
        }
      }
    }
    return this;
  }

  /// The chord with any slash bass taken off: D/E♭ → D. What a guitarist
  /// plays when the bass note is the bassist's job.
  Chord get withoutBass => bassLetter == null
      ? this
      : Chord._(
          rootLetter: rootLetter,
          rootAccidental: rootAccidental,
          qualitySymbol: qualitySymbol,
          quality: quality,
        );

  @override
  String toString() => display;
}
