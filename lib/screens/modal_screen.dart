// Modal: one chord, a long time, and the question the chart will not
// answer.
//
// The page builds in the order the problem arrives. First how long a
// chord actually lasts on these tunes, because until you have seen
// sixteen bars against Anthropology's two beats the rest sounds like
// fuss. Then the question that only matters once a chord is held: the
// chart says Dm7, and Dm7 is three different scales.
//
// The comparison at the top is measured off the library rather than
// asserted, so it cannot come to disagree with the charts it is drawn
// from.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/piano_comping.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/modal.dart';
import '../music/scales.dart';
import '../music/tune.dart';
import '../music/tune_library.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

/// The chord the question is asked about, and the one modal jazz asks it
/// about most: So What, Impressions, Little Sunflower.
const _chordSymbol = 'm7';
const _root = 'D';

/// The tunes in the comparison, modal ones first.
///
/// Named rather than taken off the top of the list, because the point of
/// a comparison is that you already know what the tunes sound like.
/// Whether each one counts as modal is still measured, not assumed.
const _compared = ['So What', 'Milestones', 'Anthropology', 'Giant Steps'];

class ModalScreen extends StatefulWidget {
  const ModalScreen({super.key, required this.player, required this.settings});

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ModalScreen> createState() => _ModalScreenState();
}

class _ModalScreenState extends State<ModalScreen> {
  late Mode _mode = _choices.first;

  /// Whether the chord is shown piled in fourths or in thirds.
  var _inFourths = true;

  static final _choices = modesWritten(_chordSymbol);

