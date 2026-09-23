// Somebody's own book of licks.
//
// Not filed under tunes. A ii-V lick found in All the Things is the same
// lick in Stella, and filing it under one tune is how you lose it.
//
// Two things happen here: licks go in, and licks come out to be taken
// round the keys. Everything else about a lick, the notes and the
// changes and the marking, lives elsewhere and is only shown here.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../audio/tuner_listener.dart';
import '../music/lick.dart';
import '../music/tuning.dart';
import '../practice/lick_store.dart';
import '../practice/lick_tape.dart';
import '../settings/app_settings.dart';
import 'lick_drill_screen.dart';
import 'record_lick_screen.dart';

class LicksScreen extends StatelessWidget {
  const LicksScreen({
    super.key,
    required this.licks,
    required this.player,
    required this.settings,
    this.tape,
    this.listener,
  });

  final LickStore licks;
  final PracticePlayer player;
  final AppSettings settings;

  /// Stood in for by the tests, which have no microphone.
  @visibleForTesting
  final LickTape? tape;
  @visibleForTesting
  final TunerListener? listener;

  Future<void> _record(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => RecordLickScreen(
          licks: licks,
          player: player,
          settings: settings,
          tape: tape,
        ),
      ),
    );
  }

  Future<void> _drill(BuildContext context, Lick lick) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => LickDrillScreen(
          lick: lick,
          player: player,
          settings: settings,
          listener: listener,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: licks,
    builder: (context, _) {
      final all = licks.all;
      return Scaffold(
        appBar: AppBar(title: const Text('Licks')),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('record-lick'),
          onPressed: () => _record(context),
          icon: const Icon(Icons.fiber_manual_record),
          label: const Text('Record a Lick'),
        ),
        body: all.isEmpty
            ? const _Empty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                itemCount: all.length,
                itemBuilder: (context, i) => _LickRow(
                  lick: all[i],
                  onOpen: () => _drill(context, all[i]),
                  onRemove: () => licks.remove(all[i].id),
                ),
              ),
      );
    },
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_motion_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text('No licks yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Play a line over some changes and the app writes it down. '
              'Then you can take it round all twelve keys, which is the '
              'difference between a phrase you have memorised and one you '
              'can actually use.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One lick: what it is over, and how much of it there is.
class _LickRow extends StatelessWidget {
  const _LickRow({
    required this.lick,
    required this.onOpen,
    required this.onRemove,
  });

  final Lick lick;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      key: ValueKey('lick-${lick.id}'),
      title: Text(lick.name),
      subtitle: Text(
        '${lick.over.title.isEmpty ? 'Your changes' : lick.over.title} '
        'in ${pitchClassName(lick.key)} · '
        '${lick.notes.length} ${lick.notes.length == 1 ? 'note' : 'notes'}',
      ),
      trailing: IconButton(
        key: ValueKey('forget-lick-${lick.id}'),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Take it out',
        onPressed: onRemove,
      ),
      onTap: onOpen,
    ),
  );
}
