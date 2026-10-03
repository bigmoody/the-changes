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

class _SideBySideScreenState extends State<SideBySideScreen> {
  var _chosen = comparisons.first;

  /// The key the table is written in, as the player reads it.
  ///
  /// Each comparison carries a key it is best read in, and that is where
  /// it opens. But the reason to read three blues against each other is
  /// usually that you are about to play one, and the key you are about to
  /// play it in is not always the key it reads best in. So it moves.
  ///
  /// Written rather than sounding, which is what every other key control
  /// in the app means and what a player wants: the point of the table is
  /// to be read. A B♭ player reading F here is reading the F they would
  /// read on a stand, and the band underneath plays the E♭ that makes.
  late String _key = _asRead(_chosen.key);

  /// The written name of a key that sounds as [concert].
  String _asRead(String concert) =>
      majorKeyNames[(tonicOf(concert) + widget.settings.instrument.semitones) %
          12];

  /// Whether the table is where this comparison was meant to be read.
  bool get _inItsOwnKey => _key == _asRead(_chosen.key);

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
        tune.transposed(
          (semitonesInto(tune, _key) - widget.settings.instrument.semitones) %
              12,
        ),
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
                        // made about.
                        _key = _asRead(comparison.key);
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final key in majorKeyNames)
                  ChoiceChip(
                    key: ValueKey('key-$key'),
                    label: Text(key),
                    selected: _key == key,
                    onSelected: (_) {
                      unawaited(_stop());
                      setState(() => _key = key);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'All in $_key · ${barsThatDiffer(rows)} of '
              '${rows.length} bars differ · play one to hear it through',
              key: const ValueKey('summary'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          // Only where the table is still in the key the note is about.
          // It says why this comparison reads best in that key, and over
          // a table somebody has moved somewhere else it would be
          // answering a question nobody asked any more.
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
