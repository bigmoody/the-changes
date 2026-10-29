// Articulation: how a line of swung eighths is played on a horn, which
// notes the tongue starts, which are slurred into, which are leaned on
// and which are barely there.
//
// It is most of what makes eighths sound like jazz rather than like an
// exercise, and it cannot be learned from a description: it is learned
// by playing a line against a ride cymbal with the marks in front of you,
// many times through. So each step here is a short line in today's key
// with a mark under every note, played with the band for as many times
// round as somebody asks for.

import '../music/chord.dart';
import '../music/scales.dart';

/// How one note of a line is played.
enum Touch {
  /// Started with the tongue: a soft "doo", the air never stopping.
  tongue('T', 'Tongued'),

  /// Not tongued: the air carries on into it from the note before.
  slur('S', 'Slurred'),

  /// Tongued and leaned on: more air, not a harder tongue.
  accent('>', 'Accented'),

  /// Barely sounded, half fingered and half heard.
  ghost('( )', 'Ghosted'),

  /// Nothing played: the beat felt and left out.
  rest('rest', 'Rest');

  const Touch(this.mark, this.label);

  /// What is written under the note: plain letters, which every font
  /// has, rather than a slur or a rest from the music fonts.
  final String mark;
  final String label;
}

/// One eighth of a line: a degree of the scale (0 is the root, 7 the
/// octave above it on a seven-note scale), and how it is played.
typedef LineNote = ({int degree, Touch touch});

/// One line to play: a few bars of swung eighths.
class LineStep {
  const LineStep({
    required this.title,
    required this.how,
    required this.notes,
    this.mode = 'Ionian',
  });

  final String title;

  /// What to listen for while playing it.
  final String how;

  /// Eighth notes, a whole number of bars of them.
  final List<LineNote> notes;

  /// The scale its degrees are counted in, by its name in `modes`.
  final String mode;
}

/// A run of lines, at a tempo that climbs from [from] to [to].
class LineExercise {
  const LineExercise({
    required this.steps,
    required this.from,
    required this.to,
  });

  final List<LineStep> steps;
  final int from;
  final int to;
}

/// One note of a line as it is written and played in a key.
typedef LineEvent = ({int? pitch, String name, Touch touch});

/// [step] in [key], from the first written pitch of the key at or above
/// [floor].
List<LineEvent> lineIn(LineStep step, String key, {required int floor}) {
  final mode = modes.firstWhere((m) => m.name == step.mode);
  final root = Chord.parse(mode.spelledRoot(key)).root;
  final tonic = floor + (root - floor) % 12;
  final semitones = mode.semitones;
  final names = mode.notesFrom(key);
  final count = semitones.length;
  return [
    for (final note in step.notes)
      note.touch == Touch.rest
          ? (pitch: null, name: '', touch: Touch.rest)
          : (
              pitch:
                  tonic +
                  semitones[note.degree % count] +
                  12 * (note.degree ~/ count),
              name: names[note.degree % count],
              touch: note.touch,
            ),
  ];
}

// ── The lines ────────────────────────────────────────────────────────────

/// Up the scale to the octave and back down: sixteen eighths, two bars.
const _scaleUpAndDown = [0, 1, 2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2, 1, 0];

/// Up the seventh chord and back, twice: two bars.
const _arpeggio = [0, 2, 4, 6, 7, 6, 4, 2, 0, 2, 4, 6, 7, 6, 4, 2];

/// [degrees] played with [onBeat] on the beats and [offBeat] on the
/// "and"s, the first note always tongued so the line has a start.
List<LineNote> _marked(List<int> degrees, Touch onBeat, Touch offBeat) => [
  for (final (i, degree) in degrees.indexed)
    (
      degree: degree,
      touch: i == 0 && onBeat == Touch.slur
          ? Touch.tongue
          : i.isEven
          ? onBeat
          : offBeat,
    ),
];

