// Chord-tone drills for improvisers.
//
// Two kinds of question:
//  • Spell it: name every note of a chord ("B♭m7?" → B♭ D♭ F A♭).
//  • Aim for: name one degree ("the 3rd of B♭m7?" → D♭), or both guide
//    tones (the 3rd and 7th), which are what make a line outline the
//    changes.
//
// Questions come from random chords at a chosen level, or walk through a
// ii–V–I in every key, which is where improvisers need these notes most.
// Everything here is written as the player reads it: a tenor player drilling
// in B♭ sees their own chord symbols and notes.

import 'dart:math' as math;

import 'chord.dart';

/// Spell the whole chord, or aim for particular degrees of it.
enum DrillMode {
  spell('Spell It'),
  aim('Aim For');

  const DrillMode(this.label);
  final String label;
}

/// Which chords the random questions use, from simplest to hardest.
enum DrillLevel {
  triads('Triads', ['', 'm', 'o', '+', 'sus4']),
  sevenths('7th chords', ['^7', 'm7', '7', 'h7', 'o7']),
  extended('6ths, 9ths & 13ths', [
    '6',
    'm6',
    '69',
    '^9',
    '9',
    'm9',
    '13',
    '7sus4',
  ]),
  altered('Altered', ['7b9', '7#9', '7#11', '7alt', '+7', 'm^7']);

  const DrillLevel(this.label, this.symbols);
  final String label;

  /// Quality symbols, in the ASCII form [Chord.parse] reads.
  final List<String> symbols;

  /// Whether any chord at this level has [target] to aim for: triads have
  /// no 7th, so "the 7th" isn't offered with them.
  bool offers(DrillTarget target) => symbols.any((symbol) {
    final chord = Chord.parse('C$symbol');
    return target.numbers.every((n) => degreeFor(chord, n) != null);
  });
}

/// What an "Aim for" question asks for.
enum DrillTarget {
  root('Root', [1]),
  third('3rd', [3]),
  fifth('5th', [5]),
  seventh('7th', [7]),
  ninth('9th', [9]),
  guideTones('3rd & 7th', [3, 7]);

  const DrillTarget(this.label, this.numbers);
  final String label;

  /// Degree numbers asked for, e.g. [3, 7] for the guide tones.
  final List<int> numbers;
}

/// Where the chords come from.
enum DrillSource {
  anyChord('Any chord'),
  twoFiveOne('ii–V–I'),
  minorTwoFiveOne('Minor ii–V–i');

  const DrillSource(this.label);
  final String label;
}

/// One question: a chord, and the degrees of it to name.
class DrillQuestion {
  const DrillQuestion({
    required this.chord,
    required this.degrees,
    required this.mode,
    this.progression = const [],
    this.position = 0,
    this.keyName,
  });

  final Chord chord;

  /// The degrees being asked for, as in [ChordQuality.formula] ("b3", "7" …).
  final List<String> degrees;
  final DrillMode mode;

  /// The whole progression when the question is part of one, with this
  /// chord at [position]: seeing where it's going is half the point.
  final List<Chord> progression;
  final int position;

  /// The key of the progression, e.g. "E♭", when there is one.
  final String? keyName;

  /// The notes that make a right answer, as pitch classes. Notes are marked
  /// by sound, not spelling: tapping C♯ for the ♭3 of B♭m7 is the right note,
  /// and the answer then shows it spelled D♭.
  Set<int> get answer => {for (final d in degrees) chord.pitchClassFor(d)};

  /// The right answer, spelled, with each note's degree.
  List<({String note, String degree})> get solution => [
    for (final d in degrees) (note: chord.noteFor(d), degree: prettyDegree(d)),
  ];

  /// "3rd" or "♭7th" for the degrees asked about, e.g. "♭3rd & ♭7th".
  String get degreeLabel => degrees.map(_ordinal).join(' & ');

  bool isRight(Set<int> tapped) =>
      tapped.length == answer.length && tapped.containsAll(answer);
}

/// "root", "♭3rd", "5th", "♭7th", "♯11th" …
String _ordinal(String degree) {
  final number = int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));
  if (number == 1) return 'root';
  final accidentals = prettyDegree(degree.replaceAll(RegExp(r'\d'), ''));
  return '$accidentals$number${number == 3 ? 'rd' : 'th'}';
}

