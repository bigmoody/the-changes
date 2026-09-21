// Side by side: two or three versions of a form, bar against bar.
//
// The table is the whole feature. Reading one chart at a time you cannot
// see that every blues is on the IV at bar five; put three in columns and
// you cannot miss it. The bars where they disagree are tinted, so the
// shape of the difference is visible before a single symbol is read.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
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
  int? _playing;

  /// The versions, all moved into the comparison's key.
  List<Tune> get _tunes => [
    for (final title in _chosen.titles)
      if (standards.where((t) => t.title == title).firstOrNull case final tune?)
        tune.transposed(semitonesInto(tune, _chosen.key)),
  ];

  /// Plays one bar from each version in turn, so the difference is heard
  /// as well as read: bar 8 as F7, then as D7, then as A♭m7 D♭7.
  Future<void> _playRow(List<Tune> tunes, int bar) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    setState(() => _playing = bar);
    const chordLength = 0.62;
    const between = 0.3;
    final notes = <SnippetNote>[];
    var at = 0.0;
    for (final tune in tunes) {
      if (bar - 1 >= tune.barCount) continue;
      final slots = tune.bars[bar - 1];
      for (final slot in slots) {
        // A bar with two chords in it gets half each, so a bar is a bar
        // however much is crammed into it.
        final length = chordLength / slots.length;
        final chord = slot.chord;
        notes.add((
          pitch: 40 + (chord.root - 40) % 12,
          start: at,
          length: length,
          velocity: 0.5,
          bass: true,
        ));
        for (final interval in chord.quality.intervals) {
          notes.add((
            pitch: 60 + (chord.root + interval - 60) % 12,
            start: at,
            length: length * 0.95,
            velocity: 0.62,
            bass: false,
          ));
        }
        at += length;
      }
      at += between;
    }
    if (notes.isEmpty) return;
    await widget.player.playSnippet(renderSnippet(bank, notes));
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tunes = _tunes;
    final rows = alignBars(tunes);
    return Scaffold(
      appBar: AppBar(title: const Text('Side By Side')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'The same form, written two or three ways. The bars they '
              'disagree on are marked; tap any bar to hear it in each '
              'version, one after another.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final comparison in comparisons)
                  ChoiceChip(
                    key: ValueKey('set-${comparison.name}'),
                    label: Text(comparison.name),
                    selected: _chosen == comparison,
                    onSelected: (_) => setState(() {
                      _chosen = comparison;
                      _playing = null;
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _chosen.about,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'All in ${_chosen.key}, so the columns can be read across. '
              '${barsThatDiffer(rows)} of ${rows.length} bars differ.',
              key: const ValueKey('summary'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          _Heading(tunes: tunes),
          for (final row in rows)
            _Row(
              row: row,
              playing: _playing == row.bar,
              onTap: () => _playRow(tunes, row.bar),
            ),
        ],
      ),
    );
  }
}

/// The version names across the top, over the columns they label.
class _Heading extends StatelessWidget {
  const _Heading({required this.tunes});

  final List<Tune> tunes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: _Row.numberWidth),
          for (final tune in tunes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  tune.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
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
  const _Row({required this.row, required this.playing, required this.onTap});

  static const numberWidth = 26.0;

  final BarRow row;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        // A bar the versions agree on is plain paper; one they don't is
        // tinted, so the shape of the difference reads before the chords.
        color: playing
            ? scheme.tertiaryContainer
            : row.differs
            ? scheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: ValueKey('bar-row-${row.bar}'),
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
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
                for (final cell in row.cells)
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
                              color: cell.isEmpty
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
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
