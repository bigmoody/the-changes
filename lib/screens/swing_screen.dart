// Swing: the ride cymbal, and the only thing changing is how late the
// "and" is.
//
// A ride rather than a line of notes, because the ride *is* the swing:
// it is the sound everybody learns the feel from, and its extra stroke
// behind each backbeat is a swung "and" with nothing else attached. A
// melody would only take the attention off the rhythm, and the rhythm is
// the only thing this screen has to say.
//
// Following the tempo is on to begin with, because that is the lesson:
// tap through the tempos and watch the swing flatten itself out without
// anybody touching the slider.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../music/swing.dart';
import '../settings/app_settings.dart';

/// The ride under the example: a ding on every beat, leaning on 2 and 4,
/// with the swung "and" after each of those and the hi-hat closing
/// underfoot with it.
///
/// The same figure the band plays behind every swing tune in the app, so
/// what is being demonstrated is the real thing rather than a diagram of
/// it. The "and" is the only part that moves.
List<SnippetDrum> ridePattern({
  required int tempo,
  required double at,
  int? bars,
}) {
  // Long enough to settle into, short enough to want to tap again. A fast
  // tempo gets through a bar in well under a second, so it gets more.
  final over = bars ?? (tempo >= 180 ? 4 : 2);
  final ride = <SnippetDrum>[];
  for (final (beat, pair) in swungEighths(
    tempo: tempo,
    at: at,
    bars: over,
  ).indexed) {
    final backbeat = beat.isOdd;
    ride.add((
      at: pair.downbeat,
      drum: Drum.ride,
      velocity: backbeat ? 0.62 : 0.52,
      hard: backbeat,
    ));
    if (backbeat) {
      // The "and": a swung eighth with nothing else attached to it.
      ride.add((at: pair.and, drum: Drum.ride, velocity: 0.4, hard: false));
      // What the "and" is heard against: without a beat underneath there
      // is nothing for it to be late to.
      ride.add((
        at: pair.downbeat,
        drum: Drum.hiHatPedal,
        velocity: 0.5,
        hard: true,
      ));
    }
  }
  return ride;
}

class SwingScreen extends StatefulWidget {
  const SwingScreen({super.key, required this.player, required this.settings});

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<SwingScreen> createState() => _SwingScreenState();
}

class _SwingScreenState extends State<SwingScreen> {
  var _chosen = swingTempos[1];
  var _follow = true;
  var _at = swingAt(swingTempos[1].tempo);

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        const [],
        drums: ridePattern(tempo: _chosen.tempo, at: _at),
      ),
    );
  }

  void _pickTempo(SwingTempo tempo) => setState(() {
    _chosen = tempo;
    if (_follow) _at = swingAt(tempo.tempo);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Swing')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('swing-list'),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Jazz eighths are long then short. How long is not '
                      'fixed, and nobody is usually told that; it opens '
                      'right out at a ballad and closes up to nothing at '
                      'a fast tempo.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _Beat(at: _at),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text('Tempo', style: theme.textTheme.titleSmall),
                  ),
                  _Chips(
                    values: [
                      for (final t in swingTempos)
                        (t.name, '${t.name}  ${t.tempo}'),
                    ],
                    selected: _chosen.name,
                    onPick: (name) => _pickTempo(
                      swingTempos.firstWhere((t) => t.name == name),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      _chosen.about,
                      key: const ValueKey('about-tempo'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('follow-the-tempo'),
                    dense: true,
                    contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    title: const Text('Follow the Tempo'),
                    subtitle: const Text(
                      'Swing it the way a player would at that tempo',
                    ),
                    value: _follow,
                    onChanged: (on) => setState(() {
                      _follow = on;
                      if (on) _at = swingAt(_chosen.tempo);
                    }),
                  ),
                  Slider(
                    key: const ValueKey('swing-slider'),
                    min: straight,
                    max: widestSwing,
                    value: _at,
                    label: ratioText(_at),
                    // Taking hold of it is a way of saying you would
                    // rather choose, so it stops following.
                    onChanged: (value) => setState(() {
                      _follow = false;
                      _at = value;
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Text(
                      'The short note stays about the same length whatever '
                      'the tempo: a tenth of a second, about as fast as a '
                      'hand plays a note and means it. It is the beat that '
                      'shrinks around it, so the swing flattens on its own '
                      'as the tempo climbs.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Played on the ride, which is where you hear it. '
                      'The extra stroke behind each backbeat is the swung '
                      '"and", the only thing that moves.',
                      key: const ValueKey('about-the-ride'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('play-swing'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Hear It'),
                  onPressed: _play,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One beat, drawn as the two notes that divide it.
///
/// The line down the middle is where the "and" would be if the eighths
/// were even, so how late it actually lands is something you can see
/// rather than a number to take on trust.
class _Beat extends StatelessWidget {
  const _Beat({required this.at});

  final double at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                ratioText(at),
                key: const ValueKey('swing-ratio'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                swingName(at),
                key: const ValueKey('swing-name'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: (at * 1000).round(),
                      child: _Half(label: 'long', filled: true),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: ((1 - at) * 1000).round(),
                      child: _Half(label: 'short', filled: false),
                    ),
                  ],
                ),
                // Halfway, which is where even eighths would put it.
                Align(
                  alignment: Alignment.center,
                  child: Container(width: 1.5, color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One beat. The mark is halfway; the "and" lands to the right '
            'of it, which is all swing is.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the beat: the long note or the short one.
class _Half extends StatelessWidget {
  const _Half({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filled
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled row of chips that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (value, written) in values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('pick-$value'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                label: Text(written),
                selected: value == selected,
                onSelected: (_) => onPick(value),
              ),
            ),
        ],
      ),
    ),
  );
}
