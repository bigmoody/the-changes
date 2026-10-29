// Session skills and getting lost, from the Practice tab: a list of drills,
// each played on the tune of the day with the band set up for it.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/library_store.dart';
import '../music/tune_library.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../practice/roadmap.dart';
import '../practice/session_drills.dart';
import '../practice/take_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import '../theme.dart';
import 'practice_screen.dart';

class SessionDrillsScreen extends StatelessWidget {
  const SessionDrillsScreen({
    super.key,
    required this.title,
    required this.intro,
    required this.drills,
    required this.tune,
    required this.instrument,
    required this.player,
    required this.settings,
    this.library,
    this.progressions,
    this.takes,
    this.partStore,
    this.recordingStore,
    this.onDone,
  });

  final String title;

  /// What the drills are for, in a sentence or two.
  final String intro;
  final List<SessionDrill> drills;

  /// The tune they are played on, by its title in the library.
  final String tune;
  final RoadmapInstrument instrument;
  final PracticePlayer player;
  final AppSettings settings;
  final LibraryStore? library;
  final ProgressionStore? progressions;
  final TakeStore? takes;
  final PartStore? partStore;
  final RecordingStore? recordingStore;

  /// Called from the Done button, to tick the block off. Null where the
  /// screen was opened to browse.
  final VoidCallback? onDone;

  void _play(BuildContext context, SessionDrill drill) {
    final found = [
      ...standards,
      ...practiceProgressions,
    ].where((t) => t.title == tune).firstOrNull;
    final setup = drill.setup;
    if (found == null || setup == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          tune: found,
          player: player,
          settings: settings,
          library: library,
          progressions: progressions,
          takes: takes,
          partStore: partStore,
          recordingStore: recordingStore,
          startBar: switch (setup.barsFromEnd) {
            final bars? => found.barCount - bars,
            null => null,
          },
          arrangement: setup.arrangement,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = [
      for (final drill in drills)
        if (drill.isFor(instrument)) drill,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(intro, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Played on $tune.',
                    key: const ValueKey('drills-tune'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final (i, drill) in shown.indexed)
                    Card(
                      key: ValueKey('drill-$i'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              drill.title,
                              style: handLettered(theme.textTheme.titleLarge),
                            ),
                            const SizedBox(height: 6),
                            Text(drill.how, style: theme.textTheme.bodyMedium),
                            if (drill.setup != null) ...[
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                key: ValueKey('drill-play-$i'),
                                icon: const Icon(Icons.play_arrow),
                                label: Text('Play It on $tune'),
                                onPressed: () => _play(context, drill),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onDone != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey('drills-done'),
                    onPressed: () {
                      onDone!();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Done'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
