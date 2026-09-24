// How a walking bass line is built, one bar at a time.
//
// Four beats, and the line has to arrive on the next chord sounding like
// it meant to. Between those two facts is most of what a bass player
// knows, and written out it is a short list: go up the chord, go down it,
// walk the scale, leap the octave, or spend the whole bar creeping
// towards the next root from above or below.
//
// These are the band's own shapes, asked for by name rather than
// described again. The bassist picks from this list every bar of every
// tune in the app, so what is shown here is what would be played, and
// the two cannot come apart.
//
// It goes round the twelve keys like the other rounds, because a line
// you can only walk in one key is not a line you can walk.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/practice_player.dart';
import '../audio/walking_bass.dart';
import '../music/bass_moves.dart';
import '../music/chord.dart';
import '../music/lick.dart' show KeyOrder, nameInKey;
import '../settings/app_settings.dart';
import '../theme.dart';
import 'key_round.dart';
import 'stave.dart';

/// The changes a line is shown walking through, written in C.
///
/// Four, because these are where nearly all walking happens: into the V,
/// into the I, sideways to the IV, and the minor version of the first.
const _changes = [
  ('ii to V', 'Dm7', 'G7'),
  ('V to I', 'G7', 'C^7'),
  ('I to IV', 'C^7', 'F^7'),
  ('Minor ii to V', 'Dh7', 'G7b9'),
];

class WalkingBassScreen extends StatefulWidget {
  const WalkingBassScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<WalkingBassScreen> createState() => _WalkingBassScreenState();
}

class _WalkingBassScreenState extends State<WalkingBassScreen> {
  var _change = 0;
  var _order = KeyOrder.fourths;
  late List<int> _moves = _order.moves();
  var _at = 0;
  final _done = <int>{};
  String? _problem;

  int get move => _moves[_at];

  /// The two chords, moved to this key.
  (Chord, Chord) get _chords {
    final (_, from, to) = _changes[_change];
    final key = _keyName(move);
    final tonic = parseNoteName(key)!;
    final shift = Transposition(
      letterSteps: tonic.letter,
      semitones: pitchClassOf(tonic),
    );
    return (
      Chord.parse(from).transposed(shift),
      Chord.parse(to).transposed(shift),
    );
  }

  String _keyName(int by) {
    const flats = [
      'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
    ];
    return flats[by % 12];
  }

  /// The key as it is written on screen, with a proper flat sign.
  String _shown(int by) => _keyName(by).replaceAll('b', '♭');

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

  Future<void> _hear(BassMove which) async {
    final bank = widget.player.samples;
    if (bank == null) {
      setState(
        () => _problem =
            'The instruments are still loading. Try again in a moment.',
      );
      return;
    }
    setState(() => _problem = null);
    final (from, to) = _chords;
    // The line, and then the chord it was walking towards, so the whole
    // point of the last note can be heard rather than described.
    final line = bassMoveLine(which, chord: from, next: to);
    await widget.player.playSnippet(
      renderSnippet(bank, [
        ...runSnippet(line, step: 0.42, bass: true),
        (
          pitch: 36 + to.root % 12,
          start: 4 * 0.42,
          length: 1.4,
          velocity: 0.8,
          bass: true,
        ),
      ], bassTone: BassTone.natural),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (from, to) = _chords;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walking Bass'),
        actions: [KeyOrderButton(order: _order, onPick: _setOrder)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                children: [
                  Text(
                    'Four beats, and the line has to arrive on the next '
                    'chord sounding like it meant to. These are the shapes '
                    'the band\'s own bassist picks from, bar by bar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const ValueKey('bass-change'),
                    initialValue: _change,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Walking through',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final (i, (name, _, _)) in _changes.indexed)
                        DropdownMenuItem(value: i, child: Text(name)),
                    ],
                    onChanged: (value) =>
                        setState(() => _change = value ?? _change),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '${handSymbol(from.display)} to '
                          '${handSymbol(to.display)}',
                          key: const ValueKey('bass-chords'),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${_at + 1} of ${_moves.length}',
                        key: const ValueKey('bass-progress'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  KeyChips(
                    moves: _moves,
                    label: _shown,
                    at: _at,
                    done: _done,
                    onPick: _goTo,
                  ),
                  if (_problem case final problem?) ...[
                    const SizedBox(height: 10),
                    Text(
                      problem,
                      key: const ValueKey('bass-problem'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final one in BassMove.values)
                    _MoveCard(
                      move: one,
                      line: bassMoveLine(one, chord: from, next: to),
                      from: from,
                      onHear: () => _hear(one),
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

/// One shape: what it is called, what it is, and the four notes.
class _MoveCard extends StatelessWidget {
  const _MoveCard({
    required this.move,
    required this.line,
    required this.from,
    required this.onHear,
  });

  final BassMove move;
  final List<int> line;

  /// The chord it is walking through, which is how the notes are spelled.
  final Chord from;

  final VoidCallback onHear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = [for (final pitch in line) nameInKey(pitch, key: from.root)];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    move.label,
                    key: ValueKey('bass-move-${move.name}'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (move.aimsAtTheNext)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'aims at the next chord',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.tertiary,
                      ),
                    ),
                  ),
                IconButton(
                  key: ValueKey('bass-hear-${move.name}'),
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: 'Hear ${move.label}',
                  onPressed: onHear,
                ),
              ],
            ),
            SizedBox(
              height: 74,
              child: Stave(
                notes: lineOnStave([
                  for (final (i, pitch) in line.indexed)
                    (pitch: pitch, name: names[i]),
                ], clef: Clef.bass),
                clef: Clef.bass,
                space: 7,
                semanticsLabel: '${move.label}: ${names.join(' ')}',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              names.join('  '),
              key: ValueKey('bass-notes-${move.name}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(move.about, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