  /// The chord as it is written on the chart: Dm7, whichever mode is
  /// being asked about, which is the whole difficulty.
  static final _chord = Chord.parse('$_root$_chordSymbol');

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    // The mode over the chord, not on its own: the 6th only sounds like
    // anything when there is a Dm7 underneath it to sound against.
    final voicing = Comper(math.Random(1)).voice(_chord, null);
    final line = modeSnippet(_mode.semitones, _chord.root);
    final end = line.last.start + line.last.length;
    await widget.player.playSnippet(
      renderSnippet(bank, [
        (
          pitch: 38 + (_chord.root - 38) % 12,
          start: 0,
          length: end,
          velocity: 0.3,
          bass: true,
        ),
        for (final pitch in voicing)
          (pitch: pitch, start: 0, length: end, velocity: 0.28, bass: false),
        ...line,
      ]),
    );
  }

  /// The chord as it is currently stacked, low to high, from D below
  /// middle C so a five-note pile still fits under two hands.
  List<int> get _stackPitches => [
    for (final step in _stack) 50 + step.semitone,
  ];

  List<StackStep> get _stack =>
      _inFourths ? fourthsStack(_mode, _root) : thirdsStack(_mode, _root);

  /// What to say under the line: where its one tritone falls, and why
  /// it is welcome here when the stack would not have it.
  String _aboutLine() {
    final line = fourthsLine(_mode, _root);
    final at = tritoneStep(_mode, _root);
    if (at < 1) return 'Seven notes, every step a fourth.';
    final from = line[at - 1].note;
    final to = line[at].note;
    return 'One step is not a fourth, and there is always exactly one: '
        '$from to $to, the tritone. The stack would not have it on top, '
        'where it would be heard as part of the chord. In a line it is a '
        'wide leap that is over before it can offend, and in ${_mode.name} '
        'it is the ${degreeLabel(colourOf(_mode).first)} that made the '
        'mode worth choosing. Where it falls is different in each of the '
        'three, which is another way of telling them apart.';
  }

  /// What to say under the pile, which depends on whether the mode made
  /// the stack stop early.
  String _aboutStack() {
    if (!_inFourths) {
      return 'The root, 3rd, 5th and 7th: the chord symbol, spelled out. '
          'Nothing wrong with it, but it says "${_chord.display}" and on a '
          'modal tune that was never the question.';
    }
    final refused = refusedBy(_mode, _root);
    if (refused == null) {
      return 'In ${_mode.name} the fourths keep coming: the flat 6th means '
          'nothing forces the stack to stop, so it never has to decide '
          'anything.';
    }
    final below = _stack[_stack.length - 2].note;
    return 'It stops where the mode makes it. Another fourth on top of '
        '$below would be ${refused.note}, ${refused.above} rather than a '
        '4th, sitting right where it is heard most. So it takes the third '
        'instead, and that is the voicing everybody knows off So What.';
  }

  Future<void> _playLine() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const step = 0.26;
    final pitches = fourthsLinePitches(_mode, _root);
    await widget.player.playSnippet(
      renderSnippet(bank, [
        // The chord underneath, so the tritone is heard against
        // something rather than in mid air.
        (
          pitch: 38 + (_chord.root - 38) % 12,
          start: 0,
          length: pitches.length * step + 0.9,
          velocity: 0.28,
          bass: true,
        ),
        for (final (i, pitch) in pitches.indexed)
          (
            pitch: pitch,
            start: i * step,
            length: i == pitches.length - 1 ? 1.1 : step * 1.4,
            velocity: 0.72,
            bass: false,
          ),
      ]),
    );
  }

  Future<void> _playStack() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    // Rolled from the bottom, quickly, the way anybody puts a wide
    // voicing down: struck dead together it reads as a block rather
    // than as a pile of intervals.
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final (i, pitch) in _stackPitches.indexed)
          (
            pitch: pitch,
            start: i * 0.045,
            length: 2.6 - i * 0.045,
            velocity: 0.6,
            bass: false,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final modal = modalTunes(standards);
    final compared = [
      for (final title in _compared)
        ?standards.where((t) => t.title == title).firstOrNull,
    ];
    final longest = compared.map(longestStay).fold(1, math.max);
    return Scaffold(
      appBar: AppBar(title: const Text('Modal')),
      body: ListView(
        key: const ValueKey('modal-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Everything else here is about keeping up. A modal tune '
              'takes that away and hands you one chord for sixteen bars, '
              'which sounds easier and is not.',
              style: theme.textTheme.bodyMedium,
            ),
          ),

          _Heading('How Long a Chord Lasts'),
          for (final tune in compared)
            _StayBar(
              key: ValueKey('stay-${tune.title}'),
              tune: tune,
              of: longest,
              modal: isModal(tune),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'The longest one chord is left sounding, in bars. Nothing '
              'about the top two is harder to play than the bottom two. '
              'It is the other way round, and that is the problem.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),

          _Heading('Which Minor?'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'Over two beats nobody minds that a chord symbol does not '
              'say which scale it means. Hold it for sixteen bars and it '
              'is the only question there is. ${_chord.display} is '
              '${_choices.length} different modes, and the chart will not '
              'tell you which: the tune\'s key does.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              children: [
                for (final mode in _choices)
                  ChoiceChip(
                    key: ValueKey('pick-${mode.name}'),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    label: Text('$_root ${mode.name}'),
                    selected: mode == _mode,
                    onSelected: (_) => setState(() => _mode = mode),
                  ),
              ],
            ),
          ),
          _Notes(mode: _mode, root: _root),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _mode.description,
              key: const ValueKey('about-mode'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('play-mode'),
                icon: const Icon(Icons.play_arrow),
                label: Text('Hear It Over ${_chord.display}'),
                onPressed: _play,
              ),
            ),
          ),

          _Heading('Fourths'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'A chord symbol is made of thirds, so a stack of thirds '
              'announces the chord and nothing else. Pile the same notes '
              'up in fourths instead and the ear hears the mode rather '
              'than the chord, which is what you want on a tune that has '
              'no changes to spell.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              children: [
                for (final (inFourths, label) in const [
                  (true, 'Fourths'),
                  (false, 'Thirds'),
                ])
                  ChoiceChip(
                    key: ValueKey('pick-${label.toLowerCase()}'),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    label: Text(label),
                    selected: inFourths == _inFourths,
                    onSelected: (_) => setState(() => _inFourths = inFourths),
                  ),
              ],
            ),
          ),
          _Stack(steps: _stack),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _aboutStack(),
              key: const ValueKey('about-stack'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('play-stack'),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _inFourths ? 'Hear It in Fourths' : 'Hear It in Thirds',
                ),
                onPressed: _playStack,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'On a guitar it is one finger. The bottom four strings are '
              'already tuned in fourths and the G to B is a third, so a '
              'straight barre across the top five strings is this chord: '
              'at the 10th fret it is exactly D G C F A.',
              key: const ValueKey('on-a-guitar'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),

          _Heading('The Same Thing On One Note At A Time'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text(
              'A horn cannot stack anything, so you run them instead. Not '
              'the voicing rolled out: stepping a fourth at a time through '
              'seven notes lands on every one of them before it comes '
              'home, so the line is the whole mode rather than the five '
              'notes a chord had room for.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _Line(mode: _mode, root: _root),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _aboutLine(),
              key: const ValueKey('about-line'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('play-line'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Hear It as a Line'),
                onPressed: _playLine,
              ),
            ),
          ),

          _Heading('What Carries It Instead'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Running the changes was doing more work than anybody '
              'admitted. With them gone a line has to hold up on its own, '
              'and there is no rule for that. These are what people reach '
              'for.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final idea in modalIdeas)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    idea.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    idea.about,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          _Heading('The Tunes'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '${modal.length} tunes in this app leave you on one chord '
              'for $modalStay bars or more.',
              key: const ValueKey('modal-count'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tune in modal)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${tune.title}  ${longestStay(tune)}'),
                    labelStyle: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tune's longest stay, drawn as a bar so the difference is a size
/// rather than a number to take on trust.
class _StayBar extends StatelessWidget {
  const _StayBar({
    super.key,
    required this.tune,
    required this.of,
    required this.modal,
  });

  final Tune tune;
  final int of;
  final bool modal;

  /// Room kept to the right of every bar for its number.
  static const _numberWidth = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bars = longestStay(tune);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(
              tune.title,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              // The number sits to the right of the bar, so the bar is
              // measured against what is left after room is kept for it.
              // Without that the longest stay fills the row and pushes
              // its own label off the edge.
              builder: (context, size) => Row(
                children: [
                  Container(
                    width: math.max(
                      3,
                      (size.maxWidth - _numberWidth) * bars / of,
                    ),
                    height: 16,
                    decoration: BoxDecoration(
                      color: modal
                          ? scheme.tertiary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(
                    width: _numberWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '$bars',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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

/// The mode's seven notes, with the one that makes it itself in pencil
/// red.
class _Notes extends StatelessWidget {
  const _Notes({required this.mode, required this.root});

  final Mode mode;
  final String root;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = mode.notesFrom(root);
    final colour = colourOf(mode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              key: const ValueKey('mode-notes'),
              children: [
                for (final (i, note) in notes.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      handSymbol(note),
                      textScaler: TextScaler.noScaling,
                      style: handLettered(
                        TextStyle(
                          fontSize: 22,
                          height: 1,
                          color: colour.contains(mode.degrees[i])
                              ? scheme.tertiary
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            colour.isEmpty
                ? 'Seven notes over the chord.'
                : 'The ${colour.map(degreeLabel).join(' and ')} in red is '
                      'what makes it ${mode.name} rather than one of the '
                      'others. One note out of seven, and it is the whole '
                      'difference.',
            key: const ValueKey('colour-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The chord drawn as a pile, lowest note at the bottom, with the
/// interval written beside each step up.
///
/// Stacked, because that is the word: laid out in a row it is a list of
/// notes, and standing up it is a shape you can see the evenness of.
class _Stack extends StatelessWidget {
  const _Stack({required this.steps});

  final List<StackStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        key: const ValueKey('the-stack'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final step in steps.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      handSymbol(step.note),
                      textScaler: TextScaler.noScaling,
                      style: handLettered(
                        TextStyle(
                          fontSize: 22,
                          height: 1,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (step.above case final interval?)
                    Text(
                      interval,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.tertiary,
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

/// The mode run in fourths, left to right, with the one step that is not
/// a fourth marked at both ends.
class _Line extends StatelessWidget {
  const _Line({required this.mode, required this.root});

  final Mode mode;
  final String root;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = fourthsLine(mode, root);
    final at = tritoneStep(mode, root);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          key: const ValueKey('the-line'),
          children: [
            for (final (i, step) in line.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  handSymbol(step.note),
                  textScaler: TextScaler.noScaling,
                  style: handLettered(
                    TextStyle(
                      fontSize: 22,
                      height: 1,
                      color: i == at || i == at - 1
                          ? scheme.tertiary
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A section title.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
