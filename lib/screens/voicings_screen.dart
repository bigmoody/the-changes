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
