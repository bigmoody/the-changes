// Lines to play with marks on them, from the Practice tab: articulation
// and ghosting for a horn.
//
// Each step is two bars of swung eighths in today's key, written out with
// a mark under every note (tongued, slurred, accented, ghosted). Play
// Along counts a bar in, then the ride, the hi-hat on 2 and 4 and, if it
// is wanted, the line itself played the way the marks say, for as many
// times through as asked: long enough to settle into it, which two bars
// of a ride on their own never were.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../music/swing.dart';
import '../practice/line_exercise.dart';
import '../practice/roadmap.dart';
import '../practice/roadmap_progress.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'stave.dart';
import 'swing_screen.dart' show ridePattern;

class LineExerciseScreen extends StatefulWidget {
  const LineExerciseScreen({
    super.key,
    required this.title,
    required this.keyName,
    required this.exercise,
    required this.progress,
    required this.player,
    required this.settings,
    required this.onDone,
    this.level = PlayerLevel.intermediate,
  });

  /// Who is playing, which sets where the tempo starts and aims for.
  final PlayerLevel level;

  final String title;

  /// Today's key, as the player reads it.
  final String keyName;
  final LineExercise exercise;
  final RoadmapProgress progress;
  final PracticePlayer player;
  final AppSettings settings;

  /// Called when every step has been played, to tick the block off.
  final VoidCallback onDone;

  @override
  State<LineExerciseScreen> createState() => _LineExerciseScreenState();
}

class _LineExerciseScreenState extends State<LineExerciseScreen> {
  var _at = 0;

  /// How many times through the line each Play Along goes.
  var _times = 4;
  var _guide = true;

  late var _tempo = widget.progress.scaleTempo(
    _tempoKey,
    widget.level.tempo(widget.exercise.from),
  );

  /// Which note of the line is sounding, while it plays.
  int? _playing;
  Timer? _clock;

  LineStep get _step => widget.exercise.steps[_at];

  String get _tempoKey => 'Line ${_step.title}';

  /// Around middle C as written, where every horn has the notes.
  List<LineEvent> get _line => lineIn(_step, widget.keyName, floor: 60);

