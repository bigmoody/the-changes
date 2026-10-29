// A scale as an exercise: the notes to play, in order, for one way of
// running it, from where an instrument wants it to start.

import 'chord.dart';
import 'scale_patterns.dart';
import 'scales.dart';

/// One run of a scale: the pitches as written, the note names to write
/// them under, and where it turns to come back down (the first note of
/// the way down), so the two halves can be written on lines of their own.
typedef ScaleRun = ({List<int> pitches, List<String> names, int turn});

/// [mode] on [key], run [way] over [octaves], starting on the first
/// written pitch of the key at or above [floor].
///
/// Straight is up and down, the top note once. Any other way is the
/// pattern going up and then mirrored coming down, which is a different
/// shape and the half that gets skipped.
ScaleRun scaleRun(
  Mode mode,
  String key,
  String way, {
  required int octaves,
  required int floor,
}) {
  final root = Chord.parse(mode.spelledRoot(key)).root;
  final tonic = floor + (root - floor) % 12;
  final semitones = mode.semitones;
  final names = mode.notesFrom(key);
  final count = semitones.length;
  final List<int> steps;
  final int turn;
  if (way == straightRun) {
    final top = count * octaves;
    steps = [
      for (var s = 0; s <= top; s++) s,
      for (var s = top - 1; s >= 0; s--) s,
    ];
    turn = top + 1;
  } else if (way == arpeggioRun) {
    // The chord the mode's 1st, 3rd, 5th and 7th make, up through the
    // octaves to the root at the top and back: only seven-note scales
    // have those degrees where an arpeggio wants them.
    final top = count * octaves;
    final up = [
      for (var octave = 0; octave < octaves; octave++)
        for (final degree in const [0, 2, 4, 6]) octave * count + degree,
      top,
    ];
    steps = [...up, ...up.reversed.skip(1)];
    turn = up.length;
  } else {
    final pattern = scalePatterns.firstWhere((p) => p.name == way);
    final reach = octavesFor(count, pattern);
    final room = reach > octaves ? reach : octaves;
    final up = patternSteps(count, pattern, octaves: room);
    steps = [...up, ...patternSteps(count, pattern, octaves: room, down: true)];
    turn = up.length;
  }
  return (
    pitches: [
      for (final step in steps)
        tonic + semitones[step % count] + 12 * (step ~/ count),
    ],
    names: [for (final step in steps) names[step % count]],
    turn: turn,
  );
}

/// The name of running a scale straight up and down.
const straightRun = 'Straight';

/// The name of running the seventh chord a scale holds, up and down.
const arpeggioRun = 'Arpeggio';

/// What a way of running a scale is called on screen.
String runLabel(String way) => switch (way) {
  straightRun => 'Straight, Up and Down',
  arpeggioRun => 'Arpeggio, Up and Down',
  _ => way,
};
