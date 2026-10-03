// Side by side: two or three versions of a form, bar against bar.
//
// The table is the whole feature. Reading one chart at a time you cannot
// see that every blues is on the IV at bar five; put three in columns and
// you cannot miss it. The bars where they disagree are tinted, so the
// shape of the difference is visible before a single symbol is read.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../settings/key_colours.dart' show majorKeyNames;
import '../music/arrangement.dart';
import '../music/loop_range.dart';
import '../music/side_by_side.dart';
import '../music/tune.dart';
import '../music/tune_library.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

class SideBySideScreen extends StatefulWidget {
  const SideBySideScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<SideBySideScreen> createState() => _SideBySideScreenState();
}

/// "An E♭ instrument", "a B♭ instrument": by how the letter is said, not
/// by how it is spelled. E and F start with a vowel sound; B and C do not.
String _article(String symbol) => 'AEF'.contains(symbol[0]) ? 'an' : 'a';

class _SideBySideScreenState extends State<SideBySideScreen> {
  var _chosen = comparisons.first;

  /// The key the music is in, as everybody in the room would name it.
  ///
  /// Each comparison carries the key it reads best in, and that is where
  /// it opens. But the reason to read three blues against each other is
  /// usually that you are about to play one, and the key a set reads
  /// best in is not always the key you are about to play it in. So it
  /// moves, through all twelve.
  ///
  /// Kept apart from the edition on purpose, and labelled, because the
  /// two are easily confused and do completely different things: this
  /// one changes what the band plays, and the edition changes only whose
  /// page it is written on. Left unlabelled side by side, both of them
  /// just look like the chords changing letter.
  late String _concert = _chosen.key;

  /// Which instrument's edition is on the page: C, B♭, E♭ or F.
  ///
  /// The four transposing groups, the way a fake book is printed in three
  /// or four editions of the same music. It opens on the player's own
  /// instrument and can be moved to any of the others, because the other
  /// reason to look at a table like this is to put it in front of
  /// somebody whose horn is not the one you play.
  late ChartInstrument _reading = widget.settings.instrument;

  /// Whether the table is still in the key this comparison was built for.
  bool get _inItsOwnKey => _concert == _chosen.key;

  /// The key on the page: the concert key as [_reading] writes it.
  String get _key =>
      majorKeyNames[(tonicOf(_concert) + _reading.semitones) % 12];

  /// Whether the note about the key is open. Shut to start with: the
  /// table is what the screen is for, and an answer nobody asked for
  /// would push the first bars off the bottom of the phone.
  var _whyOpen = false;

  /// Which column is playing, and where it has got to. A version is played
  /// whole, from the top, because that is the only way any of this is
  /// audible: a bar lifted out of three tunes and stitched together is not
  /// music, and a tritone sub you cannot hear resolve is not anything.
  int? _playingColumn;
  int? _playingBar;
  Timer? _ticker;

  /// The versions as they are read, all moved into [_key].
  List<Tune> get _tunes => [
    for (final title in _chosen.titles)
      if (standards.where((t) => t.title == title).firstOrNull case final tune?)
        tune.transposed(semitonesInto(tune, _key)),
  ];

