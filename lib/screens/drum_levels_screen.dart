// Setting each drum where you can stand it.
//
// The mixer already turns the whole kit up and down, and that is the wrong
// size of knob for this. A ride cymbal and a kick drum are not the same
// thing to listen to: the cymbals carry most of their energy where ears
// get sore, and for a lot of people, autistic players above all, that is
// where a band stops being something you play with. Turning the kit down
// to fix the ride takes the kick and the snare with it, and then there is
// no time left to play against.
//
// So: a level each, cymbals and hats at the top because they are why this
// is here, and a tap on any of them to hear it at the level you have just
// set. Choosing a level you cannot hear would be guessing, and this is
// not a setting anybody can guess at: the whole point is that what is
// comfortable is different for each person.
//
// The band starts again when a level changes, because the drums are mixed
// into one stem before a note sounds. That is the same deal as changing
// the feel, and it is why this lives here rather than in the mixer, where
// everything is live.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_levels.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../settings/app_settings.dart';

class DrumLevelsScreen extends StatelessWidget {
  const DrumLevelsScreen({
    super.key,
    required this.settings,
    required this.player,
  });

  final AppSettings settings;
  final PracticePlayer player;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = settings.drumLevels;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drum Levels'),
        actions: [
          if (levels.isNotEmpty)
            TextButton(
              key: const ValueKey('reset-drum-levels'),
              onPressed: settings.clearDrumLevels,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'How loud each drum is on its own. The cymbals and hats are '
                'first because they are usually the ones worth moving: they '
                'are the loudest part of a kit to listen to, and turning the '
                'whole kit down to fix them takes the time away with it. '
                'Tap a drum to hear it where you have put it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final drum in drumsByEar)
              _DrumRow(
                drum: drum,
                level: levels.of(drum),
                onChanged: (level) => settings.setDrumLevel(drum, level),
                onHear: () => _hear(drum, levels.of(drum)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'A level is mixed in before the band plays rather than set '
                'on it while it goes, so the band starts again from the top '
                'of the loop when you move one.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One hit of [drum], at the level it has been put at.
  ///
  /// Nothing happens without the recorded kit, which is the case in tests
  /// and for the moment before the samples have loaded. A silent button is
  /// better than one that throws.
  Future<void> _hear(Drum drum, double level) async {
    final bank = player.samples;
    if (bank == null) return;
    await player.playSnippet(
      renderSnippet(
        bank,
        const [],
        // The velocity a drum is struck at in the band, times the level,
        // which is exactly the arithmetic the band does. Hearing
        // something other than what will play would be worse than
        // hearing nothing.
        drums: [(at: 0, drum: drum, velocity: 0.8 * level, hard: false)],
      ),
    );
  }
}

class _DrumRow extends StatelessWidget {
  const _DrumRow({
    required this.drum,
    required this.level,
    required this.onChanged,
    required this.onHear,
  });

  final Drum drum;
  final double level;
  final ValueChanged<double> onChanged;
  final VoidCallback onHear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (level * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(drum.label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              key: ValueKey('level-${drum.name}'),
              value: level,
              // Up as well as down: a kick somebody has turned the rest
              // down around may need to come back up to be felt at all.
              max: 1.5,
              divisions: 30,
              label: '$percent%',
              semanticFormatterCallback: (value) =>
                  '${drum.label} at ${(value * 100).round()} per cent',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$percent%',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: level == 1
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.tertiary,
              ),
            ),
          ),
          IconButton(
            key: ValueKey('hear-${drum.name}'),
            icon: const Icon(Icons.volume_up_outlined),
            tooltip: 'Hear the ${drum.label.toLowerCase()}',
            onPressed: onHear,
          ),
        ],
      ),
    );
  }
}
