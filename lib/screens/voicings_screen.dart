// Voicings: the same chord, arranged six ways.
//
// Drawn standing up, because a voicing is a stack and a row of note
// names is not one. The dropped voice is in pencil red, so what "drop 2"
// means is a thing you can see rather than a rule you have to hold in
// your head while counting down from the top.
//
// Two buttons wherever there is something to compare: the close voicing
// and the one being looked at. A drop is only interesting against the
// thing it was dropped from.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/guitar_voicing.dart';
import '../music/voicings.dart';
import 'chord_diagram.dart';
import '../settings/app_settings.dart';
import '../theme.dart';

/// Chords worth seeing it on: a major 7th, a minor 7th and a dominant,
/// which between them cover what a ii–V–I is made of.
const _chords = ['C^7', 'Dm7', 'G7'];

class VoicingsScreen extends StatefulWidget {
  const VoicingsScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<VoicingsScreen> createState() => _VoicingsScreenState();
}

class _VoicingsScreenState extends State<VoicingsScreen> {
  var _voicing = Voicing.close;
  var _symbol = _chords.first;

  Chord get _chord => Chord.parse(_symbol);
  List<VoicedNote> get _notes => _voicing.on(_chord);

  /// Rolled quickly from the bottom, the way anybody puts a spread
  /// voicing down: struck dead together it reads as a block rather than
  /// as an arrangement of voices.
  Future<void> _play(List<VoicedNote> notes) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final (i, note) in notes.indexed)
          (
            pitch: note.pitch,
            start: i * 0.045,
            length: 2.6 - i * 0.045,
            velocity: 0.6,
            bass: false,
          ),
      ]),
    );
  }

  /// A run of chords, one after the other rather than all at once.
  Future<void> _playRun(List<List<VoicedNote>> chords) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const bar = 1.1;
    await widget.player.playSnippet(
      renderSnippet(bank, [
        for (final (i, chord) in chords.indexed)
          for (final note in chord)
            (
              pitch: note.pitch,
              start: i * bar,
              length: i == chords.length - 1 ? 2.2 : bar * 0.95,
              velocity: 0.58,
              bass: false,
            ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = _notes;
    final span = spanOf(notes);
    return Scaffold(
      appBar: AppBar(title: const Text('Voicings')),
      body: ListView(
        key: const ValueKey('voicings-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'A chord symbol names the notes and says nothing about '
              'where to put them, and where you put them is most of what '
              'a chord sounds like.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          _Chips(
            values: [
              for (final voicing in Voicing.values)
                (voicing.name, voicing.label),
            ],
            selected: _voicing.name,
            onPick: (name) => setState(
              () => _voicing = Voicing.values.firstWhere((v) => v.name == name),
            ),
          ),
          _UnderTheHands(notes: notes, chord: _chord),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              span > 12
                  ? 'Spans $span semitones. Close position never goes past '
                        'twelve, which is the whole point of dropping one.'
                  : 'Spans $span semitones, so it sits inside an octave.',
              key: const ValueKey('the-span'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _voicing.whyCalled,
              key: const ValueKey('why-called'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _voicing.about,
              key: const ValueKey('about-voicing'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (_voicing != Voicing.close) ...[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('play-close'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Close'),
                      onPressed: () => _play(Voicing.close.on(_chord)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('play-voicing'),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_voicing.label),
                    onPressed: () => _play(notes),
                  ),
                ),
              ],
            ),
          ),
          if (_voicing == Voicing.shell) _Shells(root: _chord),
          if (_voicing == Voicing.rootSeventh || _voicing == Voicing.rootThird)
            _Alternating(
              from7th: _voicing == Voicing.rootSeventh,
              onPlay: _playRun,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text('On', style: theme.textTheme.titleSmall),
          ),
          _Chips(
            values: [
              for (final symbol in _chords)
                (symbol, handSymbol(Chord.parse(symbol).display)),
            ],
            selected: _symbol,
            onPick: (symbol) => setState(() => _symbol = symbol),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'Fourths are the other family worth knowing and they have '
              'their own place, under Modal, because they belong to a '
              'tune with no changes to spell.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ii–V–I with the two forms swapped chord by chord, and what that
/// does to the note on top.
///
/// The reason there are two of them. Alone, either form is just a pair
/// of notes; alternated, the upper voice steps instead of leaping, and
/// that is the whole of why a bebop left hand sounds joined up.
class _Alternating extends StatelessWidget {
  const _Alternating({required this.from7th, required this.onPlay});

  final bool from7th;
  final ValueChanged<List<List<VoicedNote>>> onPlay;

  /// A ii–V–I in C, because it is the progression everybody has under
  /// their hands already.
  static final _changes = [
    Chord.parse('Dm7'),
    Chord.parse('G7'),
    Chord.parse('C^7'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = alternatingShells(_changes, from7th: from7th);
    final tops = [for (final row in rows) row.last];
    final steps = [
      for (var i = 1; i < tops.length; i++)
        (tops[i].pitch - tops[i - 1].pitch).abs(),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        key: const ValueKey('alternating'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why There Are Two', style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'A ii–V–I with the forms swapped chord by chord. Watch the '
            'top note rather than the chords: it is the note doing the '
            'work, and it hardly moves.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, row) in rows.indexed)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        handSymbol(_changes[i].display),
                        textScaler: TextScaler.noScaling,
                        style: handLettered(
                          TextStyle(
                            fontSize: 18,
                            height: 1,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final note in row.reversed)
                        Text(
                          '${handSymbol(note.note)}  ${note.degree}',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 12,
                            color: note == row.last
                                ? scheme.tertiary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            steps.every((step) => step <= 2)
                ? 'The top note moves '
                      '${steps.map((s) => s == 0 ? 'not at all' : '$s semitone${s == 1 ? '' : 's'}').join(', then ')}. '
                      'The hand stays where it is and the chords change '
                      'underneath it.'
                : 'The top note moves '
                      '${steps.join(' then ')} semitones.',
            key: const ValueKey('how-far-it-moves'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.tertiary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('play-alternating'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Hear the ii–V–I'),
                onPressed: () => onPlay(rows),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shells on the guitar: three qualities, from each of the two
/// strings a root is usually taken from.
///
/// The first six shapes a jazz guitarist learns, and between them most
/// of what a rhythm player does all night. They are here rather than on
/// a page of their own because a shell is what they are, and a guitarist
/// reading about shells wants to see these.
class _Shells extends StatelessWidget {
  const _Shells({required this.root});

  final Chord root;

  static const _qualities = [('^7', 'maj 7'), ('m7', 'min 7'), ('7', 'dom 7')];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        key: const ValueKey('the-shells'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shells on the Guitar', style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'The same three notes with the root on the sixth string, then '
            'on the fifth. The gap in the middle is a string your hand '
            'mutes, and it is what lets the shape stay put while the '
            'chords go past.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          for (final (string, label) in const [
            (0, 'Root on the 6th string'),
            (1, 'Root on the 5th string'),
          ]) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                ),
              ),
            ),
            Row(
              children: [
                for (final (quality, written) in _qualities)
                  Expanded(
                    child: _Shell(
                      chord: Chord.parse('${root.rootName}$quality'),
                      rootString: string,
                      label: written,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One shell shape, named.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.chord,
    required this.rootString,
    required this.label,
  });

  final Chord chord;
  final int rootString;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = shellShape(chord, rootString: rootString);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${handSymbol(chord.display)}  $label',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          AspectRatio(
            aspectRatio: GuitarDiagram.aspect,
            child: shape == null
                ? const SizedBox.shrink()
                : GuitarDiagram(
                    key: ValueKey('shell-${chord.display}-$rootString'),
                    chord: chord,
                    voicing: shape,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The voicing three ways: written out, on the keys, and on the neck.
///
/// The guitar box is beside the written stack because it is narrow and
/// the stack is not, and the keyboard goes underneath where it can have
/// the width a spread voicing needs.
class _UnderTheHands extends StatelessWidget {
  const _UnderTheHands({required this.notes, required this.chord});

  final List<VoicedNote> notes;
  final Chord chord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pitches = [for (final note in notes) note.pitch];
    final shape = shapeForPitches(pitches);
    final keyboard = VoicingKeyboard(pitches: pitches, chord: chord);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Stack(notes: notes)),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 16, 0),
              child: SizedBox(
                width: 104,
                height: 104 / GuitarDiagram.aspect,
                child: shape == null
                    ? _NotOnAGuitar(key: const ValueKey('not-on-a-guitar'))
                    : GuitarDiagram(
                        key: const ValueKey('the-shape'),
                        chord: chord,
                        voicing: shape,
                      ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
        if (shape == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'No guitar shape for this one: the notes are where they '
              'are, and six strings tuned the way they are cannot reach '
              'them. Which is a real answer rather than a gap.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// What stands in for the chord box when the guitar cannot play it.
class _NotOnAGuitar extends StatelessWidget {
  const _NotOnAGuitar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          'not on a\nguitar',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The voicing drawn as a stack, lowest note at the bottom, with the
/// degree beside each note and the moved voice in pencil red.
class _Stack extends StatelessWidget {
  const _Stack({required this.notes});

  final List<VoicedNote> notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        key: const ValueKey('the-voicing'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      handSymbol(note.note),
                      textScaler: TextScaler.noScaling,
                      style: handLettered(
                        TextStyle(
                          fontSize: 22,
                          height: 1,
                          color: note.moved
                              ? scheme.tertiary
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    note.moved ? '${note.degree}, dropped' : note.degree,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: note.moved
                          ? scheme.tertiary
                          : scheme.onSurfaceVariant,
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
