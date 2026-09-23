// Setlists: the tunes for a gig, a lesson or this month's practice, in the
// order they'll be played.
//
// A setlist holds references rather than copies, so a progression edited in
// My Changes is edited in every setlist it's in, and a tune deleted there
// simply drops out. Nothing here changes the music itself.

import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/find_tune.dart';
import '../library/library_store.dart';
import '../music/tune_library.dart';
import '../practice/take_store.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import '../theme.dart';
import 'practice_screen.dart';
import 'share_chart.dart';
import 'tunes_page.dart' show SectionHeader;

/// Everything a setlist screen needs to open a tune in the practice screen.
class LibraryContext {
  const LibraryContext({
    required this.player,
    required this.settings,
    required this.library,
    required this.progressions,
    this.takes,
    this.partStore,
    this.recordingStore,
  });

  final PracticePlayer player;
  final AppSettings settings;
  final LibraryStore library;
  final ProgressionStore progressions;
  final TakeStore? takes;
  final PartStore? partStore;

  /// Where recordings of real players are kept.
  final RecordingStore? recordingStore;

  /// Opens [found] full screen, as tapping it in any list does.
  void play(BuildContext context, FoundTune found) {
    library.justPlayed(
      found.progression == null
          ? TuneRef.of(found.tune)
          : TuneRef.mine(found.progression!.id),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          tune: found.tune,
          player: player,
          settings: settings,
          takes: takes,
          partStore: partStore,
          recordingStore: recordingStore,
          library: library,
          progression: found.progression,
          progressions: found.progression == null ? null : progressions,
        ),
      ),
    );
  }
}

/// The list of setlists.
class SetlistsScreen extends StatelessWidget {
  const SetlistsScreen({super.key, required this.deps});

  final LibraryContext deps;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: deps.library,
    builder: (context, _) {
      final setlists = deps.library.setlists;
      return Scaffold(
        appBar: AppBar(title: const Text('Setlists')),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('new-setlist'),
          onPressed: () => _newSetlist(context),
          icon: const Icon(Icons.add),
          label: const Text('New Setlist'),
        ),
        body: setlists.isEmpty
            ? const _NoSetlists()
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: setlists.length,
                itemBuilder: (context, i) => _tile(context, setlists[i]),
              ),
      );
    },
  );

  Widget _tile(BuildContext context, Setlist setlist) => ListTile(
    key: ValueKey('setlist-${setlist.id}'),
    title: Text(setlist.displayName),
    subtitle: Text(_howMany(setlist.tunes.length)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetlistScreen(deps: deps, id: setlist.id),
      ),
    ),
  );

  Future<void> _newSetlist(BuildContext context) async {
    final name = await askForName(context, title: 'New Setlist');
    if (name == null || !context.mounted) return;
    final setlist = await deps.library.addSetlist(name);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetlistScreen(deps: deps, id: setlist.id),
      ),
    );
  }
}

String _howMany(int tunes) => tunes == 1 ? '1 tune' : '$tunes tunes';

class _NoSetlists extends StatelessWidget {
  const _NoSetlists();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing on the stand',
              style: handLettered(theme.textTheme.headlineSmall),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A setlist is the tunes for a gig, a lesson, or whatever '
              'you\'re working on this month, in the order you\'ll play them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// One setlist: its tunes in order, to play, drag about or take out.
class SetlistScreen extends StatelessWidget {
  const SetlistScreen({super.key, required this.deps, required this.id});

  final LibraryContext deps;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([deps.library, deps.progressions]),
    builder: (context, _) {
      final setlist = deps.library.setlistById(id);
      // Deleted from under us (or restored from a backup that hasn't got
      // it): there's nothing left to show.
      if (setlist == null) return const _Gone();
      final found = [
        for (final ref in setlist.tunes)
          (ref: ref, found: findTune(ref, progressions: deps.progressions)),
      ];
      return Scaffold(
        appBar: AppBar(
          // A long name shrinks to fit rather than trailing off, as a tune's
          // does on the practice screen.
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(setlist.displayName),
          ),
          actions: [
            IconButton(
              key: const ValueKey('setlist-share'),
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share',
              onPressed: found.isEmpty
                  ? null
                  : () => shareCharts(context, [
                      for (final entry in found) ?entry.found?.tune,
                    ], heading: setlist.displayName),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('setlist-menu'),
              onSelected: (choice) async {
                switch (choice) {
                  case 'rename':
                    final name = await askForName(
                      context,
                      title: 'Rename Setlist',
                      was: setlist.name,
                    );
                    if (name != null) {
                      await deps.library.renameSetlist(id, name);
                    }
                  case 'delete':
                    if (!context.mounted) return;
                    final sure = await _confirmDelete(context, setlist);
                    if (!sure || !context.mounted) return;
                    await deps.library.deleteSetlist(id);
                    if (context.mounted) Navigator.of(context).pop();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete Setlist')),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('add-tunes'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PickTunesScreen(deps: deps, id: id),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add Tunes'),
        ),
        body: found.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(32, 0, 32, 96),
                  child: Text('Add the tunes you want, in playing order.'),
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: found.length,
                onReorderItem: (from, to) =>
                    deps.library.moveInSetlist(id, from, to),
                itemBuilder: (context, i) {
                  final entry = found[i];
                  return _tuneTile(context, i, entry.ref, entry.found);
                },
              ),
      );
    },
  );

