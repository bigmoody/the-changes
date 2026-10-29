// The Practice tab: a roadmap to playing jazz, and today's routine on it.
//
//   Today     the routine for the stage you are on, cut to the time you
//             have, each block opening the page it is done on
//   Roadmap   six stages, each with the goals that finish it. You tick
//             them yourself, and move up when they are all ticked.
//
// The routine changes every day (the key, the tune, which small blocks a
// short session leaves out), so a month of it covers everything on the
// stage without anybody having to plan it.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/find_tune.dart';
import '../library/library_store.dart';
import '../music/mode_examples.dart';
import '../music/tune_library.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../practice/roadmap.dart';
import '../practice/roadmap_progress.dart';
import '../practice/take_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import 'bebop_scales_screen.dart';
import 'changes_in_keys_screen.dart';
import 'chord_tones_reference_screen.dart';
import 'chord_tones_screen.dart';
import 'comping_screen.dart';
import 'ear_training_screen.dart';
import 'enclosures_screen.dart';
import 'guide_tones_screen.dart';
import 'guitar_chords_screen.dart';
import 'listening_screen.dart';
import 'mode_example_row.dart';
import 'practice_screen.dart';
import 'metronome_screen.dart';
import 'modal_screen.dart';
import 'number_patterns_screen.dart';
import 'passing_chords_screen.dart';
import 'rhythm_changes_screen.dart';
import 'scale_patterns_screen.dart';
import 'scales_reference_screen.dart';
import 'setlists_screen.dart';
import 'swing_screen.dart';
import 'through_the_changes_screen.dart';
import 'trading_screen.dart';
import 'tritone_subs_screen.dart';
import 'tuner_screen.dart';
import 'tunes_page.dart' show SectionHeader;
import 'upper_structures_screen.dart';
import 'voicings_screen.dart';
import 'walking_bass_screen.dart';
import 'where_am_i_screen.dart';

class PracticePage extends StatelessWidget {
  const PracticePage({
    super.key,
    required this.progress,
    required this.player,
    required this.settings,
    required this.library,
    required this.progressions,
    this.takes,
    this.partStore,
    this.recordingStore,
    this.today,
  });

  final RoadmapProgress progress;
  final PracticePlayer player;
  final AppSettings settings;
  final LibraryStore library;
  final ProgressionStore progressions;
  final TakeStore? takes;
  final PartStore? partStore;
  final RecordingStore? recordingStore;

  /// What day it is, for tests. Otherwise the clock's.
  @visibleForTesting
  final DateTime? today;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: progress,
    builder: (context, _) {
      final instrument = progress.instrument;
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: SafeArea(
          child: instrument == null
              ? _ChooseInstrument(progress: progress)
              : _Roadmap(page: this, instrument: instrument),
        ),
      );
    },
  );

  Widget _screenFor(Tool tool) => switch (tool) {
    Tool.metronome => MetronomeScreen(player: player, settings: settings),
    Tool.swing => SwingScreen(player: player, settings: settings),
    Tool.scalesReference => ScalesReferenceScreen(
      player: player,
      settings: settings,
    ),
    Tool.scalePatterns => ScalePatternsScreen(
      player: player,
      settings: settings,
    ),
    Tool.numberPatterns => NumberPatternsScreen(
      player: player,
      settings: settings,
    ),
    Tool.bebopScales => BebopScalesScreen(player: player, settings: settings),
    Tool.chordTones => ChordTonesReferenceScreen(
      player: player,
      settings: settings,
    ),
    Tool.chordQuiz => ChordTonesScreen(player: player, settings: settings),
    Tool.guideTones => GuideTonesScreen(player: player, settings: settings),
    Tool.changesInKeys => ChangesInKeysScreen(
      player: player,
      settings: settings,
    ),
    Tool.throughTheChanges => ThroughTheChangesScreen(
      player: player,
      settings: settings,
    ),
    Tool.enclosures => EnclosuresScreen(player: player, settings: settings),
    Tool.passingChords => PassingChordsScreen(
      player: player,
      settings: settings,
    ),
    Tool.earTraining => EarTrainingScreen(player: player, settings: settings),
    Tool.whereAmI => WhereAmIScreen(player: player, settings: settings),
    Tool.walkingBass => WalkingBassScreen(player: player, settings: settings),
    Tool.comping => CompingScreen(player: player, settings: settings),
    Tool.voicings => VoicingsScreen(player: player, settings: settings),
    Tool.guitarChords => GuitarChordsScreen(player: player, settings: settings),
    Tool.trading => TradingScreen(player: player, settings: settings),
    Tool.rhythmChanges => RhythmChangesScreen(
      player: player,
      settings: settings,
    ),
    Tool.tritoneSubs => TritoneSubsScreen(player: player, settings: settings),
    Tool.upperStructures => UpperStructuresScreen(
      player: player,
      settings: settings,
    ),
    Tool.modal => ModalScreen(player: player, settings: settings),
    Tool.listening => const ListeningScreen(),
    Tool.tuner => TunerScreen(player: player, settings: settings),
  };

  void _openTool(BuildContext context, Tool tool) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => _screenFor(tool)));

  void _openTune(BuildContext context, String title, {int semitones = 0}) {
    final tune = [
      ...standards,
      ...practiceProgressions,
    ].where((t) => t.title == title).firstOrNull;
    if (tune == null) return;
    if (semitones != 0) {
      library.justPlayed(TuneRef.of(tune));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PracticeScreen(
            tune: tune,
            player: player,
            settings: settings,
            takes: takes,
            partStore: partStore,
            recordingStore: recordingStore,
            library: library,
            progressions: progressions,
            semitones: semitones,
          ),
        ),
      );
      return;
    }
    LibraryContext(
      player: player,
      settings: settings,
      library: library,
      progressions: progressions,
      takes: takes,
      partStore: partStore,
      recordingStore: recordingStore,
    ).play(context, FoundTune(tune));
  }
}

