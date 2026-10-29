// A scale to play, from the Practice tab: today's scale in today's key,
// written out, with a count-in and a click to play it against.
//
// The routine used to say "G major, two octaves, at 70 to 90" and send
// you to the reference page, which tells you what a scale is and gives
// you nothing to do with it. This is the doing: a few runs through the
// scale, one shape at a time, the note you should be on lit as the band
// goes, and a tempo that is kept so tomorrow starts where today ended.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../music/scale_patterns.dart';
import '../music/scale_run.dart';
import '../music/scales.dart';
import '../practice/roadmap.dart';
import '../practice/roadmap_progress.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'stave.dart';

/// One step of the exercise: a mode, run one way.
typedef _Step = ({Mode mode, String way});

class ScaleOfTheDayScreen extends StatefulWidget {
  const ScaleOfTheDayScreen({
    super.key,
    required this.title,
    required this.modes,
    required this.keyName,
    required this.exercise,
    required this.instrument,
    required this.progress,
    required this.player,
    required this.settings,
    required this.onDone,
  });

  /// The block's name, for the bar at the top.
  final String title;

  /// The modes to play, by their names in `modes`.
  final List<String> modes;

  /// Today's key, as the player reads it.
  final String keyName;
  final ScaleExercise exercise;
  final RoadmapInstrument instrument;
  final RoadmapProgress progress;
  final PracticePlayer player;
  final AppSettings settings;

  /// Called when every step has been played, to tick the block off.
  final VoidCallback onDone;

  @override
  State<ScaleOfTheDayScreen> createState() => _ScaleOfTheDayScreenState();
}

class _ScaleOfTheDayScreenState extends State<ScaleOfTheDayScreen> {
  late final List<_Step> _steps = [
    for (final name in widget.modes)
      for (final way in widget.exercise.ways)
        (mode: modes.firstWhere((m) => m.name == name), way: way),
  ];
  var _at = 0;

  /// A horn's range is its player's, and one octave is the honest default
  /// for a scale on a horn the app cannot hear; the others have the room
  /// for two.
  late var _octaves = widget.instrument == RoadmapInstrument.horn ? 1 : 2;

  /// Whether the band plays the scale with you, or only counts.
  var _guide = true;

  late var _tempo = widget.progress.scaleTempo(_tempoKey, widget.exercise.from);

  /// Which note of the line is being played, while it is.
  int? _playing;
  Timer? _clock;

  _Step get _step => _steps[_at];

  String get _tempoKey => '${_step.mode.name} ${_step.way}';

  bool get _bass => widget.instrument == RoadmapInstrument.bass;

  Clef get _clef => _bass ? Clef.bass : Clef.treble;

  /// Where the scale starts, as written: low on the bass (which sounds an
  /// octave under what it reads), near the bottom of the stave for the
  /// guitar (likewise), and around middle C for piano and horns.
  int get _floor => switch (widget.instrument) {
    RoadmapInstrument.bass => 40,
    RoadmapInstrument.guitar => 52,
    _ => _octaves == 1 ? 60 : 55,
  };

  ScaleRun get _run => scaleRun(
    _step.mode,
    widget.keyName,
    _step.way,
    octaves: _octaves,
    floor: _floor,
  );

  /// Two notes to the beat.
  double get _noteSeconds => 30 / _tempo;

