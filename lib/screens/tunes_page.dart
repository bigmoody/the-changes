import 'package:flutter/material.dart';

import '../audio/practice_player.dart';
import '../library/find_tune.dart';
import '../library/library_store.dart';
import '../music/tune.dart';
import '../music/tune_library.dart';
import '../practice/take_store.dart';
import '../practice/part_store.dart';
import '../practice/recording_store.dart';
import '../settings/app_settings.dart';
import '../settings/progression_store.dart';
import 'alphabet_index.dart';
import 'genre_filter.dart';
import 'setlists_screen.dart';
import 'starting_order_screen.dart';
import 'star_button.dart';
import 'tuner_screen.dart';
import '../library/something_to_play.dart';
import 'tuning_fork_icon.dart';
import '../theme.dart';
import 'note_ink.dart';

/// The Tunes tab: the standards and practice progressions, to search, star,
/// filter by genre and put in order.
class TunesPage extends StatefulWidget {
  const TunesPage({
    super.key,
    required this.player,
    required this.settings,
    required this.library,
    required this.progressions,
    this.takes,
    this.partStore,
    this.recordingStore,
    this.audioError,
  });

  final PracticePlayer player;
  final AppSettings settings;
  final LibraryStore library;
  final ProgressionStore progressions;
  final TakeStore? takes;
  final PartStore? partStore;

  /// Where recordings of real players are kept.
  final RecordingStore? recordingStore;

  /// Set when the audio engine failed to start, so we can tell the user.
  final String? audioError;

  @override
  State<TunesPage> createState() => _TunesPageState();
}

class _TunesPageState extends State<TunesPage> {
  String _query = '';
  Genre? _genre;
  var _order = TuneOrder.title;
  var _starredOnly = false;
  final _scroll = ScrollController();
  late final _letters = LetterIndex(_scroll);