/// The first time: what do you play?
class _ChooseInstrument extends StatelessWidget {
  const _ChooseInstrument({required this.progress});

  final RoadmapProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('A Roadmap to Playing Jazz', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Six stages, from playing in time on a blues to a voice of your '
          'own. Every day: scales, chord tones and a tune, cut to the time '
          'you have. What do you play?',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        for (final instrument in RoadmapInstrument.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonal(
              key: ValueKey('roadmap-for-${instrument.name}'),
              onPressed: () => progress.setInstrument(instrument),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(instrument.label),
              ),
            ),
          ),
        Text(
          'Horns covers saxophones, trumpet, trombone, clarinet and flute.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Roadmap extends StatelessWidget {
  const _Roadmap({required this.page, required this.instrument});

  final PracticePage page;
  final RoadmapInstrument instrument;

  RoadmapProgress get progress => page.progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = stagesFor(instrument);
    final stage = stages[progress.stageOf(instrument) - 1];
    final day = dayNumber(page.today ?? DateTime.now());
    final routine = routineFor(stage, progress.minutes, day: day);
    final done = [
      for (var b = 0; b < routine.length; b++)
        progress.isDone(day, b, routine[b].block.title),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<RoadmapInstrument>(
            key: const ValueKey('roadmap-instrument'),
            showSelectedIcon: false,
            segments: [
              for (final i in RoadmapInstrument.values)
                ButtonSegment(value: i, label: Text(i.label)),
            ],
            selected: {instrument},
            onSelectionChanged: (chosen) =>
                progress.setInstrument(chosen.single),
          ),
        ),
        SectionHeader('Today'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Stage ${stage.number}: ${stage.title}',
            key: const ValueKey('today-stage'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 6,
            children: [
              for (final length in sessionLengths)
                ChoiceChip(
                  key: ValueKey('session-$length'),
                  label: Text('$length Min'),
                  showCheckmark: false,
                  selected: progress.minutes == length,
                  onSelected: (_) => progress.setMinutes(length),
                ),
            ],
          ),
        ),
        for (var b = 0; b < routine.length; b++)
          _RoutineRow(
            key: ValueKey('routine-$b'),
            block: routine[b],
            instrument: instrument,
            done: done[b],
            onDone: (on) =>
                progress.markDone(day, b, routine[b].block.title, on),
            onOpen: switch ((routine[b].tune, routine[b].block.tool)) {
              (final String tune, _) => () => page._openTune(context, tune),
              (_, final Tool tool) => () => page._openTool(context, tool),
              _ => null,
            },
            // A tune a mode is heard in opens in today's key, so the
            // sound is heard where it is being practised.
            onTune: (tune) => page._openTune(
              context,
              tune,
              semitones: semitonesToKey(tune, routine[b].key),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            done.every((d) => d)
                ? "That's today done. Same time tomorrow: the key and the "
                      'tune will have moved on.'
                : '${done.where((d) => d).length} of ${routine.length} done. '
                      'The key and the tune change every day.',
            key: const ValueKey('today-done'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SectionHeader('Roadmap'),
        for (final s in stages)
          _StageTile(
            key: ValueKey('stage-${s.number}'),
            stage: s,
            instrument: instrument,
            progress: progress,
            current: s.number == stage.number,
            onTune: (title) => page._openTune(context, title),
          ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    super.key,
    required this.block,
    required this.instrument,
    required this.done,
    required this.onDone,
    required this.onOpen,
    required this.onTune,
  });

  final RoutineBlock block;
  final RoadmapInstrument instrument;
  final bool done;
  final ValueChanged<bool> onDone;
  final VoidCallback? onOpen;

  /// Plays a tune the block's modes are heard in.
  final ValueChanged<String> onTune;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tool = block.block.tool;
    return ListTile(
      leading: Checkbox(value: done, onChanged: (on) => onDone(on ?? false)),
      title: Text(
        block.block.title,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${block.block.area.labelFor(instrument)} · ${block.how}'
            '${block.tune == null && tool != null ? ' (${tool.label})' : ''}',
          ),
          if (block.block.modes.isNotEmpty)
            _HeardIn(
              modes: block.block.modes,
              todayKey: block.key,
              onTune: onTune,
            ),
        ],
      ),
      trailing: Text(
        '${block.minutes} min',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      isThreeLine: true,
      onTap: onOpen,
    );
  }
}

/// Where the modes a block works on are heard: the tunes, to play with
/// the band, and everything else a tap away. A scale practised with a
/// sound in mind is a scale remembered.
class _HeardIn extends StatelessWidget {
  const _HeardIn({
    required this.modes,
    required this.todayKey,
    required this.onTune,
  });

