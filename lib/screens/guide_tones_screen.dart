// Guide-tone lines: the exercise.
//
// Two notes — each chord's 3rd and 7th — held through a progression while
// everything else changes underneath. The lesson is how little they move,
// so the movement is what's written beside every chord: held, or a
// semitone, or a tone. Play the two lines and you have played the changes.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/guide_tones.dart';
import '../settings/app_settings.dart';
import 'chord_diagram.dart';
import 'stave.dart';
import 'stave_figure.dart';

/// A progression to hold the lines through, written in degrees of the key
/// so it can be put in any of them.
typedef Changes = ({String name, String how, List<String> degrees});

const _changes = <Changes>[
  (
    name: 'ii–V–I',
    how:
        'The one to learn first. The 7th of the ii falls a semitone to '
        'the 3rd of the V, and the 3rd of the V falls a semitone to the '
        '7th of the I. Two semitones in the whole thing.',
    degrees: ['IIm7', 'V7', 'I^7'],
  ),
  (
    name: 'Minor ii–V–i',
    how:
        'The same shape with the ii half-diminished and the V altered. '
        'The lines still barely move, which is how you find your way '
        'through a minor tune.',
    degrees: ['IIm7b5', 'V7b9', 'Im7'],
  ),
  (
    name: 'Turnaround',
    how:
        'The last two bars of a chorus, sending you back to the top. '
        'Four chords, and the lines walk down through them.',
    degrees: ['I^7', 'VI7', 'IIm7', 'V7'],
  ),
  (
    name: 'Round the Cycle',
    how:
        'Dominants falling in fourths, as the bridge of a rhythm tune '
        'does. Every 7th becomes the next 3rd: the same two notes over '
        'and over, moving a semitone at a time.',
    degrees: ['III7', 'VI7', 'II7', 'V7'],
  ),
];

/// Which instrument the notes are shown on.
enum _Under { keyboard, guitar, bass }

class GuideTonesScreen extends StatefulWidget {
  const GuideTonesScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<GuideTonesScreen> createState() => _GuideTonesScreenState();
}

class _GuideTonesScreenState extends State<GuideTonesScreen> {
  Changes _changesPicked = _changes.first;
  String _key = 'C';
  var _under = _Under.keyboard;

  /// The chords, in the key chosen.
  List<Chord> get _chords => [
    for (final degree in _changesPicked.degrees) _chordFor(degree),
  ];

  Chord _chordFor(String degree) {
    // "IIm7" is the 2nd degree of the key with an m7 on it.
    final match = RegExp(r'^([IV]+)(.*)$').firstMatch(degree)!;
    const degrees = {'I': 0, 'II': 2, 'III': 4, 'IV': 5, 'V': 7, 'VI': 9};
    final steps = degrees[match.group(1)!]!;
    final tonic = Chord.parse(_key);
    return Chord.parse(
      '${tonic.noteFor('1')}${match.group(2)}',
    ).transposed(Transposition(letterSteps: _letters(steps), semitones: steps));
  }

  /// How many letter names a degree moves: a 2nd is one letter, a 5th four.
  int _letters(int semitones) =>
      const {0: 0, 2: 1, 4: 2, 5: 3, 7: 4, 9: 5}[semitones]!;

  List<GuideTones> get _lines => guideTonesThrough(_chords);

  /// The lines put in an octave, each note following the one before it by
  /// exactly the move the line says. Built this way the two lines are as
  /// still on the page as they are in the theory.
  List<({GuideTones tones, int upper, int lower})> get _voiced {
    final out = <({GuideTones tones, int upper, int lower})>[];
    var upper = 0;
    var lower = 0;
    for (final (i, tones) in _lines.indexed) {
      if (i == 0) {
        upper = _nearest(71, tones.upper);
        lower = _nearest(upper - 5, tones.lower);
        if (lower >= upper) lower -= 12;
      } else {
        upper += tones.upperMove;
        lower += tones.lowerMove;
      }
      out.add((tones: tones, upper: upper, lower: lower));
    }
    return out;
  }

