import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/key_order.dart' show KeyOrder;
import '../music/mode_examples.dart';
import '../music/scales.dart';
import '../music/tune_library.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';
import 'chord_diagram.dart';
import 'chord_tones_reference_screen.dart';
import 'key_round.dart';
import 'mode_example_row.dart';
import 'practice_screen.dart';
import 'stave.dart';

/// Every mode, in any key: its notes under their degrees, the chord it goes
/// with, the notes that give it its sound, and where it sits on the keys,
/// each one to hear, up and down.
///
/// For a B♭, E♭ or F instrument the keys are the ones you read: each card
/// says what it sounds as, and plays at that real pitch.
class ScalesReferenceScreen extends StatefulWidget {
  const ScalesReferenceScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ScalesReferenceScreen> createState() => _ScalesReferenceScreenState();
}

class _ScalesReferenceScreenState extends State<ScalesReferenceScreen> {
  /// The round of keys: which order they come in, where in it we are,
  /// and which have been through.
  ///
  /// Chromatic to begin with, unlike the drills, because this is
  /// somewhere you come to look something up as well as somewhere you
  /// work: going up in semitones is how somebody finds the key they
  /// wanted. The cycle is a menu away when it is a round you want.
  var _order = KeyOrder.chromatic;
  late List<int> _moves = _order.moves();
  var _at = 0;
  final _done = <int>{};

  /// The key showing, spelled as the reference has always spelled them.
  String get _root => ChordTonesReferenceScreen.roots[_moves[_at] % 12];

  String _keyName(int by) => ChordTonesReferenceScreen.roots[by % 12];

  void _goTo(int index) {
    setState(() {
      _done.add(_moves[_at]);
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

  /// The family shown, or null for every mode.
  ScaleFamily? _family;

  /// Which clef the modes are written in: bass players read their own.
  late var _clef = widget.settings.diagram == ChordDiagram.bass
      ? Clef.bass
      : Clef.treble;
  final _list = ScrollController();

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  /// [root] as written for the player's instrument, at concert pitch.
  String _concert(String root) {
    final move = widget.settings.instrument.transposition;
    return Chord.parse(root)
        .transposed(
          Transposition(
            letterSteps: (7 - move.letterSteps) % 7,
            semitones: (12 - move.semitones) % 12,
          ),
        )
        .rootName;
  }

  /// Opens [title] with the band, to hear the mode where it lives.
  void _openTune(String title) {
    final tune = standards.where((t) => t.title == title).firstOrNull;
    if (tune == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          tune: tune,
          player: widget.player,
          settings: widget.settings,
        ),
      ),
    );
  }

  Future<void> _play(Mode mode) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final chord = mode.chordOn(_concert(_root));
    // In bass clef it's played an octave down, roughly where it's written,
    // but on the piano, not the bass. Down on the recorded bass it turned
    // into a rumble: two octaves below this the notes are under 70 Hz, and
    // a phone can't reproduce them, so all that's left is the thud of the
    // body. The piano an octave down is the same register a bass player
    // reads and you can hear every note of it.
    final notes = modeSnippet(mode.semitones, chord.root);
    final down = _clef == Clef.bass ? 12 : 0;
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final note in notes)
          (
            pitch: note.pitch - down,
            start: note.start,
            length: note.length,
            velocity: note.velocity,
            bass: false,
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final instrument = widget.settings.instrument;
    final shown = [
      for (final mode in modes)
        if (_family == null || mode.family == _family) mode,
    ];

    Widget chips<T>(
      List<T> values,
      String Function(T) label,
      String Function(T) key,
      bool Function(T) selected,
      ValueChanged<T> onSelected,
    ) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey(key(value)),
                label: Text(label(value)),
                showCheckmark: false,
                selected: selected(value),
                onSelected: (_) => onSelected(value),
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scales & Modes'),
        actions: [KeyOrderButton(order: _order, onPick: _setOrder)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: InstrumentKeyPicker(
              instrument: instrument,
              onChanged: widget.settings.setInstrument,
            ),
          ),
          chips<Clef>(
            const [Clef.treble, Clef.bass],
            (clef) => clef == Clef.bass ? 'Bass Clef' : 'Treble Clef',
            (clef) => 'clef-${clef.name}',
            (clef) => clef == _clef,
            (clef) => setState(() => _clef = clef),
          ),
          chips<ScaleFamily?>(
            [null, ...ScaleFamily.values],
            (family) => family?.label ?? 'All',
            (family) => 'family-${family?.name ?? 'all'}',
            (family) => family == _family,
            (family) {
              setState(() => _family = family);
              // Back to the family's first mode.
              if (_list.hasClients) _list.jumpTo(0);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: KeyChips(
              moves: _moves,
              label: _keyName,
              at: _at,
              done: _done,
              onPick: _goTo,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _list,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final mode = shown[index];
                return _ModeCard(
                  mode: mode,
                  root: _root,
                  clef: _clef,
                  soundsAs: instrument == ChartInstrument.concert
                      ? null
                      : _concert(_root),
                  onPlay: () => _play(mode),
                  onTune: _openTune,
                );
              },
            ),
          ),
          KeyStep(onBack: () => _goTo(_at - 1), onNext: () => _goTo(_at + 1)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.root,
    required this.clef,
    required this.soundsAs,
    required this.onPlay,
    required this.onTune,
  });