  Widget _tuneTile(
    BuildContext context,
    int index,
    TuneRef ref,
    FoundTune? found,
  ) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('setlist-tune-${ref.value}'),
      leading: Text(
        '${index + 1}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        found?.tune.title ?? (ref.isMine ? 'Deleted progression' : ref.name),
        style: found == null
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(
        found == null
            ? 'Not in the book any more'
            : [
                'Key of '
                    '${found.tune.keyLabelBy(deps.settings.instrument.semitones)}',
                '${found.tune.defaultTempo} bpm',
              ].join(' · '),
      ),
      onTap: found == null ? null : () => deps.play(context, found),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Take out of the setlist',
            onPressed: () => deps.library.setInSetlist(id, ref, false),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 4, right: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Setlist setlist) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete "${setlist.displayName}"?'),
          content: const Text(
            'The setlist goes; the tunes in it stay where they are.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('That setlist isn\'t here any more.')),
  );
}

/// Choosing tunes to put in a setlist: the whole book and the player's own,
/// searchable, ticking the ones to add.
class PickTunesScreen extends StatefulWidget {
  const PickTunesScreen({super.key, required this.deps, required this.id});

  final LibraryContext deps;
  final String id;

  @override
  State<PickTunesScreen> createState() => _PickTunesScreenState();
}

class _PickTunesScreenState extends State<PickTunesScreen> {
  String _query = '';
  final _chosen = <TuneRef>{};

  bool _matches(String title, String? composer, String key) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      title,
      composer ?? '',
      key,
    ].any((text) => text.toLowerCase().contains(query));
  }

  Future<void> _add() async {
    final library = widget.deps.library;
    for (final ref in _chosen) {
      await library.setInSetlist(widget.id, ref, true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final setlist = widget.deps.library.setlistById(widget.id);
    final already = {...?setlist?.tunes};
    final mine = [
      for (final progression in widget.deps.progressions.all)
        if (_matches(
          progression.displayTitle,
          progression.composer,
          progression.key,
        ))
          (
            ref: TuneRef.mine(progression.id),
            title: progression.displayTitle,
            below: 'Key of ${progression.key} · yours',
          ),
    ];
    final book = [
      for (final tune in [...standards, ...practiceProgressions])
        if (_matches(tune.title, tune.composer, tune.key))
          (
            ref: TuneRef.of(tune),
            title: tune.title,
            below: [?tune.composer, 'Key of ${tune.key}'].join(' · '),
          ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Add Tunes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const ValueKey('pick-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tunes, composers or keys',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (mine.isNotEmpty) ...[
                  const SectionHeader('My Changes'),
                  for (final entry in mine)
                    _pick(entry.ref, entry.title, entry.below, already),
                ],
                if (book.isNotEmpty) ...[
                  const SectionHeader('Standards'),
                  for (final entry in book)
                    _pick(entry.ref, entry.title, entry.below, already),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _chosen.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                key: const ValueKey('pick-add'),
                onPressed: _add,
                child: Text(
                  _chosen.length == 1
                      ? 'Add 1 Tune'
                      : 'Add ${_chosen.length} Tunes',
                ),
              ),
            ),
    );
  }

  Widget _pick(TuneRef ref, String title, String below, Set<TuneRef> already) {
    final inIt = already.contains(ref);
    return CheckboxListTile(
      key: ValueKey('pick-${ref.value}'),
      value: inIt || _chosen.contains(ref),
      // A tune that's already in the setlist can't be added twice.
      onChanged: inIt
          ? null
          : (on) => setState(
              () => on == true ? _chosen.add(ref) : _chosen.remove(ref),
            ),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: Text(inIt ? 'Already in this setlist' : below),
    );
  }
}

/// Asks which setlists [tune] should be in, from wherever it's open.
Future<void> showAddToSetlist(
  BuildContext context,
  LibraryStore library,
  TuneRef tune,
  String title,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => ListenableBuilder(
    listenable: library,
    builder: (context, _) {
      final setlists = library.setlists;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Add "$title" To',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final setlist in setlists)
                CheckboxListTile(
                  key: ValueKey('to-setlist-${setlist.id}'),
                  value: setlist.tunes.contains(tune),
                  onChanged: (on) =>
                      library.setInSetlist(setlist.id, tune, on == true),
                  title: Text(setlist.displayName),
                  subtitle: Text(_howMany(setlist.tunes.length)),
                ),
              ListTile(
                key: const ValueKey('to-new-setlist'),
                leading: const Icon(Icons.add),
                title: const Text('New Setlist'),
                onTap: () async {
                  final name = await askForName(
                    context,
                    title: 'New Setlist',
                    was: title,
                  );
                  if (name == null) return;
                  final setlist = await library.addSetlist(name);
                  await library.setInSetlist(setlist.id, tune, true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  ),
);

/// Asks for a setlist's name, starting from [was] if it has one.
Future<String?> askForName(
  BuildContext context, {
  required String title,
  String was = '',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, was: was),
  );
  return name?.trim();
}

/// The name dialog owns its text, so it lives exactly as long as the dialog
/// does: disposing the controller while the dialog is still fading out
/// rebuilds a field that no longer has one.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.was});

  final String title;
  final String was;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.was);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('setlist-name'),
      controller: _text,
      autofocus: true,
      // Sentences, not words: a setlist is called "Tuesday at the Vortex",
      // not "Tuesday At The Vortex".
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Friday at the Vortex'),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_text.text),
        child: const Text('Save'),
      ),
    ],
  );
}
