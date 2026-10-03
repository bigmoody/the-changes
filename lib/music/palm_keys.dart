// Getting up to the palm keys and back down again.
//
// The top of a saxophone is played with the side of the left palm rather
// than the fingers, and the join is where it falls apart. Below written
// C♯ the fingers are doing ordinary work; above it the hand has to roll
// off them onto three keys it cannot feel for, hold the note steady while
// it does, and roll back. Most players can hit a high F on its own and
// cannot get to one in the middle of a line.
//
// So the exercises here are not palm key exercises. They are ordinary
// scales and arpeggios that happen to run out of the top of the normal
// range, which is the only way the join gets practised in the place it
// actually breaks: on the way past, at tempo, with somewhere to be.
//
// Written pitches throughout. The palm keys are the same written notes on
// every saxophone, alto to baritone, so one set of exercises serves them
// all; what changes is what comes out, and the app already knows that
// from the instrument setting.

import 'chord.dart';
import 'scales.dart';

/// The lowest written note the palm keys make: D above the staff.
///
/// Everything below this is fingered. The exercises are built to cross
/// this line rather than to sit above it.
const firstPalmNote = 86;

/// The highest written note these exercises go to: F.
///
/// Not the F♯ above it. That is a side key worked by the right hand, a
/// different problem with a different solution, and putting it in here
/// would mean an exercise that practises two things and teaches neither.
const topPalmNote = 89;

/// Where the exercises start from, as written pitches: the tonic in the
/// octave below the staff's top, so there is an octave and a half of
/// ordinary playing before the hand has to move.
const _lowestStart = 60;
const _highestStart = 71;

/// One note of an exercise: what to play and what it is called.
typedef ExerciseNote = ({int pitch, String name});

/// A scale or an arpeggio, up into the palm keys and back down.
typedef Exercise = ({List<ExerciseNote> notes, Set<int> palm});

/// What the exercises are built out of.
enum PalmShape {
  major('Major Scale'),
  dominant('Dominant Scale'),
  minor('Minor Scale'),
  triad('Triad'),
  seventh('Seventh Arpeggio');

  const PalmShape(this.label);

  final String label;

  /// Whether it is built from a chord rather than a scale, which decides
  /// where its notes come from.
  bool get isChord => this == triad || this == seventh;
}

/// The exercise in [key] for [shape]: up to the highest note the palm
/// keys reach in that key, and back down to where it started.
///
/// Comes back empty for nothing playable, which cannot happen for the
/// twelve keys but is better than a crash if it ever does.
Exercise palmExercise(String key, PalmShape shape) {
  final steps = _stepsOf(key, shape);
  if (steps.isEmpty) return (notes: const [], palm: const {});

  final start = _startFor(key);
  final up = <ExerciseNote>[];
  Exercise finish() => _upAndDown(_reaching(up, key));
  // Every degree in order, octave after octave, until the next one would
  // be above the top. The last note is therefore always the highest the
  // shape reaches inside the palm keys.
  for (var octave = 0; octave < 4; octave++) {
    for (final (semitones, name) in steps) {
      final pitch = start + semitones + octave * 12;
      if (pitch > topPalmNote) return finish();
      if (pitch >= start) up.add((pitch: pitch, name: name));
    }
  }
  return finish();
}

/// The climb, carried up to a palm note where it stopped short of one.
///
/// Only one of the sixty exercises needs it: a G♭ triad is G♭ B♭ D♭ and
/// not one of those is a D, E♭, E or F, so it tops out a semitone below
/// the join however far it climbs. An exercise that never reaches the
/// palm keys is not what this page says it is, so it carries on to the
/// lowest note of the key that does. From the D♭ that is a whole tone,
/// which is the join itself and no bad way to meet it.
List<ExerciseNote> _reaching(List<ExerciseNote> up, String key) {
  if (up.isEmpty || up.last.pitch >= firstPalmNote) return up;
  final scale = modes.firstWhere((m) => m.name == 'Ionian');
  final names = scale.notesFrom(key);
  final semitones = scale.semitones;
  final tonic = Chord.parse(key).root % 12;
  for (var pitch = firstPalmNote; pitch <= topPalmNote; pitch++) {
    for (var i = 0; i < semitones.length && i < names.length; i++) {
      if ((tonic + semitones[i]) % 12 == pitch % 12) {
        return [...up, (pitch: pitch, name: names[i])];
      }
    }
  }
  return up;
}

/// The way up, then the way back without repeating the top note.
///
/// Both ways on purpose: coming down off the palm keys is the harder of
/// the two and the half everybody leaves out, because an exercise that
/// ends on the high note ends on the bit that went well.
Exercise _upAndDown(List<ExerciseNote> up) {
  if (up.isEmpty) return (notes: const [], palm: const {});
  final notes = [...up, ...up.reversed.skip(1)];
  return (
    notes: notes,
    palm: {
      for (final (index, note) in notes.indexed)
        if (note.pitch >= firstPalmNote) index,
    },
  );
}

/// The tonic to begin on: the one between middle C and the B above it,
/// which leaves room to climb.
///
/// From the key itself rather than from the first interval of the shape,
/// which is always nought and so started every one of the twelve on a C.
int _startFor(String key) {
  final tonic = Chord.parse(key).root % 12;
  for (var pitch = _lowestStart; pitch <= _highestStart; pitch++) {
    if (pitch % 12 == tonic) return pitch;
  }
  return _lowestStart;
}

/// The semitones and spelled names of one octave of [shape] in [key].
List<(int, String)> _stepsOf(String key, PalmShape shape) {
  if (shape.isChord) {
    final chord = Chord.parse(
      '$key${shape == PalmShape.triad ? '' : _seventhOf(key)}',
    );
    final names = chord.noteNames;
    final intervals = chord.quality.intervals;
    return [
      for (var i = 0; i < names.length && i < intervals.length; i++)
        (intervals[i], names[i]),
    ];
  }
  final mode = modes.firstWhere((m) => m.name == _modeFor(shape));
  final names = mode.notesFrom(key);
  final semitones = mode.semitones;
  return [
    for (var i = 0; i < names.length && i < semitones.length; i++)
      (semitones[i], names[i]),
  ];
}

String _modeFor(PalmShape shape) => switch (shape) {
  PalmShape.major || PalmShape.triad || PalmShape.seventh => 'Ionian',
  PalmShape.dominant => 'Mixolydian',
  PalmShape.minor => 'Dorian',
};

/// Which seventh the arpeggio is: a major 7th, because these run up to
/// the tonic and a dominant would put a ♭7 where the ear wants the top.
String _seventhOf(String key) => '^7';
