// The guitar chord dictionary: pick a chord, see every way to play it up
// the neck, and hear any of them.
//
// The shapes aren't a stored table — the fretboard is searched for them —
// so every chord the app knows has its shapes, in every key.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/guitar_chord_shapes.dart';
import '../music/guitar_voicing.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chord_diagram.dart';
import 'chord_tones_reference_screen.dart' show ChordTonesReferenceScreen;

class GuitarChordsScreen extends StatefulWidget {
  const GuitarChordsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<GuitarChordsScreen> createState() => _GuitarChordsScreenState();
}

class _GuitarChordsScreenState extends State<GuitarChordsScreen> {
  String _root = 'C';
  String _quality = '';

  /// Shapes with another chord tone in the bass, as well as the root.
  var _inversions = false;

  Chord get _chord => Chord.parse('$_root$_quality');

  List<GuitarVoicing> get _shapes =>
      allGuitarShapes(_chord, rootInBass: !_inversions);

  Future<void> _play(GuitarVoicing shape) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    // Strummed, low string first.
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final (i, pitch) in shape.pitches.indexed)
          (
            pitch: pitch,
            start: i * 0.035,
            length: 2.2 - i * 0.035,
            velocity: 0.8,
            bass: false,
          ),
      ], guitar: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chord = _chord;
    final shapes = _shapes;
    return Scaffold(
      appBar: AppBar(title: const Text('Guitar Chords')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Chips(
            values: ChordTonesReferenceScreen.roots,
            label: (root) => root,
            id: (root) => 'root-$root',
            selected: (root) => root == _root,
            onPick: (root) => setState(() => _root = root),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final quality in chordQualities)
                  ChoiceChip(
                    key: ValueKey('quality-${quality.symbols.first}'),
                    label: Text(
                      quality.symbols.first.isEmpty
                          ? 'major'
                          : prettyQuality(quality.symbols.first),
                    ),
                    showCheckmark: false,
                    selected: _quality == quality.symbols.first,
                    onSelected: (_) =>
                        setState(() => _quality = quality.symbols.first),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: chord.display,
                          style: handLettered(theme.textTheme.headlineSmall),
                        ),
                        TextSpan(
                          text: shapes.length == 1
                              ? '  1 way to play it'
                              : '  ${shapes.length} ways to play it',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilterChip(
                  key: const ValueKey('inversions'),
                  label: const Text('Inversions'),
                  tooltip: 'Shapes with another note of the chord in the bass',
                  selected: _inversions,
                  onSelected: (on) => setState(() => _inversions = on),
                ),
              ],
            ),
          ),
          if (shapes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No shapes a hand can reach')),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Three to a row on a phone, more on a wider screen.
                final columns = (constraints.maxWidth / 130).floor().clamp(
                  3,
                  6,
                );
                final width = constraints.maxWidth / columns;
                return Wrap(
                  children: [
                    for (final (i, shape) in shapes.indexed)
                      SizedBox(
                        width: width,
                        child: _Shape(
                          key: ValueKey('shape-$i'),
                          chord: chord,
                          shape: shape,
                          onPlay: () => _play(shape),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One shape: its grid, where it sits, and what's in the bass.
class _Shape extends StatelessWidget {
  const _Shape({
    super.key,
    required this.chord,
    required this.shape,
    required this.onPlay,
  });

  final Chord chord;
  final GuitarVoicing shape;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bass = bassDegreeOf(chord, shape);
    final where = shape.position <= 1 ? 'Open' : 'Fret ${shape.position}';
    return Semantics(
      button: true,
      label:
          '${chord.display} at ${where.toLowerCase()}, '
          '${bass.toLowerCase()} in the bass: '
          '${shape.frets.map((f) => f == null ? 'muted' : 'fret $f').join(', ')}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: GuitarDiagram.aspect,
                child: GuitarDiagram(chord: chord, voicing: shape),
              ),
              const SizedBox(height: 4),
              // The frets string by string, low to high, as guitarists
              // write them down.
              Text(
                shape.frets.map((f) => f?.toString() ?? 'x').join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(where, style: theme.textTheme.labelMedium),
              Text(
                bass == 'Root' ? '' : '$bass in the bass',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrolling row of choices.
class _Chips<T> extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.label,
    required this.id,
    required this.selected,
    required this.onPick,
  });

  final List<T> values;
  final String Function(T) label;
  final String Function(T) id;
  final bool Function(T) selected;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: ValueKey(id(value)),
              label: Text(label(value)),
              showCheckmark: false,
              selected: selected(value),
              onSelected: (_) => onPick(value),
            ),
          ),
      ],
    ),
  );
}
