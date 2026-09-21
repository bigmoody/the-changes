// Notes on a stave: a chord stacked as it's written, or a scale in a row.
//
// Which notes, and where each one sits, is worked out here. The drawing is
// [StaveFigure]'s, next door; this says what to put on the stave and hands
// it over.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../music/chord.dart';
import '../music/clef.dart';
import 'stave_figure.dart';

export '../music/clef.dart' show Clef;

const _accidentals = {
  -2: Smufl.doubleFlat,
  -1: Smufl.flat,
  1: Smufl.sharp,
  2: Smufl.doubleSharp,
};

/// One note on the stave: its [step] up from the bottom line (0 is the
/// bottom line, 1 the first space, 8 the top line), its [accidental] (−2
/// to 2), and whether it's [marked], drawn in the accent colour.
typedef StaveNote = ({int step, int accidental, bool marked});

/// The letter (0 = C … 6 = B) and accidental of a spelled note name such
/// as "B♭" or "F𝄪".
({int letter, int accidental}) _spelling(String name) {
  var accidental = 0;
  for (final rune in name.substring(1).runes) {
    accidental += switch (String.fromCharCode(rune)) {
      '♭' || 'b' => -1,
      '♯' || '#' => 1,
      '𝄫' => -2,
      '𝄪' => 2,
      _ => 0,
    };
  }
  return (letter: noteLetters.indexOf(name[0]), accidental: accidental);
}

/// Where a run of notes spanning [low]–[high] diatonic steps from its first
/// note sits best on the stave: the octave for its first note that needs
/// the fewest ledger lines, lower on a tie.
int _bestStart(Clef clef, int letter, int low, int high) {
  var best = 0;
  var bestCost = 1 << 30;
  for (var octave = 1; octave <= 6; octave++) {
    final first = octave * 7 + letter - clef.bottomLine;
    final int cost =
        math.max(0, -2 - (first + low)) + math.max(0, first + high - 10);
    if (cost < bestCost) {
      bestCost = cost;
      best = first;
    }
  }
  return best;
}

/// [chord]'s notes stacked in root position, as written: each degree its
/// letter above the root (the 9th a ninth up, not a second), spelled as the
/// chord spells it. [extra] adds degrees beyond the chord's own (a 9th to
/// aim for); degrees in [marked] are drawn in the accent colour.
List<StaveNote> chordOnStave(
  Chord chord, {
  Clef clef = Clef.treble,
  Set<String> marked = const {},
  Iterable<String> extra = const [],
}) {
  int number(String degree) =>
      int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));
  final formula = [
    ...chord.quality.formula,
    for (final degree in extra)
      if (!chord.quality.formula.contains(degree)) degree,
  ];
  final spans = [for (final d in formula) number(d) - 1];
  final root = _spelling(chord.rootName);
  final first = _bestStart(
    clef,
    root.letter,
    spans.reduce(math.min),
    spans.reduce(math.max),
  );
  return [
    for (final (i, degree) in formula.indexed)
      (
        step: first + spans[i],
        accidental: _spelling(chord.noteFor(degree)).accidental,
        marked: marked.contains(degree),
      ),
  ]..sort((a, b) => a.step.compareTo(b.step));
}

/// A scale's [notes] (spelled names, root first, going up) written in a
/// row, with the root an octave up to finish. [marked] are indexes into
/// [notes] to draw in the accent colour.
List<StaveNote> scaleOnStave(
  List<String> notes, {
  Clef clef = Clef.treble,
  Set<int> marked = const {},
}) {
  final spellings = [for (final n in notes) _spelling(n)];
  // Each note on the next letter up (or the same one, for G then G♯).
  final offsets = <int>[0];
  for (var i = 1; i < spellings.length; i++) {
    offsets.add(
      offsets.last + (spellings[i].letter - spellings[i - 1].letter) % 7,
    );
  }
  final top =
      offsets.last + (spellings.first.letter - spellings.last.letter) % 7;
  final first = _bestStart(clef, spellings.first.letter, 0, top);
  return [
    for (var i = 0; i < spellings.length; i++)
      (
        step: first + offsets[i],
        accidental: spellings[i].accidental,
        marked: marked.contains(i),
      ),
    (
      step: first + top,
      accidental: spellings.first.accidental,
      marked: marked.contains(0),
    ),
  ];
}

/// A melodic line: notes at the pitches given, each spelled as it's
/// written, in the order they're played.
///
/// [scaleOnStave] climbs, a letter at a time, because a scale does. A line
/// goes both ways, so each note is placed by the pitch it actually is,
/// which is the only way an enclosure, which steps down to step up, lands
/// where it should.
List<StaveNote> lineOnStave(
  List<({int pitch, String name})> line, {
  Clef clef = Clef.treble,
  Set<int> marked = const {},
}) => [
  for (final (i, note) in line.indexed)
    () {
      final spelling = _spelling(note.name);
      // Which octave the letter belongs to: the one that puts its natural
      // nearest the pitch actually sounding, so a B♯ is written under the
      // C it sounds as rather than an octave off.
      final natural = pitchClassOf((letter: spelling.letter, accidental: 0));
      // Middle C is MIDI 60 and is called C4, so the octave a pitch is in
      // is one less than the number of octaves it sits above C-1.
      final sounding = note.pitch - spelling.accidental;
      final octave = ((sounding - natural) / 12).round() - 1;
      return (
        step: clef.stepOf(noteLetters[spelling.letter], octave),
        accidental: spelling.accidental,
        marked: marked.contains(i),
      );
    }(),
];

