// Sound, from the Practice tab: held notes written out, with the band
// holding a drone or a ballad's chords under them, and the note you
// should be on lit as it goes.
//
// Long tones and the ballad sound used to open the tuner, which shows a
// needle and gives you nothing to play. This is the playing: each step a
// row of notes to hold, a count-in, and something under every note to
// sit in tune with.

import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../library/library_store.dart';
import '../music/arrangement.dart';
import '../music/tune_library.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../practice/sound_exercise.dart';
import '../practice/take_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import '../theme.dart';
import 'practice_screen.dart';
import 'stave.dart';

class SoundExerciseScreen extends StatefulWidget {
  const SoundExerciseScreen({
    super.key,
    required this.title,
    required this.exercise,
    required this.keyName,
    required this.day,
    required this.player,
    required this.settings,
    required this.onDone,
    this.library,
    this.progressions,
    this.takes,
    this.partStore,
    this.recordingStore,
  });

  /// The block's name, for the bar at the top.
  final String title;
  final SoundExercise exercise;

  /// Today's key, as the player reads it.
  final String keyName;

  /// Which day it is, for which ballad comes round.
  final int day;
  final PracticePlayer player;
  final AppSettings settings;

  /// Called when every step has been played, to tick the block off.
  final VoidCallback onDone;
  final LibraryStore? library;
  final ProgressionStore? progressions;
  final TakeStore? takes;
  final PartStore? partStore;
  final RecordingStore? recordingStore;

  @override
  State<SoundExerciseScreen> createState() => _SoundExerciseScreenState();
}

class _SoundExerciseScreenState extends State<SoundExerciseScreen> {
  var _at = 0;
  var _tempo = 60;

  /// Whether the band plays your note too, or only what goes under it.
  var _guide = true;

  /// Which note is being held, while the band plays; -1 for the count-in.
  int? _playing;
  Timer? _clock;

  /// Notes to a line of the stave, so a long step wraps rather than
  /// shrinking to nothing.
  static const _perLine = 8;

  SoundStep get _step => widget.exercise.steps[_at];

  late final String _balladTitle = balladFor(widget.day);

  /// The ballad in the player's written key.
  late final _ballad = standards
      .where((t) => t.title == _balladTitle)
      .firstOrNull
      ?.transposed(widget.settings.instrument.semitones);

  List<HeldNote> get _notes =>
      heldNotes(_step.way, widget.keyName, ballad: _ballad);

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
    final notes = _notes;
    if (notes.isEmpty) return;
    final band = soundBand(
      notes,
      tempo: _tempo,
      down: widget.settings.instrument.semitones,
      guide: _guide,
    );
    final starts = band.starts;
    final totalBeats = band.totalBeats;
    final beat = 60 / _tempo;
    final lead = soundCountIn * beat;
    setState(() => _playing = -1);
    await widget.player.playSnippet(
      renderSnippet(bank, band.notes, drums: band.drums),
    );
    final started = Stopwatch()..start();
    _clock = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final beats = (started.elapsedMilliseconds / 1000 - lead) / beat;
      if (beats >= totalBeats + 1) {
        _stop();
        return;
      }
      var index = -1;
      for (final (i, start) in starts.indexed) {
        if (beats >= start) index = i;
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

  void _next() {
    unawaited(_stop());
    if (_at == widget.exercise.steps.length - 1) {
      widget.onDone();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _at++);
  }

  void _openBallad() {
    final tune = standards.where((t) => t.title == _balladTitle).firstOrNull;
    if (tune == null) return;
    unawaited(_stop());
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          tune: tune,
          player: widget.player,
          settings: widget.settings,
          library: widget.library,
          progressions: widget.progressions,
          takes: widget.takes,
          partStore: widget.partStore,
          recordingStore: widget.recordingStore,
          startAt: 60,
          arrangement: const Arrangement(choruses: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final step = _step;
    final notes = _notes;
    final last = _at == widget.exercise.steps.length - 1;
    final melody = step.way == SoundWay.theMelody;
    final ballad =
        step.way == SoundWay.balladGuides || step.way == SoundWay.theMelody;
    final now = switch (_playing) {
      final i? when i >= 0 && i < notes.length => notes[i],
      _ => null,
    };

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
                    'Step ${_at + 1} of ${widget.exercise.steps.length}',
                    key: const ValueKey('sound-step'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    step.title,
                    key: const ValueKey('sound-title'),
                    style: handLettered(theme.textTheme.headlineMedium),
                  ),
                  if (ballad)
                    Text(
                      'On $_balladTitle',
                      key: const ValueKey('sound-ballad'),
                      style: theme.textTheme.titleMedium,
                    ),
                  const SizedBox(height: 6),
                  Text(step.how, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  if (melody)
                    FilledButton.tonalIcon(
                      key: const ValueKey('sound-melody'),
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Play $_balladTitle at 60'),
                      onPressed: _openBallad,
                    )
                  else ...[
                    for (var from = 0; from < notes.length; from += _perLine)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Stave(
                            key: ValueKey('sound-stave-$from'),
                            clef: Clef.treble,
                            notes: lineOnStave(
                              [
                                for (final note
                                    in notes.skip(from).take(_perLine))
                                  (pitch: note.pitch, name: note.name),
                              ],
                              marked: {
                                if (_playing case final at?
                                    when at >= from && at < from + _perLine)
                                  at - from,
                              },
                            ),
                            space: MediaQuery.sizeOf(context).width > 600
                                ? 12
                                : 8,
                            semanticsLabel: step.title,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        for (final note in notes)
                          [note.name, ?note.chord, ?note.label].join(' '),
                      ].join(' · '),
                      key: const ValueKey('sound-notes'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // What is happening now, big enough to read from the
                    // stand while the horn is up.
                    SizedBox(
                      height: 40,
                      child: Text(
                        switch ((_playing, now)) {
                          (-1, _) => 'Counting in…',
                          (_, final n?) => [
                            n.name,
                            ?n.chord,
                            ?n.label,
                          ].join('   '),
                          _ => '',
                        },
                        key: const ValueKey('sound-now'),
                        style: handLettered(theme.textTheme.headlineSmall)
                            .copyWith(color: scheme.primary),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton.outlined(
                          key: const ValueKey('sound-slower'),
                          tooltip: 'Slower',
                          icon: const Icon(Icons.remove),
                          onPressed: () => setState(
                            () => _tempo = (_tempo - 5).clamp(40, 100),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$_tempo',
                                key: const ValueKey('sound-tempo'),
                                style: theme.textTheme.headlineSmall,
                              ),
                              Text(
                                'BPM',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.outlined(
                          key: const ValueKey('sound-faster'),
                          tooltip: 'Faster',
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(
                            () => _tempo = (_tempo + 5).clamp(40, 100),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilterChip(
                      key: const ValueKey('sound-guide'),
                      label: const Text('Band Plays Your Note Too'),
                      selected: _guide,
                      onSelected: (on) => setState(() => _guide = on),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (!melody) ...[
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('sound-play'),
                        icon: Icon(
                          _playing == null ? Icons.play_arrow : Icons.stop,
                        ),
                        label: Text(_playing == null ? 'Play Along' : 'Stop'),
                        onPressed: _playAlong,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('sound-next'),
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