  final Mode mode;

  /// Opens a tune the mode is heard in.
  final ValueChanged<String> onTune;

  /// The root as written.
  final String root;

  /// Which clef it's written in.
  final Clef clef;

  /// For a transposing instrument, the root at concert pitch.
  final String? soundsAs;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spelled = mode.spelledRoot(root);
    final title = '$spelled ${mode.name}';
    final notes = mode.notesFrom(root);
    final chord = mode.chordOn(root);
    final colourNotes = [
      for (var i = 0; i < mode.degrees.length; i++)
        if (mode.colour.contains(mode.degrees[i]))
          '${prettyDegree(mode.degrees[i])} (${notes[i]})',
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: handLettered(theme.textTheme.headlineSmall)
                            .copyWith(height: 1.15),
                      ),
                      Text(
                        mode.parentFrom(root),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (mode.alsoKnownAs != null)
                        Text('Also called ${mode.alsoKnownAs}', style: muted),
                      if (soundsAs != null)
                        Text(
                          'Sounds as ${mode.spelledRoot(soundsAs!)} '
                          '${mode.name}',
                          style: muted,
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Hear $title',
                  onPressed: onPlay,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var i = 0; i < mode.degrees.length; i++)
                  _Degree(
                    degree: prettyDegree(mode.degrees[i]),
                    note: notes[i],
                    colour: mode.colour.contains(mode.degrees[i]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Written out, root to root, its sound in pencil.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Stave(
                key: const ValueKey('scale-stave'),
                notes: scaleOnStave(
                  notes,
                  clef: clef,
                  marked: {
                    for (var i = 0; i < mode.degrees.length; i++)
                      if (mode.colour.contains(mode.degrees[i])) i,
                  },
                ),
                clef: clef,
                space: 8,
                semanticsLabel: '$title on the stave: ${notes.join(', ')}',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Over '),
                            TextSpan(
                              text: chord.display,
                              style: handLettered(
                                const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (colourNotes.isNotEmpty)
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Its sound: '),
                              TextSpan(
                                text: colourNotes.join(', '),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final keys = ScaleKeyboard(
                      root: chord.root,
                      semitones: mode.semitones,
                      colour: {
                        for (final d in mode.colour) degreeToSemitones(d),
                      },
                    );
                    return SizedBox(
                      height: 44,
                      width: 44 * keys.aspect,
                      child: keys,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(mode.description, style: theme.textTheme.bodyMedium),
            // Where it is heard: a sound is what makes a mode stick, and a
            // tune to play it in is a sound you can go and get.
            if (modeExamples[mode.name] case final examples?) ...[
              const SizedBox(height: 12),
              Text('Heard In', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final example in examples)
                ModeExampleRow(example: example, onTune: onTune),
            ],
          ],
        ),
      ),
    );
  }
}

/// One note of the mode: its degree above, the note below. The notes that
/// give the mode its sound stand out.
class _Degree extends StatelessWidget {
  const _Degree({
    required this.degree,
    required this.note,
    required this.colour,
  });

  final String degree;
  final String note;
  final bool colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: colour ? scheme.tertiaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            degree,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colour
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          Text(
            note,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colour
                  ? scheme.onTertiaryContainer
                  : scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
