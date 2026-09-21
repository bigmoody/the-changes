// Swing: one repeated note, and the only thing changing is how late the
// "and" is.
//
// The note never moves in pitch on purpose. A line with any interest in
// it would take the attention off the rhythm, and the rhythm is the only
// thing this screen has to say.
//
// Following the tempo is on to begin with, because that is the lesson:
// tap through the tempos and watch the swing flatten itself out without
// anybody touching the slider.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/swing.dart';
import '../settings/app_settings.dart';

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

  /// One note, repeated. See the note at the top of the file.
  static const _pitch = 69;

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final beat = 60 / _chosen.tempo;
    const bars = 2;
    final notes = <SnippetNote>[
      for (var bar = 0; bar < bars; bar++)
        (
          pitch: 38 + (_pitch - 38) % 12,
          start: bar * 4 * beat,
          length: 4 * beat,
          velocity: 0.28,
          bass: true,
        ),
    ];
    final clicks = <SnippetClick>[];
    final eighths = swungEighths(tempo: _chosen.tempo, at: _at, bars: bars);
    for (final (b, pair) in eighths.indexed) {
      clicks.add((at: pair.downbeat, accent: b % 4 == 0));
      // The downbeat eighth, then the "and" wherever the swing puts it.
      // The weight goes on the offbeat, which is what makes a run of
      // these sound played rather than counted.
      notes.add((
        pitch: _pitch,
        start: pair.downbeat,
        length: (pair.and - pair.downbeat) * 0.9,
        velocity: 0.55,
        bass: false,
      ));
      notes.add((
        pitch: _pitch,
        start: pair.and,
        length: (1 - _at) * beat * 0.9,
        velocity: 0.9,
        bass: false,
      ));
    }
    await widget.player.playSnippet(renderSnippet(bank, notes, clicks: clicks));
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
                      'fixed, and nobody is usually told that — it opens '
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
                    title: const Text('Follow The Tempo'),
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
                      'the tempo — a tenth of a second, about as fast as a '
                      'hand plays a note and means it. It is the beat that '
                      'shrinks around it, so the swing flattens on its own '
                      'as the tempo climbs.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
            'One beat. The mark is halfway — the "and" lands to the right '
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
