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
import '../music/voicings.dart';
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
          _Stack(notes: notes),
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