  static const _countIn = 4;

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(widget.player.stopSnippet());
    super.dispose();
  }

  Future<void> _playAlong() async {
    if (_playing != null) return _stop();
    final bank = widget.player.samples;
    if (bank == null) return;
    final run = _run;
    final beat = 60 / _tempo;
    final lead = _countIn * beat;
    final length = run.pitches.length * _noteSeconds;
    // Concert pitch, and the octave the guitar and bass sound in.
    final down =
        widget.settings.instrument.semitones +
        (_bass || widget.instrument == RoadmapInstrument.guitar ? 12 : 0);
    final notes = <SnippetNote>[
      if (_guide)
        for (final (i, pitch) in run.pitches.indexed)
          (
            pitch: pitch - down,
            start: lead + i * _noteSeconds,
            length: i == run.pitches.length - 1
                ? beat * 2
                : _noteSeconds * 0.95,
            velocity: 0.6,
            bass: _bass,
          ),
    ];
    final drums = <SnippetDrum>[
      // A bar to come in on: every beat, the first one louder.
      for (var b = 0; b < _countIn; b++)
        (
          at: b * beat,
          drum: Drum.crossStick,
          velocity: b == 0 ? 0.8 : 0.6,
          hard: b == 0,
        ),
      // Then 2 and 4, which is where the time lives in this music.
      for (var b = 1; b * beat < length + beat; b += 2)
        (at: lead + b * beat, drum: Drum.hiHatPedal, velocity: 0.6, hard: true),
    ];
    setState(() => _playing = -1);
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        notes,
        drums: drums,
        guitar: widget.instrument == RoadmapInstrument.guitar,
      ),
    );
    final started = Stopwatch()..start();
    _clock = Timer.periodic(const Duration(milliseconds: 20), (_) {
      final seconds = started.elapsedMilliseconds / 1000 - lead;
      final index = seconds < 0 ? -1 : (seconds / _noteSeconds).floor();
      if (index >= run.pitches.length + 2) {
        _stop();
      } else if (index != _playing && mounted) {
        setState(() => _playing = index);
      }
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
    if (_at == _steps.length - 1) {
      widget.onDone();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _at++;
      _tempo = widget.progress.scaleTempo(_tempoKey, widget.exercise.from);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final run = _run;
    final step = _step;
    final pattern = scalePatterns.where((p) => p.name == step.way).firstOrNull;
    final scale = '${step.mode.spelledRoot(widget.keyName)} ${step.mode.name}';
    final last = _at == _steps.length - 1;
    final atGoal = _tempo >= widget.exercise.to;

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
                    'Step ${_at + 1} of ${_steps.length}',
                    key: const ValueKey('scale-step'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    scale,
                    key: const ValueKey('scale-name'),
                    style: handLettered(theme.textTheme.headlineMedium),
                  ),
                  Text(
                    runLabel(step.way),
                    key: const ValueKey('scale-way'),
                    style: theme.textTheme.titleMedium,
                  ),
                  if (pattern != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      pattern.about,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // The way up and the way back down, a line each, each
                  // made smaller if it has to be to fit: the whole run in
                  // view, so nothing has to be scrolled to while playing.
                  for (final (from, to) in [
                    (0, run.turn),
                    (run.turn, run.pitches.length),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Stave(
                          key: ValueKey('scale-stave-$from'),
                          clef: _clef,
                          notes: lineOnStave(
                            [
                              for (var i = from; i < to; i++)
                                (pitch: run.pitches[i], name: run.names[i]),
                            ],
                            clef: _clef,
                            marked: {
                              if (_playing case final at?
                                  when at >= from && at < to)
                                at - from,
                            },
                          ),
                          // Bigger where there is the room: on an iPad on a
                          // music stand, the notes are read from arm's length.
                          space: MediaQuery.sizeOf(context).width > 600
                              ? 12
                              : 8,
                          semanticsLabel: from == 0
                              ? '$scale, ${runLabel(step.way)}, going up'
                              : 'and coming down',
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    run.names.join(' '),
                    key: const ValueKey('scale-notes'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton.outlined(
                        key: const ValueKey('scale-slower'),
                        tooltip: 'Slower',
                        icon: const Icon(Icons.remove),
                        onPressed: () => _setTempo(_tempo - 5),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$_tempo',
                              key: const ValueKey('scale-tempo'),
                              style: theme.textTheme.headlineSmall,
                            ),
                            Text(
                              atGoal
                                  ? 'At the goal of ${widget.exercise.to}. '
                                        'Keep it there, or push on.'
                                  : 'BPM, two notes a beat. Goal: '
                                        '${widget.exercise.to}',
                              key: const ValueKey('scale-goal'),
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
                        key: const ValueKey('scale-faster'),
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
                    children: [
                      SegmentedButton<int>(
                        key: const ValueKey('scale-octaves'),
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1 Octave')),
                          ButtonSegment(value: 2, label: Text('2 Octaves')),
                        ],
                        selected: {_octaves},
                        onSelectionChanged: (value) {
                          unawaited(_stop());
                          setState(() => _octaves = value.first);
                        },
                      ),
                      FilterChip(
                        key: const ValueKey('scale-guide'),
                        label: const Text('Band Plays It Too'),
                        selected: _guide,
                        onSelected: (on) => setState(() => _guide = on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _guide
                        ? 'A bar counted in, then play with the band, the '
                              'note you should be on lit as it goes. Say each '
                              'note name as you play it.'
                        : 'A bar counted in, then the click on 2 and 4 and '
                              'nothing else: the notes are yours.',
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
                      key: const ValueKey('scale-play'),
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
                      key: const ValueKey('scale-next'),
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
