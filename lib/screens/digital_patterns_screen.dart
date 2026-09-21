// Digital patterns: one shape, run through the changes.
//
// The screen is built so the numbers stay still and the notes move, which
// is the whole idea. Pick 1-2-3-5 and it is written out over every chord
// of the progression — D E F A, then G A B D, then C D E G — with the
// numbers underneath each one so you can see your hand doing the same
// thing while the music does something different.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/digital_patterns.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'stave_figure.dart';

const _keys = ['C', 'F', 'B♭', 'E♭', 'G', 'D', 'A'];

/// Note names for each step above a key's root, spelled for flat keys —
/// which is most of them.
const _steps = [
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

class DigitalPatternsScreen extends StatefulWidget {
  const DigitalPatternsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<DigitalPatternsScreen> createState() => _DigitalPatternsScreenState();
}

class _DigitalPatternsScreenState extends State<DigitalPatternsScreen> {
  var _pattern = digitalPatterns.first;
  var _changes = patternChanges.first;
  var _key = 'C';

  /// The progression's chords in the chosen key.
  List<Chord> get _chords {
    final root = _steps.indexOf(_key);
    return [
      for (final (step, quality) in _changes.chords)
        Chord.parse('${_steps[(root + step) % 12]}$quality'),
    ];
  }

  /// Plays the pattern through the changes, each chord under its own four
  /// notes so the shape is heard against what it is being played over.
  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const quaver = 0.26;
    final notes = <SnippetNote>[];
    var at = 0.0;
    for (final chord in _chords) {
      final run = patternOn(_pattern.degrees, chord);
      if (run.isEmpty) continue;
      const bar = quaver * 4;
      notes.add((
        pitch: 36 + (chord.root - 36) % 12,
        start: at,
        length: bar,
        velocity: 0.34,
        bass: true,
      ));
      for (final interval in chord.quality.intervals) {
        notes.add((
          pitch: 48 + (chord.root + interval - 48) % 12,
          start: at,
          length: bar,
          velocity: 0.2,
          bass: false,
        ));
      }
      for (final (i, note) in run.indexed) {
        notes.add((
          pitch: note.pitch,
          start: at + i * quaver,
          length: quaver * 0.92,
          velocity: i == 0 ? 0.9 : 0.72,
          bass: false,
        ));
      }
      at += bar;
    }
    if (notes.isEmpty) return;
    await widget.player.playSnippet(renderSnippet(bank, notes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chords = _chords;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Patterns'),
        actions: [
          IconButton(
            key: const ValueKey('play-pattern'),
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Play it through the changes',
            onPressed: _play,
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('patterns-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '"1235" is not a lick, it is a shape: the 1st, 2nd, 3rd and '
              '5th of whatever scale the chord wants. Your hand does the '
              'same thing over every chord and different notes come out. '
              'Practise the numbers and the changes do the rest.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [for (final p in digitalPatterns) (p.written, p.written)],
            selected: _pattern.written,
            onPick: (written) => setState(
              () => _pattern = digitalPatterns.firstWhere(
                (p) => p.written == written,
              ),
            ),
          ),
          _Chips(
            values: [for (final c in patternChanges) (c.name, c.name)],
            selected: _changes.name,
            onPick: (name) => setState(
              () => _changes = patternChanges.firstWhere((c) => c.name == name),
            ),
          ),
          _Chips(
            values: [for (final k in _keys) (k, k)],
            selected: _key,
            onPick: (key) => setState(() => _key = key),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '${_pattern.name}. ${_pattern.about}',
              key: const ValueKey('about-pattern'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              _changes.about,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, chord) in chords.indexed)
                  _OverChord(
                    chord: chord,
                    degrees: _pattern.degrees,
                    // The clef once, at the front, as it is written.
                    first: i == 0,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'The numbers under the stave are the same in every bar. The '
              'notes are not. Once a shape is in your hands, move the key '
              'on and do it again — that is the whole exercise, and it is '
              'meant to take weeks rather than minutes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pattern over one chord: the symbol, the notes, and the numbers.
class _OverChord extends StatelessWidget {
  const _OverChord({
    required this.chord,
    required this.degrees,
    required this.first,
  });

  final Chord chord;
  final List<int> degrees;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = patternOn(degrees, chord);
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            handSymbol(chord.display),
            key: ValueKey('over-${chord.display}'),
            style: handLettered(
              TextStyle(fontSize: 22, color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 2),
          if (run.isEmpty)
            SizedBox(
              height: 90,
              child: Center(
                child: Text(
                  'no scale',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            StaveFigure(
              columns: [
                for (final (i, note) in run.indexed)
                  StaveColumn(
                    [
                      if (note.name.length > 1)
                        sym(
                          note.name.substring(1) == '♭'
                              ? Smufl.flat
                              : Smufl.sharp,
                          step: _stepOf(note),
                          dx: -1.15,
                        ),
                      sym(
                        Smufl.noteheadBlack,
                        step: _stepOf(note),
                        // The first of each group is the one to hear
                        // landing, and the one to put on the beat.
                        marked: i == 0,
                        ledgers: true,
                      ),
                    ],
                    stem: true,
                    gap: 1.5,
                    label: '${note.degree}',
                  ),
              ],
              clef: first ? Clef.treble : null,
              beams: [(from: 0, to: run.length - 1, count: 1)],
              space: 7,
              above: 6,
              below: 6,
              semanticsLabel:
                  'Over ${chord.display}: '
                  '${[for (final n in run) n.name].join(', ')}',
            ),
        ],
      ),
    );
  }

  /// Where the note sits on a treble stave.
  static double _stepOf(PatternNote note) =>
      Clef.treble.stepOf(note.name[0], note.octave).toDouble();
}

/// A labelled row of chips that scrolls sideways.
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
