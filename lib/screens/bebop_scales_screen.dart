// Bebop scales: the extra note, and what it is for.
//
// The point is not the scale, it is where the beats land, so the screen is
// built round showing that. Two bars of quavers, the notes on the beats
// marked, and the plain seven-note scale underneath doing the same thing
// so you can see it come apart. One picture, two rows, and the whole idea
// is in the difference between them.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/bebop_scales.dart';
import '../music/chord.dart';
import '../settings/app_settings.dart';
import 'stave_figure.dart';

/// Roots worth drilling: the ones the tunes are in.
const _roots = ['C', 'F', 'B♭', 'E♭', 'G', 'D', 'A'];

class BebopScalesScreen extends StatefulWidget {
  const BebopScalesScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<BebopScalesScreen> createState() => _BebopScalesScreenState();
}

class _BebopScalesScreenState extends State<BebopScalesScreen> {
  var _scale = bebopScales.first;
  var _root = 'C';

  Chord get _chord => Chord.parse('$_root${_scale.quality}');

  /// Plays [degrees] as quavers over the chord, so the beats are audible
  /// as well as visible.
  Future<void> _play(List<String> degrees) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const quaver = 0.23;
    final root = 60 + (_chord.root - 60) % 12;
    final notes = <SnippetNote>[
      // The chord underneath, quietly, so the beats have something to be
      // on or off.
      for (final interval in _chord.quality.intervals)
        (
          pitch: 48 + (_chord.root + interval - 48) % 12,
          start: 0,
          length: quaver * 16,
          velocity: 0.22,
          bass: false,
        ),
      (
        pitch: 36 + (_chord.root - 36) % 12,
        start: 0,
        length: quaver * 16,
        velocity: 0.3,
        bass: true,
      ),
    ];
    final steps = semitonesOf(degrees);
    for (var i = 0; i < 16; i++) {
      notes.add((
        pitch: root + steps[i % degrees.length] + 12 * (i ~/ degrees.length),
        start: i * quaver,
        // On the beat gets the weight, which is what the eye is being
        // asked to look at.
        length: quaver * 0.92,
        velocity: i.isEven ? 0.9 : 0.6,
        bass: false,
      ));
    }
    await widget.player.playSnippet(renderSnippet(bank, notes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = {..._scale.tones};
    return Scaffold(
      appBar: AppBar(title: const Text('Bebop Scales')),
      body: ListView(
        key: const ValueKey('bebop-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'A seven-note scale run in quavers takes a bar and an eighth '
              'to come round, so after one bar the beats stop landing on '
              'chord tones. Put one note in and a bar of quavers is exactly '
              'an octave, and every beat lands on a chord tone for as long '
              'as you keep going. That is the whole trick.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [for (final s in bebopScales) (s.short, s.short)],
            selected: _scale.short,
            onPick: (short) => setState(
              () => _scale = bebopScales.firstWhere((s) => s.short == short),
            ),
          ),
          _Chips(
            values: [for (final r in _roots) (r, r)],
            selected: _root,
            onPick: (root) => setState(() => _root = root),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              '${_scale.about} Over ${_chord.display}, the note put in is '
              'the ${prettyDegree(_scale.added)}: '
              '${_chord.noteFor(_scale.added)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _Run(
            title: _scale.name,
            degrees: _scale.degrees,
            chord: _chord,
            tones: tones,
            onPlay: () => _play(_scale.degrees),
          ),
          _Run(
            title: '${_scale.plainName}, for comparison',
            degrees: _scale.plain,
            chord: _chord,
            tones: tones,
            onPlay: () => _play(_scale.plain),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'The marked notes are the ones on the beat. Count how many of '
              'them are chord tones in each row, then play them one after '
              'the other: the second row is not wrong, it just stops '
              'agreeing with the chord after the first bar.',
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

/// One scale written out as two bars of quavers, and played.
class _Run extends StatelessWidget {
  const _Run({
    required this.title,
    required this.degrees,
    required this.chord,
    required this.tones,
    required this.onPlay,
  });

  final String title;
  final List<String> degrees;
  final Chord chord;
  final Set<String> tones;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final run = runOf(degrees, tones);
    final landed = tonesOnBeats(degrees, tones);
    final names = spell(degrees, chord.rootName, chord.quality.symbols.first);
    // The root's line, so everything above it can be counted from there.
    final rootStep = Clef.treble.stepOf(chord.rootName[0], 4);

    final columns = <StaveColumn>[];
    final beams = <Beam>[];
    for (var i = 0; i < run.length; i++) {
      final at = i % degrees.length;
      final name = names[at];
      final number = int.parse(degrees[at].replaceAll(RegExp('[b#]'), ''));
      final step = (rootStep + (number - 1) + 7 * (i ~/ degrees.length))
          .toDouble();
      final accidental = name.length > 1
          ? name.substring(1) == '♭'
                ? Smufl.flat
                : Smufl.sharp
          : null;
      columns.add(
        StaveColumn(
          [
            if (accidental != null) sym(accidental, step: step, dx: -1.15),
            sym(
              Smufl.noteheadBlack,
              step: step,
              // On the beat is what the eye is here for.
              marked: run[i].onBeat,
              ledgers: true,
            ),
          ],
          stem: true,
          gap: (i % 4 == 3) ? 2.2 : 1.35,
          label: run[i].onBeat ? name : null,
        ),
      );
      // Beamed in fours, the way quavers are written.
      if (i % 4 == 0) beams.add((from: i, to: i + 3, count: 1));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              Text(
                '$landed of 8 beats',
                key: ValueKey('landed-$title'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: landed == 8 ? scheme.tertiary : scheme.error,
                ),
              ),
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
            child: StaveFigure(
              columns: columns,
              clef: Clef.treble,
              beams: beams,
              space: 7,
              above: 6,
              below: 6,
              semanticsLabel: '$title: $landed of 8 beats land on a chord tone',
            ),
          ),
        ],
      ),
    );
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
