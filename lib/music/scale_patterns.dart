// Running a scale in something other than a straight line.
//
// Playing a scale up and down teaches your fingers the notes and teaches
// your ears almost nothing, because nothing in the music ever goes up a
// scale for eight notes. What music does is move in thirds, in fourths,
// through triads, in little groups of four. So these take the same seven
// notes and go through them in those shapes instead, which is how a scale
// turns into something you can actually play with.
//
// A pattern is a handful of scale steps repeated from each degree in
// turn. In thirds is "this note and the one two steps up", started on the
// 1st, then the 2nd, then the 3rd: C E, D F, E G, F A, G B, A C. Nothing
// here knows or cares which scale it is being applied to, so the same
// half dozen shapes work on a major scale, a diminished scale and a
// pentatonic, and the pentatonic ones come out different because five
// notes into a shape of two does not divide as seven does.

import 'dart:math' as math;

/// A shape to run a scale in.
class ScalePattern {
  const ScalePattern({
    required this.name,
    required this.steps,
    required this.about,
  });

  /// Steps up the scale from each starting degree, where 0 is the
  /// starting note, 1 the next note of the scale, and so on.
  final List<int> steps;

  final String name;
  final String about;

  /// How far the highest note of a group is above its first.
  int get reach => steps.isEmpty ? 0 : steps.reduce(math.max);

  /// How many notes are played from each degree.
  int get length => steps.length;
}

/// The shapes worth practising, plainest first.
const scalePatterns = [
  ScalePattern(
    name: 'In 3rds',
    steps: [0, 2],
    about:
        'Every note and the one two steps above it: C E, D F, E G. The '
        'first thing to do to a scale, and the one that turns up most '
        'in real lines.',
  ),
  ScalePattern(
    name: 'In 4ths',
    steps: [0, 3],
    about:
        'C F, D G, E A. Wider than the ear expects, which is exactly '
        'why it sounds modern and why it is worth the work.',
  ),
  ScalePattern(
    name: 'In 5ths',
    steps: [0, 4],
    about:
        'C G, D A, E B. Open and plain, and the interval most lines '
        'leap by when they leap.',
  ),
  ScalePattern(
    name: 'In 6ths',
    steps: [0, 5],
    about:
        'C A, D B, E C. The upside-down 3rd: the same pairs of notes, '
        'reached the long way round.',
  ),
  ScalePattern(
    name: 'Triads',
    steps: [0, 2, 4],
    about:
        'The triad on every degree: C E G, D F A, E G B. This is how '
        'you learn what harmony the scale actually contains.',
  ),
  ScalePattern(
    name: 'Sevenths',
    steps: [0, 2, 4, 6],
    about:
        'The four-note chord on every degree: C E G B, D F A C. The '
        'same thing again with the note that names the chord quality.',
  ),
  ScalePattern(
    name: 'In fours',
    steps: [0, 1, 2, 3],
    about:
        'Four in a row from each degree: C D E F, D E F G. It sounds '
        'like a scale and it is not: the ear hears the group, and the '
        'group is what phrasing is made of.',
  ),
  ScalePattern(
    name: '1 2 3 5',
    steps: [0, 1, 2, 4],
    about:
        'Three in a row and a jump: C D E G, D E F A. The oldest bebop '
        'shape there is, and the one that stops a line sounding like an '
        'exercise.',
  ),
  ScalePattern(
    name: '1 3 2 4',
    steps: [0, 2, 1, 3],
    about:
        'Thirds, turned inside out: C E D F, D F E G. Awkward under the '
        'fingers and worth it, because it never sounds like running up '
        'and down.',
  ),
];

/// The degrees of [scale] played in [pattern], as scale steps from the
/// bottom note.
///
/// Step 7 of a seven-note scale is the octave above step 0, which is why
/// these are steps rather than notes: the shape does not change when the
/// scale does, only how far apart the notes come out.
///
/// The run stops when the top of a group would go above [octaves] octaves
/// of the scale, so in thirds it ends on the octave rather than reaching
/// past it: C E, D F, E G, F A, G B, A C, and stop. Going further is what
/// another octave is for.
///
/// With [down], the whole thing is mirrored: it starts at the top and the
/// groups descend, which is a different exercise and not the same one
/// played backwards.
List<int> patternSteps(
  int notesInScale,
  ScalePattern pattern, {
  int octaves = 1,
  bool down = false,
}) {
  if (notesInScale < 1 || pattern.steps.isEmpty || octaves < 1) return const [];
  final top = notesInScale * octaves;
  final out = <int>[];
  for (var start = 0; start + pattern.reach <= top; start++) {
    for (final step in pattern.steps) {
      out.add(down ? top - (start + step) : start + step);
    }
  }
  return out;
}

/// The fewest octaves that leave room for [pattern] on a scale of
/// [notesInScale] notes.
///
/// A shape that reaches a seventh needs seven notes under it, and a
/// pentatonic only has five, so sevenths on a pentatonic want two
/// octaves or they want nothing at all. Asking rather than guessing means
/// a screen never offers a pattern and then shows an empty stave.
int octavesFor(int notesInScale, ScalePattern pattern, {int most = 3}) {
  if (notesInScale < 1) return 1;
  for (var octaves = 1; octaves < most; octaves++) {
    if (pattern.reach <= notesInScale * octaves) return octaves;
  }
  return most;
}

/// [pattern] on a scale whose notes are [semitones] above its root,
/// as semitones above that root.
///
/// The scale repeats an octave higher as the steps run past its end, so
/// a five-note pentatonic reaches the octave after five steps and a
/// seven-note scale after seven, and neither needs telling.
List<int> patternOn(
  List<int> semitones,
  ScalePattern pattern, {
  int octaves = 1,
  bool down = false,
}) {
  if (semitones.isEmpty) return const [];
  return [
    for (final step in patternSteps(
      semitones.length,
      pattern,
      octaves: octaves,
      down: down,
    ))
      semitones[step % semitones.length] + 12 * (step ~/ semitones.length),
  ];
}
