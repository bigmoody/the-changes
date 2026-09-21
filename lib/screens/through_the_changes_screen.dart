// Through the Changes: chord tones over a whole form, for one note at a
// time.
//
// Everything else in Learn that works on chord tones works on a cell: a
// ii-V-I, a turnaround, four bars of cycle. That is where you learn what
// the notes are. It is not where the difficulty is. The difficulty turns
// up when the cell is bar seven of something and you arrive at it from
// wherever bar six left you, at a tempo, with no time to work anything
// out.
//
// So this runs a line of nothing but chord tones through a chorus of the
// blues or of rhythm changes, and lets you change one thing about how each
// chord is started. The written line is the page you play from, and the
// measurements under it are there so the comparison between the two ways
// of starting is a fact rather than a claim.
//
// Chord symbols sit over the note they change on rather than in a row of
// their own, because the whole point is which note the change lands on.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/backing_synth.dart';
import '../audio/drum_patterns.dart';
import '../audio/practice_player.dart';
import '../music/chord.dart';
import '../music/chord_tone_line.dart';
import '../music/tune.dart';
import '../music/tune_library.dart';
import '../settings/app_settings.dart';
import '../theme.dart';
import 'chart_instrument_button.dart';
import 'stave.dart';
import 'stave_figure.dart';

/// A stretch of a form to run the exercise through.
///
/// Bars rather than a tune, because the two halves of a rhythm tune are
/// different problems: eight bars of two chords a bar, and then eight bars
/// of one chord every two bars going round the cycle. Practising them
/// together teaches neither.
typedef Changes = ({
  String name,
  String about,
  Tune tune,
  int firstBar,
  int lastBar,
});

Tune _practice(String title) =>
    practiceProgressions.firstWhere((tune) => tune.title == title);

List<Changes> _allChanges() {
  final blues = _practice('Jazz blues in F');
  final rhythm = _practice('Rhythm changes in B♭');
  return [
    (
      name: 'Blues in F',
      about:
          'Eleven changes and nowhere to stop and think about any of them. '
          'The IV arrives at bar 5 and you are on your way home from bar 9.',
      tune: blues,
      firstBar: 0,
      lastBar: 11,
    ),
    (
      name: 'Blues in B♭',
      about:
          'The same twelve bars moved up a fourth. Worth doing second: the '
          'shapes are the ones you have just played and none of the notes '
          'are, which is the only way to find out which you had learned.',
      tune: blues.transposed(5),
      firstBar: 0,
      lastBar: 11,
    ),
    (
      name: 'The A Section',
      about:
          'Rhythm changes, the first eight bars: two chords in nearly every '
          'bar, so you get two notes each and no room to wander. This is '
          'the one that catches people out, and it is only four chords '
          'going round.',
      tune: rhythm,
      firstBar: 0,
      lastBar: 7,
    ),
    (
      name: 'The Bridge',
      about:
          'Four dominants, two bars each, every one a fourth above the last. '
          'Because they are a fourth apart the 7th of each is a semitone '
          'from the 3rd of the next, so the nearest note is always right '
          'there. Play this one and then look at what it cost you.',
      tune: rhythm,
      firstBar: 16,
      lastBar: 23,
    ),
    (
      name: 'ii–V–I',
      about:
          'The move the rest of it is made of, on its own and slowly, in '
          'case a whole chorus is too much at once.',
      tune: Tune.fromChart(
        title: 'ii–V–I',
        key: 'C',
        chart: '| Dm7 | G7 | CΔ7 | CΔ7 |',
        defaultTempo: 100,
      ),
      firstBar: 0,
      lastBar: 3,
    ),
  ];
}

/// Which clef the line is written in, since a trombone and a trumpet want
/// different pages and both of them are one note at a time.
enum _Reading {
  treble('Treble'),
  bass('Bass');

  const _Reading(this.label);
  final String label;
}

class ThroughTheChangesScreen extends StatefulWidget {
  const ThroughTheChangesScreen({
    super.key,
    required this.player,
    required this.settings,
  });

