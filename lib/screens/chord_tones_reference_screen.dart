import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drill_sounds.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/fretboard_arpeggio.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';
import 'chord_diagram.dart';
import 'stave.dart';

/// The notes in every kind of chord, in any key: each chord tone lined up
/// under its degree (1 3 5 7), the extensions players add, and where they
/// sit on the keys, each one to hear as an arpeggio.
///
/// For a B♭, E♭ or F instrument the chords are the ones you read: each card
/// says what it sounds as, and plays at that real pitch.
///
/// On the guitar and bass, each chord's arpeggio in one position from a
/// root on the lowest string and on the next (the guitar's 6th and 5th, the
/// bass's E and A), every note marked with its degree, to hear in the order
/// it's played. Both read at concert pitch, so there's no transposing there.
class ChordTonesReferenceScreen extends StatefulWidget {
  const ChordTonesReferenceScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  /// The keys to choose from, spelled as they're usually written.
  static const roots = [
    'C', 'D♭', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B', //
  ];

  @override
  State<ChordTonesReferenceScreen> createState() =>
      _ChordTonesReferenceScreenState();
}

/// How the chords are shown: on the keys, or as guitar or bass arpeggios.
enum ChordTonesView { keyboard, guitar, bass }

class _ChordTonesReferenceScreenState extends State<ChordTonesReferenceScreen> {
  String _root = 'C';
  String _query = '';

  /// Guitarists and bassists (those who show guitar chord boxes or the bass
  /// fretboard while playing) start on their own instrument.
  late var _view = switch (widget.settings.diagram) {
    ChordDiagram.guitar || ChordDiagram.barre => ChordTonesView.guitar,
    ChordDiagram.bass => ChordTonesView.bass,
    _ => ChordTonesView.keyboard,
  };