/// A short stave with [notes] on it, either stacked as a [chord] or in a
/// row. [space] is the distance between two stave lines.
class Stave extends StatelessWidget {
  const Stave({
    super.key,
    required this.notes,
    this.clef = Clef.treble,
    this.chord = false,
    this.space = 7,
    this.semanticsLabel,
  });

  final List<StaveNote> notes;
  final Clef clef;
  final bool chord;
  final double space;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final steps = [for (final n in notes) n.step];
    return StaveFigure(
      clef: clef,
      space: space,
      // Room for anything that climbs off the stave, and never less than
      // the clef itself reaches.
      above: (math.max(steps.fold(8, math.max) + 2, clef.room.high) - 8)
          .toDouble(),
      below: -math.min(steps.fold(0, math.min) - 2, clef.room.low).toDouble(),
      columns: chord ? _stacked(notes) : _inARow(notes),
      semanticsLabel: semanticsLabel,
    );
  }
}

/// One note's head, and the ledger lines it needs to reach the stave.
StaveColumn _head(StaveNote note, {double gap = 1.1}) => StaveColumn.one(
  Smufl.noteheadWhole,
  step: note.step.toDouble(),
  marked: note.marked,
  ledgers: true,
  gap: gap,
);

/// The accidental in front of [note], if it has one. It gets a column of
/// its own so the font's own width decides how much room it takes: a sharp
/// is nearly twice a flat.
StaveColumn? _accidental(StaveNote note, {double gap = 0.3}) {
  final glyph = _accidentals[note.accidental];
  if (glyph == null) return null;
  return StaveColumn.one(
    glyph,
    step: note.step.toDouble(),
    marked: note.marked,
    gap: gap,
  );
}

/// A scale: one note after another, each behind its own accidental.
List<StaveColumn> _inARow(List<StaveNote> notes) => [
  for (final note in notes) ...[?_accidental(note), _head(note)],
];

/// A chord: the notes stacked at one place along the stave.
///
/// Two things stop them colliding. Accidentals go in columns to the left,
/// the highest note's nearest the chord, so two within a sixth of each
/// other don't land on the same spot. And a note only a step above the one
/// below it can't sit beside it, so it goes in a second column of heads,
/// one notehead to the right.
List<StaveColumn> _stacked(List<StaveNote> notes) {
  final byHeight = [for (var i = 0; i < notes.length; i++) i]
    ..sort((a, b) => notes[b].step.compareTo(notes[a].step));
  final column = <int, int>{};
  for (final i in byHeight) {
    if (notes[i].accidental == 0) continue;
    var c = 0;
    while (column.entries.any(
      (e) => e.value == c && (notes[e.key].step - notes[i].step).abs() < 6,
    )) {
      c++;
    }
    column[i] = c;
  }
  final columns = column.isEmpty ? 0 : column.values.reduce(math.max) + 1;

  // Which heads have to move right of the rest.
  final offset = <int>{};
  var previousStep = -100;
  var previousRight = true;
  for (var i = 0; i < notes.length; i++) {
    final right = notes[i].step - previousStep == 1 && !previousRight;
    if (right) offset.add(i);
    previousStep = notes[i].step;
    previousRight = right;
  }

  return [
    // Furthest column of accidentals first: they read outwards from the
    // chord, so they're written inwards towards it.
    for (var c = columns - 1; c >= 0; c--)
      StaveColumn([
        for (final i in column.keys)
          if (column[i] == c)
            sym(
              _accidentals[notes[i].accidental]!,
              step: notes[i].step.toDouble(),
              marked: notes[i].marked,
            ),
      ], gap: c == 0 ? 0.35 : 0.15),
    StaveColumn(
      [
        for (var i = 0; i < notes.length; i++)
          if (!offset.contains(i))
            sym(
              Smufl.noteheadWhole,
              step: notes[i].step.toDouble(),
              marked: notes[i].marked,
              ledgers: true,
            ),
      ],
      // Nothing between these heads and the ones beside them, but a stave
      // that stops dead at the last notehead reads as a torn-off one.
      gap: offset.isEmpty ? 1.5 : 0,
    ),
    // A column wide enough to be exactly one notehead along, because that
    // is what it holds.
    if (offset.isNotEmpty)
      StaveColumn([
        for (final i in offset)
          sym(
            Smufl.noteheadWhole,
            step: notes[i].step.toDouble(),
            marked: notes[i].marked,
            ledgers: true,
          ),
      ], gap: 1.5),
  ];
}