  final PracticePlayer player;
  final AppSettings settings;

  @override
  State<ThroughTheChangesScreen> createState() =>
      _ThroughTheChangesScreenState();
}

class _ThroughTheChangesScreenState extends State<ThroughTheChangesScreen> {
  static final _changes = _allChanges();

  var _picked = _changes.first;
  var _exercise = ToneExercise.nearest;
  var _reading = _Reading.treble;
  var _tempo = 100;

  /// The bars being worked on, at concert pitch, which is where the
  /// exercise is worked out.
  List<ChordSlot> get _slots => [
    for (final slot in _picked.tune.slots)
      if (slot.barIndex >= _picked.firstBar && slot.barIndex <= _picked.lastBar)
        slot,
  ];

  /// The line as it sounds. The range is a concert one, so every player
  /// gets the same notes in the same order and the numbers under them
  /// mean the same thing whoever is reading. The bass clef is not a
  /// transposition, it is a different part of the range, which is why it
  /// changes this and the instrument does not.
  List<ToneNote> _lineOf(ToneExercise exercise) => chordToneLine(
    _slots,
    exercise: exercise,
    beatsPerBar: _picked.tune.beatsPerBar,
    low: _reading == _Reading.bass ? 45 : 57,
    high: _reading == _Reading.bass ? 63 : 75,
  );

  List<ToneNote> get _line => _lineOf(_exercise);

  /// The same line in the key the player reads, which is the only thing
  /// the instrument setting changes.
  List<ToneNote> get _read =>
      writtenFor(_line, widget.settings.instrument.transposition);

  /// Plays the line, with the roots under it so the changes are heard
  /// rather than taken on trust, and the ride keeping the time so it is an
  /// exercise rather than a demonstration.
  Future<void> _play() async {
    final bank = widget.player.samples;
    if (bank == null) return;
    final beat = 60 / _tempo;
    final line = _line;
    if (line.isEmpty) return;
    final notes = <SnippetNote>[];
    final drums = <SnippetDrum>[];
    var at = 0.0;
    Chord? sounding;
    for (final note in line) {
      final length = beat * note.beats;
      notes.add((
        pitch: note.pitch,
        start: at,
        length: length * 0.96,
        velocity: 0.85,
        bass: _reading == _Reading.bass,
      ));
      if (note.chord.display != sounding?.display) {
        sounding = note.chord;
        notes.add((
          // The root where a bass player would put it, not under the line.
          pitch: 40 + (note.chord.root - 40) % 12,
          start: at,
          length: length,
          velocity: 0.3,
          bass: true,
        ));
      }
      at += length;
    }
    for (var tick = 0.0; tick < at; tick += beat) {
      drums.add((at: tick, drum: Drum.ride, velocity: 0.3, hard: false));
    }
    await widget.player.playSnippet(
      renderSnippet(bank, notes, drums: drums, bassTone: BassTone.tight),
    );
  }

