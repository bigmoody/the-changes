// Naming what a chord *does* in a key: Roman numerals and Nashville numbers.
//
// A chord symbol says which notes to play; a number says what the chord is
// for. Dm7 G7 CΔ7 and Fm7 Bb7 EbΔ7 are the same three chords — ii7 V7 IΔ7 —
// and a player who hears that hears the same phrase in both keys. These two
// functions turn a [Chord] into that reading, either as Roman numerals (the
// way theory books and jazz teachers write it) or as Nashville numbers (the
// way a session player writes a chart they may have to move on the stand).
//
// The one big caveat: every number here is measured from the key the tune is
// *written* in, and a tune that modulates doesn't stay there. Cherokee is
// written in B♭, and its bridge is four ii–V–Is stepping down from B through
// A and G, which read here as ♭iii7 ♭VI7 ♭IIΔ7, ♭ii7 ♯IV7 VIIΔ7, vii7 III7
// VIΔ7 — every one of them true, and none of them how a player thinks about
// it. What a player thinks is "ii–V–I in B, then in A, then in G". The
// numbers say how far each chord is from home, not what key the music is in
// at that moment, because the chart names only the one key.

import 'chord.dart';

/// Semitones above the tonic for scale degrees 1–7 of a major key.
const _majorScale = [0, 2, 4, 5, 7, 9, 11];

/// The same for a minor key, where the reference is the *natural* minor
/// scale. This is what makes C minor read the way musicians talk about it:
/// E♭ is the 3, A♭ the 6 and B♭ the 7 of C minor, not ♭3, ♭6 and ♭7. The
/// cost is that the raised degrees of harmonic and melodic minor come out
/// marked: in C minor a B natural is ♯7, so a B°7 reads ♯vii°7. That is
/// consistent — an accidental always means "this far from the reference
/// scale" — and it has the virtue of showing the player exactly which note
/// has been raised.
const _minorScale = [0, 2, 3, 5, 7, 8, 10];

const _romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

/// A scale degree: which number (1–7) and how far it is from that degree of
/// the reference scale (0 = as the scale has it, -1 = flattened, +1 = raised).
typedef _Degree = ({int number, int alteration});

/// What each chromatic note away from home is called, in a major key —
/// see [_degreeOf]. Indexed by semitones above the tonic. The flats win over
/// the sharps (♭II, ♭III, ♭VI, ♭VII rather than ♯I, ♯II, ♯V, ♯VI) because
/// those are the names players actually use for the borrowed chords: the
/// bridge of Cherokee goes to ♭II, not to ♯I. The tritone is the exception
/// and is ♯4, because ♯iv is a chord players know by that name and ♭v isn't.
const _majorBySound = <_Degree>[
  (number: 1, alteration: 0),
  (number: 2, alteration: -1),
  (number: 2, alteration: 0),
  (number: 3, alteration: -1),
  (number: 3, alteration: 0),
  (number: 4, alteration: 0),
  (number: 4, alteration: 1),
  (number: 5, alteration: 0),
  (number: 6, alteration: -1),
  (number: 6, alteration: 0),
  (number: 7, alteration: -1),
  (number: 7, alteration: 0),
];

/// The same for a minor key, measured from the natural minor scale, so the
/// notes that are already in it (the 3, 6 and 7) are plain and the ones
/// raised out of it — the leading tone, the Dorian 6th — are sharp.
const _minorBySound = <_Degree>[
  (number: 1, alteration: 0),
  (number: 2, alteration: -1),
  (number: 2, alteration: 0),
  (number: 3, alteration: 0),
  (number: 3, alteration: 1),
  (number: 4, alteration: 0),
  (number: 4, alteration: 1),
  (number: 5, alteration: 0),
  (number: 6, alteration: 0),
  (number: 6, alteration: 1),
  (number: 7, alteration: 0),
  (number: 7, alteration: 1),
];

/// One way of writing each quality, whatever the chart wrote. A numeral is
/// already a crowded little thing, so "Cmin7" and "C-7" both read as ii7, and
/// the wordy spellings never reach the screen. Built from the app's own
/// symbol list, so a quality added there is handled here without a change.
final Map<String, String> _shortForm = {
  for (final quality in chordQualities)
    for (final symbol in quality.symbols) symbol: quality.symbols.first,
  // Two deliberate exceptions. An augmented 7th reads better as 7♯5 than as
  // +7, because the 7 is what says the chord is a dominant and these charts
  // write it that way; and a six-nine keeps its slash, since a bass degree
  // is only ever 1–7 so "I6/9" can't be misread as a chord over its 9th.
  '+7': '7#5',
  '7#5': '7#5',
  '69': '6/9',
  '6/9': '6/9',
};