  static const _countIn = 4;

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(widget.player.stopSnippet());
    super.dispose();
  }

  /// When each eighth of a pass starts, in beats: the "and" late by as
  /// much as a player swings at this tempo.
  List<double> _eighthBeats(int count) => eighthBeats(count, _tempo);

  Future<void> _playAlong() async {
    if (_playing != null) return _stop();
    final bank = widget.player.samples;
    if (bank == null) return;
    final line = _line;
    final beat = 60 / _tempo;
    final lead = _countIn * beat;
    final beats = line.length / 2;
    final bars = (beats / 4).ceil();
    final starts = _eighthBeats(line.length);
    final notes = _guide
        ? guideNotes(
            line,
            tempo: _tempo,
            times: _times,
            from: lead,
            down: widget.settings.instrument.semitones,
          )
        : const <SnippetNote>[];
    final drums = <SnippetDrum>[
      // A bar to come in on.
      for (var b = 0; b < _countIn; b++)
        (
          at: b * beat,
          drum: Drum.crossStick,
          velocity: b == 0 ? 0.8 : 0.6,
          hard: b == 0,
        ),
      // Then the ride and the hi-hat for every pass.
      for (final hit in ridePattern(
        tempo: _tempo,
        at: swingAt(_tempo),
        bars: bars * _times,
      ))
        (
          at: lead + hit.at,
          drum: hit.drum,
          velocity: hit.velocity,
          hard: hit.hard,
        ),
    ];
    setState(() => _playing = -1);
    await widget.player.playSnippet(
      renderSnippet(bank, notes, drums: drums, pianoRelease: guideRelease),
    );
    final started = Stopwatch()..start();
    final passSeconds = beats * beat;
    _clock = Timer.periodic(const Duration(milliseconds: 15), (_) {
      final seconds = started.elapsedMilliseconds / 1000 - lead;
      if (seconds >= passSeconds * _times + beat) {
        _stop();
        return;
      }
      var index = -1;
      if (seconds >= 0) {
        final within = (seconds % passSeconds) / beat;
        for (var i = 0; i < starts.length; i++) {
          if (starts[i] <= within) index = i;
        }
      }
      if (index != _playing && mounted) setState(() => _playing = index);
    });
  }

  Future<void> _stop() async {
    _clock?.cancel();
    _clock = null;
    if (mounted) setState(() => _playing = null);
    await widget.player.stopSnippet();
  }

  void _setTempo(int tempo) {
    setState(() => _tempo = tempo.clamp(40, 280));
    widget.progress.setScaleTempo(_tempoKey, _tempo);
  }

  void _next() {
    unawaited(_stop());
    if (_at == widget.exercise.steps.length - 1) {
      widget.onDone();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _at++;
      _tempo = widget.progress.scaleTempo(
        _tempoKey,
        widget.level.tempo(widget.exercise.from),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final step = _step;
    final line = _line;
    final steps = widget.exercise.steps;
    final last = _at == steps.length - 1;
    // The stave has no rests, so its notes are the pitched ones, and the
    // one to light is found by counting them.
    final pitched = [
      for (final (i, e) in line.indexed)
        if (e.pitch != null) i,
    ];
    final lit = _playing == null ? -1 : pitched.indexOf(_playing!);
    final atGoal = _tempo >= widget.level.tempo(widget.exercise.to);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    'Step ${_at + 1} of ${steps.length} · '
                    '${widget.keyName} ${step.mode == 'Ionian' ? 'major' : step.mode}',
                    key: const ValueKey('line-step'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    step.title,
                    key: const ValueKey('line-title'),
                    style: handLettered(theme.textTheme.headlineMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(step.how, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Stave(
                      key: const ValueKey('line-stave'),
                      notes: lineOnStave(
                        [
                          for (final i in pitched)
                            (pitch: line[i].pitch!, name: line[i].name),
                        ],
                        marked: {if (lit >= 0) lit},
                      ),
                      space: MediaQuery.sizeOf(context).width > 600 ? 12 : 8,
                      semanticsLabel: step.title,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Marks(line: line, playing: _playing),
                  const SizedBox(height: 8),
                  Text(
                    '${Touch.tongue.mark} tongued   ${Touch.slur.mark} slurred   '
                    '${Touch.accent.mark} accented   ${Touch.ghost.mark} ghosted   '
                    '${Touch.rest.mark} rest',
                    key: const ValueKey('line-legend'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.outlined(
                        key: const ValueKey('line-slower'),
                        tooltip: 'Slower',
                        icon: const Icon(Icons.remove),
                        onPressed: () => _setTempo(_tempo - 5),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$_tempo',
                              key: const ValueKey('line-tempo'),
                              style: theme.textTheme.headlineSmall,
                            ),
                            Text(
                              atGoal
                                  ? 'At the goal of ${widget.level.tempo(widget.exercise.to)}. '
                                        'Keep it there, or push on.'
                                  : 'BPM, swung eighths. Goal: '
                                        '${widget.level.tempo(widget.exercise.to)}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: atGoal
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.outlined(
                        key: const ValueKey('line-faster'),
                        tooltip: 'Faster',
                        icon: const Icon(Icons.add),
                        onPressed: () => _setTempo(_tempo + 5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<int>(
                        key: const ValueKey('line-times'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 2, label: Text('2 Times')),
                          ButtonSegment(value: 4, label: Text('4 Times')),
                          ButtonSegment(value: 8, label: Text('8 Times')),
                        ],
                        selected: {_times},
                        onSelectionChanged: (value) =>
                            setState(() => _times = value.first),
                      ),
                      FilterChip(
                        key: const ValueKey('line-guide'),
                        label: const Text('Band Plays the Line'),
                        selected: _guide,
                        onSelected: (on) => setState(() => _guide = on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _guide
                        ? 'A bar counted in, then play with the band: the line '
                              'is played the way the marks say, so you can hear '
                              'it before you match it. Then turn it off and '
                              'play it alone over the ride.'
                        : 'A bar counted in, then the ride and the hi-hat '
                              'and nothing else: the line is yours.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('line-play'),
                      icon: Icon(
                        _playing == null ? Icons.play_arrow : Icons.stop,
                      ),
                      label: Text(_playing == null ? 'Play Along' : 'Stop'),
                      onPressed: _playAlong,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('line-next'),
                      onPressed: _next,
                      child: Text(last ? 'Done' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The line as a row of eighths in beat pairs: the count above, the mark
/// and the note name in each, the one being played lit.
class _Marks extends StatelessWidget {
  const _Marks({required this.line, required this.playing});

  final List<LineEvent> line;
  final int? playing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget cell(int i) {
      final event = line[i];
      final lit = i == playing;
      final strong = event.touch == Touch.accent;
      return Container(
        key: ValueKey('mark-$i'),
        width: 36,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: lit ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              i.isEven ? '${(i ~/ 2) % 4 + 1}' : '&',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              event.touch.mark,
              style:
                  (event.touch == Touch.rest
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                        color: strong ? scheme.tertiary : null,
                      ),
            ),
            Text(
              event.name,
              style: theme.textTheme.labelMedium?.copyWith(
                color: event.touch == Touch.ghost
                    ? scheme.onSurfaceVariant
                    : null,
              ),
            ),
          ],
        ),
      );
    }

    // A bar to a row, the beats a little apart, so it reads as counted.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var bar = 0; bar * 8 < line.length; bar++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (var beat = 0; beat < 4; beat++) ...[
                    for (
                      var i = bar * 8 + beat * 2;
                      i < bar * 8 + beat * 2 + 2 && i < line.length;
                      i++
                    )
                      cell(i),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
