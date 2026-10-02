// Dominants that lean on each other, and why a run of them pulls.
//
// A dominant wants to go a fourth up. Nearly always it gets there and the
// music settles. But if what it lands on is another dominant, that one
// wants to go on as well, and nothing settles until the run runs out.
// That is the whole idea, and everything else on this page is either a
// demonstration of it or a place you will meet it.
//
// The page leads with the guide tones rather than with the roots, because
// the guide tones are what you actually hear. The roots leap about by
// fourths; the 3rd and the ♭7 of each chord fall a semitone into the ♭7
// and the 3rd of the next, every time, for as long as the run of
// dominants lasts. That is a chromatic line hiding inside a set of
// changes that look like they are jumping around, and seeing it once is
// the difference between memorising a bridge and hearing one.
//
// At the end of the run one of the two stops falling and is simply held:
// the 3rd of the last dominant is already the 7th of the chord it lands
// on. That is worth showing rather than glossing, because the note that
// stops moving is a good part of why the ending sounds like one.
//
// Written independently, as every chart and every page here is: the
// changes below are the ones everybody plays, worked out from the idea
// rather than copied from anywhere.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/guide_tones.dart';
import '../theme.dart';

/// The keys worth offering, the ones these turn up in.
const _keys = ['B♭', 'C', 'F', 'E♭', 'G', 'D'];

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

/// One run worth hearing: how many dominants, and where they are met.
typedef _Run = ({int length, String name, String where});

const _runs = <_Run>[
  (
    length: 2,
    name: 'Two',
    where:
        'The dominant of a dominant, and the usual way a tune reaches for '
        'a chord that is not in its key. All of Me does it in its second '
        'bar. Two steps from home instead of one.',
  ),
  (
    length: 3,
    name: 'Three',
    where:
        'Long enough to feel like it is going somewhere on its own. Doxy '
        'and Caravan both run three, and a blues often picks one up in '
        'its last four bars.',
  ),
  (
    length: 4,
    name: 'Four',
    where:
        'The bridge of rhythm changes, give or take the key. Eight bars, '
        'two to a chord, nothing resolving until the last of them hands '
        'back to the tune. It is the most played set of eight bars in '
        'this music.',
  ),
];

class DominantChainsScreen extends StatefulWidget {
  const DominantChainsScreen({super.key, required this.player});

  final PracticePlayer player;

  @override
  State<DominantChainsScreen> createState() => _DominantChainsScreenState();
}

class _DominantChainsScreenState extends State<DominantChainsScreen> {
  _Run _run = _runs.last;
  String _key = 'B♭';

  /// The run, ending on the chord it hands back to.
  ///
  /// Counted backwards from home: a run of four into B♭ starts on D, not
  /// on B♭, because each chord is a fourth below the one it is going to.
  List<Chord> get _chords {
    final home = _steps.indexOf(_key);
    return [
      for (var i = _run.length; i > 0; i--)
        Chord.parse('${_steps[(home + i * 7) % 12]}7'),
      Chord.parse('$_keyΔ7'),
    ];
  }

  /// Plays the run, a bar each, with the roots underneath.
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

