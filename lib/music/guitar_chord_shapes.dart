// Every way to play a chord on the guitar: the chord dictionary.
//
// The fretboard is searched position by position rather than looked up in a
// table, so any chord the app knows has shapes. What makes a shape real
// rather than merely correct is the rules: a hand spans four frets, open
// strings belong to shapes at the nut, four fingers (a barre counts as
// one), the strings that sound run together, and the notes that give the
// chord its name (the 3rd, the 7th, any altered 5th, and the extension
// it's named after) are all there.

import 'chord.dart';
import 'guitar_voicing.dart';

/// The highest fret a shape may start on.
const _highestPosition = 12;

/// How far the hand reaches: four frets, one to a finger.
const _span = 4;

/// Every playable shape for [chord], lowest position first. With
/// [rootInBass] false, shapes with another chord tone in the bass (an
/// inversion) are included too.
List<GuitarVoicing> allGuitarShapes(
  Chord chord, {
  bool rootInBass = true,
  int limit = 40,
}) {
  final degreeOf = <int, String>{};
  for (final degree in chord.quality.formula) {
    degreeOf.putIfAbsent(chord.pitchClassFor(degree), () => degree);
  }
  final needed = _essential(chord);
  final shapes = <String, GuitarVoicing>{};

  for (var position = 0; position <= _highestPosition; position++) {
    // Open strings belong to shapes played at the nut.
    final open = position <= _span;
    final choices = [
      for (var string = 0; string < guitarTuning.length; string++)
        <int?>[
          null,
          if (open && degreeOf.containsKey(guitarTuning[string] % 12)) 0,
          for (var fret = position; fret < position + _span; fret++)
            if (fret > 0 &&
                degreeOf.containsKey((guitarTuning[string] + fret) % 12))
              fret,
        ],
    ];

    void build(int string, List<int?> frets) {
      if (string == choices.length) {
        final shape = _shapeFor(
          frets,
          chord: chord,
          degreeOf: degreeOf,
          needed: needed,
          rootInBass: rootInBass,
        );
        if (shape != null) shapes.putIfAbsent(frets.join(','), () => shape);
        return;
      }
      for (final fret in choices[string]) {
        build(string + 1, [...frets, fret]);
      }
    }

    build(0, []);
  }

  // The same grip with a string left off is the same shape: keep the
  // fullest one of each.
  final fullest = <GuitarVoicing>[];
  for (final shape
      in shapes.values.toList()..sort(
        (a, b) => b.frets.whereType<int>().length.compareTo(
          a.frets.whereType<int>().length,
        ),
      )) {
    if (!fullest.any((kept) => _within(shape, kept))) fullest.add(shape);
  }
  fullest.sort((a, b) {
    final position = a.position.compareTo(b.position);
    if (position != 0) return position;
    final strings = b.pitches.length.compareTo(a.pitches.length);
    if (strings != 0) return strings;
    return _fingers(a).compareTo(_fingers(b));
  });
  return fullest.take(limit).toList();
}

/// Whether [shape] is [kept] with some strings left off: the same frets
/// wherever it sounds, and nothing kept doesn't have.
bool _within(GuitarVoicing shape, GuitarVoicing kept) {
  for (var string = 0; string < shape.frets.length; string++) {
    final fret = shape.frets[string];
    if (fret != null && kept.frets[string] != fret) return false;
  }
  return true;
}

/// The notes that make the chord what it is, as pitch classes: the root,
/// the 3rd (or the 4th of a sus chord), the 7th or 6th, an altered 5th,
/// and whatever the chord is named after (the 9th of a 9 chord, the 13th
/// of a 13). The plain 5th can be left out, and so can a 9th or 11th that
/// only fills the chord out.
Set<int> _essential(Chord chord) {
  final formula = chord.quality.formula;
  final top = formula.last;
  return {
    for (final degree in formula)
      if (degree == '1' ||
          degree == top ||
          RegExp(r'^[b#]?[34]$').hasMatch(degree) ||
          degree == 'b5' ||
          degree == '#5' ||
          RegExp(r'^b?b?[67]$').hasMatch(degree))
        chord.pitchClassFor(degree),
  };
}

