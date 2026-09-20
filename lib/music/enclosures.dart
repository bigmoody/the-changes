// Enclosures: arriving at a note by going round it first.
//
// A bebop line rarely walks up to a chord tone and lands on it. It circles
// it — a note above, a note below, then the target — so the note you meant
// all along arrives sounding inevitable. Every player learns a handful of
// these shapes and then hears them everywhere.
//
// What's written here is the shape, not a lick: where the notes sit
// relative to the target, and whether each one is a semitone away or the
// next note of the scale. Put a target under it and you have the exercise.

import 'chord.dart';
import 'scales.dart';

/// One note on the way to the target.
///
/// The chromatic ones are fixed distances. The scale ones depend on what
/// the line is in — over a Dm7 the note above E is F, and over a D7 it's
/// F♯ — which is most of why an enclosure sounds like the tune rather than
/// like an exercise.
enum Approach {
  scaleAbove('the note above it in the scale'),
  scaleBelow('the note below it in the scale'),
  semitoneAbove('a semitone above'),
  semitoneBelow('a semitone below'),
  toneAbove('a tone above'),
  toneBelow('a tone below');

  const Approach(this.label);

  final String label;

  /// How far this lands from the target, in semitones, or null when that
  /// depends on the scale.
  int? get semitones => switch (this) {
    semitoneAbove => 1,
    semitoneBelow => -1,
    toneAbove => 2,
    toneBelow => -2,
    scaleAbove || scaleBelow => null,
  };

  bool get isAbove =>
      this == scaleAbove || this == semitoneAbove || this == toneAbove;
}

/// One way round a note: the notes played before it, in order.
class Enclosure {
  const Enclosure({
    required this.name,
    required this.steps,
    required this.description,
  });

  final String name;

  /// Before the target, in playing order.
  final List<Approach> steps;

  final String description;

  /// How many notes it is, the target included.
  int get length => steps.length + 1;
}

/// The ones worth knowing, easiest first.
const enclosures = [
  Enclosure(
    name: 'Above and Below',
    steps: [Approach.semitoneAbove, Approach.semitoneBelow],
    description:
        'A semitone each side, then the note. The plainest one, and the '
        'one you will hear most: it works over any chord because neither '
        'note stays long enough to belong to anything.',
  ),
  Enclosure(
    name: 'Scale Above, Semitone Below',
    steps: [Approach.scaleAbove, Approach.semitoneBelow],
    description:
        'Down from the scale, up from underneath. The one above is in the '
        'key, so the shape leans towards the chord rather than sitting '
        'outside it — this is the bebop default.',
  ),
  Enclosure(
    name: 'Semitone Below, Scale Above',
    steps: [Approach.semitoneBelow, Approach.scaleAbove],
    description:
        'The same two notes the other way round, which changes where the '
        'weight falls: you arrive from above, and the target lands softer.',
  ),
  Enclosure(
    name: 'Two From Below',
    steps: [Approach.toneBelow, Approach.semitoneBelow],
    description:
        'Two semitones below, then one, then the note: a run at it from '
        'underneath. Strong on a downbeat, and the easiest to hear coming.',
  ),
  Enclosure(
    name: 'Two From Above',
    steps: [Approach.toneAbove, Approach.semitoneAbove],
    description:
        'The same run from over the top. Useful when the line is already '
        'high and you want it to come down onto the chord tone.',
  ),
];

/// One note of a worked-out enclosure: what to play, and what it's called.
typedef EnclosureNote = ({int pitch, String name, bool isTarget});

/// [enclosure] arriving at [target] (a MIDI pitch), in the key of [scale].
///
/// [scale] is the spelled notes of the scale the line is in, in any order —
/// what the scale steps move through. The chromatic notes are spelled the
/// way a player writes them: sharps going up to the target, flats coming
/// down to it, because that is what the movement is.
List<EnclosureNote> enclosureOn(
  Enclosure enclosure, {
  required int target,
  required String targetName,
  required List<String> scale,
}) {
  final pitches = {
    for (final note in scale)
      if (parseNoteName(note) case final spelling?)
        pitchClassOf(spelling): note,
  };

  int scaleStep(int from, {required bool up}) {
    for (var step = 1; step <= 12; step++) {
      final pitch = from + (up ? step : -step);
      if (pitches.containsKey(pitch % 12)) return pitch;
    }
    return from + (up ? 1 : -1); // no scale given: fall back to a semitone
  }

  return [
    for (final step in enclosure.steps)
      switch (step.semitones) {
        final semitones? => (
          pitch: target + semitones,
          name: _chromaticName(target + semitones, up: !step.isAbove),
          isTarget: false,
        ),
        null => () {
          final pitch = scaleStep(target, up: step.isAbove);
          return (
            pitch: pitch,
            name: pitches[pitch % 12] ?? _chromaticName(pitch, up: step.isAbove),
            isTarget: false,
          );
        }(),
      },
    (pitch: target, name: targetName, isTarget: true),
  ];
}

/// The scale a line over [chord] is most likely in, as spelled notes, or an
/// empty list when nothing in the book fits the chord.
List<String> scaleFor(Chord chord) {
  for (final mode in modes) {
    if (mode.chord == chord.quality.symbols.first) {
      return mode.notesFrom(chord.rootName);
    }
  }
  return const [];
}

const _sharpNames = [
  'C',
  'C♯',
  'D',
  'D♯',
  'E',
  'F',
  'F♯',
  'G',
  'G♯',
  'A',
  'A♯',
  'B',
];
const _flatNames = [
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

/// A note approached from below is written as a sharp and one from above as
/// a flat, because that is the way it is moving.
String _chromaticName(int pitch, {required bool up}) =>
    (up ? _sharpNames : _flatNames)[pitch % 12];
