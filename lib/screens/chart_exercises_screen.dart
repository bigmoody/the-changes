// The exercises for a tune, as a page you play from.
//
// Levels rather than one drill, and kept per tune, because what you can
// do on a blues you cannot necessarily do on Stella and there is no
// reason the app should pretend otherwise. The level is remembered by the
// tune's title, so a chart written in the app or imported this morning
// keeps its own place exactly as A Foggy Day does.
//
// The written line is the point of the screen: a page to read, with the
// chord symbol over the note the change lands on, because which note the
// change lands on is most of what these exercises teach. The buttons play
// it so you can hear what you are about to try.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart' show renderSnippet;
import '../audio/practice_player.dart';
import '../music/chart_exercises.dart';
import '../music/tune.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'stave.dart';

class ChartExercisesScreen extends StatefulWidget {
  const ChartExercisesScreen({
    super.key,
    required this.tune,
    required this.player,
    required this.settings,
  });

  /// The chart as the player reads it: already transposed for their
  /// instrument, so a tenor player's exercise is in a tenor player's key.
  final Tune tune;
  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ChartExercisesScreen> createState() => _ChartExercisesScreenState();
}

class _ChartExercisesScreenState extends State<ChartExercisesScreen> {
  late ChartExercise _which = widget.settings.exerciseFor(widget.tune.title);
  bool _playing = false;

  List<ExerciseNote> get _line => exerciseOver(widget.tune, _which);

  Future<void> _choose(ChartExercise which) async {
    setState(() => _which = which);
    await widget.settings.setExerciseFor(widget.tune.title, which);
  }

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    setState(() => _playing = true);
    // Slow enough to read and to get your fingers to, whatever the tune's
    // own tempo is: this is the exercise, not the performance.
    const beat = 0.5;
    final line = _line;
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final note in line)
          (
            pitch: note.pitch,
            start: note.beat * beat,
            length: note.length * beat,
            velocity: note.target ? 0.8 : 0.66,
            bass: false,
          ),
        // The root underneath each change, quietly, so the line is heard
        // against the chord rather than on its own.
        for (final note in line)
          if (note.startsChord)
            (
              pitch: 40 + (note.chord.bass - 40) % 12,
              start: note.beat * beat,
              length: note.length * beat,
              velocity: 0.26,
              bass: true,
            ),
      ]),
    );
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _stop() async {
    await widget.player.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = _line;
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                widget.tune.title,
                style: handLettered(theme.textTheme.titleLarge),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Five of them, in the order they are worth learning, and '
                'generated from this tune\'s own changes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final which in ChartExercise.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        key: ValueKey('exercise-${which.name}'),
                        label: Text('${which.level}. ${which.label}'),
                        selected: which == _which,
                        onSelected: (_) => _choose(which),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _which.about,
                key: const ValueKey('exercise-about'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('hear-exercise'),
                      onPressed: _playing ? null : _play,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Hear It'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('stop-exercise'),
                    tooltip: 'Stop',
                    onPressed: _playing ? _stop : null,
                    icon: const Icon(Icons.stop),
                  ),
                ],
              ),
            ),
            _Written(
              key: ValueKey('exercise-written-${_which.name}'),
              tune: widget.tune,
              line: line,
            ),
          ],
        ),
      ),
    );
  }
}

/// The exercise written out, a bar to a block, wrapping like a chart.
class _Written extends StatelessWidget {
  const _Written({super.key, required this.tune, required this.line});

  final Tune tune;
  final List<ExerciseNote> line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beats = tune.beatsPerBar;
    final bars = <Widget>[];
    for (var bar = 0; bar * beats < _lastBeat() + 1; bar++) {
      final from = bar * beats;
      final inBar = [
        for (final note in line)
          if (note.beat >= from && note.beat < from + beats) note,
      ];
      if (inBar.isEmpty) continue;
      bars.add(
        _Bar(
          key: ValueKey('exercise-bar-$bar'),
          number: bar + 1,
          notes: inBar,
          theme: theme,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(spacing: 12, runSpacing: 16, children: bars),
    );
  }

  double _lastBeat() => line.isEmpty
      ? 0
      : line.map((n) => n.beat).reduce((a, b) => a > b ? a : b);
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.number,
    required this.notes,
    required this.theme,
  });

  final int number;
  final List<ExerciseNote> notes;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    // The chords this bar changes on, over the notes they land on.
    final changes = [
      for (final note in notes)
        if (note.startsChord) note.chord.display,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          changes.isEmpty ? ' ' : changes.map(handSymbol).join('  '),
          style: handLettered(theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 2),
        Stave(
          notes: lineOnStave(
            [for (final note in notes) (pitch: note.pitch, name: note.name)],
            marked: {
              for (final (i, note) in notes.indexed)
                if (note.target) i,
            },
          ),
          semanticsLabel:
              'Bar $number: '
              '${notes.map((n) => n.name).join(', ')}',
        ),
        const SizedBox(height: 2),
        Text(
          '$number',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
