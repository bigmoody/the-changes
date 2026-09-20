// Barre chords: the movable shapes most guitarists learn first.
//
// Each shape is fingered with the first finger laid flat across the neck
// (the barre) and the root on the low E string ("E shape") or the A string
// ("A shape"). Sliding the whole shape up the neck changes the key, so a
// handful of shapes cover every chord.

import 'chord.dart';
import 'guitar_voicing.dart';

/// Frets relative to the barre, low E string first; null = not played.
typedef _Shape = List<int?>;

/// Root on the low E string.
const _eShapes = <String, _Shape>{
  'Major': [0, 2, 2, 1, 0, 0],
  'Minor': [0, 2, 2, 0, 0, 0],
  'Dominant 7th': [0, 2, 0, 1, 0, 0],
  'Minor 7th': [0, 2, 0, 0, 0, 0],
  'Major 7th': [0, 2, 1, 1, 0, 0],
  'Minor 6th': [0, 2, 2, 0, 2, 0],
  'Minor-major 7th': [0, 2, 1, 0, 0, 0],
  'Dominant 9th': [0, 2, 0, 1, 0, 2],
  'Suspended 4th': [0, 2, 2, 2, 0, 0],
  'Dominant 7th suspended 4th': [0, 2, 0, 2, 0, 0],
};

/// Root on the A string; the low E isn't played.
const _aShapes = <String, _Shape>{
  'Major': [null, 0, 2, 2, 2, 0],
  'Minor': [null, 0, 2, 2, 1, 0],
  'Dominant 7th': [null, 0, 2, 0, 2, 0],
  'Minor 7th': [null, 0, 2, 0, 1, 0],
  'Major 7th': [null, 0, 2, 1, 2, 0],
  'Major 6th': [null, 0, 2, 2, 2, 2],
  'Minor 6th': [null, 0, 2, 2, 1, 2],
  'Minor-major 7th': [null, 0, 2, 1, 1, 0],
  'Suspended 4th': [null, 0, 2, 2, 3, 0],
  'Dominant 7th suspended 4th': [null, 0, 2, 0, 3, 0],
};

/// A barre-chord grip for [chord], or null if it has no barre shape
/// (diminished, half-diminished and augmented chords are played as
/// smaller grips instead).
///
/// Extensions and alterations come off first — a C13 is barred as a C7,
/// a Cm9 as a Cm7 — since barre shapes are the plain chords.
GuitarVoicing? barreVoicingFor(Chord chord) {
  final name = barreShapeChord(chord)?.quality.name;
  if (name == null) return null;
  final options = [
    if (_eShapes[name] case final shape?) (shape, 0),
    if (_aShapes[name] case final shape?) (shape, 1),
  ];

  // Whichever shape sits lowest on the neck. Fret 0 would be an open chord,
  // not a barre, so the shape goes up to the 12th fret instead.
  GuitarVoicing? best;
  for (final (shape, rootString) in options) {
    var fret = (chord.root - guitarTuning[rootString]) % 12;
    if (fret == 0) fret = 12;
    final voicing = GuitarVoicing(
      [for (final offset in shape) offset == null ? null : fret + offset],
      barre: (fret: fret, from: rootString, to: 5),
    );
    if (best == null || fret < best.barre!.fret) best = voicing;
  }
  return best;
}

/// The chord a barre grip for [chord] actually plays: [chord] itself if
/// there's a barre shape for it, otherwise its plain version (C7 for a C13),
/// or null if neither has one.
Chord? barreShapeChord(Chord chord) {
  // Barre shapes are built on the root, so a slash chord's bass note is
  // left to the bass player: F/A is played as an F barre.
  chord = chord.withoutBass;
  for (final candidate in [chord, chord.withoutExtensions]) {
    final name = candidate.quality.name;
    if (_eShapes.containsKey(name) || _aShapes.containsKey(name)) {
      return candidate;
    }
  }
  return null;
}
