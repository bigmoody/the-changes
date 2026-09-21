// Working out a guitar grip for a chord symbol.
//
// Rather than keeping a dictionary of shapes, this searches the fretboard
// for one: pick a set of strings, a hand position, and a note on each string
// that belongs to the chord. Most of the work is in the rules that separate
// the shapes a guitarist would actually play from the thousands that are
// merely correct: the hand spans three frets, open strings only belong to
// shapes at the nut, the lowest note has to be the root, and the 3rd and 7th
// (plus any altered 5th) are what make the chord sound like itself.

import 'chord.dart';

/// Open strings in standard tuning, lowest first: E2 A2 D3 G3 B3 E4.
const guitarTuning = [40, 45, 50, 55, 59, 64];

/// How far up the neck a shape may sit before it stops being useful.
const _highestPosition = 11;

/// A chord shape: one entry per string from the low E, either a fret number
/// (0 = open) or null for a string that isn't played.
class GuitarVoicing {
  const GuitarVoicing(this.frets, {this.barre});

  final List<int?> frets;

  /// For a barre chord: the fret the first finger lies across, and the
  /// strings it covers (0 = low E … 5 = high E).
  final ({int fret, int from, int to})? barre;

  Iterable<int> get _fretted => frets.whereType<int>().where((f) => f > 0);

  /// The lowest fret the hand has to reach, or 0 if the shape is all open.
  int get position => _fretted.isEmpty ? 0 : _fretted.reduce(min);

  /// The notes the shape sounds, lowest first.
  List<int> get pitches => [
    for (var string = 0; string < frets.length; string++)
      if (frets[string] != null) guitarTuning[string] + frets[string]!,
  ];

  static int min(int a, int b) => a < b ? a : b;
  static int max(int a, int b) => a > b ? a : b;
}

/// The sets of strings worth playing, low to high. Skipping the 5th string
/// under a 6th-string root is the one gap a hand can mute comfortably.
const _stringSets = [
  [1, 2, 3, 4],
  [0, 2, 3, 4],
  [1, 2, 3, 4, 5],
  [0, 1, 2, 3],
  [2, 3, 4, 5],
  [0, 1, 2, 3, 4],
  [0, 2, 3, 4, 5],
  [1, 2, 3],
  [0, 1, 2, 3, 4, 5],
];

/// Searching the whole fretboard takes a few milliseconds, and the same
/// handful of chords come round again every chorus.
final _cache = <String, GuitarVoicing?>{};

/// A grip for [chord], or null if the fretboard has nothing playable (which
/// shouldn't happen for any ordinary chord symbol).
GuitarVoicing? guitarVoicingFor(Chord chord) => _cache.putIfAbsent(
  chord.display,
  () => _search(chord) ?? _search(guitarShapeChord(chord)),
);

/// The chord a guitar grip for [chord] plays: [chord] itself, or (for a
/// slash chord no hand can put the bass under, like D/E♭) the chord without
/// its bass, which is left to the bass player.
Chord guitarShapeChord(Chord chord) =>
    chord.bass == chord.root || _search(chord) != null
    ? chord
    : chord.withoutBass;

GuitarVoicing? _search(Chord chord) {
  final intervals = chord.quality.intervals;
  final tones = {
    for (final interval in intervals) (chord.root + interval) % 12,
  };
  bool hasDegree(int semitones) => intervals.contains(semitones);

  // The notes that say what kind of chord this is. Without them a shape is
  // just a stack of right notes that sounds like the wrong chord.
  final guides = <int>{
    for (final degree in [3, 4, 5]) // minor 3rd, major 3rd, suspended 4th
      if (hasDegree(degree)) (chord.root + degree) % 12,
    for (final degree in [9, 10, 11]) // 6th, ♭7th, major 7th
      if (hasDegree(degree)) (chord.root + degree) % 12,
    // An altered 5th is the sound of a 7♯5, a ø7 or a °7: leave it out
    // and the grip is just a plain 7th chord.
    for (final degree in [6, 8]) // ♭5, ♯5
      if (hasDegree(degree) && !hasDegree(7)) (chord.root + degree) % 12,
    // Whatever the symbol goes out of its way to name: the 13th of a C13,
    // the ♭9 of a C7♭9. A shape without it is a different chord.
    (chord.root + intervals.reduce((a, b) => a > b ? a : b)) % 12,
  };

  GuitarVoicing? best;
  var bestScore = double.infinity;

  for (final strings in _stringSets) {
    for (var position = 0; position <= _highestPosition; position++) {
      final choices = <List<int>>[];
      for (final string in strings) {
        final open = guitarTuning[string];
        choices.add([
          for (var fret = position; fret <= position + 3; fret++)
            if (tones.contains((open + fret) % 12)) fret,
          // An open string is always in reach.
          if (position > 0 && tones.contains(open % 12)) 0,
        ]);
      }
      if (choices.any((frets) => frets.isEmpty)) continue;

      for (final frets in _combinations(choices)) {
        final shape = List<int?>.filled(6, null);
        for (var i = 0; i < strings.length; i++) {
          shape[strings[i]] = frets[i];
        }
        final voicing = GuitarVoicing(shape);
        final score = _score(voicing, chord, guides);
        if (score != null && score < bestScore) {
          bestScore = score;
          best = voicing;
        }
      }
    }
  }
  return best;
}

