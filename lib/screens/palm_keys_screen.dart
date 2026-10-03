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
          const _TheKeys(),
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
                child: Stave(
                  key: ValueKey('palm-stave-$_key-${_shape.name}'),
                  notes: lineOnStave(exercise.notes, marked: exercise.palm),
                  space: 8,
                  semanticsLabel:
                      '${_shape.label} in $_key, '
                      '${exercise.notes.length} notes',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'In red: the notes the palm keys make. Up and back down, '
              'because coming off them is the harder of the two and the '
              'half everybody leaves out: an exercise that ends on the '
              'high note ends on the bit that went well.',
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

/// Where the three palm keys are, and what is held down for each note.
///
/// The map and the fingerings together, because apart they are two half
/// answers: the map says there are three keys under the side of the left
/// palm and the fingerings say which of them combine for what. Tapping a
/// note lights the keys it holds down, so the thing being learned, that
/// the notes stack rather than replace each other, can be seen happening
/// rather than read about.
class _TheKeys extends StatefulWidget {
  const _TheKeys();

  @override
  State<_TheKeys> createState() => _TheKeysState();
}

class _TheKeysState extends State<_TheKeys> {
  /// Which note's fingering is being shown. Starts on F, the one people
  /// come to this page for.
  var _showing = palmFingerings.last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final held = _showing.keys.toSet();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drawn top to bottom as they sit on the horn, the F
              // highest and furthest from the hand.
              Column(
                children: [
                  for (final key in [
                    SaxKey.palmF,
                    SaxKey.palmEFlat,
                    SaxKey.palmD,
                  ])
                    _Key(saxKey: key, down: held.contains(key)),
                  const SizedBox(height: 6),
                  // Apart from the three, and below them, because it is
                  // the other hand entirely.
                  _Key(saxKey: SaxKey.sideE, down: held.contains(SaxKey.sideE)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Three keys under the side of the left palm, each named '
                  'for the note it first gives you, and the octave key '
                  'down for all of them. The hand rolls outwards onto them '
                  'and back, which is why the join is a movement rather '
                  'than a finger. The fourth is the upper right-hand side '
                  'key, taken with the side of the other hand: it is what '
                  'makes E out of E♭, and the reason the right hand cannot '
                  'be left behind at the top.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final fingering in palmFingerings)
                ChoiceChip(
                  key: ValueKey('fingering-${fingering.name}'),
                  label: Text(fingering.name),
                  selected: fingering.name == _showing.name,
                  onSelected: (_) => setState(() => _showing = fingering),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_showing.name}: '
              '${_showing.keys.map((k) => k.said).join(' + ')}',
              key: const ValueKey('fingering-line'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Nothing is let go of on the way up: every note keeps what '
              'the one below it was holding. F♯ is left out, because it is '
              'a side key worked by the right hand and a different problem '
              'with a different solution.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One key on the map, drawn down or up.
class _Key extends StatelessWidget {
  const _Key({required this.saxKey, required this.down});

  final SaxKey saxKey;
  final bool down;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: ValueKey('palm-key-${saxKey.name}'),
      width: 54,
      height: 26,
      margin: const EdgeInsets.only(bottom: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: down ? scheme.tertiary : scheme.surfaceContainerHigh,
        border: Border.all(
          color: down ? scheme.tertiary : scheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        saxKey.label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: down ? scheme.onTertiary : null,
        ),
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