  final List<String> modes;

  /// The key the tunes open in.
  final String todayKey;
  final ValueChanged<String> onTune;

  @override
  Widget build(BuildContext context) {
    final tunes = <String>{
      for (final mode in modes)
        for (final example in modeExamples[mode] ?? const <ModeExample>[])
          ?example.tune,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            key: ValueKey('heard-in-${modes.join('-')}'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.hearing, size: 16),
            // Named for the sound: the major sound is the major sound in
            // C or in G, and the tunes are only examples of it.
            label: Text('${modes.join(' and ')} Heard In'),
            tooltip:
                'Where ${modes.join(' and ')} ${modes.length == 1 ? 'is' : 'are'} heard',
            onPressed: () => _showAll(context),
          ),
          for (final tune in tunes)
            ActionChip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.play_arrow, size: 16),
              label: Text(switch (movedKeyLabel(tune, todayKey)) {
                final key? => '$tune, in $key',
                null => tune,
              }),
              onPressed: () => onTune(tune),
            ),
        ],
      ),
    );
  }

  void _showAll(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Heard In', style: theme.textTheme.titleLarge),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'A mode sounds the same in every key. The tunes open in '
                "$todayKey, today's key; the bars and chords named here are "
                'in the key each tune is written in.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final mode in modes) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(mode, style: theme.textTheme.titleSmall),
              ),
              for (final example in modeExamples[mode] ?? const <ModeExample>[])
                ModeExampleRow(
                  example: example,
                  opensIn: switch (example.tune) {
                    final tune? => movedKeyLabel(tune, todayKey),
                    null => null,
                  },
                  onTune: (tune) {
                    Navigator.of(sheet).pop();
                    onTune(tune);
                  },
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    super.key,
    required this.stage,
    required this.instrument,
    required this.progress,
    required this.current,
    required this.onTune,
  });

  final Stage stage;
  final RoadmapInstrument instrument;
  final RoadmapProgress progress;
  final bool current;
  final ValueChanged<String> onTune;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticked = stage.goals
        .where((goal) => progress.isTicked(instrument, goal))
        .length;
    final finished = ticked == stage.goals.length;
    final last = stage.number == 6;
    return ExpansionTile(
      initiallyExpanded: current,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: current
            ? theme.colorScheme.primary
            : finished
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: current
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        child: finished && !current
            ? const Icon(Icons.check, size: 16)
            : Text('${stage.number}'),
      ),
      title: Text(stage.title),
      subtitle: Text('$ticked of ${stage.goals.length} · ${stage.aim}'),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        for (final goal in stage.goals)
          CheckboxListTile(
            key: ValueKey('goal-${goal.id}'),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: progress.isTicked(instrument, goal),
            onChanged: (on) => progress.tick(instrument, goal, on ?? false),
            title: Text(goal.text),
            subtitle: Text(goal.area.labelFor(instrument)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final title in stage.tunes)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.play_arrow, size: 16),
                    label: Text(title),
                    onPressed: () => onTune(title),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: current
                ? FilledButton(
                    key: ValueKey('move-up-${stage.number}'),
                    // Ticked yourself, so moved up yourself: the button is
                    // there once you say you can do it all.
                    onPressed: finished && !last
                        ? () => progress.setStage(instrument, stage.number + 1)
                        : null,
                    child: Text(
                      last
                          ? 'The Last Stage'
                          : finished
                          ? 'Move Up to Stage ${stage.number + 1}'
                          : 'Tick Every Goal to Move Up',
                    ),
                  )
                : OutlinedButton(
                    key: ValueKey('work-on-${stage.number}'),
                    onPressed: () =>
                        progress.setStage(instrument, stage.number),
                    child: const Text('Work on This Stage'),
                  ),
          ),
        ),
      ],
    );
  }
}