/// How good a shape is, or null if a guitarist wouldn't play it.
double? _score(GuitarVoicing voicing, Chord chord, Set<int> guides) {
  final pitches = voicing.pitches;
  // The bass note carries the chord: the lowest string must be its root (or
  // whatever a slash chord asks for).
  if (pitches.first % 12 != chord.bass) return null;

  final sounded = {for (final pitch in pitches) pitch % 12};
  if (!sounded.containsAll(guides)) return null;

  final frets = voicing.frets;
  final fretted = frets.whereType<int>().where((f) => f > 0).toList();
  if (fretted.isEmpty) return null;
  final lowest = fretted.reduce(GuitarVoicing.min);
  final highest = fretted.reduce(GuitarVoicing.max);

  // The hand covers three frets comfortably. Four is a stretch most players
  // can't make, least of all near the nut, where the frets are widest.
  if (highest - lowest > 2) return null;

  // Open strings belong to shapes at the nut. Mixed into a shape further up
  // (x-4-3-1-0-x), they leave the hand in two places at once.
  if (frets.contains(0) && highest > 3) return null;

  // Four fingers. If that's not enough, the first finger barres the lowest
  // fret, which only works if nothing under the barre is meant to be muted
  // or open.
  if (fretted.length > 4) {
    if (fretted.where((fret) => fret != lowest).length > 3) return null;
    final barred = [
      for (var string = 0; string < 6; string++)
        if (frets[string] == lowest) string,
    ];
    for (var string = barred.first; string <= barred.last; string++) {
      final fret = frets[string];
      if (fret == null || fret == 0) return null;
    }
  }

  var score = 0.0;
  // Shapes in the first few positions are the ones people know.
  score += voicing.position * 0.6;
  if (voicing.position > 7) score += (voicing.position - 7) * 2;
  // Four notes is the jazz norm; more is fine, thinner is weak.
  score += pitches.length < 4
      ? (4 - pitches.length) * 2.5
      : (pitches.length - 4) * 1.0;
  // Doubling notes other than the root wastes a string.
  score += (pitches.length - sounded.length) * 1.2;
  // Every chord tone that fits is worth having.
  score += (chord.quality.intervals.length - sounded.length).clamp(0, 9) * 1.4;
  // A wide stretch is harder than a compact shape.
  score += (highest - lowest) * 0.8;
  return score;
}

/// Every way of picking one fret per string.
Iterable<List<int>> _combinations(List<List<int>> choices) sync* {
  final indices = List.filled(choices.length, 0);
  while (true) {
    yield [for (var i = 0; i < choices.length; i++) choices[i][indices[i]]];
    var i = choices.length - 1;
    while (i >= 0) {
      indices[i]++;
      if (indices[i] < choices[i].length) break;
      indices[i] = 0;
      i--;
    }
    if (i < 0) return;
  }
}

/// The shape that sounds exactly [pitches] on the neck, or null where a
/// guitar cannot make that arrangement.
///
/// With [onStrings], only that set of strings is tried, which is how you
/// ask for a shape on the top three rather than wherever it happens to
/// fall most easily.
///
/// Exact rather than approximate: the same notes in the same octaves, in
/// the same order, so a drop 2 comes out as a drop 2 rather than as some
/// other grip on the same chord. Null is a real answer and worth saying
/// out loud, because a four-note chord packed inside an octave mostly
/// cannot be played at all, which is the whole reason drop voicings
/// exist.
GuitarVoicing? shapeForPitches(
  List<int> pitches, {
  int highestFret = 15,
  int reach = 5,
  List<int>? onStrings,
}) {
  if (pitches.length < 2 || pitches.length > guitarTuning.length) return null;
  // Each note's distance above the lowest, which is what has to survive.
  final wanted = [for (final pitch in pitches) pitch - pitches.first];
  GuitarVoicing? best;

  final runs = onStrings == null
      ? _stringRuns(pitches.length)
      : [if (onStrings.length == pitches.length) onStrings];
  for (final strings in runs) {
    for (var fret = 0; fret <= highestFret; fret++) {
      final lowest = guitarTuning[strings.first] + fret;
      if (lowest % 12 != pitches.first % 12) continue;
      final frets = List<int?>.filled(guitarTuning.length, null);
      var fits = true;
      for (final (i, string) in strings.indexed) {
        final at = lowest + wanted[i] - guitarTuning[string];
        if (at < 0 || at > highestFret) {
          fits = false;
          break;
        }
        frets[string] = at;
      }
      if (!fits) continue;
      final voicing = GuitarVoicing(frets);
      final fretted = voicing.frets.whereType<int>().where((f) => f > 0);
      if (fretted.isNotEmpty &&
          fretted.reduce(GuitarVoicing.max) -
                  fretted.reduce(GuitarVoicing.min) >=
              reach) {
        continue;
      }
      // The lowest one on the neck, so the shape is the one a hand
      // would actually reach for.
      if (best == null || voicing.position < best.position) best = voicing;
    }
  }
  return best;
}