  /// The same versions as they sound, which is what the band is given.
  ///
  /// A table written for a B♭ player and handed to the band as written
  /// would play a tone above what it says, which is the one mistake a
  /// transposing instrument makes everybody make at least once.
  List<Tune> get _sounding => [
    for (final title in _chosen.titles)
      if (standards.where((t) => t.title == title).firstOrNull case final tune?)
        tune.transposed(semitonesInto(tune, _concert)),
  ];

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(widget.player.stop());
    super.dispose();
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    if (mounted) {
      setState(() {
        _playingColumn = null;
        _playingBar = null;
      });
    }
    await widget.player.stop();
  }

  /// Plays one version through, once, with the band.
  ///
  /// [tunes] is what sounds, not what is on the page: see [_sounding].
  Future<void> _play(List<Tune> tunes, int column) async {
    if (_playingColumn == column) {
      await _stop();
      return;
    }
    await _stop();
    final tune = tunes[column];
    setState(() {
      _playingColumn = column;
      _playingBar = null;
    });
    try {
      await widget.player.start(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: tune.defaultTempo,
          comping: widget.settings.comping,
          seed: math.Random().nextInt(1 << 31),
          // Once through and out: this is for hearing the changes go by,
          // not for playing over.
          arrangement: const Arrangement(choruses: 1),
        ),
      );
    } catch (e) {
      debugPrint('Could not play the comparison: $e');
      await _stop();
      return;
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final at = widget.player.position();
      if (!mounted || _playingColumn != column) return;
      // Past the end of the one chorus: it has said its piece.
      if (at != null && (at.chorus ?? 0) > 0) {
        unawaited(_stop());
        return;
      }
      final beat = at?.tuneBeat;
      final bar = beat == null ? null : beat ~/ tune.beatsPerBar + 1;
      if (bar != _playingBar) setState(() => _playingBar = bar);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tunes = _tunes;
    final rows = alignBars(tunes);
    return Scaffold(
      appBar: AppBar(title: const Text('Side by Side')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final comparison in comparisons)
                  ChoiceChip(
                    key: ValueKey('set-${comparison.name}'),
                    label: Text(comparison.name),
                    selected: _chosen == comparison,
                    onSelected: (_) {
                      unawaited(_stop());
                      setState(() {
                        _chosen = comparison;
                        // Back to the key this one reads best in. Keeping
                        // the last key would carry a choice made about
                        // one set of tunes onto another it was never
                        // made about. The edition stays: that is about
                        // who is reading, not about which tunes.
                        _concert = comparison.key;
                        _whyOpen = false;
                      });
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              _chosen.about,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Text('In the Key Of', style: theme.textTheme.labelMedium),
                const SizedBox(width: 10),
                _KeyMenu(
                  chosen: _concert,
                  onPick: (key) {
                    unawaited(_stop());
                    setState(() => _concert = key);
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'what the band plays',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Which edition is on the page. The four transposing groups,
          // the way a fake book is printed as a C book, a B♭ book and an
          // E♭ book of the same music: the table is the same comparison
          // whichever one you read, and the band plays the same notes.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                // Short, because four chips and a label is all the row
                // holds: the summary under it says in words what this
                // one has done, which is where the explaining belongs.
                Text('For', style: theme.textTheme.labelMedium),
                const SizedBox(width: 10),
                for (final instrument in ChartInstrument.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('reads-${instrument.symbol}'),
                      label: Text(instrument.symbol),
                      selected: _reading == instrument,
                      onSelected: (_) => setState(() => _reading = instrument),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '${_reading == ChartInstrument.concert ? 'All in $_key' : 'In $_key, which is the $_concert '
                        '${_article(_reading.symbol)} '
                        '${_reading.symbol} instrument reads'} · '
              '${barsThatDiffer(rows)} of '
              '${rows.length} bars differ · play one to hear it through',
              key: const ValueKey('summary'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          // Why this set is in the key it is in, where there is anything
          // to say about it.
          // Only where the table is still in the key the note is about:
          // over a set somebody has moved somewhere else it would be
          // answering a question nobody is asking any more.
          if (_inItsOwnKey)
            if (whyThisKey(_chosen.key) case final note?)
              _WhyTheKey(
                musicKey: _chosen.key,
                note: note,
                open: _whyOpen,
                onToggle: () => setState(() => _whyOpen = !_whyOpen),
              ),
          _Heading(
            tunes: tunes,
            playing: _playingColumn,
            onPlay: (column) => _play(_sounding, column),
          ),
          for (final row in rows)
            _Row(row: row, playingColumn: _playingColumn, at: _playingBar),
        ],
      ),
    );
  }
}

/// The twelve keys, as a menu rather than a row of chips.
///
/// A menu because twelve chips is three rows of them on a phone, and the
/// table has to be on the screen when the screen opens: that is the whole
/// of what this page is for. A menu shows all twelve at once and costs
/// one line.
class _KeyMenu extends StatelessWidget {
  const _KeyMenu({required this.chosen, required this.onPick});

  final String chosen;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      key: const ValueKey('concert-key'),
      initialValue: chosen,
      tooltip: 'The key the music is in',
      onSelected: onPick,
      itemBuilder: (_) => [
        for (final key in majorKeyNames)
          PopupMenuItem(
            key: ValueKey('key-$key'),
            value: key,
            child: Text(key),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(chosen, style: theme.textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A one-line question above the table, and the answer when it is asked
/// for.
///
/// Every set here is in a key somebody chose for a reason, and "why F?"
/// is the question the summary line provokes. Folded away by default so
/// it costs one line rather than a paragraph; the table has been pushed
/// off the screen by explanation before now.
class _WhyTheKey extends StatelessWidget {
  const _WhyTheKey({
    required this.musicKey,
    required this.note,
    required this.open,
    required this.onToggle,
  });

  final String musicKey;
  final String note;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const ValueKey('why-the-key'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Why $musicKey?',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colorScheme.outlineVariant,
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              note,
              key: const ValueKey('why-the-key-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The version names across the top, each with a way to hear it.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.tunes,
    required this.playing,
    required this.onPlay,
  });

  final List<Tune> tunes;
  final int? playing;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: _Row.numberWidth),
          for (final (i, tune) in tunes.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    Text(
                      tune.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                    IconButton(
                      key: ValueKey('play-$i'),
                      visualDensity: VisualDensity.compact,
                      tooltip: playing == i
                          ? 'Stop'
                          : 'Play ${tune.title} through',
                      icon: Icon(
                        playing == i
                            ? Icons.stop_circle
                            : Icons.play_circle_outline,
                        color: playing == i
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => onPlay(i),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One bar, across the versions.
class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.playingColumn,
    required this.at,
  });

  static const numberWidth = 26.0;

  final BarRow row;

  /// Which column is playing, and which bar it has reached.
  final int? playingColumn;
  final int? at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        // A bar the versions agree on is plain paper; one they don't is
        // tinted, so the shape of the difference reads before the chords.
        // The bar sounding now is in pencil red, over the top of either.
        color: at == row.bar
            ? scheme.tertiaryContainer
            : row.differs
            ? scheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          key: ValueKey('bar-row-${row.bar}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: numberWidth,
                  child: Text(
                    '${row.bar}',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: row.differs
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
                for (final (i, cell) in row.cells.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          cell.isEmpty ? '·' : handSymbol(cell),
                          textScaler: TextScaler.noScaling,
                          semanticsLabel: cell.isEmpty
                              ? 'no bar ${row.bar}'
                              : cell,
                          style: handLettered(
                            TextStyle(
                              fontSize: 19,
                              height: 1,
                              // While one version is playing its column
                              // stays black and the others step back, so
                              // it is plain which one you are hearing.
                              color: cell.isEmpty
                                  ? scheme.onSurfaceVariant
                                  : playingColumn == null || playingColumn == i
                                  ? scheme.onSurface
                                  : scheme.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
