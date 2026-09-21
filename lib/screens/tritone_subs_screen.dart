// Tritone substitution: why it is allowed, rather than that it is.
//
// The screen leads with the mechanism, because the mechanism is the whole
// thing: the two chords are drawn side by side with their 3rds and ♭7ths
// marked, and they are the same two notes swapped over. Once that has been
// seen there is nothing left to memorise; everything below it is just
// where you would use it.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/guide_tones.dart';
import '../music/tritone_subs.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'stave_figure.dart';

const _keys = ['C', 'F', 'B♭', 'E♭', 'G', 'D', 'A'];

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

class TritoneSubsScreen extends StatefulWidget {
  const TritoneSubsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<TritoneSubsScreen> createState() => _TritoneSubsScreenState();
}

class _TritoneSubsScreenState extends State<TritoneSubsScreen> {
  var _changes = subChanges.first;
  var _key = 'C';

  List<Chord> get _written {
    final root = _steps.indexOf(_key);
    return [
      for (final (step, quality) in _changes.chords)
        Chord.parse('${_steps[(root + step) % 12]}$quality'),
    ];
  }

  /// The same changes with the substitution made.
  List<Chord> get _subbed {
    final chords = [..._written];
    final sub = subFor(chords[_changes.at]);
    if (sub != null) chords[_changes.at] = sub;
    return chords;
  }

  /// Plays a progression, each chord a bar, with its root underneath.
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
    final written = _written;
    final subbed = _subbed;
    final from = written[_changes.at];
    final to = subbed[_changes.at];
    return Scaffold(
      appBar: AppBar(title: const Text('Tritone Subs')),
      body: ListView(
        key: const ValueKey('subs-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'A tritone is half an octave: six semitones. Every dominant '
              '7th has one, and it is the sound that makes the chord want '
              'to move. Any dominant can be swapped for the dominant a '
              'tritone away, and this is why it is allowed:',
              key: const ValueKey('tritone-in-short'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [for (final c in subChanges) (c.name, c.name)],
            selected: _changes.name,
            onPick: (name) => setState(
              () => _changes = subChanges.firstWhere((c) => c.name == name),
            ),
          ),
          _Chips(
            values: [for (final k in _keys) (k, k)],
            selected: _key,
            onPick: (key) => setState(() => _key = key),
          ),
          const SizedBox(height: 14),
          _TheSwap(from: from, to: to),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              _changes.about,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _Line(
            title: 'As Written',
            chords: written,
            changedAt: null,
            onPlay: () => _play(written),
          ),
          _Line(
            title: 'With the Sub',
            chords: subbed,
            changedAt: _changes.at,
            onPlay: () => _play(subbed),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'The arrows are what the bass does. Fourths become semitones '
              'going downhill, and that (not the chord symbol) is what '
              'anyone listening actually hears change.',
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

/// The two chords and their guide tones, side by side. The point of the
/// screen.
class _TheSwap extends StatelessWidget {
  const _TheSwap({required this.from, required this.to});

  final Chord from;
  final Chord to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shared = shareGuideTones(from, to);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Dyad(chord: from),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.swap_horiz,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  _Dyad(chord: to),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                shared
                    ? '${_names(from)} in ${from.display}, '
                          '${_names(to)} in ${to.display}. The same two '
                          'notes with their jobs swapped: nothing the ear '
                          'was listening to has moved.\n\n'
                          'Those two are six semitones apart: three whole '
                          'tones, which is what a tritone is. It is the '
                          'one interval that is its own opposite (half an '
                          'octave either way lands on the same note) so '
                          'the swap goes both ways.'
                    : '${from.display} is not a dominant, so it has no '
                          'tritone to swap.',
                key: const ValueKey('what-a-tritone-is'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "F the ♭7 and B the 3rd": the degrees are the point, because it is
  /// the jobs they swap, not the notes.
  static String _names(Chord chord) {
    final tones = guideTonesThrough([chord]).single;
    return '${tones.lower} the ${prettyDegree(tones.lowerDegree)} '
        'and ${tones.upper} the ${prettyDegree(tones.upperDegree)}';
  }
}

/// One chord's 3rd and ♭7 written on a stave, with its name above.
class _Dyad extends StatelessWidget {
  const _Dyad({required this.chord});

  final Chord chord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = guideTonesThrough([chord]).single;
    // The lower note first, and the upper put above it rather than
    // wherever its letter happens to fall.
    final lowerStep = Clef.treble.stepOf(tones.lower[0], 4);
    var upperStep = Clef.treble.stepOf(tones.upper[0], 4);
    if (upperStep <= lowerStep) upperStep += 7;

    Sym head(String name, double step) =>
        sym(Smufl.noteheadBlack, step: step, marked: true, ledgers: true);
    Sym? mark(String name, double step) => name.length > 1
        ? sym(
            name.substring(1) == '♭' ? Smufl.flat : Smufl.sharp,
            step: step,
            dx: -1.25,
          )
        : null;

    return Column(
      children: [
        Text(
          handSymbol(chord.display),
          key: ValueKey('dyad-${chord.display}'),
          style: handLettered(
            TextStyle(fontSize: 20, color: theme.colorScheme.onSurface),
          ),
        ),
        StaveFigure(
          columns: [
            StaveColumn([
              ?mark(tones.lower, lowerStep.toDouble()),
              ?mark(tones.upper, upperStep.toDouble()),
              head(tones.lower, lowerStep.toDouble()),
              head(tones.upper, upperStep.toDouble()),
            ], label: '${tones.lower} ${tones.upper}'),
          ],
          clef: Clef.treble,
          space: 7,
          above: 5,
          below: 5,
          semanticsLabel: '${chord.display}: ${tones.lower} and ${tones.upper}',
        ),
      ],
    );
  }
}

/// A progression written out, with what the bass does between chords.
class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    required this.chords,
    required this.changedAt,
    required this.onPlay,
  });

  final String title;
  final List<Chord> chords;

  /// Which chord was substituted, if any, drawn in pencil red.
  final int? changedAt;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final moves = bassMoves(chords);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              IconButton(
                key: ValueKey('play-$title'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Play $title',
                onPressed: onPlay,
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final (i, chord) in chords.indexed) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        // What the bass does to get here.
                        _arrow(moves[i - 1]),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: moves[i - 1].abs() == 1
                              ? scheme.tertiary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    handSymbol(chord.display),
                    key: ValueKey('$title-${chord.display}'),
                    style: handLettered(
                      TextStyle(
                        fontSize: 24,
                        color: i == changedAt
                            ? scheme.tertiary
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What the bass does, named rather than counted: "↑ 5" beside "↓
  /// semitone" reads as two different kinds of thing, and a fourth is
  /// what the prose calls it.
  static String _arrow(int move) {
    final up = move > 0;
    final name = switch (move.abs()) {
      1 => 'semitone',
      2 => 'tone',
      3 => 'minor 3rd',
      4 => 'major 3rd',
      5 => 'a 4th',
      6 => 'a tritone',
      _ => '${move.abs()} semitones',
    };
    return '${up ? '↑' : '↓'} $name';
  }
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
