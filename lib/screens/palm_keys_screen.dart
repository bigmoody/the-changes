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
import 'sax_diagram.dart';
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

/// The fingerings, drawn as a saxophone rather than as a column of
/// holes.
///
/// Seven of them: the four the palm keys make and the three the hand
/// comes from below the join, because the join is a movement between
/// them and a chart of only the destination teaches half of it. Reading
/// left to right across the two groups is the movement itself.
class _TheKeys extends StatelessWidget {
  const _TheKeys();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The Keys', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          const _KeyMap(),
          const SizedBox(height: 6),
          Text(
            'The whole horn every time, with the keys a note holds filled '
            'in. The three under the side of the left palm sit above the '
            'left hand as a cluster rather than in a line, which is how '
            'the hand meets them: it rolls across that shape. The side E '
            'is reached with the side of the right hand, and is what '
            'makes E out of E♭.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _Group(title: 'Up to the Join', fingerings: approachFingerings),
          const SizedBox(height: 14),
          _Group(title: 'On the Palm Keys', fingerings: palmFingerings),
          const SizedBox(height: 10),
          Text(
            'Nothing is let go of on the way up: every note above the '
            'join keeps what the one below it was holding. Coming the '
            'other way, C♯ is the hard one, because it is nothing held '
            'down at all and the hand has no shape to arrive at. F♯ is '
            'left out, being a side key worked by the right hand and a '
            'different problem with a different solution.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One horn, bigger, with the keys this page is about named.
///
/// Only those five. A chart that labels all twenty-two keys is a diagram
/// of a saxophone, which is a different page: this one is about the top
/// of the horn, and the rest is drawn so the picture is honest rather
/// than so it can be read off.
class _KeyMap extends StatelessWidget {
  const _KeyMap();

  static const _scale = 1.45;
  static const _leftPad = 62.0;
  static const _rightPad = 48.0;
  static const _width = _leftPad + canvasWidth * _scale + _rightPad;

  /// The named ones, and which side the name goes.
  static const _names = <SaxKey, bool>{
    SaxKey.octave: false,
    SaxKey.palmEFlat: false,
    SaxKey.palmD: false,
    SaxKey.palmF: false,
    SaxKey.sideE: true,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.tertiary,
    );
    return SizedBox(
      width: _width,
      height: canvasHeight * _scale,
      child: Stack(
        children: [
          Positioned(
            left: _leftPad,
            child: const SaxDiagram(held: {}, idPrefix: 'map', scale: _scale),
          ),
          for (final entry in _names.entries)
            if (saxLayout[entry.key] case final place?)
              Positioned(
                // Named outside the drawing on the side the key is on,
                // so no name sits over the horn.
                left: entry.value
                    ? _leftPad + (place.x + place.w) * _scale + 6
                    : null,
                right: entry.value
                    ? null
                    : _width - _leftPad - place.x * _scale + 6,
                top: (place.y + place.h / 2) * _scale - 7,
                child: Text(entry.key.said, style: style),
              ),
        ],
      ),
    );
  }
}

/// One side of the join, titled, with its notes in a row.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.fingerings});

  final String title;
  final List<PalmFingering> fingerings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final fingering in fingerings)
              Column(
                children: [
                  SaxDiagram(
                    held: fingering.keys.toSet(),
                    idPrefix: fingering.name,
                    scale: 0.74,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fingering.name,
                    key: ValueKey('fingering-name-${fingering.name}'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
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
