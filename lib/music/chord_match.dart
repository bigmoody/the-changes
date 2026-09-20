// Naming a chord from the notes somebody played.
//
// Two chords are often made of exactly the same notes: C6 and Am7 are both
// C, E, G and A. What tells them apart is which note is underneath, so the
// bass note counts for a lot here. Where it can't decide, the plainer
// reading wins — somebody strumming C, E and G has played a C, not an
// Am♭6 with notes missing.

import 'chord.dart';

/// A chord the notes might be, and how well they fit it.
class ChordGuess {
  const ChordGuess({required this.chord, required this.score, this.bass});

  final Chord chord;

  /// Roughly nought to one: how much of what was played the chord accounts
  /// for, and how much of the chord was played.
  final double score;

  /// The note underneath, when it isn't the root — the "E" of "C/E".
  final String? bass;

  String get display => bass == null ? chord.display : '${chord.display}/$bass';
}

/// The note names used for roots: the spellings a jazz chart would use.
const _rootNames = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', //
  'F#', 'G', 'Ab', 'A', 'Bb', 'B',
];

/// How ordinary each kind of chord is. This only breaks ties — it is far
/// too small to name something as a triad when the 7th is plainly there —
/// but it stops a plain major chord being reported as one of the dozen
/// rarer chords that happen to contain those three notes.
double _ordinary(ChordQuality quality) => switch (quality.symbols.first) {
  '' || 'm' => 1,
  '7' || 'm7' || '^7' => 0.95,
  '6' || 'm6' || 'h7' || 'o7' || 'sus4' || '7sus4' => 0.8,
  '9' || 'm9' || '^9' || '13' || '69' => 0.7,
  _ => 0.55,
};

/// Below this a note counts as not played at all.
const _quiet = 0.04;

/// What [chroma] might be — best first. [chroma] holds how much of each of
/// the twelve notes was heard (index 0 is C); [bass] is the pitch class of
/// the lowest note, which decides between chords made of the same notes.
List<ChordGuess> namesFor(List<double> chroma, {int? bass, int most = 4}) {
  final played = {
    for (var pitchClass = 0; pitchClass < 12; pitchClass++)
      if (chroma[pitchClass] > _quiet) pitchClass,
  };
  if (played.length < 2) return const [];

  final guesses = <ChordGuess>[];
  for (var root = 0; root < 12; root++) {
    for (final quality in chordQualities) {
      final chord = Chord.parse('${_rootNames[root]}${quality.symbols.first}');
      final template = chord.pitchClasses.toSet();
      var present = 0.0;
      var extra = 0.0;
      for (var pitchClass = 0; pitchClass < 12; pitchClass++) {
        if (template.contains(pitchClass)) {
          present += chroma[pitchClass];
        } else {
          extra += chroma[pitchClass];
        }
      }
      // A chord with notes nobody played is a worse reading than a smaller
      // one that fits — which is what keeps C from being read as C6.
      final missing = template.where((pc) => chroma[pc] <= _quiet).length;
      var score = present - extra - 0.1 * missing;

      String? slash;
      if (bass != null) {
        if (bass == chord.root) {
          score += 0.25;
        } else if (template.contains(bass)) {
          // Played over another of its own notes: right chord, turned over.
          score += 0.02;
          slash = chord.noteNames[chord.pitchClasses.indexOf(bass)];
        } else {
          // The lowest note isn't in the chord at all, which usually means
          // the root is somewhere else.
          score -= 0.35;
        }
      }
      score += 0.05 * _ordinary(quality);
      guesses.add(ChordGuess(chord: chord, score: score, bass: slash));
    }
  }

  guesses.sort((a, b) => b.score.compareTo(a.score));
  // One reading per chord name: the same notes spelled two ways is noise.
  final kept = <String, ChordGuess>{};
  for (final guess in guesses) {
    kept.putIfAbsent(guess.display, () => guess);
    if (kept.length >= most) break;
  }
  return kept.values.toList();
}