/// Swung eighths on a horn, first time: one note, then the tongue on the
/// "and"s, then the "and"s leaned on, then the top of a line.
final articulation = LineExercise(
  from: 100,
  to: 140,
  steps: [
    LineStep(
      title: 'One Note, Legato Tongue',
      how:
          'The root, sixteen times, every note tongued with a soft "doo": '
          'the tongue barely touching, the air never stopping between '
          'notes. Long then short, sitting on the ride.',
      notes: [for (var i = 0; i < 16; i++) (degree: 0, touch: Touch.tongue)],
    ),
    LineStep(
      title: 'Tongue the Off-Beats',
      how:
          'Tongue only the notes on the "and" and slur each one into the '
          'beat after it: doo-AH, doo-AH. The tongue on the "and" is what '
          'makes eighths swing on a horn.',
      notes: _marked(_scaleUpAndDown, Touch.slur, Touch.tongue),
    ),
    LineStep(
      title: 'Accent the Off-Beats',
      how:
          'The same line, with every "and" pushed: a little more air on '
          'each, never a harder tongue. The beats stay light.',
      notes: _marked(_scaleUpAndDown, Touch.slur, Touch.accent),
    ),
    LineStep(
      title: 'Accent the Top',
      how:
          'Up the seventh chord and back. Lean on the top note, the one a '
          'listener hears as the peak of the line, and on nothing else.',
      notes: [
        for (final (i, degree) in _arpeggio.indexed)
          (
            degree: degree,
            touch: degree == 7
                ? Touch.accent
                : i == 0 || i.isOdd
                ? Touch.tongue
                : Touch.slur,
          ),
      ],
    ),
  ],
);

/// Ghost notes, and lines that start off the beat.
final ghosting = LineExercise(
  from: 120,
  to: 170,
  steps: [
    LineStep(
      title: 'Ghost the Beats',
      how:
          'Barely sound the notes on the beat and push the "and"s, so the '
          'line is carried by the off-beats: doo-DAH, with the doo almost '
          'not there.',
      notes: _marked(_scaleUpAndDown, Touch.ghost, Touch.accent),
    ),
    LineStep(
      title: 'Start on the And',
      how:
          'The line starts on the "and" of 1, as most bebop lines do. Feel '
          'the beat you leave out, tongue the first note, and end on the '
          'root on beat 4 of the second bar.',
      notes: [
        (degree: 0, touch: Touch.rest),
        (degree: 0, touch: Touch.accent),
        (degree: 1, touch: Touch.slur),
        (degree: 2, touch: Touch.tongue),
        (degree: 3, touch: Touch.slur),
        (degree: 4, touch: Touch.tongue),
        (degree: 5, touch: Touch.slur),
        (degree: 6, touch: Touch.tongue),
        (degree: 7, touch: Touch.accent),
        (degree: 6, touch: Touch.tongue),
        (degree: 5, touch: Touch.slur),
        (degree: 4, touch: Touch.tongue),
        (degree: 3, touch: Touch.slur),
        (degree: 2, touch: Touch.tongue),
        (degree: 0, touch: Touch.accent),
        (degree: 0, touch: Touch.rest),
      ],
    ),
    LineStep(
      title: 'Ghost and Lean on the Top',
      how:
          'Up the seventh chord and back with the beats ghosted, the "and"s '
          'tongued, and the top note leaned on: the shape of a bebop line.',
      notes: [
        for (final (i, degree) in _arpeggio.indexed)
          (
            degree: degree,
            touch: degree == 7
                ? Touch.accent
                : i.isEven
                ? Touch.ghost
                : Touch.tongue,
          ),
      ],
    ),
    LineStep(
      title: 'In the Dorian',
      mode: 'Dorian',
      how:
          'The same ghosting on the Dorian, the sound of a minor ii chord: '
          'beats ghosted, "and"s pushed.',
      notes: _marked(_scaleUpAndDown, Touch.ghost, Touch.accent),
    ),
  ],
);
