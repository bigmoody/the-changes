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

/// The fingerings, drawn the way a fingering chart draws them.
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
          Text(
            'Filled is held down. The three keys under the side of the '
            'left palm are drawn down the left, each named for the note '
            'it first gives you, and the octave key is down for all of '
            'these. The one on the right is the upper right-hand side '
            'key, taken with the side of the other hand: it is what makes '
            'E out of E♭, and the reason the right hand cannot be left '
            'behind at the top.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
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
          spacing: 14,
          runSpacing: 12,
          children: [
            for (final fingering in fingerings)
              _Fingering(fingering: fingering),
          ],
        ),
      ],
    );
  }
}

/// One note, drawn as a fingering.
///
/// The octave key at the top left where the thumb is, the palm keys down
/// the left of the left hand, the side key down the right of the right
/// hand, and the two hands either side of the break. The same shape a
/// fingering chart has always used, so somebody who has read one before
/// does not have to be taught this one.
class _Fingering extends StatelessWidget {
  const _Fingering({required this.fingering});

  final PalmFingering fingering;

  static const _hole = 17.0;
  static const _sideKey = 9.0;
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final held = fingering.keys.toSet();

    Widget hole(SaxKey key) => Container(
      key: ValueKey('hole-${fingering.name}-${key.name}'),
      width: _hole,
      height: _hole,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: held.contains(key) ? scheme.onSurface : Colors.transparent,
        border: Border.all(color: scheme.onSurface, width: 1.3),
      ),
    );

    // The palm and side keys are drawn as the small rounded bars they
    // are on the horn, rather than as holes: they are keys the hand
    // rolls onto, not holes a finger covers, and the picture should not
    // pretend otherwise.
    Widget bar(SaxKey? key) => SizedBox(
      width: _sideKey,
      height: _hole,
      child: key == null
          ? null
          : Container(
              key: ValueKey('bar-${fingering.name}-${key.name}'),
              decoration: BoxDecoration(
                color: held.contains(key)
                    ? scheme.onSurface
                    : Colors.transparent,
                border: Border.all(color: scheme.onSurface, width: 1.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
    );

    Widget row(SaxKey? left, SaxKey finger, [SaxKey? right]) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar(left),
          const SizedBox(width: _gap),
          hole(finger),
          const SizedBox(width: _gap),
          bar(right),
        ],
      ),
    );

    return Column(
      children: [
        // The octave key, over on the left where the thumb reaches it
        // from behind the horn.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: ValueKey('bar-${fingering.name}-${SaxKey.octave.name}'),
                width: _sideKey + 4,
                height: 10,
                decoration: BoxDecoration(
                  color: held.contains(SaxKey.octave)
                      ? scheme.onSurface
                      : Colors.transparent,
                  border: Border.all(color: scheme.onSurface, width: 1.3),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: _gap + _hole + _gap + _sideKey - 4),
            ],
          ),
        ),
        row(SaxKey.palmF, SaxKey.lh1),
        row(SaxKey.palmEFlat, SaxKey.lh2),
        row(SaxKey.palmD, SaxKey.lh3),
        // The break between the hands.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SizedBox(
            width: _sideKey * 2 + _gap * 2 + _hole,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 6; i++)
                  Container(width: 3, height: 1.2, color: scheme.outline),
              ],
            ),
          ),
        ),
        row(null, SaxKey.rh1, SaxKey.sideE),
        row(null, SaxKey.rh2),
        row(null, SaxKey.rh3),
        const SizedBox(height: 4),
        Text(
          fingering.name,
          key: ValueKey('fingering-name-${fingering.name}'),
          style: theme.textTheme.titleSmall?.copyWith(color: scheme.tertiary),
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