  /// Just the two guide tones, so the chromatic line can be heard on its
  /// own without the roots leaping about underneath it.
  Future<void> _playTheLine(List<GuideTones> tones) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const bar = 0.95;
    final notes = <SnippetNote>[];
    for (final (i, at) in tones.indexed) {
      for (final degree in [at.upperDegree, at.lowerDegree]) {
        final semitones = degreeToSemitones(degree);
        notes.add((
          pitch: 60 + (at.chord.root + semitones - 60) % 12,
          start: i * bar,
          length: bar * 0.95,
          velocity: 0.6,
          bass: false,
        ));
      }
    }
    await widget.player.playSnippet(renderSnippet(bank, notes));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chords = _chords;
    final tones = guideTonesThrough(chords);
    return Scaffold(
      appBar: AppBar(title: const Text('Chains of Dominants')),
      body: ListView(
        key: const ValueKey('chains-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'A dominant leans a fourth up, and usually gets there. Where '
              'it lands on another dominant, that one leans on as well, '
              'and nothing settles until the run runs out. That is what '
              'makes a bridge built this way feel like it is being pulled '
              'along rather than going anywhere.',
              key: const ValueKey('chains-in-short'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [for (final run in _runs) (run.name, run.name)],
            selected: _run.name,
            onPick: (name) => setState(
              () => _run = _runs.firstWhere((run) => run.name == name),
            ),
          ),
          _Chips(
            values: [for (final key in _keys) (key, key)],
            selected: _key,
            onPick: (key) => setState(() => _key = key),
          ),
          _Changes(chords: chords, onPlay: () => _play(chords)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _run.where,
              key: const ValueKey('chains-where'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'What You Are Actually Hearing',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'The roots leap about by fourths. The 3rd and the ♭7 of each '
              'chord do not: each falls a semitone into the ♭7 and the 3rd '
              'of the next, every time, for as long as the dominants last. '
              'There is a chromatic line hiding inside changes that look '
              'like they are jumping around, and it is the line, not the '
              'roots, that makes a run sound like one thing.\n\n'
              'At the end one of the two stops falling and is held: the '
              '3rd of the last dominant is already the 7th of the chord it '
              'lands on. The note that stops moving is a good part of why '
              'the ending sounds like one.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _TheLine(tones: tones, onPlay: () => _playTheLine(tones)),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'What to Do with One',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const _Note(
            'Put a ii in front of any of them. Each dominant in the run can '
            'take its own minor chord a fourth above, which turns a run of '
            'four chords into eight and is what a comper is usually doing '
            'behind a bridge like this.',
          ),
          const _Note(
            'Sub any of them. A dominant in a run can be swapped for the '
            'one a tritone away just as any other can, and in a run it has '
            'a particular effect: the bass stops leaping and walks down by '
            'semitones instead.',
          ),
          const _Note(
            'Do not try to land. The run is the point, and playing each '
            'chord as though it were an arrival is what makes a bridge '
            'sound like four unrelated bars. Aim at the end of it and let '
            'the chords in between pass.',
          ),
        ],
      ),
    );
  }
}

/// The run as a line of chords, with what the bass does between them.
class _Changes extends StatelessWidget {
  const _Changes({required this.chords, required this.onPlay});

  final List<Chord> chords;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('The Run', style: theme.textTheme.titleSmall),
              ),
              IconButton(
                key: const ValueKey('play-the-run'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Play the run',
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
                        '↑4',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    handSymbol(chord.display),
                    key: ValueKey('run-${chord.display}'),
                    style: handLettered(
                      TextStyle(
                        fontSize: 26,
                        // The chord it hands back to, which is the only one
                        // in the line that is allowed to settle.
                        color: i == chords.length - 1
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.onSurface,
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
}

/// The two guide tones under each chord, with the semitone steps marked.
class _TheLine extends StatelessWidget {
  const _TheLine({required this.tones, required this.onPlay});

  final List<GuideTones> tones;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'The Two Notes, on Their Own',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const ValueKey('play-the-line'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.play_circle_outline),
                tooltip: 'Play the two notes',
                onPressed: onPlay,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, at) in tones.indexed) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        at.chord.display,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      for (final (note, move) in [
                        (at.upper, at.upperMove),
                        (at.lower, at.lowerMove),
                      ])
                        Text(
                          note,
                          key: ValueKey('tone-$i-$note'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            // A step of one semitone is the thing being
                            // shown, so it is the thing that is marked.
                            color: move.abs() == 1
                                ? scheme.tertiary
                                : scheme.onSurface,
                            fontWeight: move.abs() == 1
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'In red: a note that fell a semitone from the chord before it. '
            'The one left plain at the end is the note being held.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// A row of choices, the chosen one filled in.
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
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    child: Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in values)
          ChoiceChip(
            key: ValueKey('chain-chip-$value'),
            label: Text(label),
            selected: value == selected,
            onSelected: (_) => onPick(value),
          ),
      ],
    ),
  );
}
