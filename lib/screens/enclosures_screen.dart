// Enclosures: the exercise, one shape at a time.
//
// Pick a chord and which of its notes to aim at, and each shape is written
// out on the stave, shown under the fingers, and played. The point of doing
// it this way round — the same target, five ways in — is that you stop
// hearing five licks and start hearing one idea.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/enclosures.dart';
import '../music/fretboard_arpeggio.dart';
import '../settings/app_settings.dart';
import 'chord_diagram.dart';
import 'stave.dart';

/// Which instrument the shapes are shown on.
enum _Under { keyboard, guitar, bass }

class EnclosuresScreen extends StatefulWidget {
  const EnclosuresScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<EnclosuresScreen> createState() => _EnclosuresScreenState();
}

class _EnclosuresScreenState extends State<EnclosuresScreen> {
  String _root = 'D';
  String _quality = 'm7';
  String _degree = '3';
  var _under = _Under.keyboard;

  /// The chord the line is over.
  Chord get _chord => Chord.parse('$_root$_quality');

  /// Which note of the chord is being aimed at.
  ///
  /// The degree picked stays picked as the chord changes, but a minor 7th
  /// has no major 3rd: aiming at "the 3rd" of a Dm7 has to mean its ♭3.
  /// Without this it quietly aimed at an F♯ the chord hasn't got.
  String get _aim {
    final formula = _chord.quality.formula;
    if (formula.contains(_degree)) return _degree;
    final number = _degree.replaceAll(RegExp(r'[b#]'), '');
    return formula.firstWhere(
      (degree) => degree.replaceAll(RegExp(r'[b#]'), '') == number,
      orElse: () => formula.length > 1 ? formula[1] : formula.first,
    );
  }

  /// The note being aimed at, around middle C.
  int get _target {
    final pitch = pitchClassOf(parseNoteName(_chord.noteFor(_aim))!);
    return 60 + (pitch - 60) % 12;
  }

  List<EnclosureNote> _notesFor(Enclosure enclosure) => enclosureOn(
    enclosure,
    target: _target,
    targetName: _chord.noteFor(_aim),
    scale: scaleFor(_chord),
  );

  Future<void> _play(Enclosure enclosure) async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final notes = _notesFor(enclosure);
    const step = 0.26;
    await widget.player.playSnippet(
      renderSnippet(
        bank,
        [
          // The chord underneath, so the target is heard as part of it
          // rather than as a note on its own.
          for (final interval in _chord.quality.intervals)
            (
              pitch: 48 + (_chord.root + interval - 48) % 12,
              start: 0,
              length: step * (notes.length + 1),
              velocity: 0.35,
              bass: false,
            ),
          for (final (i, note) in notes.indexed)
            (
              pitch: note.pitch + (_under == _Under.bass ? -24 : 0),
              start: 0.15 + i * step,
              length: note.isTarget ? step * 2 : step,
              velocity: note.isTarget ? 0.95 : 0.75,
              bass: _under == _Under.bass,
            ),
        ],
        guitar: _under == _Under.guitar,
        bassTone: _under == _Under.bass ? BassTone.bright : BassTone.tight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Enclosures')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'A bebop line rarely walks up to a chord tone and lands on '
              'it. It goes round it first — a note above, a note below — '
              'so the note you meant all along arrives sounding '
              'inevitable. Five ways round the same note.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Under>(
                key: const ValueKey('enclosure-under'),
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
          _Chips(
            label: 'Over',
            values: const [
              ('m7', 'm7'),
              ('7', '7'),
              ('^7', 'Δ7'),
              ('m7b5', 'ø7'),
              ('o7', '°7'),
            ],
            selected: _quality,
            onPick: (value) => setState(() => _quality = value),
          ),
          _Chips(
            label: 'Root',
            values: const [
              ('C', 'C'),
              ('D', 'D'),
              ('E♭', 'E♭'),
              ('F', 'F'),
              ('G', 'G'),
              ('A', 'A'),
              ('B♭', 'B♭'),
            ],
            selected: _root,
            onPick: (value) => setState(() => _root = value),
          ),
          _Chips(
            label: 'Aim for',
            values: [
              for (final degree in _chord.quality.formula)
                (degree, prettyDegree(degree)),
            ],
            selected: _aim,
            onPick: (value) => setState(() => _degree = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Aiming at the ${prettyDegree(_aim)} of '
              '${_chord.display}: ${_chord.noteFor(_aim)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final enclosure in enclosures)
            _EnclosureCard(
              enclosure: enclosure,
              notes: _notesFor(enclosure),
              under: _under,
              onPlay: () => _play(enclosure),
            ),
        ],
      ),
    );
  }
}