  late final _deps = LibraryContext(
    player: widget.player,
    settings: widget.settings,
    library: widget.library,
    progressions: widget.progressions,
    takes: widget.takes,
    partStore: widget.partStore,
    recordingStore: widget.recordingStore,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A new filter starts from the top of what it found.
  void _filter(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool _matches(Tune tune) {
    if (_genre != null && !tune.genres.contains(_genre)) return false;
    if (_starredOnly && !widget.library.isFavourite(TuneRef.of(tune))) {
      return false;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      tune.title,
      tune.composer ?? '',
      tune.key,
      tune.description,
    ].any((text) => text.toLowerCase().contains(query));
  }

  /// The recently-played list is a shortcut back to what you were working
  /// on, so it only makes sense when nothing is being searched or filtered.
  bool get _showRecent =>
      _query.trim().isEmpty && _genre == null && !_starredOnly;

  /// Picks a tune, a key, a feel and a tempo, and goes straight to it
  /// counting in.
  ///
  /// Straight to it on purpose. Showing what it picked and waiting to be
  /// told to go would hand back the decision this exists to take away,
  /// and somebody who needed the button is exactly the person that stops.
  /// What it chose is said on the way past, in a line that can be ignored.
  void _justPlaySomething(BuildContext context) {
    final picked = somethingToPlay(
      [...standards, ...widget.progressions.all.map((p) => p.toTune())],
      starred: {
        for (final ref in widget.library.favourites)
          if (ref.value.startsWith('s:')) ref.value.substring(2),
      },
      recent: [
        for (final played in widget.library.played)
          if (played.tune.value.startsWith('s:'))
            played.tune.value.substring(2),
      ],
    );
    if (picked == null) return;

    // A feel this tune has already been given stays: somebody who has
    // said they play Oleo as a bossa has decided, and a random suggestion
    // does not get to argue with a decision.
    final ref = TuneRef.of(picked.tune);
    final chosen = widget.library.styleFor(ref);
    var tune = picked.tune.transposed(picked.semitones);
    if (chosen == null && picked.style != null) {
      tune = tune.withStyle(picked.style!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('just-played'),
        content: Text(describe(picked)),
        duration: const Duration(seconds: 4),
      ),
    );
    _deps.play(context, FoundTune(tune), startAt: picked.tempo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Changes'),
        actions: [
          IconButton(
            key: const ValueKey('just-play'),
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Just Play Something',
            onPressed: () => _justPlaySomething(context),
          ),
          IconButton(
            key: const ValueKey('where-to-start'),
            icon: const Icon(Icons.signpost_outlined),
            tooltip: 'Where to Start',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StartingOrderScreen(deps: _deps),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('setlists'),
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Setlists',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SetlistsScreen(deps: _deps),
              ),
            ),
          ),
          IconButton(
            icon: const TuningForkIcon(),
            tooltip: 'Tuner',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TunerScreen(
                  player: widget.player,
                  settings: widget.settings,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.settings,
          widget.library,
          widget.progressions,
        ]),
        builder: (context, _) {
          final foundStandards = sortedTunes(standards.where(_matches), _order);
          final foundDrills = sortedTunes(
            practiceProgressions.where(_matches),
            _order,
          );
          final instrument = widget.settings.instrument;
          // The strip only makes sense down a list in an order with an
          // alphabet to it, and only earns its place on a long one. Which
          // alphabet depends: the titles, or the composers' surnames.
          final filing = [for (final tune in foundStandards) _fileUnder(tune)];
          final letters = _order.hasAnAlphabet && filing.length > 12
              ? lettersIn(filing)
              : const <String>[];
          final indexed = letters.length > 1;
          if (indexed) _letters.follow(filing);
          var lastLetter = '';
          final recent = _showRecent
              ? findTunes(
                  widget.library.played.map((entry) => entry.tune),
                  progressions: widget.progressions,
                ).take(6).toList()
              : const <FoundTune>[];
          return Column(
            children: [
              if (widget.audioError != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Audio could not start: ${widget.audioError}'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search tunes, composers or keys',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => _filter(() => _query = value),
                ),
              ),
              TuneListControls(
                starredOnly: _starredOnly,
                onStarred: (on) => _filter(() => _starredOnly = on),
                order: _order,
                onOrder: (order) => _filter(() => _order = order),
              ),
              GenreFilter(
                available: GenreFilter.of([
                  ...standards,
                  ...practiceProgressions,
                ]),
                selected: _genre,
                onChanged: (genre) => _filter(() => _genre = genre),
              ),
              Expanded(
                child: Stack(
                  // The letter beside a thumb on the strip reaches out over
                  // the list.
                  clipBehavior: Clip.none,
                  children: [
                    ListView(
                      key: const ValueKey('tune-list'),
                      controller: _scroll,
                      // Room down the side for the strip, so it never sits on
                      // top of a chevron.
                      padding: EdgeInsets.only(
                        right: indexed ? AlphabetIndex.width : 0,
                      ),
                      children: [
                        // Only for a library nobody has played yet: an
                        // alphabetical list of three hundred tunes is no
                        // use at all if you do not know which of them you
                        // could get through tonight. Once anything has
                        // been played it goes, and the signpost in the bar
                        // is where it lives from then on.
                        if (recent.isEmpty && _showRecent)
                          _StartHereCard(deps: _deps),
                        if (recent.isNotEmpty) ...[
                          SectionHeader(
                            'Recently Played',
                            action: TextButton(
                              onPressed: widget.library.clearPlayed,
                              child: const Text('Clear'),
                            ),
                          ),
                          for (final found in recent) _recentTile(found),
                        ],
                        if (foundStandards.isNotEmpty) ...[
                          SectionHeader(
                            instrument == ChartInstrument.concert
                                ? 'Standards (${foundStandards.length})'
                                : 'Standards (${foundStandards.length}) · keys '
                                      'for ${instrument.name}',
                          ),
                          for (final tune in foundStandards)
                            _tile(
                              tune,
                              // The first tune under each letter is what the
                              // strip scrolls to.
                              letter:
                                  !indexed ||
                                      letterOf(_fileUnder(tune)) == lastLetter
                                  ? null
                                  : lastLetter = letterOf(_fileUnder(tune)),
                            ),
                        ],
                        if (foundDrills.isNotEmpty) ...[
                          const SectionHeader('Practice Progressions'),
                          for (final tune in foundDrills) _tile(tune),
                        ],
                        if (foundStandards.isEmpty && foundDrills.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                _starredOnly
                                    ? 'Nothing starred yet'
                                    : 'Not in the book',
                                style:
                                    handLettered(
                                      Theme.of(context).textTheme.headlineSmall,
                                    ).copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Text(
                            'Charts show chord changes only. Standards are played '
                            'in many versions; these follow common jam-session '
                            'changes.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
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
          );
        },
      ),
    );
  }

  /// What the strip files [tune] under: its title, or whoever wrote it,
  /// depending on which way round the list is.
  String _fileUnder(Tune tune) =>
      _order == TuneOrder.composer ? filedUnder(tune.composer) : tune.title;

  /// Just enough to choose by: who wrote it, what it is, and its key.
  Widget _tile(Tune tune, {String? letter}) {
    final details = [
      // In composer order the surname comes first, so the list reads down
      // the way it's sorted.
      ?(_order == TuneOrder.composer
          ? indexName(tune.composer)
          : tune.composer),
      if (tune.description.isNotEmpty) tune.description,
      'Key of ${tune.keyLabelBy(widget.settings.instrument.semitones)}',
      if (_order == TuneOrder.tempo) '${tune.defaultTempo} bpm',
      // "Latin" for the bossa groove (Tunisia isn't a bossa); others by name.
      if (tune.feel != Feel.swing)
        tune.feel == Feel.bossa ? Genre.latin.label : tune.feel.label,
    ];
    final ref = TuneRef.of(tune);
    return ListTile(
      key: letter == null ? null : _letters.keyFor(letter),
      leading: StarButton(
        library: widget.library,
        tune: ref,
        title: tune.title,
      ),
      title: Text(tune.title),
      subtitle: DetailLine(details),
      trailing: const Icon(Icons.chevron_right),
      // A long press puts it on a setlist without opening it, which is how
      // you'd build one: straight down the list.
      onLongPress: () =>
          showAddToSetlist(context, widget.library, ref, tune.title),
      onTap: () => _deps.play(context, FoundTune(tune)),
    );
  }

  /// A tune played lately, which may be one of the player's own.
  Widget _recentTile(FoundTune found) => ListTile(
    key: ValueKey('recent-${found.tune.title}'),
    leading: Icon(
      found.isMine ? Icons.edit_note : Icons.history,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    title: Text(found.tune.title),
    subtitle: KeyText(
      'Key of ${found.tune.keyLabelBy(widget.settings.instrument.semitones)}',
      name: found.tune.keyLabelBy(widget.settings.instrument.semitones),
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _deps.play(context, found),
  );
}

/// The row under the search box: starred only, and what order the list is
/// in. My Changes uses the same one, so the two lists behave alike.
class TuneListControls extends StatelessWidget {
  const TuneListControls({
    super.key,
    required this.starredOnly,
    required this.onStarred,
    required this.order,
    required this.onOrder,
  });

  final bool starredOnly;
  final ValueChanged<bool> onStarred;
  final TuneOrder order;
  final ValueChanged<TuneOrder> onOrder;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
    // Room apart rather than a Spacer between: turn the text size up and
    // the chip and the sort button are together wider than the phone, and
    // each has to be free to give way.
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FilterChip(
            key: const ValueKey('starred-only'),
            selected: starredOnly,
            onSelected: onStarred,
            avatar: Icon(
              starredOnly ? Icons.star : Icons.star_border,
              size: 18,
              color: starredOnly
                  ? Theme.of(context).colorScheme.tertiary
                  : null,
            ),
            label: const Text('Starred', overflow: TextOverflow.ellipsis),
          ),
        ),
        Flexible(
          child: PopupMenuButton<TuneOrder>(
            key: const ValueKey('sort'),
            initialValue: order,
            onSelected: onOrder,
            tooltip: 'Sort',
            itemBuilder: (context) => [
              for (final option in TuneOrder.values)
                PopupMenuItem(value: option, child: Text(option.label)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'By ${order.label}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A small coloured heading over part of a list.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.action});

  final String text;

  /// A button at the end of the heading, e.g. "Select".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, action == null ? 16 : 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// The way in to the path, shown at the top of a library nobody has played
/// yet, the one moment when "which of these do I even start with?" is the
/// only question there is.
class _StartHereCard extends StatelessWidget {
  const _StartHereCard({required this.deps});

  final LibraryContext deps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: scheme.tertiaryContainer,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('start-here-card'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StartingOrderScreen(deps: deps),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.signpost_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where to Start',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Twenty-one of these in an order worth learning '
                        'them in, and what each one teaches',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