  /// Everything on the page is written for whichever instrument the
  /// player reads, and that is chosen in the app bar, so the page has to
  /// be listening: without this the chords and the line stay in the old
  /// key until something else happens to rebuild them.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final line = _line;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Through the Changes'),
        actions: [ChartInstrumentButton(settings: widget.settings)],
      ),
      body: ListView(
        key: const ValueKey('through-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'On one note at a time the question is never what the notes of '
              'the chord are. It is which of them is nearest to the note you '
              'are already on, and which way to go from there. Here is a '
              'whole chorus of nothing but chord tones, one on every beat, '
              'with one thing to change about how each chord is started.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('The Changes', style: theme.textTheme.titleSmall),
          ),
          _Chips(
            values: [for (final c in _changes) (c.name, c.name)],
            selected: _picked.name,
            onPick: (name) => setState(
              () => _picked = _changes.firstWhere((c) => c.name == name),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _picked.about,
              key: const ValueKey('about-changes'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Text('The Exercise', style: theme.textTheme.titleSmall),
          ),
          _Chips(
            values: [
              for (final exercise in ToneExercise.values)
                (exercise.name, exercise.label),
            ],
            selected: _exercise.name,
            onPick: (name) =>
                setState(() => _exercise = ToneExercise.values.byName(name)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              _exercise.about,
              key: const ValueKey('about-exercise'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _Cost(
            line: line,
            against: _lineOf(ToneExercise.fromTheRoot),
            exercise: _exercise,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Written Out', style: theme.textTheme.titleSmall),
                ),
                SegmentedButton<_Reading>(
                  key: const ValueKey('through-clef'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    for (final reading in _Reading.values)
                      ButtonSegment(value: reading, label: Text(reading.label)),
                  ],
                  selected: {_reading},
                  onSelectionChanged: (value) =>
                      setState(() => _reading = value.first),
                ),
              ],
            ),
          ),
          _Written(
            line: _read,
            clef: _reading == _Reading.bass ? Clef.bass : Clef.treble,
          ),
          _Tempo(
            tempo: _tempo,
            onChanged: (bpm) => setState(() => _tempo = bpm),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('play-line'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Hear It'),
                onPressed: _play,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Nothing here is a lick and none of it is meant to be played '
              'in a solo. It is the thing underneath a solo: if you can run '
              'the chord tones through a form without looking, you can hear '
              'where you are, and everything else is decoration on top of '
              'knowing that.',
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

/// What the way of starting each chord costs, in semitones.
///
/// Measured off the line on the screen rather than written down here, so
/// the page cannot go on claiming something after the music stops being
/// true. The comparison is against starting from the root, which is what
/// everybody does first and what the rest of the exercises are answers to.
class _Cost extends StatelessWidget {
  const _Cost({
    required this.line,
    required this.against,
    required this.exercise,
  });

  final List<ToneNote> line;
  final List<ToneNote> against;
  final ToneExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final changes = changesIn(line);
    if (changes.isEmpty) return const SizedBox.shrink();
    final worst = biggestJumpAtChanges(line);
    final smooth = changesWithin(line, 2);
    final naive = biggestJumpAtChanges(against);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            key: const ValueKey('the-cost'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'At every change',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The furthest you have to move when the chord changes is '
                '${_semitones(worst)}.',
                key: const ValueKey('worst-jump'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 3),
              Text(
                '$smooth of the ${changes.length} changes are a tone or less.',
                key: const ValueKey('smooth-changes'),
                style: theme.textTheme.bodyMedium,
              ),
              if (!exercise.lands && exercise != ToneExercise.fromTheRoot) ...[
                const SizedBox(height: 6),
                Text(
                  'Starting every chord from its root instead, the furthest '
                  'is ${_semitones(naive)}.',
                  key: const ValueKey('against-root'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _semitones(int count) => switch (count) {
    0 => 'nothing at all',
    1 => 'a semitone',
    2 => 'a tone',
    _ => '$count semitones',
  };
}

/// The line on a stave, two bars to a row, with the chord symbols over the
/// notes they change on and each note's degree underneath.
class _Written extends StatelessWidget {
  const _Written({required this.line, required this.clef});

  final List<ToneNote> line;
  final Clef clef;

  /// Two bars a row fits a phone. Four would need the notes closer
  /// together than a chord symbol can be written over.
  static const _barsPerRow = 2;

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // The note each chord starts on, which is the one the exercise is
    // about and the one to look at when comparing two of them. In the
    // landing exercises every note starts a chord, and marking all of
    // them would be marking none of them, so nothing is marked.
    final opens = {
      for (final (i, note) in line.indexed)
        if (note.opens) i,
    };
    final placed = lineOnStave(
      [for (final note in line) (pitch: note.pitch, name: note.name)],
      clef: clef,
      marked: opens.length == line.length ? const {} : opens,
    );
    final bars = <int>{for (final note in line) note.bar}.toList()..sort();
    final rows = <List<int>>[];
    for (var i = 0; i < bars.length; i += _barsPerRow) {
      rows.add(bars.sublist(i, (i + _barsPerRow).clamp(0, bars.length)));
    }
    return Column(
      key: const ValueKey('written-out'),
      children: [
        for (final row in rows)
          Padding(
            // Room between one system and the next, so a row's chord
            // symbols read as belonging to it rather than to the degrees
            // written above them.
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              // Centred rather than pinned to the bottom: a row with a
              // ledger line under it is taller than one without, and a
              // number measured from the bottom edge would wander down
              // the page as the line does.
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${row.first + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: StaveFigure(
                      key: ValueKey('row-${row.first}'),
                      clef: clef,
                      space: 9,
                      above: _room(row, placed, above: true),
                      below: _room(row, placed, above: false),
                      columns: _columnsFor(row, placed),
                      semanticsLabel: _spoken(row),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// How much room [row] needs past the stave, in steps.
  ///
  /// Fixed room is enough until the line goes somewhere the default did
  /// not expect, and then the chord symbols land on top of the ledger
  /// lines. That turned up as soon as the same line was written for an F
  /// instrument, a fifth higher, which is the whole point of writing it
  /// for the player: the notes are wherever the instrument puts them.
  double _room(List<int> row, List<StaveNote> placed, {required bool above}) {
    final steps = [
      for (final (i, note) in line.indexed)
        if (row.contains(note.bar)) placed[i].step,
    ];
    if (steps.isEmpty) return 4;
    // Step 0 is the bottom line and 8 the top, so anything outside that
    // is hanging off the stave and needs room of its own, plus a little
    // so a notehead is not flush against what is written beyond it.
    final past = above ? steps.reduce(math.max) - 8 : -steps.reduce(math.min);
    return math.max(4, past + 3);
  }

  /// The columns for one row: each note behind its own accidental, with a
  /// bar line between the bars.
  List<StaveColumn> _columnsFor(List<int> row, List<StaveNote> placed) {
    const accidentals = {
      -2: Smufl.doubleFlat,
      -1: Smufl.flat,
      1: Smufl.sharp,
      2: Smufl.doubleSharp,
    };
    final columns = <StaveColumn>[];
    for (final (atBar, bar) in row.indexed) {
      if (atBar > 0) {
        columns.add(
          const StaveColumn.one(Smufl.barlineSingle, step: 0, gap: 1.4),
        );
      }
      for (final (i, note) in line.indexed) {
        if (note.bar != bar) continue;
        final head = placed[i];
        if (accidentals[head.accidental] case final glyph?) {
          columns.add(
            StaveColumn.one(glyph, step: head.step.toDouble(), gap: 0.2),
          );
        }
        columns.add(
          StaveColumn(
            [
              sym(
                // A held note looks held: the landing exercises put one
                // note on a whole chord and it should not read as a beat.
                note.beats > 1 ? Smufl.noteheadWhole : Smufl.noteheadBlack,
                step: head.step.toDouble(),
                marked: head.marked,
                ledgers: true,
              ),
            ],
            label: prettyDegree(note.degree),
            over: note.opens ? handSymbol(note.chord.display) : null,
            gap: note.beats > 1 ? 3.4 : 1.8,
          ),
        );
      }
    }
    return columns;
  }

  String _spoken(List<int> row) => [
    for (final note in line)
      if (row.contains(note.bar))
        '${note.opens ? "${note.chord.display}, " : ""}${note.name}',
  ].join(', ');
}

/// How fast to hear it. Slower than you can play it is the point: this is
/// a thing to get right rather than a thing to get through.
class _Tempo extends StatelessWidget {
  const _Tempo({required this.tempo, required this.onChanged});

  final int tempo;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tempo', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '$tempo',
                key: const ValueKey('through-tempo'),
                style: handLettered(theme.textTheme.titleMedium),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('through-tempo-slider'),
            value: tempo.toDouble(),
            min: 40,
            max: 240,
            onChanged: (value) => onChanged(value.round()),
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
    padding: const EdgeInsets.only(top: 8),
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