/// Whether [key] — "C minor", "D Dorian", "B♭" — is a minor key. Dorian
/// counts as minor, exactly as the rest of the app reads a key string: a
/// Dorian tune is a minor tune with a raised 6th, and So What's Dm7 is its
/// i chord, not its ii.
bool _isMinorKey(String key) => key.contains('minor') || key.contains('Dorian');

/// The tonic of [key], e.g. B♭ from "B♭" and C from "C minor". A key string
/// the app doesn't recognise is read as C rather than thrown out, because a
/// numeral is a reading aid and should never stop a chart being shown.
Spelling _tonicOf(String key) =>
    parseNoteName(RegExp(r'^[A-G][♭♯b#]?').stringMatch(key) ?? 'C') ??
    (letter: 0, accidental: 0);

/// Where [note] falls in the key whose tonic is [tonic].
///
/// A note that is in the key is counted by its letter: in C, a D is the 2
/// and an E♭ — one letter further on — the ♭3. A note that isn't in the key
/// could be counted either way, and then it's named by sound, from
/// [_majorBySound], rather than by how the chart happened to spell it. This
/// matters because charts spell chromatic roots for the player's fingers,
/// not for the analyst: All the Things You Are is in A♭ and its bridge is
/// written EΔ7, so counting letters would call it ♯VΔ7, when what every
/// player hears and says is ♭VIΔ7.
///
/// [trustSpelling] turns that off for diminished chords, where the spelling
/// is the one thing that says which way the chord is going. Donna Lee's B°7
/// climbs into a Cm7, so in A♭ it reads ♯ii°7; the very same four notes
/// written D°7 are leaning elsewhere and read ♯iv°7.
_Degree _degreeOf(
  Spelling note,
  Spelling tonic,
  bool minorKey, {
  bool trustSpelling = false,
}) {
  final scale = minorKey ? _minorScale : _majorScale;
  final distance = (pitchClassOf(note) - pitchClassOf(tonic) + 12) % 12;
  final index = (note.letter - tonic.letter + 7) % 7;
  // The distance from the scale's own version of this degree, in -6..5.
  final alteration = (distance - scale[index] + 6) % 12 - 6;
  if (alteration == 0 || (trustSpelling && alteration.abs() == 1)) {
    return (number: index + 1, alteration: alteration);
  }
  return (minorKey ? _minorBySound : _majorBySound)[distance];
}

/// "♭", "♯" or nothing, to go in front of the numeral.
String _accidentals(int alteration) =>
    (alteration < 0 ? '♭' : '♯') * alteration.abs();

/// Whether the chord is one of the minor-sounding kinds — minor, minor 6th,
/// half-diminished, diminished — which is what decides upper or lower case.
/// Worked out from the notes rather than the text, so every quality the app
/// knows is covered: a ♭3 makes it lower case, and nothing else does. A sus
/// chord has no 3rd at all and stays upper case, as V7sus4 always is.
bool _isMinorish(ChordQuality quality) => quality.intervals.contains(3);

/// Whether the chord is a dominant: a ♭7 without a ♭3. These are the chords
/// whose 7th a Nashville chart leaves out, see [nashvilleFor].
bool _isDominant(ChordQuality quality) =>
    quality.intervals.contains(10) && !_isMinorish(quality);

/// Whether the chord is a diminished one — a ♭3 and a ♭5 with no ♭7, so the
/// diminished triad and the diminished 7th but not the half-diminished,
/// whose spelling carries no such promise. See [_degreeOf].
bool _isDiminished(ChordQuality quality) =>
    quality.intervals.contains(3) &&
    quality.intervals.contains(6) &&
    !quality.intervals.contains(10);

/// What goes after the numeral: the chord's own character, written the way
/// the chart writes it — 7♭9, Δ7, ø7, 7alt. A minor chord's "m" comes off,
/// because the lower-case numeral has already said it (ii7, not iim7), and
/// a plain triad keeps nothing at all, so C in C is just "I".
String _suffix(Chord chord) {
  final symbol = _shortForm[chord.qualitySymbol] ?? chord.qualitySymbol;
  final text = prettyQuality(symbol);
  if (_isMinorish(chord.quality) && text.startsWith('m')) {
    return text.substring(1);
  }
  return text;
}

