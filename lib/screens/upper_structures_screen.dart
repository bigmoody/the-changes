// Upper structures: a triad you already know, on top of a chord you
// have to think about.
//
// The triad's name is the biggest thing on the screen, because it is the
// thing to remember. Everything under it (what each note turns into,
// what the whole chord is called) is the explanation, and the
// explanation is not what you reach for at a hundred and eighty.
//
// Two buttons, the plain dominant and the one with the triad on it,
// because the sound is the argument and a list of alterations is not.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/guitar_voicing.dart';
import '../music/upper_structures.dart';
import '../music/voicings.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chord_diagram.dart';

/// Dominants to hear it over. Three is enough to show the triad moves
/// with the chord rather than being a fact about C.
const _dominants = ['C7', 'F7', 'G7'];

class UpperStructuresScreen extends StatefulWidget {
  const UpperStructuresScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<UpperStructuresScreen> createState() => _UpperStructuresScreenState();
}

class _UpperStructuresScreenState extends State<UpperStructuresScreen> {
  var _structure = upperStructures.first;
  var _symbol = _dominants.first;

  Chord get _chord => Chord.parse(_symbol);
  List<int> get _triad => triadOver(_chord, _structure);

  /// The chord underneath: its root in the bass and the two notes that
  /// say it is a dominant. Anything more and the triad has to fight it.
  List<int> get _under {
    final shell = Voicing.shell.on(_chord).map((n) => n.pitch).toList();
    return [shell.first - 12, ...shell.skip(1)];
  }

  Future<void> _play({required bool withTriad}) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final pitches = [..._under, if (withTriad) ..._triad];
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final (i, pitch) in pitches.indexed)
          (
            pitch: pitch,
            start: i * 0.04,
            length: 2.8 - i * 0.04,
            velocity: 0.55,
            bass: false,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tensions = tensionsOf(_chord, _structure);
    final keyboard = VoicingKeyboard(
      pitches: [..._under, ..._triad],
      chord: _chord,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Upper Structures')),
      body: ListView(
        key: const ValueKey('upper-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'An altered dominant is a lot to spell and a plain triad is '
              'three notes you have known for years. Put the triad on top '
              'of the chord and you have played the alterations without '
              'having worked any of them out.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [
              for (final structure in upperStructures)
                (structure.roman, structure.roman),
            ],
            selected: _structure.roman,
            onPick: (roman) => setState(
              () => _structure = upperStructures.firstWhere(
                (s) => s.roman == roman,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${handSymbol(triadName(_chord, _structure))} over '
                        '${handSymbol(_chord.display)}',
                        key: const ValueKey('the-triad'),
                        textScaler: TextScaler.noScaling,
                        style: handLettered(
                          TextStyle(
                            fontSize: 26,
                            height: 1.1,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'is ${symbolOver(_chord, _structure)}',
                        key: const ValueKey('the-symbol'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              key: const ValueKey('the-tensions'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, pitch) in _triad.indexed.toList().reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            handSymbol(_noteName(pitch)),
                            textScaler: TextScaler.noScaling,
                            style: handLettered(
                              TextStyle(
                                fontSize: 20,
                                height: 1,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'the ${tensions[i]} of ${_chord.display}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SizedBox(
              height: 62,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AspectRatio(
                  key: const ValueKey('the-keys'),
                  aspectRatio: keyboard.aspect,
                  child: keyboard,
                ),
              ),
            ),
          ),
          _OnTheGuitar(triad: Chord.parse(triadName(_chord, _structure))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _structure.about,
              key: const ValueKey('about-structure'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
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
                    label: Text(handSymbol(_chord.display)),
                    onPressed: () => _play(withTriad: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('play-structure'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('With It On'),
                    onPressed: () => _play(withTriad: true),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text('Over', style: theme.textTheme.titleSmall),
          ),
          _Chips(
            values: [
              for (final symbol in _dominants)
                (symbol, handSymbol(Chord.parse(symbol).display)),
            ],
            selected: _symbol,
            onPick: (symbol) => setState(() => _symbol = symbol),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'The bass has the root and the chord underneath is only its '
              '3rd and ♭7, because those two say it is a dominant and '
              'anything else would be in the triad\'s way.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A note name for a pitch, spelled off the triad it belongs to.
  String _noteName(int pitch) {
    final triad = Chord.parse(triadName(_chord, _structure));
    return triad.noteFor(switch ((pitch - triad.root) % 12) {
      4 => '3',
      7 => '5',
      _ => '1',
    });
  }
}

/// The triad on the top three strings, all three ways up.
///
/// A guitarist does not play "the A triad", they play whichever A triad
/// is under the hand, so the three inversions in a row are the useful
/// thing rather than one shape somewhere on the neck. Top three strings
/// because something else has the bottom of the chord: that is what
/// makes it an upper structure.
class _OnTheGuitar extends StatelessWidget {
  const _OnTheGuitar({required this.triad});

  final Chord triad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shapes = triadInversions(triad);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        key: const ValueKey('on-the-guitar'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On the top three strings',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'All three ways up, so whichever is nearest your hand is the '
            'one to play. Something else has the bottom of the chord, '
            'which is what makes it an upper structure.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, shape) in shapes.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inversionNames[i],
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AspectRatio(
                          aspectRatio: GuitarDiagram.aspect,
                          child: shape == null
                              ? const SizedBox.shrink()
                              : GuitarDiagram(
                                  key: ValueKey('inversion-$i'),
                                  chord: triad,
                                  voicing: shape,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
