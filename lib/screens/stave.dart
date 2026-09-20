// Notes on a stave: a chord stacked as it's written, or a scale in a row —
// in Petaluma, the hand-drawn music font that goes with the chart's
// lettering, so a stave looks copied into the same Real Book.
//
// Petaluma follows SMuFL, the standard layout for music fonts: a font size
// of one em is the height of the stave (four spaces), and each symbol's
// origin sits where it belongs — a notehead's on its line or space, the
// treble clef's on the G line, the bass clef's on the F line. So every
// symbol is placed by its origin, from the font's own baseline.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../music/chord.dart';
import '../music/clef.dart';

export '../music/clef.dart' show Clef;

const _musicFont = 'Petaluma';

// SMuFL code points.
const _wholeNote = '\uE0A2';
const _accidentals = {
  -2: '\uE264', // double flat
  -1: '\uE260', // flat
  1: '\uE262', // sharp
  2: '\uE263', // double sharp
};

/// One note on the stave: its [step] up from the bottom line (0 is the
/// bottom line, 1 the first space, 8 the top line), its [accidental] (−2
/// to 2), and whether it's [marked] — drawn in the accent colour.
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
    final scheme = Theme.of(context).colorScheme;
    final layout = _StaveLayout(notes, clef: clef, chord: chord, space: space);
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: layout.width,
        height: layout.height,
        child: CustomPaint(
          painter: _StavePainter(
            layout,
            ink: scheme.onSurface,
            lines: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            marked: scheme.tertiary,
          ),
        ),
      ),
    );
  }
}

/// A music symbol, measured once.
class _Glyph {
  _Glyph(String text, double size, Color colour)
    : painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: _musicFont,
            fontSize: size,
            height: 1,
            color: colour,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout() {
    baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  final TextPainter painter;
  late final double baseline;

  double get width => painter.width;

  /// Draws it with its SMuFL origin at [origin].
  void paint(Canvas canvas, Offset origin) =>
      painter.paint(canvas, origin - Offset(0, baseline));
}

/// Where everything goes, worked out once for both the size and the
/// drawing. Horizontal positions are in pixels from the left; vertical ones
/// are stave steps (half-spaces) up from the bottom line.
class _StaveLayout {
  _StaveLayout(
    List<StaveNote> notes, {
    required this.clef,
    required this.chord,
    required this.space,
  }) : notes = [...notes] {
    final head = _headWidth;
    final accidental = space * 1.2;
    const gap = 0.35;
    var x = space * 0.6 + _clefWidth + space * 1.2;
    if (chord) {
      // Accidentals in columns, so ones within a sixth don't collide, the
      // highest note's nearest the chord.
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
      final headX = x + columns * accidental;
      // A note a second above the one below it sits to the right.
      var previousStep = -100;
      var previousRight = true;
      for (var i = 0; i < this.notes.length; i++) {
        final n = this.notes[i];
        final right = n.step - previousStep == 1 && !previousRight;
        headXs.add(headX + (right ? head : 0));
        accidentalXs.add(
          column.containsKey(i)
              ? headX - (column[i]! + 1) * accidental - space * gap
              : null,
        );
        previousStep = n.step;
        previousRight = right;
      }
      width = headX + head * 2 + space;
    } else {
      for (final n in this.notes) {
        if (n.accidental != 0) {
          accidentalXs.add(x);
          x += accidental;
        } else {
          accidentalXs.add(null);
        }
        headXs.add(x);
        x += head + space * 1.1;
      }
      width = x;
    }
    final steps = [for (final n in this.notes) n.step];
    lowStep = math.min(steps.fold(0, math.min) - 2, clef.room.low);
    highStep = math.max(steps.fold(8, math.max) + 2, clef.room.high);
    height = (highStep - lowStep) * space / 2;
  }

  final List<StaveNote> notes;
  final Clef clef;
  final bool chord;
  final double space;
  final headXs = <double>[];
  final accidentalXs = <double?>[];
  late final double width;
  late final double height;
  late final int lowStep;
  late final int highStep;

  double get fontSize => space * 4;
  double get _headWidth => space * 1.9;
  double get _clefWidth => space * 2.7;

  double y(int step) => (highStep - step) * space / 2;
}

class _StavePainter extends CustomPainter {
  _StavePainter(
    this.layout, {
    required this.ink,
    required this.lines,
    required this.marked,
  });

  final _StaveLayout layout;
  final Color ink;
  final Color lines;
  final Color marked;

  @override
  void paint(Canvas canvas, Size size) {
    final space = layout.space;
    final linePaint = Paint()
      ..color = lines
      ..strokeWidth = math.max(1, space * 0.12);
    // The five lines.
    for (var line = 0; line <= 8; line += 2) {
      final y = layout.y(line);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    // The clef, on its line.
    final clef = _Glyph(layout.clef.glyph, layout.fontSize, ink);
    clef.paint(canvas, Offset(space * 0.6, layout.y(layout.clef.originStep)));

    final headWidth = _Glyph(_wholeNote, layout.fontSize, ink).width;
    final ledger = Paint()
      ..color = ink
      ..strokeWidth = math.max(1, space * 0.14);
    for (var i = 0; i < layout.notes.length; i++) {
      final note = layout.notes[i];
      final colour = note.marked ? marked : ink;
      final x = layout.headXs[i];
      // Ledger lines, a little wider than the note.
      for (var step = -2; step >= note.step; step -= 2) {
        canvas.drawLine(
          Offset(x - space * 0.4, layout.y(step)),
          Offset(x + headWidth + space * 0.4, layout.y(step)),
          ledger,
        );
      }
      for (var step = 10; step <= note.step; step += 2) {
        canvas.drawLine(
          Offset(x - space * 0.4, layout.y(step)),
          Offset(x + headWidth + space * 0.4, layout.y(step)),
          ledger,
        );
      }
      _Glyph(
        _wholeNote,
        layout.fontSize,
        colour,
      ).paint(canvas, Offset(x, layout.y(note.step)));
      final accidentalX = layout.accidentalXs[i];
      final glyph = _accidentals[note.accidental];
      if (accidentalX != null && glyph != null) {
        _Glyph(
          glyph,
          layout.fontSize,
          colour,
        ).paint(canvas, Offset(accidentalX, layout.y(note.step)));
      }
    }
  }

  @override
  bool shouldRepaint(_StavePainter old) =>
      old.layout.notes.toString() != layout.notes.toString() ||
      old.layout.clef != layout.clef ||
      old.ink != ink;
}
