// Getting up to the palm keys and back down, in all twelve.
//
// The exercises are deliberately ordinary: scales and arpeggios that run
// out of the top of the normal range. Almost every player can hit a high
// F on its own and far fewer can get to one in the middle of a line, so
// the practice that matters is the join, taken on the way past rather
// than aimed at.
//
// Everything on this page is written pitch, which is what a saxophone
// reads and what makes one page serve alto, tenor, soprano and baritone
// alike: the palm keys are the same written notes on all of them.
//
// The notes the palm keys make are marked, so the eye can see where the
// hand has to move before the ear finds out.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/palm_keys.dart';
import 'stave.dart';
import 'stave_figure.dart';

/// The twelve, in the order a player would work through them: round the
/// flat keys first, which is where the horn lives.
const _keys = ['C', 'F', 'B♭', 'E♭', 'A♭', 'D♭', 'G♭', 'B', 'E', 'A', 'D', 'G'];

class PalmKeysScreen extends StatefulWidget {
  const PalmKeysScreen({super.key, required this.player});

  final PracticePlayer player;

  @override
  State<PalmKeysScreen> createState() => _PalmKeysScreenState();
}

class _PalmKeysScreenState extends State<PalmKeysScreen> {
  var _key = 'C';
  var _shape = PalmShape.major;

  /// Plays the exercise, two notes to a beat, as written.
  ///
  /// At written pitch rather than moved to what a saxophone would sound,
  /// because which saxophone is not something the app knows: an E♭ horn
  /// is an alto or a baritone an octave apart, and guessing would put the
  /// line in the wrong octave half the time. The page is a written-pitch
  /// page and this is the written pitch.
  Future<void> _play(Exercise exercise) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const step = 0.26;
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final (index, note) in exercise.notes.indexed)
          (
            pitch: note.pitch,
            start: index * step,
            length: step * 0.95,
            velocity: 0.55,
            bass: false,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = palmExercise(_key, _shape);
    return Scaffold(
      appBar: AppBar(title: const Text('Palm Keys')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'The top of the horn is played with the side of the left '
              'palm rather than the fingers, and the join is where it '
              'falls apart. Most players can hit a high F on its own and '
              'far fewer can get to one in the middle of a line, so these '
              'are ordinary scales and arpeggios that happen to run out '
              'of the top of the range. The join gets practised where it '
              'actually breaks: on the way past.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const Divider(height: 28),
          _Chips(
            values: [for (final shape in PalmShape.values) shape.label],
            selected: _shape.label,
            keyPrefix: 'shape',
            onPick: (label) => setState(
              () =>
                  _shape = PalmShape.values.firstWhere((s) => s.label == label),
            ),
          ),
          _Chips(
            values: _keys,
            selected: _key,
            keyPrefix: 'palm-key',
            onPick: (key) => setState(() => _key = key),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_shape.label} in $_key, as written',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('play-palm'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Hear it',
                  onPressed: () => _play(exercise),
                ),
              ],
            ),
          ),
          if (exercise.notes.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Nothing to play in this one.'),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _ExerciseStave(
                  key: ValueKey('palm-stave-$_key-${_shape.name}'),
                  exercise: exercise,
                  about: '${_shape.label} in $_key',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'Under each note, what it is doing: the 3rd of a chord is '
              'the 3rd whatever key you are in, and a high F got to by '
              'feel without knowing that is a stretch learned rather than '
              'a note. In red: the notes the palm keys make. Up and back '
              'down, because coming off them is the harder of the two and '
              'the half everybody leaves out: an exercise that ends on '
              'the high note ends on the bit that went well.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'How to Practise These',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const _Note(
            'Slowly enough that the hand rolls rather than jumps. The '
            'speed is not the exercise; the join is, and a join taken at '
            'a speed you cannot control is a join you are practising '
            'badly.',
          ),
          const _Note(
            'Slurred first, then tongued. Slurring leaves nothing to hide '
            'behind: if the hand is late the note bends, and you can hear '
            'exactly where.',
          ),
          const _Note(
            'Listen for the pitch as well as the note. The palm keys sit '
            'sharp, and the voicing has to drop as the hand moves, which '
            'is two things at once and the reason this takes a while. The '
            'tuner is in the top bar of the Tunes tab.',
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.keyPrefix,
    required this.onPick,
  });

  final List<String> values;
  final String selected;
  final String keyPrefix;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final value in values)
          ChoiceChip(
            key: ValueKey('$keyPrefix-$value'),
            label: Text(value),
            selected: value == selected,
            onSelected: (_) => onPick(value),
          ),
      ],
    ),
  );
}

/// The exercise on a stave, with what each note is doing written under it.
///
/// Built here rather than with [lineOnStave] because that draws notes and
/// this has to draw what they are as well: the degree is the half of the
/// lesson that travels to another key.
class _ExerciseStave extends StatelessWidget {
  const _ExerciseStave({
    super.key,
    required this.exercise,
    required this.about,
  });

  final Exercise exercise;
  final String about;

  @override
  Widget build(BuildContext context) {
    final drawn = lineOnStave([
      for (final note in exercise.notes) (pitch: note.pitch, name: note.name),
    ], marked: exercise.palm);
    return StaveFigure(
      clef: Clef.treble,
      space: 8,
      above: 10,
      below: 6,
      columns: [
        for (final (i, note) in drawn.indexed) ...[
          ?_accidentalFor(note),
          StaveColumn.one(
            Smufl.noteheadWhole,
            step: note.step.toDouble(),
            marked: note.marked,
            ledgers: true,
            gap: 1.1,
            label: exercise.notes[i].degree,
          ),
        ],
      ],
      semanticsLabel: '$about, ${exercise.notes.length} notes',
    );
  }
}

/// The accidental in front of a note, where it has one.
StaveColumn? _accidentalFor(StaveNote note) {
  final glyph = switch (note.accidental) {
    -2 => Smufl.doubleFlat,
    -1 => Smufl.flat,
    1 => Smufl.sharp,
    2 => Smufl.doubleSharp,
    _ => null,
  };
  if (glyph == null) return null;
  return StaveColumn.one(glyph, step: note.step.toDouble(), gap: 0.3);
}