/// The shape these [frets] make, or null if a hand couldn't play it or it
/// isn't really the chord.
GuitarVoicing? _shapeFor(
  List<int?> frets, {
  required Chord chord,
  required Map<int, String> degreeOf,
  required Set<int> needed,
  required bool rootInBass,
}) {
  final sounded = [
    for (var string = 0; string < frets.length; string++)
      if (frets[string] != null) string,
  ];
  if (sounded.length < 3) return null;
  // The strings that sound run together, bar one the hand can damp inside.
  final gaps = sounded.last - sounded.first + 1 - sounded.length;
  if (gaps > 1) return null;

  final voicing = GuitarVoicing(frets);
  final pitches = voicing.pitches;
  if (rootInBass && pitches.first % 12 != chord.root) return null;
  final played = {for (final pitch in pitches) pitch % 12};
  if (!played.containsAll(needed)) return null;
  // Nothing doubled at the same pitch, and not too wide a stretch.
  if (pitches.toSet().length != pitches.length) return null;
  if (_fingers(voicing) > 4) return null;
  return GuitarVoicing(frets, barre: _barreOf(frets));
}

/// How many fingers the shape takes: one for each fretted note, but a barre
/// across the lowest fret counts once.
int _fingers(GuitarVoicing voicing) {
  final fretted = [
    for (final fret in voicing.frets)
      if (fret != null && fret > 0) fret,
  ];
  if (fretted.isEmpty) return 0;
  final lowest = fretted.reduce(GuitarVoicing.min);
  final atLowest = fretted.where((fret) => fret == lowest).length;
  return fretted.length - (atLowest > 1 ? atLowest - 1 : 0);
}

/// The barre, if the first finger lies across the lowest fret. Strings
/// under it must be either fretted there or higher up: a barre can't cover
/// a string that has to stay open or silent inside it.
({int fret, int from, int to})? _barreOf(List<int?> frets) {
  final fretted = [
    for (final fret in frets)
      if (fret != null && fret > 0) fret,
  ];
  if (fretted.isEmpty) return null;
  final lowest = fretted.reduce(GuitarVoicing.min);
  final at = [
    for (var string = 0; string < frets.length; string++)
      if (frets[string] == lowest) string,
  ];
  if (at.length < 2) return null;
  for (var string = at.first; string <= at.last; string++) {
    final fret = frets[string];
    if (fret == null || fret < lowest) return null;
  }
  return (fret: lowest, from: at.first, to: at.last);
}

/// What's in the bass of [voicing]: "Root", "3rd", "♭7th"…
String bassDegreeOf(Chord chord, GuitarVoicing voicing) {
  final pitch = voicing.pitches.first % 12;
  for (final degree in chord.quality.formula) {
    if (chord.pitchClassFor(degree) == pitch) {
      return degree == '1' ? 'Root' : prettyDegree(degree);
    }
  }
  return prettyDegree('1');
}

/// The shape that best matches [pitches]: what somebody actually played,
/// rather than a way they might have. Shapes are compared by the notes they
/// sound: the one sharing the most of them, and closest in size, wins.
GuitarVoicing? shapeLike(Chord chord, List<int> pitches) {
  if (pitches.isEmpty) return null;
  final wanted = pitches.toSet();
  final classes = {for (final pitch in pitches) pitch % 12};
  GuitarVoicing? best;
  var bestScore = -1.0;
  // Both lists: a shape whose root is in the bass is folded into a fuller
  // one when inversions are allowed, and it may be exactly what was played.
  final candidates = [
    ...allGuitarShapes(chord, limit: 40),
    ...allGuitarShapes(chord, rootInBass: false, limit: 60),
  ];
  for (final shape in candidates) {
    final sounded = shape.pitches.toSet();
    // An exact note counts for most; the right note in the wrong octave
    // counts for a little, because a microphone hears the octave of a low
    // string less reliably than its name; a string sounding a note that
    // wasn't heard at all counts against.
    var score = 0.0;
    for (final pitch in sounded) {
      if (wanted.contains(pitch)) {
        score += 2;
      } else if (classes.contains(pitch % 12)) {
        score += 0.5;
      } else {
        score -= 1.5;
      }
    }
    // Neither cluttered with strings that weren't heard nor missing ones.
    score -= (sounded.length - wanted.length).abs();
    if (score > bestScore) {
      bestScore = score;
      best = shape;
    }
  }
  return best;
}
