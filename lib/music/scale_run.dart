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

/// What a way of running a scale is called on screen.
String runLabel(String way) =>
    way == straightRun ? 'Straight, Up and Down' : way;