/// The degree of [chord] that answers "the [number]th": the 3rd of Cm7 is its
/// ♭3, the 7th of C°7 its 𝄫7. A 6th chord's 6th stands in for its 7th, as it
/// does in the chord itself. Null if the chord hasn't got one, or has two
/// (a 7alt has both a ♭9 and a ♯9, so "the 9th" means nothing).
String? degreeFor(Chord chord, int number) {
  int numberOf(String degree) =>
      int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));
  List<String> matching(Iterable<String> degrees, int wanted) => [
    for (final d in degrees)
      if (numberOf(d) == wanted) d,
  ];

  final formula = chord.quality.formula;
  var found = matching(formula, number);
  if (found.isEmpty && number == 7) found = matching(formula, 6);
  if (found.isEmpty) found = matching(chord.quality.extensions, number);
  return found.length == 1 ? found.single : null;
}

/// Roots that read naturally for each kind of chord: nobody practises D♯7.
const _majorRoots = 'C Db D Eb E F Gb G Ab A Bb B';
const _dominantRoots = 'C Db D Eb E F F# G Ab A Bb B';
const _minorRoots = 'C C# D Eb E F F# G G# A Bb B';

List<String> _rootsFor(String symbol) {
  final quality = Chord.parse('C$symbol').quality;
  final intervals = quality.intervals;
  final roots = intervals.contains(3)
      ? _minorRoots // minor, ø, °
      : intervals.contains(10)
      ? _dominantRoots
      : _majorRoots;
  return roots.split(' ');
}

/// The progressions, written in C (or C minor); moved to every key.
const _twoFiveOne = ['Dm7', 'G7', 'C^7'];
const _minorTwoFiveOne = ['Dh7', 'G7b9', 'Cm6'];

/// Major keys by tonic, and minor keys, as they're usually written.
const _majorKeys = 'C Db D Eb E F Gb G Ab A Bb B';
// A♭ minor rather than G♯ minor: G♯ minor's V chord is D♯7, whose 3rd is
// F𝄪, a spelling that stops a player dead.
const _minorKeys = 'C C# D Eb E F F# G Ab A Bb B';

/// Deals out questions for one drill setting, never the same chord twice in
/// a row, and working through progressions a key at a time.
class ChordDrill {
  ChordDrill({
    required this.mode,
    required this.source,
    this.level = DrillLevel.sevenths,
    this.target = DrillTarget.third,
    math.Random? random,
  }) : random = random ?? math.Random();

  final DrillMode mode;
  final DrillSource source;
  final DrillLevel level;
  final DrillTarget target;
  final math.Random random;

  String? _lastChord;
  List<Chord> _progression = const [];
  String? _key;
  int _position = 0;
  final _keysLeft = <String>[];

  DrillQuestion next() {
    for (var attempt = 0; attempt < 200; attempt++) {
      final question = source == DrillSource.anyChord
          ? _randomChord()
          : _progressionChord();
      if (question == null) continue;
      if (source == DrillSource.anyChord &&
          question.chord.display == _lastChord) {
        continue;
      }
      _lastChord = question.chord.display;
      return question;
    }
    throw StateError('No question fits $mode / $level / $target');
  }

  DrillQuestion? _question(
    Chord chord, {
    List<Chord> progression = const [],
    int position = 0,
    String? keyName,
  }) {
    final List<String> degrees;
    if (mode == DrillMode.spell) {
      degrees = chord.quality.formula;
    } else {
      final found = [for (final n in target.numbers) degreeFor(chord, n)];
      if (found.contains(null)) return null;
      degrees = found.cast<String>();
    }
    return DrillQuestion(
      chord: chord,
      degrees: degrees,
      mode: mode,
      progression: progression,
      position: position,
      keyName: keyName,
    );
  }

  DrillQuestion? _randomChord() {
    final symbol = level.symbols[random.nextInt(level.symbols.length)];
    final roots = _rootsFor(symbol);
    final root = roots[random.nextInt(roots.length)];
    return _question(Chord.parse('$root$symbol'));
  }

  DrillQuestion? _progressionChord() {
    if (_position >= _progression.length) _startNextKey();
    final question = _question(
      _progression[_position],
      progression: _progression,
      position: _position,
      keyName: _key,
    );
    _position++;
    return question;
  }

  /// Moves on to a new key; every key comes up once before any repeats.
  void _startNextKey() {
    final minor = source == DrillSource.minorTwoFiveOne;
    if (_keysLeft.isEmpty) {
      _keysLeft
        ..addAll((minor ? _minorKeys : _majorKeys).split(' '))
        ..shuffle(random);
    }
    final key = _keysLeft.removeLast();
    final tonic = parseNoteName(key)!;
    final move = Transposition(
      letterSteps: tonic.letter,
      semitones: pitchClassOf(tonic),
    );
    _progression = [
      for (final symbol in minor ? _minorTwoFiveOne : _twoFiveOne)
        Chord.parse(symbol).transposed(move),
    ];
    _key = '${noteNameOf(tonic)}${minor ? ' minor' : ''}';
    _position = 0;
  }
}
