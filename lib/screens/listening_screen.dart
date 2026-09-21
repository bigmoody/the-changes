// Listening: the records, and which of these charts are on them.
//
// The only page in Learn that does not teach you to do anything. It is
// here because a chart is a reminder of a performance and this app is
// otherwise all charts, which quietly suggests that the paper is the
// music. It is not, and saying so out loud once seems worth a screen.
//
// Nothing here plays. That is deliberate: the app has no business
// holding recordings, and pretending to be a jukebox would take the
// weight off the thing it is actually asking you to do, which is go and
// find them.

import 'package:flutter/material.dart';

import '../library/listening.dart';
import '../music/tune_library.dart';

class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final have = {for (final tune in standards) tune.title};
    final covered = tunesListened.where(have.contains).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Listening')),
      body: ListView(
        key: const ValueKey('listening-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'This music is passed on by recordings, not by paper. A '
              'chart is a reminder of a performance, so you can read one '
              'of these tunes, play every chord correctly, and still not '
              'know what it is.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'Somewhere to start, oldest first. ${listening.length} '
              'records, and $covered of the tunes in this app are on '
              'them.',
              key: const ValueKey('listening-count'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
          for (final record in listening)
            _Record(key: ValueKey('record-${titleOf(record)}'), record: record),
        ],
      ),
    );
  }
}

/// One record: what it is, why it is here, and the charts this app has
/// for what is on it.
class _Record extends StatelessWidget {
  const _Record({super.key, required this.record});

  final Listening record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(record.artist, style: theme.textTheme.titleSmall),
          Text(
            record.album == null
                ? record.year
                : '${record.album}  ·  ${record.year}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            record.about,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final tune in record.tunes)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(tune),
                  labelStyle: theme.textTheme.labelSmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