  Future<void> _playShape(FretArpeggio shape) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        fretArpeggioSnippet(shape),
        guitar: !shape.isBass,
        bassTone: shape.isBass ? BassTone.bright : BassTone.natural,
      ),
    );
  }

  /// Plays [chord] (written for the player's instrument) as an arpeggio,
  /// at concert pitch.
  Future<void> _play(Chord chord) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    await widget.player.playSnippet(
      renderSnippet(bank, chordArpeggioSnippet(_concert(chord))),
    );
  }

  /// What a chord written for the player's instrument sounds as.
  Chord _concert(Chord written) {
    final move = widget.settings.instrument.transposition;
    return written.transposed(
      Transposition(
        letterSteps: (7 - move.letterSteps) % 7,
        semitones: (12 - move.semitones) % 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final fretted = _view != ChordTonesView.keyboard;
    // Guitar and bass read at concert pitch.
    final instrument = fretted
        ? ChartInstrument.concert
        : widget.settings.instrument;
    final chords = [
      for (final quality in chordQualities)
        if (query.isEmpty ||
            quality.name.toLowerCase().contains(query) ||
            quality.symbols
                .map(prettyQuality)
                .join(' ')
                .toLowerCase()
                .contains(query))
          Chord.parse('$_root${quality.symbols.first}'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Chord Tones')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ChordTonesView>(
                key: const ValueKey('chord-tones-view'),
                segments: const [
                  ButtonSegment(
                    value: ChordTonesView.keyboard,
                    label: Text('Keyboard'),
                  ),
                  ButtonSegment(
                    value: ChordTonesView.guitar,
                    label: Text('Guitar'),
                  ),
                  ButtonSegment(
                    value: ChordTonesView.bass,
                    label: Text('Bass'),
                  ),
                ],
                selected: {_view},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _view = value.first),
              ),
            ),
          ),
          if (!fretted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: InstrumentKeyPicker(
                instrument: instrument,
                onChanged: widget.settings.setInstrument,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search, e.g. "minor" or "ø"',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          // Every key, all built at once so each can be reached directly.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                for (final root in ChordTonesReferenceScreen.roots)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('root-$root'),
                      label: Text(root),
                      showCheckmark: false,
                      selected: root == _root,
                      onSelected: (_) => setState(() => _root = root),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: chords.isEmpty
                ? const Center(child: Text('No matching chords'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: chords.length,
                    itemBuilder: (context, index) {
                      final chord = chords[index];
                      final shapes = switch (_view) {
                        ChordTonesView.keyboard => null,
                        ChordTonesView.guitar => [
                          for (final string in [6, 5])
                            ?guitarArpeggio(chord, rootString: string),
                        ],
                        ChordTonesView.bass => [
                          for (final string in [4, 3])
                            ?bassArpeggio(chord, rootString: string),
                        ],
                      };
                      return _ChordTonesCard(
                        chord: chord,
                        soundsAs: instrument == ChartInstrument.concert
                            ? null
                            : _concert(chord),
                        onPlay: shapes == null || shapes.isEmpty
                            ? () => _play(chord)
                            : () => _playShape(shapes.first),
                        shapes: shapes,
                        onPlayShape: _playShape,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChordTonesCard extends StatelessWidget {
  const _ChordTonesCard({
    required this.chord,
    required this.soundsAs,
    required this.onPlay,
    this.shapes,
    required this.onPlayShape,
  });

  final Chord chord;

  /// For a transposing instrument, the chord at concert pitch.
  final Chord? soundsAs;
  final VoidCallback onPlay;

  /// On the guitar or bass, the chord's arpeggio shapes (from the lowest
  /// string, then the next) in place of the keyboard.
  final List<FretArpeggio>? shapes;
  final ValueChanged<FretArpeggio> onPlayShape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quality = chord.quality;
    // The chord's own notes (1 3 5 7, and a 9th or 13th if it's in the
    // name), then the extensions players add; each a column, the degree
    // above the note.
    final tones = [
      for (var i = 0; i < quality.formula.length; i++)
        (prettyDegree(quality.formula[i]), chord.noteNames[i]),
    ];
    final extensions = [
      for (final extension in chord.extensionNotes)
        (extension.degree, extension.note),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  chord.display,
                  style: handLettered(theme.textTheme.headlineMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quality.name, style: theme.textTheme.titleSmall),
                      if (soundsAs != null)
                        Text(
                          'Sounds as ${soundsAs!.display}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Hear ${chord.display}',
                  onPressed: onPlay,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final (degree, note) in tones)
                  _Tone(degree: degree, note: note, strong: true),
                for (final (degree, note) in extensions)
                  _Tone(degree: degree, note: note, strong: false),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // As written: stacked on the stave (in bass clef for the
                // bass).
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Stave(
                      key: const ValueKey('chord-stave'),
                      notes: chordOnStave(
                        chord,
                        clef: shapes?.firstOrNull?.isBass ?? false
                            ? Clef.bass
                            : Clef.treble,
                      ),
                      clef: shapes?.firstOrNull?.isBass ?? false
                          ? Clef.bass
                          : Clef.treble,
                      chord: true,
                      space: 9,
                      semanticsLabel:
                          '${chord.display} on the stave: '
                          '${chord.noteNames.join(', ')}',
                    ),
                  ),
                ),
                if (shapes == null) ...[
                  const Spacer(),
                  // Where they sit on the keys, in root position.
                  SizedBox(
                    height: 44,
                    width:
                        44 * KeyboardDiagram.aspectFor(chord.withoutExtensions),
                    child: KeyboardDiagram(chord: chord.withoutExtensions),
                  ),
                ],
              ],
            ),
            if (shapes != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, shape) in shapes!.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _Shape(
                        chord: chord,
                        shape: shape,
                        onPlay: () => onPlayShape(shape),
                      ),
                    ),
                  ],
                  // One shape only: keep it the size it would be beside
                  // another.
                  if (shapes!.length == 1) ...[
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One arpeggio shape: which string the root is on, and the fretboard.
/// Tap either to hear it.
class _Shape extends StatelessWidget {
  const _Shape({
    required this.chord,
    required this.shape,
    required this.onPlay,
  });

  final Chord chord;
  final FretArpeggio shape;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Guitarists number the strings; bassists name them.
    final string = switch (shape.rootString) {
      6 => '6th',
      5 => '5th',
      4 => 'E',
      _ => 'A',
    };
    return Semantics(
      button: true,
      label:
          '${chord.display} arpeggio, root on the $string string, '
          'from fret ${shape.lowestFret}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('shape-${shape.rootString}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      'Root on $string string',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Strings as far apart as the guitar's, so a bass's four
              // strings take less of the width rather than growing tall.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      constraints.maxWidth *
                      ArpeggioDiagram.widthInStrings(shape) /
                      (guitarOpenStrings.length + 0.4);
                  return SizedBox(
                    width: width,
                    height: width / ArpeggioDiagram.aspectFor(shape),
                    child: ArpeggioDiagram(shape: shape),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chord tone: its degree above, the note below.
class _Tone extends StatelessWidget {
  const _Tone({required this.degree, required this.note, required this.strong});

  final String degree;
  final String note;

  /// A tone of the chord itself, rather than an extension.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: strong ? scheme.secondaryContainer : null,
        border: strong ? null : Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            degree,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            note,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: strong ? scheme.onSecondaryContainer : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