/// Runs of [length] strings, adjacent first and then with one string
/// skipped, which is how a drop 3 has to be played.
List<List<int>> _stringRuns(int length) {
  final runs = <List<int>>[];
  final strings = guitarTuning.length;
  for (var from = 0; from + length <= strings; from++) {
    runs.add([for (var i = 0; i < length; i++) from + i]);
  }
  for (var from = 0; from + length < strings; from++) {
    for (var gap = 1; gap < length; gap++) {
      final run = [
        for (var i = 0; i < length; i++) from + i + (i >= gap ? 1 : 0),
      ];
      if (run.last < strings) runs.add(run);
    }
  }
  return runs;
}

/// The shell of [chord] with its root on [rootString], counted from the
/// low E as nought.
///
/// The first shapes a jazz guitarist learns, and the ones a rhythm
/// player uses all night. Three notes: the root, then the 7th two
/// strings up and the 3rd on the string above that, which skips a string
/// in the middle and leaves the hand somewhere it can stay.
///
/// Null where the chord has no 3rd or 7th to speak of, or where the
/// shape runs off the end of the neck.
GuitarVoicing? shellShape(
  Chord chord, {
  required int rootString,
  int highestFret = 15,
}) {
  // The 7th two strings up, the 3rd on the one above it: the gap in the
  // middle is what a finger mutes and why the shape sits still.
  final seventhString = rootString + 2;
  final thirdString = rootString + 3;
  if (thirdString >= guitarTuning.length) return null;

  final intervals = chord.quality.intervals.map((i) => i % 12).toSet();
  final third = intervals.contains(3)
      ? 3
      : intervals.contains(4)
      ? 4
      : null;
  final seventh = intervals.contains(11)
      ? 11
      : intervals.contains(10)
      ? 10
      : intervals.contains(9)
      ? 9 // a 6th chord: its 6th does the 7th's work
      : null;
  if (third == null || seventh == null) return null;

  for (var fret = 0; fret <= highestFret; fret++) {
    if ((guitarTuning[rootString] + fret) % 12 != chord.root % 12) continue;
    final root = guitarTuning[rootString] + fret;
    final frets = List<int?>.filled(guitarTuning.length, null);
    frets[rootString] = fret;
    var reachable = true;
    for (final (string, degree) in [
      (seventhString, seventh),
      (thirdString, third),
    ]) {
      // The fret nearest the root's own, rather than the lowest one
      // that happens to sound the note: an open string beside a tenth
      // fret is the right note in a place no hand can go.
      var at = (root + degree - guitarTuning[string]) % 12;
      while (at < fret - 1) {
        at += 12;
      }
      if (at > fret + 4 || at > highestFret) {
        reachable = false;
        break;
      }
      frets[string] = at;
    }
    if (!reachable) continue;
    final voicing = GuitarVoicing(frets);
    final fretted = voicing.frets.whereType<int>().where((f) => f > 0);
    if (fretted.isNotEmpty &&
        fretted.reduce(GuitarVoicing.max) - fretted.reduce(GuitarVoicing.min) >=
            5) {
      continue;
    }
    return voicing;
  }
  return null;
}

/// The three inversions of [triad] on [strings], lowest note first.
///
/// How a guitarist actually uses a triad: not as a chord with a name but
/// as three shapes in a row up the neck, so whichever one is nearest the
/// hand is the one that gets played. Any that will not fit comes back
/// null rather than being left out, so the three stay in their places.
List<GuitarVoicing?> triadInversions(
  Chord triad, {
  List<int> strings = const [3, 4, 5],
}) {
  // Root position, then the 3rd on the bottom, then the 5th: the same
  // three notes rotated, and each rotation has its own spacing.
  const rotations = [
    (0, [0, 4, 7]),
    (4, [0, 3, 8]),
    (7, [0, 5, 9]),
  ];
  return [
    for (final (from, spacing) in rotations)
      shapeForPitches([
        for (final step in spacing) 60 + triad.root + from + step,
      ], onStrings: strings),
  ];
}

/// What each inversion is called.
const inversionNames = ['root position', '1st inversion', '2nd inversion'];
