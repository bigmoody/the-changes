// Where phrases start: the same notes, moved, so the difference is the
// placement and nothing else.
//
// The notes are deliberately dull (four from a number pattern over one
// chord) because the moment the line is interesting you stop hearing
// where it began. A click on every beat goes under it, so there is
// something to be early or late against; without that the whole thing is
// inaudible.

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/number_patterns.dart';
import '../music/phrasing.dart';
import '../settings/app_settings.dart';
import 'stave_figure.dart';

class PhrasingScreen extends StatefulWidget {
  const PhrasingScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<PhrasingScreen> createState() => _PhrasingScreenState();
}

class _PhrasingScreenState extends State<PhrasingScreen> {
  var _placement = placements.first;
  var _accent = Accent.upbeats;

  /// One chord and four notes off it, kept plain on purpose: an
  /// interesting line would take the attention off where it starts.
  static final _chord = Chord.parse('Dm7');
  static const _degrees = [1, 2, 3, 5];

  List<PatternNote> get _notes => patternOn(_degrees, _chord);

  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    const quaver = 0.24;
    // Two bars, so a phrase that comes in before the bar or runs over it
    // has somewhere to do it.
    const bars = 2;
    final notes = <SnippetNote>[];
    // A click on every beat, so the line has something to be early or
    // late against: a rim click rather than a note, because a pitched
    // metronome under a pitched exercise is one more thing to listen to.
    final clicks = <SnippetDrum>[];
    for (var bar = 0; bar < bars; bar++) {
      notes.add((
        pitch: 38 + (_chord.root - 38) % 12,
        start: bar * 8 * quaver,
        length: 8 * quaver,
        velocity: 0.3,
        bass: true,
      ));
      for (var beat = 0; beat < 4; beat++) {
        final downbeat = beat == 0;
        clicks.add((
          at: (bar * 8 + beat * 2) * quaver,
          drum: Drum.crossStick,
          velocity: downbeat ? 0.5 : 0.34,
          hard: downbeat,
        ));
      }
    }
    // The phrase, placed in the second bar so a pick-up has room.
    final from = 8 + _placement.at;
    for (final (i, note) in _notes.indexed) {
      notes.add((
        pitch: note.pitch,
        start: (from + i) * quaver,
        length: quaver * 0.92,
        velocity: _accent.weightAt(from + i),
        bass: false,
      ));
    }
    await widget.player.playSnippet(renderSnippet(bank, notes, drums: clicks));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Where Phrases Start')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('phrasing-list'),
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Everything else here is about which notes to play. '
                      'This is about when. The notes below never change; '
                      'what moves is where they come in. The moment a '
                      'line gets interesting you stop hearing where it '
                      'began.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _Chips(
                    values: [for (final p in placements) (p.name, p.name)],
                    selected: _placement.name,
                    onPick: (name) => setState(
                      () => _placement = placements.firstWhere(
                        (p) => p.name == name,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      _placement.about,
                      key: const ValueKey('about-placement'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Bar(placement: _placement, notes: _notes, accent: _accent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text('Weight', style: theme.textTheme.titleSmall),
                  ),
                  _Chips(
                    values: [for (final a in Accent.values) (a.name, a.label)],
                    selected: _accent.name,
                    onPick: (name) => setState(
                      () => _accent = Accent.values.firstWhere(
                        (a) => a.name == name,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      _accent == Accent.upbeats
                          ? 'The weight on the offbeats, which is where '
                                'bebop puts it. It is the opposite of what '
                                'counting out loud makes you do, and most '
                                'of why beginners\' quavers sound stiff.'
                          : _accent == Accent.downbeats
                          ? 'The weight on the beats: what you do if you '
                                'are counting. Hear it once and then go '
                                'back to the other.'
                          : 'Nothing pushed either way, for comparison.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('play-phrase'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Hear It'),
                  onPressed: _play,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar of quavers with the phrase written where it falls, and rests in
/// front of it so the placement is something you can see.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.placement,
    required this.notes,
    required this.accent,
  });

  final Placement placement;
  final List<PatternNote> notes;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = <StaveColumn>[];
    final beams = <Beam>[];
    final labels = <String>[];

    // The pick-up sits before the bar line; everything else after it.
    final before = placement.at < 0 ? -placement.at : 0;
    var index = 0;
    var beamFrom = -1;

    /// A note, drawn as a bare head for a beam to join or as a whole
    /// quaver when it stands alone: a lone head on a stem with no flag
    /// is a crotchet, which would be the wrong rhythm on the page.
    void addNote(int position, PatternNote note, {required bool beamed}) {
      final step = Clef.treble.stepOf(note.name[0], note.octave).toDouble();
      columns.add(
        StaveColumn(
          [
            if (note.name.length > 1)
              sym(
                note.name.substring(1) == '♭' ? Smufl.flat : Smufl.sharp,
                step: step,
                dx: -1.15,
              ),
            sym(
              beamed ? Smufl.noteheadBlack : Smufl.note8thUp,
              step: step,
              // The ones carrying the weight, so the accent is visible
              // rather than only audible.
              marked: accent.weightAt(position) > 0.8,
              ledgers: true,
            ),
          ],
          stem: beamed,
          gap: 1.4,
        ),
      );
      labels.add(countName(position));
      if (beamFrom < 0) beamFrom = index;
      index++;
    }

    // The bar before, when the phrase starts in it.
    for (var i = 0; i < before; i++) {
      addNote(placement.at + i, notes[i], beamed: before > 1);
    }
    if (before > 0) {
      if (index - 1 > beamFrom) {
        beams.add((from: beamFrom, to: index - 1, count: 1));
      }
      beamFrom = -1;
      columns.add(StaveColumn([sym(Smufl.barlineSingle)], gap: 1.6));
      labels.add('');
      index++;
    }
    // Rests up to where it comes in.
    for (var i = 0; i < restsBefore(placement.at); i++) {
      columns.add(StaveColumn([sym(Smufl.rest8th)], gap: 1.4));
      labels.add('');
      index++;
    }
    // And the rest of the phrase.
    final left = notes.length - before;
    for (var i = before; i < notes.length; i++) {
      addNote(placement.at + i, notes[i], beamed: left > 1);
    }
    if (beamFrom >= 0 && index - 1 > beamFrom) {
      beams.add((from: beamFrom, to: index - 1, count: 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            crossesTheBar(placement.at, notes.length)
                ? 'Over the bar line, which is where you want to be.'
                : 'Inside the bar.',
            key: const ValueKey('crosses'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StaveFigure(
            columns: [
              for (final (i, column) in columns.indexed)
                StaveColumn(
                  column.symbols,
                  stem: column.stem,
                  gap: column.gap,
                  label: labels[i].isEmpty ? null : labels[i],
                ),
            ],
            clef: Clef.treble,
            beams: beams,
            space: 7,
            above: 6,
            below: 6,
            semanticsLabel:
                'The phrase starting ${placement.name.toLowerCase()}',
          ),
        ),
      ],
    );
  }
}

/// A labelled row of chips that scrolls sideways.
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