  /// The pitch of [name] nearest to [about].
  int _nearest(int about, String name) {
    final pitchClass = pitchClassOf(parseNoteName(name)!);
    return about + ((pitchClass - about) + 6) % 12 - 6;
  }

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const beat = 0.75;
    final voiced = _voiced;
    final down = _under == _Under.bass ? 12 : 0;
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        [
          for (final (i, at) in voiced.indexed) ...[
            // The root underneath, so the lines are heard against the
            // change rather than on their own — and quiet, because it is
            // the thing they are heard against and not the exercise.
            (
              pitch: 40 + (at.tones.chord.root - 40) % 12,
              start: i * beat,
              length: beat,
              velocity: 0.28,
              bass: true,
            ),
            (
              pitch: at.upper - down,
              start: i * beat,
              length: beat * 0.95,
              velocity: 0.85,
              bass: false,
            ),
            (
              pitch: at.lower - down,
              start: i * beat,
              length: beat * 0.95,
              velocity: 0.85,
              bass: false,
            ),
          ],
        ],
        guitar: _under == _Under.guitar,
        // Driven only when the bass is the exercise. Under the lines it
        // is merely tightened: the boom taken out so it doesn't muddy
        // them, without the drive that makes it shout.
        bassTone: _under == _Under.bass ? BassTone.bright : BassTone.tight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiced = _voiced;
    return Scaffold(
      appBar: AppBar(title: const Text('Guide Tones')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              "A chord's 3rd says whether it is major or minor, and its 7th "
              'says what kind of 7th it is. Leave the root and the 5th to '
              'the bass player and those two notes are the chord. Hold them '
              'through a progression and they barely move — which is the '
              'whole lesson.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Under>(
                key: const ValueKey('guide-under'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Under.keyboard, label: Text('Keys')),
                  ButtonSegment(value: _Under.guitar, label: Text('Guitar')),
                  ButtonSegment(value: _Under.bass, label: Text('Bass')),
                ],
                selected: {_under},
                onSelectionChanged: (value) =>
                    setState(() => _under = value.first),
              ),
            ),
          ),
          _Row(
            label: 'Changes',
            values: [for (final c in _changes) (c.name, c.name)],
            selected: _changesPicked.name,
            onPick: (name) => setState(
              () => _changesPicked = _changes.firstWhere((c) => c.name == name),
            ),
          ),
          _Row(
            label: 'Key',
            values: const [
              ('C', 'C'),
              ('F', 'F'),
              ('B♭', 'B♭'),
              ('E♭', 'E♭'),
              ('G', 'G'),
              ('D', 'D'),
              ('A', 'A'),
            ],
            selected: _key,
            onPick: (key) => setState(() => _key = key),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('play-guide-tones'),
                onTap: _play,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              [for (final chord in _chords) chord.display]
                                  .join('  '),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          Icon(
                            Icons.play_arrow,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _Lines(
                          voiced: voiced,
                          clef: _under == _Under.bass ? Clef.bass : Clef.treble,
                          down: _under == _Under.bass ? 12 : 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (final (i, at) in voiced.indexed)
            _ChordRow(
              tones: at.tones,
              upper: at.upper,
              lower: at.lower,
              under: _under,
              isFirst: i == 0,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_changesPicked.how, style: theme.textTheme.bodyMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Held is the easiest thing there is: the chord changed and '
              'your note did not. When a line does move it is nearly always '
              'a semitone, and nearly always down.',
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

/// The two lines written out, a pair of notes to a chord.
class _Lines extends StatelessWidget {
  const _Lines({required this.voiced, required this.clef, required this.down});

  final List<({GuideTones tones, int upper, int lower})> voiced;
  final Clef clef;
  final int down;

  @override
  Widget build(BuildContext context) {
    const accidentals = {
      -2: Smufl.doubleFlat,
      -1: Smufl.flat,
      1: Smufl.sharp,
      2: Smufl.doubleSharp,
    };
    final columns = <StaveColumn>[];
    for (final at in voiced) {
      final pair = lineOnStave([
        (pitch: at.lower - down, name: at.tones.lower),
        (pitch: at.upper - down, name: at.tones.upper),
      ], clef: clef);
      // Accidentals go in their own column ahead of the heads, so the
      // font's own widths decide the spacing.
      for (final note in pair) {
        if (accidentals[note.accidental] case final glyph?) {
          columns.add(
            StaveColumn.one(glyph, step: note.step.toDouble(), gap: 0.2),
          );
        }
      }
      columns.add(
        StaveColumn([
          for (final note in pair)
            sym(Smufl.noteheadWhole, step: note.step.toDouble(), ledgers: true),
        ], gap: 2.4),
      );
    }
    return StaveFigure(
      key: const ValueKey('guide-tone-stave'),
      clef: clef,
      space: 8,
      columns: columns,
      semanticsLabel: [
        for (final at in voiced)
          '${at.tones.chord.display}: ${at.tones.upper} and ${at.tones.lower}',
      ].join(', '),
    );
  }
}

/// One chord: its two notes, what degree each is, and how far it moved.
class _ChordRow extends StatelessWidget {
  const _ChordRow({
    required this.tones,
    required this.upper,
    required this.lower,
    required this.under,
    required this.isFirst,
  });

  final GuideTones tones;
  final int upper;
  final int lower;
  final _Under under;

  /// The first chord has nothing to have moved from, so saying it held
  /// would be claiming something that hasn't happened yet.
  final bool isFirst;

  /// Short enough to sit beside the note and the degree on a phone.
  String _move(int move) => switch (move) {
    0 => 'held',
    -1 => '↓ semitone',
    1 => '↑ semitone',
    -2 => '↓ tone',
    2 => '↑ tone',
    < 0 => '↓ ${-move}',
    _ => '↑ $move',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget line(String note, String degree, int move, bool held) => Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              note,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              prettyDegree(degree),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isFirst ? 'start here' : _move(move),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: held && !isFirst
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: held && !isFirst ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 74,
                child: Text(
                  tones.chord.display,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(
                      tones.upper,
                      tones.upperDegree,
                      tones.upperMove,
                      tones.upperHeld,
                    ),
                    line(
                      tones.lower,
                      tones.lowerDegree,
                      tones.lowerMove,
                      tones.lowerHeld,
                    ),
                  ],
                ),
              ),
              if (under == _Under.keyboard) _Keys(upper: upper, lower: lower),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pair under the fingers.
class _Keys extends StatelessWidget {
  const _Keys({required this.upper, required this.lower});

  final int upper;
  final int lower;

  @override
  Widget build(BuildContext context) {
    final scale = ScaleKeyboard(
      root: lower % 12,
      semitones: [0, upper - lower],
      colour: {upper - lower},
    );
    return SizedBox(height: 40, width: 40 * scale.aspect, child: scale);
  }
}

/// A labelled row of chips that scrolls sideways.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final String label;
  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  for (final (value, written) in values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: ValueKey('guide-$value'),
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
          ),
        ],
      ),
    );
  }
}
