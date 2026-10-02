// A scale, run in a shape, in any key.
//
// The scales reference says what a scale is. This is what to do with one.
// Nothing in music goes up a scale for eight notes, so playing one that
// way teaches the fingers the notes and the ears almost nothing; the
// shapes here are what lines are actually made of, and running a scale
// through them is the work that turns it into something you can use.
//
// It goes round the twelve keys like the other rounds in the app,
// because a shape you can only play in C is a shape you cannot play.
//
// The notes are spelled by the scale itself rather than worked out here,
// so what is written is what the scales reference would write, double
// flats and all.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/key_order.dart' show KeyOrder;
import '../music/scale_patterns.dart';
import '../music/scales.dart';
import '../settings/app_settings.dart';
import 'key_round.dart';
import 'stave.dart';

class ScalePatternsScreen extends StatefulWidget {
  const ScalePatternsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ScalePatternsScreen> createState() => _ScalePatternsScreenState();
}

class _ScalePatternsScreenState extends State<ScalePatternsScreen> {
  Mode _mode = modes.first;
  ScalePattern _pattern = scalePatterns.first;
  var _down = false;

  var _order = KeyOrder.fourths;
  late List<int> _moves = _order.moves();
  var _at = 0;
  final _done = <int>{};

  /// The key it starts in, as a pitch class of what you read.
  static const _fromKey = 0;

  int get move => _moves[_at];

  /// How many octaves this shape needs to have room at all.
  int get _octaves => octavesFor(_mode.degrees.length, _pattern);

  /// The key as you read it, spelled the way the scale spells things.
  String get _root => _spelledKey(move);

  String _spelledKey(int by) {
    // C up by the move, then named. The scale respells it again if a
    // double flat would be needed, which is its business and not this
    // screen's.
    const flats = [
      'C',
      'D♭',
      'D',
      'E♭',
      'E',
      'F',
      'G♭',
      'G',
      'A♭',
      'A',
      'B♭',
      'B',
    ];
    const sharps = [
      'C',
      'C♯',
      'D',
      'D♯',
      'E',
      'F',
      'F♯',
      'G',
      'G♯',
      'A',
      'A♯',
      'B',
    ];
    final pitch = (_fromKey + by) % 12;
    // The cycle of fourths runs into flats, so flats unless a sharp key
    // is being asked for directly.
    return _order == KeyOrder.chromatic ? sharps[pitch] : flats[pitch];
  }

  /// The line, as pitches and the names to write them under.
  ({List<int> pitches, List<String> names}) get _line {
    final names = _mode.notesFrom(_root);
    final semitones = _mode.semitones;
    final count = _mode.degrees.length;
    final steps = patternSteps(count, _pattern, octaves: _octaves, down: _down);
    final root = Chord.parse(_mode.spelledRoot(_root)).root;
    // The root between C4 and B4, so the line sits around middle C.
    final tonic = 60 + root % 12;
    return (
      pitches: [
        for (final step in steps)
          tonic + semitones[step % count] + 12 * (step ~/ count),
      ],
      names: [for (final step in steps) names[step % count]],
    );
  }

  /// What the microphone and the speaker deal in: the scale as it sounds,
  /// not as a transposing instrument reads it.
  int get _concertDown => widget.settings.instrument.semitones;

  Future<void> _hear() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final line = _line.pitches;
    if (line.isEmpty) return;
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        runSnippet([for (final pitch in line) pitch - _concertDown]),
      ),
    );
  }

  void _goTo(int index) {
    setState(() {
      _done.add(move);
      _at = index % _moves.length;
    });
  }

  void _setOrder(KeyOrder order) {
    setState(() {
      _order = order;
      _moves = order.moves(seed: DateTime.now().millisecond);
      _at = 0;
      _done.clear();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = _line;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scale Patterns'),
        actions: [KeyOrderButton(order: _order, onPick: _setOrder)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('pattern-scale'),
                    initialValue: _mode.name,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Scale',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final mode in modes)
                        DropdownMenuItem(
                          value: mode.name,
                          child: Text(
                            '${mode.name}  ·  ${mode.family.label}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (name) => setState(
                      () => _mode = modes.firstWhere((m) => m.name == name),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('pattern-shape'),
                    initialValue: _pattern.name,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pattern',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final pattern in scalePatterns)
                        DropdownMenuItem(
                          value: pattern.name,
                          child: Text(pattern.name),
                        ),
                    ],
                    onChanged: (name) => setState(
                      () => _pattern = scalePatterns.firstWhere(
                        (p) => p.name == name,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _pattern.about,
                    key: const ValueKey('pattern-about'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '$_root ${_mode.name}',
                          key: const ValueKey('pattern-key'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${_at + 1} of ${_moves.length}'
                        '${_octaves > 1 ? ' · $_octaves octaves' : ''}',
                        key: const ValueKey('pattern-progress'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: Stave(
                      key: const ValueKey('pattern-line'),
                      notes: lineOnStave([
                        for (final (i, pitch) in line.pitches.indexed)
                          (pitch: pitch, name: line.names[i]),
                      ]),
                      space: 8,
                      semanticsLabel: '$_root ${_mode.name} ${_pattern.name}',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    line.names.join(' '),
                    key: const ValueKey('pattern-notes'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          key: const ValueKey('pattern-direction'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: false, label: Text('Up')),
                            ButtonSegment(value: true, label: Text('Down')),
                          ],
                          selected: {_down},
                          onSelectionChanged: (value) =>
                              setState(() => _down = value.first),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const ValueKey('pattern-hear'),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Hear It'),
                        onPressed: _hear,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  KeyChips(
                    moves: _moves,
                    label: _spelledKey,
                    at: _at,
                    done: _done,
                    onPick: _goTo,
                  ),
                ],
              ),
            ),
            KeyStep(onBack: () => _goTo(_at - 1), onNext: () => _goTo(_at + 1)),
          ],
        ),
      ),
    );
  }
}