/// A labelled row of chips that scrolls sideways.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.label,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final String label;

  /// Each one its value and what to write on it.
  final List<(String, String)> values;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 74,
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
          ),
        ],
      ),
    );
  }
}

/// One shape: what it is, written out, and under the fingers.
class _EnclosureCard extends StatelessWidget {
  const _EnclosureCard({
    required this.enclosure,
    required this.notes,
    required this.under,
    required this.onPlay,
  });

  final Enclosure enclosure;
  final List<EnclosureNote> notes;
  final _Under under;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('enclosure-${enclosure.name}'),
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        enclosure.name,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Icon(
                      Icons.play_arrow,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [for (final note in notes) note.name].join('  →  '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stave(
                        key: const ValueKey('enclosure-stave'),
                        clef: under == _Under.bass ? Clef.bass : Clef.treble,
                        notes: lineOnStave(
                          [
                            for (final note in notes)
                              (pitch: note.pitch, name: note.name),
                          ],
                          clef: under == _Under.bass ? Clef.bass : Clef.treble,
                          marked: {notes.length - 1},
                        ),
                        semanticsLabel:
                            '${enclosure.name}: '
                            '${[for (final n in notes) n.name].join(', ')}',
                      ),
                      const SizedBox(width: 16),
                      _UnderTheFingers(notes: notes, under: under),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(enclosure.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same notes where you actually play them.
class _UnderTheFingers extends StatelessWidget {
  const _UnderTheFingers({required this.notes, required this.under});

  final List<EnclosureNote> notes;
  final _Under under;

  @override
  Widget build(BuildContext context) {
    if (under == _Under.keyboard) {
      final lowest = notes.map((n) => n.pitch).reduce((a, b) => a < b ? a : b);
      final scale = ScaleKeyboard(
        root: lowest % 12,
        semitones: [for (final note in notes) note.pitch - lowest]..sort(),
        colour: {notes.last.pitch - lowest},
      );
      return SizedBox(height: 54, width: 54 * scale.aspect, child: scale);
    }
    final shape = _onTheNeck(notes, bass: under == _Under.bass);
    if (shape == null) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      width: 92 * ArpeggioDiagram.aspectFor(shape),
      child: ArpeggioDiagram(shape: shape),
    );
  }
}

/// The notes on a neck, each on the lowest string that can reach it without
/// the hand moving. Null when they won't sit in one position.
FretArpeggio? _onTheNeck(List<EnclosureNote> notes, {required bool bass}) {
  final tuning = bass ? bassOpenStrings : guitarOpenStrings;
  // Bass sounds an octave below where the enclosure is written.
  final pitches = [for (final note in notes) note.pitch - (bass ? 24 : 0)];
  final lowest = pitches.reduce((a, b) => a < b ? a : b);
  // Start the hand where the lowest note can be played above the nut.
  for (var first = 1; first <= 15; first++) {
    final placed = <FretNote>[];
    for (final (i, pitch) in pitches.indexed) {
      for (var string = 0; string < tuning.length; string++) {
        final fret = pitch - tuning[string];
        if (fret < first || fret > first + 4) continue;
        placed.add((
          string: string,
          fret: fret,
          pitch: pitch,
          degree: notes[i].isTarget ? '●' : '${i + 1}',
        ));
        break;
      }
    }
    if (placed.length == pitches.length && lowest >= tuning.first + first) {
      return FretArpeggio(
        tuning: tuning,
        rootString: bass ? 4 : 6,
        notes: placed,
      );
    }
  }
  return null;
}
