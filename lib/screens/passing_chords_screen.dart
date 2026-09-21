// Between the chords: the same changes, with one more chord in them.
//
// Two rows, one above the other, and the only difference is the chord in
// pencil red. Everything else on the screen exists to make that
// comparison possible: the same key, the same tempo, the same two
// buttons, so the one thing that changed is the one thing you hear.
//
// The bass line is written out under each row because that is where the
// argument actually is. A passing chord is not squeezed in between two
// others, it is built on a note the bass was going to walk over anyway,
// and seeing C C♯ D under the chords says that faster than a paragraph.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/passing_chords.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

/// The keys offered. Enough to show the spelling holds up, not so many
/// that the row scrolls.
const _keys = ['C', 'F', 'B♭', 'E♭', 'G'];

class PassingChordsScreen extends StatefulWidget {
  const PassingChordsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<PassingChordsScreen> createState() => _PassingChordsScreenState();
}

class _PassingChordsScreenState extends State<PassingChordsScreen> {
  var _move = passingMoves.first;
  var _key = 'C';

  List<Chord> get _plain => chordsIn(_move.plain, _key);
  List<Chord> get _filled => chordsIn(_move.filled, _key);

  /// Plays a progression, a bar each, with its root underneath.
  Future<void> _play(List<Chord> chords) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const bar = 0.95;
    final notes = <SnippetNote>[];
    for (final (i, chord) in chords.indexed) {
      notes.add((
        pitch: 36 + (chord.root - 36) % 12,
        start: i * bar,
        length: bar * 0.95,
        velocity: 0.5,
        bass: true,
      ));
      for (final interval in chord.quality.intervals) {
        notes.add((
          pitch: 55 + (chord.root + interval - 55) % 12,
          start: i * bar,
          length: bar * 0.95,
          velocity: 0.55,
          bass: false,
        ));
      }
    }
    await widget.player.playSnippet(renderSnippet(bank, notes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Between The Chords')),
      body: ListView(
        key: const ValueKey('passing-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'A chart gives you the chords that have to be there. '
              'Between any two of them there is usually room for one that '
              'does not, and putting it in is most of what people mean by '
              'reharmonising.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [for (final m in passingMoves) (m.name, m.name)],
            selected: _move.name,
            onPick: (name) => setState(
              () => _move = passingMoves.firstWhere((m) => m.name == name),
            ),
          ),
          _Row(
            key: const ValueKey('row-plain'),
            label: 'As written',
            chords: _plain,
          ),
          _Row(
            key: const ValueKey('row-filled'),
            label: 'With one more',
            chords: _filled,
            marked: _move.at,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _move.about,
              key: const ValueKey('about-move'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (fillsTheGap(_move, _key))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'The bass was going to walk over '
                '${gapNote(_move, _key)} anyway. All the passing chord '
                'does is put a chord on a note that was already on its '
                'way past.',
                key: const ValueKey('fills-the-gap'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('play-plain'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('As Written'),
                    onPressed: () => _play(_plain),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('play-filled'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('With It In'),
                    onPressed: () => _play(_filled),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text('Key', style: theme.textTheme.titleSmall),
          ),
          _Chips(
            values: [for (final key in _keys) (key, key)],
            selected: _key,
            onPick: (key) => setState(() => _key = key),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'A chord climbing a semitone is written sharp, whichever '
              'key you are in: going up from the I to the ii it is a '
              '${chordsIn(const [(0, '6'), (1, 'o7')], _key).last.rootName} '
              'diminished, never the same note spelled flat. Charts get '
              'this wrong often enough to be worth saying.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One progression, written out, with the bass note under each chord.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.label,
    required this.chords,
    this.marked,
  });

  final String label;
  final List<Chord> chords;

  /// Which chord is the one that was added.
  final int? marked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, chord) in chords.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handSymbol(chord.display),
                          textScaler: TextScaler.noScaling,
                          style: handLettered(
                            TextStyle(
                              fontSize: 24,
                              height: 1,
                              color: i == marked
                                  ? scheme.tertiary
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          chord.rootName,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == marked
                                ? scheme.tertiary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of chips that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (value, written) in values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('pick-$value'),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                label: Text(written),
                selected: value == selected,
                onSelected: (_) => onPick(value),
              ),
            ),
        ],
      ),
    ),
  );
}
