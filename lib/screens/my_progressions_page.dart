import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/library_store.dart';
import '../music/tune.dart';
import '../music/user_progression.dart';
import '../practice/take_store.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import '../theme.dart';
import 'alphabet_index.dart';
import 'genre_filter.dart';
import 'import_screen.dart';
import 'practice_screen.dart';
import 'progression_editor_screen.dart';
import 'star_button.dart';
import 'tunes_page.dart' show TuneListControls;
import 'note_ink.dart';

/// The My changes tab: progressions the player has written, to play, edit,
/// filter by genre and delete: one at a time or several at once.
class MyProgressionsPage extends StatefulWidget {
  const MyProgressionsPage({
    super.key,
    required this.player,
    required this.settings,
    required this.progressions,
    required this.library,
    this.takes,
    this.partStore,
    this.recordingStore,
  });

  final PracticePlayer player;
  final AppSettings settings;
  final ProgressionStore progressions;
  final LibraryStore library;
  final TakeStore? takes;
  final PartStore? partStore;

  /// Where recordings of real players are kept.
  final RecordingStore? recordingStore;

  @override
  State<MyProgressionsPage> createState() => _MyProgressionsPageState();
}

class _MyProgressionsPageState extends State<MyProgressionsPage> {
  Genre? _genre;
  var _order = TuneOrder.title;
  var _starredOnly = false;
  var _query = '';
  final _scroll = ScrollController();
  late final _letters = LetterIndex(_scroll);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Whether [progression] is one of what's being looked for.
  ///
  /// The same fields the Tunes tab searches, as far as a progression has
  /// them: what it is called, who wrote it, what key it is in, and the
  /// feel the band plays it with, so "bossa" finds the bossas. An
  /// imported playlist can run to hundreds, which is what this is for.
  bool _matches(UserProgression progression) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      progression.title,
      progression.composer ?? '',
      progression.key,
      progression.style.drums.label,
    ].any((text) => text.toLowerCase().contains(query));
  }

  /// Choosing progressions to delete several at once.
  bool _selecting = false;
  final _selected = <String>{};

  void _startSelecting([String? first]) => setState(() {
    _selecting = true;
    if (first != null) _selected.add(first);
  });

  void _stopSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    if (!await confirmDeleteMany(context, _selected.length)) return;
    final gone = {..._selected};
    await widget.progressions.deleteAll(gone);
    // A deleted progression can't be left starred or sitting on a setlist.
    await widget.library.forget(gone.map(TuneRef.mine));
    _stopSelecting();
  }

  /// Brings charts in from iReal Pro, and says how many came.
  Future<void> _import() async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ImportScreen(store: widget.progressions),
      ),
    );
    if (!mounted || count == null || count == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(count == 1 ? 'Imported 1 song' : 'Imported $count songs'),
      ),
    );
  }

  void _openEditor(UserProgression? progression) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProgressionEditorScreen(
        store: widget.progressions,
        player: widget.player,
        settings: widget.settings,
        existing: progression,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Saving or deleting a progression shows straight away.
    listenable: Listenable.merge([
      widget.settings,
      widget.progressions,
      widget.library,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final all = widget.progressions.all;
    final genres = {for (final p in all) ...p.genres};
    // A genre whose last progression was deleted can't stay chosen.
    if (_genre != null && !genres.contains(_genre)) _genre = null;
    final shown = sortedProgressions([
      for (final progression in all)
        if ((_genre == null || progression.genres.contains(_genre)) &&
            (!_starredOnly ||
                widget.library.isFavourite(TuneRef.mine(progression.id))) &&
            _matches(progression))
          progression,
    ], _order);
    // The strip only makes sense down a list in an order with an alphabet
    // to it, and only earns its place on a long one. While several are
    // being chosen to delete, the rows are checkboxes and there's nothing
    // for it to scroll to.
    final filing = [for (final p in shown) _fileUnder(p)];
    final letters = _order.hasAnAlphabet && !_selecting && filing.length > 12
        ? lettersIn(filing)
        : const <String>[];
    // Most of your own progressions have nobody credited, so by composer
    // there's often only one letter, and a strip of one is no use.
    final indexed = letters.length > 1;
    if (indexed) _letters.follow(filing);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopSelecting();
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar(all) : _normalBar(all),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openEditor(null),
                icon: const Icon(Icons.add),
                label: const Text('New Progression'),
              ),
        body: all.isEmpty
            ? _Empty(onImport: _import)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TextField(
                      key: const ValueKey('progression-search'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search your changes, composers or keys',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  TuneListControls(
                    starredOnly: _starredOnly,
                    onStarred: (on) => setState(() => _starredOnly = on),
                    order: _order,
                    onOrder: (order) => setState(() => _order = order),
                  ),
                  if (genres.length > 1)
                    GenreFilter(
                      available: genres,
                      selected: _genre,
                      onChanged: (genre) => setState(() => _genre = genre),
                    ),
                  Expanded(
                    child: Stack(
                      // The letter beside a thumb on the strip reaches out
                      // over the list.
                      clipBehavior: Clip.none,
                      children: [
                        // Built as they scroll into view: an imported
                        // playlist can hold hundreds.
                        ListView.builder(
                          key: const ValueKey('progression-list'),
                          controller: _scroll,
                          // Room at the end so the button never hides the
                          // last, and down the side for the strip.
                          padding: EdgeInsets.only(
                            bottom: 88,
                            right: indexed ? AlphabetIndex.width : 0,
                          ),
                          itemCount: shown.length,
                          itemBuilder: (context, i) => _tile(
                            shown[i],
                            // The first under each letter is what the strip
                            // scrolls to.
                            letter:
                                !indexed ||
                                    (i > 0 &&
                                        letterOf(filing[i]) ==
                                            letterOf(filing[i - 1]))
                                ? null
                                : letterOf(filing[i]),
                          ),
                        ),
                        if (indexed)
                          Positioned(
                            top: 8,
                            bottom: 8,
                            right: 0,
                            child: AlphabetIndex(
                              letters: letters,
                              onLetter: _letters.goTo,
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

  AppBar _normalBar(List<UserProgression> all) => AppBar(
    title: const Text('My Changes'),
    actions: [
      TextButton(
        key: const ValueKey('import'),
        onPressed: _import,
        child: const Text('Import'),
      ),
      if (all.isNotEmpty)
        TextButton(onPressed: _startSelecting, child: const Text('Select')),
    ],
  );

  AppBar _selectionBar(List<UserProgression> all) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Cancel',
      onPressed: _stopSelecting,
    ),
    title: Text('${_selected.length} selected'),
    actions: [
      TextButton(
        onPressed: () => setState(() {
          if (_selected.length == all.length) {
            _selected.clear();
          } else {
            _selected.addAll(all.map((p) => p.id));
          }
        }),
        child: Text(
          _selected.length == all.length && all.isNotEmpty
              ? 'Select none'
              : 'Select all',
        ),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete selected',
        onPressed: _selected.isEmpty ? null : _deleteSelected,
      ),
    ],
  );

  /// What the strip files [progression] under: its title, or whoever wrote
  /// it, depending on which way round the list is.
  String _fileUnder(UserProgression progression) => _order == TuneOrder.composer
      ? filedUnder(progression.composer)
      : progression.displayTitle;

  /// Deleting one everywhere: the progression itself, and any star,
  /// setlist place or line in the recently-played list pointing at it.
  Future<void> _delete(UserProgression progression) async {
    await widget.progressions.delete(progression.id);
    await widget.library.forget([TuneRef.mine(progression.id)]);
  }

  Widget _tile(UserProgression progression, {String? letter}) {
    final tune = progression.toTune();
    final style = progression.style;
    final key =
        'Key of ${tune.keyLabelBy(widget.settings.instrument.semitones)}';
    if (_selecting) {
      return CheckboxListTile(
        value: _selected.contains(progression.id),
        onChanged: (_) => _toggle(progression.id),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(progression.displayTitle),
        subtitle: DetailLine([key, '${tune.barCount} bars']),
      );
    }
    final tile = ListTile(
      key: letter == null ? null : _letters.keyFor(letter),
      // A long press starts choosing several to delete.
      onLongPress: () => _startSelecting(progression.id),
      leading: StarButton(
        library: widget.library,
        tune: TuneRef.mine(progression.id),
        title: progression.displayTitle,
      ),
      title: Text(progression.displayTitle),
      subtitle: DetailLine([
        // Only while the list is sorted by it: otherwise the line is
        // already long enough, and most of your own have nobody named.
        if (_order == TuneOrder.composer && progression.composer != null)
          indexName(progression.composer),
        key,
        '${tune.barCount} bars',
        '${style.drums.label} drums, ${style.bass.label.toLowerCase()} '
            'bass, ${style.piano.label.toLowerCase()}',
      ]),
      onTap: () {
        widget.library.justPlayed(TuneRef.mine(progression.id));
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PracticeScreen(
              takes: widget.takes,
              partStore: widget.partStore,
              recordingStore: widget.recordingStore,
              tune: tune,
              player: widget.player,
              settings: widget.settings,
              library: widget.library,
              progression: progression,
              progressions: widget.progressions,
            ),
          ),
        );
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit ${progression.displayTitle}',
            onPressed: () => _openEditor(progression),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete ${progression.displayTitle}',
            onPressed: () async {
              if (await confirmDelete(context, progression)) {
                await _delete(progression);
              }
            },
          ),
        ],
      ),
    );
    // Swiping left deletes too, after the same question.
    return Dismissible(
      key: ValueKey('progression-${progression.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(context, progression),
      onDismissed: (_) => _delete(progression),
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: tile,
    );
  }
}

/// Before the first progression: what this tab is for, with a ii–V–I
/// pencilled into four empty bars, the way you'd sketch one out.
class _Empty extends StatelessWidget {
  const _Empty({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 260,
                height: 64,
                child: Row(
                  children: [
                    // The last bar a simile mark: "play the last bar again".
                    for (final chord in ['Dm7', 'G7', 'CΔ7', '%'])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cardColour(scheme),
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            chord,
                            style: handLettered(
                              TextStyle(fontSize: 24, color: scheme.tertiary),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Start your own book',
              style: handLettered(theme.textTheme.headlineSmall),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Write out the changes to a tune you\'re shedding, a '
              'turnaround that trips you up, or a vamp to blow over.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const ValueKey('import-empty'),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Import from iReal Pro'),
              onPressed: onImport,
            ),
          ],
        ),
      ),
    );
  }
}