/// The slash bass as a degree of the key, e.g. "/3" for C/E in C. Empty
/// unless the chord really has a bass note of its own: the bass degree is
/// always arabic, in both notations, because it names a note of the scale
/// and not a chord.
String _over(Chord chord, Spelling tonic, bool minorKey) {
  final bassLetter = chord.bassLetter;
  if (bassLetter == null || chord.bass == chord.root) return '';
  final degree = _degreeOf(
    (letter: bassLetter, accidental: chord.bassAccidental),
    tonic,
    minorKey,
  );
  return '/${_accidentals(degree.alteration)}${degree.number}';
}

/// The degree of the key that [chord] is built on.
_Degree _rootDegree(Chord chord, Spelling tonic, bool minorKey) => _degreeOf(
  (letter: chord.rootLetter, accidental: chord.rootAccidental),
  tonic,
  minorKey,
  trustSpelling: _isDiminished(chord.quality),
);

/// A chord's function in a key, written as a Roman numeral: "ii7", "V7",
/// "IΔ7", "♭III7", "♯iv°7", "I/3".
///
/// The numeral is the chord's root counted up from the key's tonic; its case
/// says what kind of chord it is (upper for major and dominant, lower for
/// minor, half-diminished and diminished); the suffix is the chord's own
/// quality, as the chart writes it.
String romanFor(Chord chord, String key) {
  final minorKey = _isMinorKey(key);
  final tonic = _tonicOf(key);
  final degree = _rootDegree(chord, tonic, minorKey);
  final numeral = _romanNumerals[degree.number - 1];
  return _accidentals(degree.alteration) +
      (_isMinorish(chord.quality) ? numeral.toLowerCase() : numeral) +
      _suffix(chord) +
      _over(chord, tonic, minorKey);
}

/// The same reading, Nashville style: "2-7", "5", "1Δ7", "♭2", "1/3".
///
/// Two things differ from the Roman numerals, both of them the common
/// Nashville convention:
///
/// Arabic numerals can't be upper or lower case, so a minor chord is marked
/// with a minus instead: 2-7 is a minor 7th on the 2. A half-diminished or
/// diminished chord doesn't get one, because its ø or ° has already said
/// that the chord is minor-sounding (2ø7, not 2-ø7).
///
/// A number on its own is played as a dominant when a dominant is what the
/// music wants, so the 7 of a dominant chord isn't written: G7 in C is "5",
/// and a blues in F reads 1 4 1 1 4 4 1 1 5 4 1 5, which is exactly how a
/// Nashville chart writes a blues. The rest of the alteration stays, with
/// the assumed 7 taken off the front of it — G7♭9 in C is "5♭9", G7alt is
/// "5alt". The price is that a plain major triad and a dominant 7th look
/// alike here (C and C7 in C are both "1"); the Roman numeral tells them
/// apart (I and I7), which is why the app can show both readings.
///
/// A suffix that is itself a number and would land straight against the
/// degree goes in brackets, because a Nashville chart writes it small and
/// raised and this one can't: C6 in C is "1(6)", since "16" reads as sixteen.
/// After a minus there's no such trouble, so a minor 6th stays "1-6".
String nashvilleFor(Chord chord, String key) {
  final minorKey = _isMinorKey(key);
  final tonic = _tonicOf(key);
  final degree = _rootDegree(chord, tonic, minorKey);
  var suffix = _suffix(chord);
  if (_isDominant(chord.quality) && suffix.startsWith('7')) {
    suffix = suffix.substring(1);
  }
  // The minus goes on the minor chords that don't already say so in their
  // suffix: m, m7, m6, m9 and mΔ7, but not ø7 or °7.
  final minor = _isMinorish(chord.quality) && !suffix.startsWith(RegExp('[ø°]'))
      ? '-'
      : '';
  if (minor.isEmpty && suffix.startsWith(RegExp(r'\d'))) {
    suffix = '($suffix)';
  }
  return '${_accidentals(degree.alteration)}${degree.number}$minor$suffix'
      '${_over(chord, tonic, minorKey)}';
}
