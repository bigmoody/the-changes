// A figure for the reading guide: any music symbols, placed on a stave or
// standing on their own, with a caption under each.
//
// [Stave] next door draws notes (chords and scales) and knows how to
// space them. This draws *notation*: clefs, rests, time signatures, bar
// lines, dynamics, a beamed pair of quavers. It takes the symbols already
// placed, because a guide wants each one exactly where the page puts it.
//
// Everything is measured in the two units the font uses: a step is half a
// space (so 0 is the bottom line, 1 the first space, 8 the top line), and
// one em of the font is the height of the stave.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../music/clef.dart';
import '../theme.dart';

export '../music/clef.dart' show Clef;

const musicFont = 'Petaluma';

/// The SMuFL symbols the guide draws, under the names SMuFL gives them.
abstract final class Smufl {
  // Notes, whole down to demisemiquaver.
  static const noteWhole = '\u{E1D2}';
  static const noteHalfUp = '\u{E1D3}';
  static const noteQuarterUp = '\u{E1D5}';
  static const note8thUp = '\u{E1D7}';
  static const note16thUp = '\u{E1D9}';
  static const note32ndUp = '\u{E1DB}';
  static const noteheadWhole = '\u{E0A2}';
  static const noteheadBlack = '\u{E0A4}';
  static const augmentationDot = '\u{E1E7}';

  // Rests of the same lengths.
  static const restWhole = '\u{E4E3}';
  static const restHalf = '\u{E4E4}';
  static const restQuarter = '\u{E4E5}';
  static const rest8th = '\u{E4E6}';
  static const rest16th = '\u{E4E7}';
  static const rest32nd = '\u{E4E8}';

  // Accidentals.
  static const flat = '\u{E260}';
  static const natural = '\u{E261}';
  static const sharp = '\u{E262}';
  static const doubleSharp = '\u{E263}';
  static const doubleFlat = '\u{E264}';

  // Time signatures.
  static const timeSigCommon = '\u{E08A}';
  static const timeSigCutCommon = '\u{E08B}';
  static String timeSigDigit(int digit) => String.fromCharCode(0xE080 + digit);

  // Bar lines and the road map.
  static const barlineSingle = '\u{E030}';
  static const barlineDouble = '\u{E031}';
  static const barlineFinal = '\u{E032}';
  static const barlineReverseFinal = '\u{E033}';
  static const repeatDots = '\u{E043}';
  static const repeatRightLeft = '\u{E042}';
  static const segno = '\u{E047}';
  static const coda = '\u{E048}';

  /// Petaluma's own repeat bar lines are drawn ten spaces tall, for a whole
  /// system rather than one stave, so these are built from the parts: the
  /// heavy-and-thin bar line, and the two dots that face into the repeat.
  static const repeatStart = barlineReverseFinal + repeatDots;
  static const repeatEnd = repeatDots + barlineFinal;

  // Marks over and under the notes.
  static const staccato = '\u{E4A2}';
  static const accent = '\u{E4A0}';
  static const tenuto = '\u{E4A4}';
  static const fermata = '\u{E4C0}';
  static const trill = '\u{E566}';
  static const piano = '\u{E520}';
  static const mezzo = '\u{E521}';
  static const forte = '\u{E522}';
  static const ottavaAlta = '\u{E511}';
}

/// One symbol in a figure: its SMuFL [code], and the [step] its origin sits
/// on. [marked] draws it in the accent colour; [ledgers] gives it the short
/// lines it needs to reach the stave.
///
/// [scale] is how big to draw it against the stave, where 1 is the font's
/// own idea. Petaluma draws a few symbols for somewhere other than a single
/// stave (a time signature digit is four spaces tall on its own) and this
/// is what brings those back down.
/// [dx] nudges it right of the column, in spaces: what an augmentation
/// dot needs, sitting after its note but in the space above it.
typedef Sym = ({
  String code,
  double step,
  bool marked,
  bool ledgers,
  double scale,
  double dx,
});

Sym sym(
  String code, {
  double step = 4,
  bool marked = false,
  bool ledgers = false,
  double scale = 1,
  double dx = 0,
}) => (
  code: code,
  step: step,
  marked: marked,
  ledgers: ledgers,
  scale: scale,
  dx: dx,
);

/// Symbols at the same place along the stave (a time signature's two
/// digits, or a note with a dot beside it) with a caption underneath.
class StaveColumn {
  const StaveColumn(
    List<Sym> symbols, {
    this.label,
    this.over,
    this.gap = 1.2,
    this.stem = false,
  }) : _symbols = symbols,
       _one = null;

  /// One symbol, which is nearly always what a column is.
  const StaveColumn.one(
    String code, {
    double step = 4,
    bool marked = false,
    bool ledgers = false,
    double scale = 1,
    this.label,
    this.over,
    this.gap = 1.2,
    this.stem = false,
  }) : _symbols = null,
       _one = (
         code: code,
         step: step,
         marked: marked,
         ledgers: ledgers,
         scale: scale,
         dx: 0,
       );

  final List<Sym>? _symbols;
  final Sym? _one;

  List<Sym> get symbols => _symbols ?? [_one!];

  /// Written under the stave, e.g. a note's name.
  final String? label;

  /// Written over the stave, where a chord symbol goes. It sits above this
  /// column rather than in a row of its own, so a chord always lands over
  /// the note it changes on, however the font has spaced the notes.
  ///
  /// Not to be confused with [StaveFigure.above], which is room rather
  /// than writing.
  final String? over;

  /// The room after this column, in spaces.
  final double gap;

  /// Draw a stem up from the first symbol, for noteheads that a beam
  /// joins, which the font has no single symbol for.
  final bool stem;
}

/// A beam across the stems of columns [from] to [to]: one line for
/// quavers, two for semiquavers.
typedef Beam = ({int from, int to, int count});

/// A curve under two columns. Between the same pitch it's a tie and they
/// become one note; between different ones it's a slur.
typedef Tie = ({int from, int to});

/// The number over a group, saying how many are being played in the time of
/// fewer: a 3 over three quavers makes them a triplet.
typedef Tuplet = ({int from, int to, String label});

/// A short stave with [columns] of symbols on it.
class StaveFigure extends StatelessWidget {
  const StaveFigure({
    super.key,
    required this.columns,
    this.clef,
    this.space = 8,
    this.lines = true,
    this.above = 4,
    this.below = 4,
    this.beams = const [],
    this.ties = const [],
    this.tuplet,
    this.semanticsLabel,
  });

  final List<StaveColumn> columns;

  /// Drawn at the front, and it sets nothing else; the symbols are already
  /// placed. Null leaves the stave bare.
  final Clef? clef;

  /// The distance between two stave lines.
  final double space;

  /// Whether to draw the five lines. Off, the symbols stand on their own,
  /// which is how a note value or a dynamic is usually shown.
  final bool lines;

  /// Room past the stave, in steps, so stems and clefs have somewhere to
  /// go.
  final double above;
  final double below;

  final List<Beam> beams;
  final List<Tie> ties;
  final Tuplet? tuplet;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant) ??
        const TextStyle(fontSize: 12);
    // Chord symbols over a stave are hand lettered here as they are
    // everywhere else in the app, so a written-out exercise reads as the
    // same kind of page as a chart.
    final overStyle = handLettered(
      TextStyle(fontSize: space * 2.1, height: 1, color: scheme.onSurface),
    );
    final layout = _FigureLayout(
      columns: columns,
      clef: clef,
      space: space,
      above: above,
      below: below,
      labelStyle: labelStyle,
      overStyle: overStyle,
      textScaler: MediaQuery.textScalerOf(context),
    );
    return Semantics(
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: layout.width,
        height: layout.height,
        child: CustomPaint(
          painter: _FigurePainter(
            layout,
            beams: beams,
            ties: ties,
            tuplet: tuplet,
            lines: lines,
            ink: scheme.onSurface,
            rules: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            marked: scheme.tertiary,
            labelStyle: labelStyle,
            overStyle: overStyle,
          ),
        ),
      ),
    );
  }
}

/// A symbol, measured once, ready to draw from its SMuFL origin.
class _Glyph {
  _Glyph(String text, double size, Color colour)
    : painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: musicFont,
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

  void paint(Canvas canvas, Offset origin) =>
      painter.paint(canvas, origin - Offset(0, baseline));
}

/// Where everything goes, worked out once for both the size and the
/// drawing.
class _FigureLayout {
  _FigureLayout({
    required this.columns,
    required this.clef,
    required this.space,
    required this.above,
    required this.below,
    required TextStyle labelStyle,
    required TextStyle overStyle,
    required TextScaler textScaler,
  }) {
    // A stave that starts flush with its first symbol reads as a fragment,
    // so there's always a little of it before anything is written on it.
    var x = clef == null ? space : space * 0.6 + _clefWidth + space;
    for (final column in columns) {
      var widest = 0.0;
      for (final symbol in column.symbols) {
        widest = math.max(
          widest,
          symbol.dx * space + _measure(symbol.code, symbol.scale),
        );
      }
      symbolWidths.add(widest);
      final label = column.label == null
          ? null
          : (TextPainter(
              text: TextSpan(text: column.label, style: labelStyle),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              textScaler: textScaler,
            )..layout());
      labels.add(label);
      final chord = column.over == null
          ? null
          : (TextPainter(
              text: TextSpan(text: column.over, style: overStyle),
              textDirection: TextDirection.ltr,
              textScaler: textScaler,
            )..layout());
      overs.add(chord);
      // A chord symbol is wider than its note and is written from the
      // note's own left edge, the way a chart writes it, so it is allowed
      // to reach into the gap after the column rather than pushing the
      // notes apart. Nothing else would space evenly.
      final width = math.max(widest, label?.width ?? 0);
      // The symbol sits in the middle of whatever the caption needs.
      xs.add(x + (width - widest) / 2);
      x += width + column.gap * space;
    }
    // Room for the last chord symbol to finish in, so it isn't clipped.
    final lastOver = overs.isEmpty ? null : overs.last;
    width = math.max(x, xs.isEmpty ? x : xs.last + (lastOver?.width ?? 0));
    labelHeight = labels.fold(
      0,
      (tallest, label) => math.max(tallest, label?.height ?? 0),
    );
    overHeight = overs.fold(
      0,
      (tallest, over) => math.max(tallest, over?.height ?? 0),
    );
    height =
        overHeight +
        (8 + above + below) * space / 2 +
        (labelHeight > 0 ? 6 : 0) +
        labelHeight;
  }

  final List<StaveColumn> columns;
  final Clef? clef;
  final double space;
  final double above;
  final double below;

  /// Where each column's symbols start, in pixels from the left.
  final xs = <double>[];
  final symbolWidths = <double>[];
  final labels = <TextPainter?>[];
  final overs = <TextPainter?>[];
  late final double width;
  late final double height;
  late final double labelHeight;
  late final double overHeight;

  double get fontSize => space * 4;
  double get _clefWidth => _measure(clef!.glyph, 1);

  final _measured = <(String, double), double>{};
  double _measure(String code, double scale) => _measured[(code, scale)] ??=
      _Glyph(code, fontSize * scale, const Color(0xFF000000)).width;

  /// The top of the box down to [step]. Everything on the stave is pushed
  /// down by whatever the chord symbols above it need.
  double y(num step) => overHeight + (8 + above - step) * space / 2;
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(
    this.layout, {
    required this.beams,
    required this.ties,
    required this.tuplet,
    required this.lines,
    required this.ink,
    required this.rules,
    required this.marked,
    required this.labelStyle,
    required this.overStyle,
  });

  final _FigureLayout layout;
  final List<Beam> beams;
  final List<Tie> ties;
  final Tuplet? tuplet;
  final bool lines;
  final Color ink;
  final Color rules;
  final Color marked;
  final TextStyle labelStyle;
  final TextStyle overStyle;

  /// How far a stem reaches from its notehead, in steps.
  static const _stemLength = 7.0;

  /// Where a tuplet's number sits: clear of the beam over a stem.
  static const _tupletStep = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    final space = layout.space;
    if (lines) {
      final rule = Paint()
        ..color = rules
        ..strokeWidth = math.max(1, space * 0.12);
      for (var line = 0; line <= 8; line += 2) {
        final y = layout.y(line);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
      }
    }
    final clef = layout.clef;
    if (clef != null) {
      _Glyph(
        clef.glyph,
        layout.fontSize,
        ink,
      ).paint(canvas, Offset(space * 0.6, layout.y(clef.originStep)));
    }

    final stemPaint = Paint()
      ..color = ink
      ..strokeWidth = math.max(1, space * 0.13);
    final ledgerPaint = Paint()
      ..color = ink
      ..strokeWidth = math.max(1, space * 0.14);
    // Where each stem's top ends up, so the beams can find them, and where
    // each notehead sits, for the ties and the tuplet number.
    final stemTops = <int, Offset>{};
    final heads = <int, Rect>{};

    for (var i = 0; i < layout.columns.length; i++) {
      final column = layout.columns[i];
      final x = layout.xs[i];
      for (final symbol in column.symbols) {
        final at = x + symbol.dx * space;
        final colour = symbol.marked ? marked : ink;
        final glyph = _Glyph(
          symbol.code,
          layout.fontSize * symbol.scale,
          colour,
        );
        if (symbol.ledgers) {
          for (var step = -2; step >= symbol.step; step -= 2) {
            _ledger(canvas, at, glyph.width, step, ledgerPaint);
          }
          for (var step = 10; step <= symbol.step; step += 2) {
            _ledger(canvas, at, glyph.width, step, ledgerPaint);
          }
        }
        glyph.paint(canvas, Offset(at, layout.y(symbol.step)));
      }
      final head = column.symbols.firstOrNull;
      if (head != null) {
        heads[i] = Rect.fromLTWH(
          x,
          layout.y(head.step),
          layout._measure(head.code, head.scale),
          0,
        );
      }
      if (column.stem) {
        final note = column.symbols.first;
        final headWidth = layout._measure(note.code, note.scale);
        final stemX = x + headWidth - stemPaint.strokeWidth / 2;
        final top = layout.y(note.step + _stemLength);
        canvas.drawLine(
          Offset(stemX, layout.y(note.step)),
          Offset(stemX, top),
          stemPaint,
        );
        stemTops[i] = Offset(stemX, top);
      }
      final label = layout.labels[i];
      if (label != null) {
        label.paint(
          canvas,
          Offset(
            x + (layout.symbolWidths[i] - label.width) / 2,
            size.height - layout.labelHeight,
          ),
        );
      }
      // A chord symbol starts at its note's left edge rather than being
      // centred on it, because that is where a chart puts it and because
      // centring a wide symbol over a narrow notehead would have it
      // hanging back over the note before.
      layout.overs[i]?.paint(canvas, Offset(x, 0));
    }

    for (final tie in ties) {
      final from = heads[tie.from];
      final to = heads[tie.to];
      if (from != null && to != null) _tie(canvas, from, to);
    }

    final group = tuplet;
    if (group != null) {
      final from = heads[group.from];
      final to = heads[group.to];
      if (from != null && to != null) {
        // Over a beamed group the number stands on its own: engravers
        // leave the bracket off when the beam already shows the group.
        final number = _Glyph(
          [
            for (final digit in group.label.runes)
              String.fromCharCode(0xE880 + digit - 0x30),
          ].join(),
          layout.fontSize,
          ink,
        );
        number.paint(
          canvas,
          Offset(
            (from.center.dx + to.center.dx - number.width) / 2,
            layout.y(from.top == to.top ? _tupletStep : _tupletStep),
          ),
        );
      }
    }

    for (final beam in beams) {
      final from = stemTops[beam.from];
      final to = stemTops[beam.to];
      if (from == null || to == null) continue;
      final thickness = space * 0.5;
      for (var line = 0; line < beam.count; line++) {
        final top = from.dy + line * thickness * 1.6;
        canvas.drawRect(
          Rect.fromLTRB(
            from.dx - stemPaint.strokeWidth / 2,
            top,
            to.dx + stemPaint.strokeWidth / 2,
            top + thickness,
          ),
          Paint()..color = ink,
        );
      }
    }
  }

  /// A curve under the two noteheads, sagging in the middle.
  void _tie(Canvas canvas, Rect from, Rect to) {
    final space = layout.space;
    final start = Offset(from.center.dx, from.top + space * 0.7);
    final end = Offset(to.center.dx, to.top + space * 0.7);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          (start.dx + end.dx) / 2,
          start.dy + space * 1.5,
          end.dx,
          end.dy,
        ),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, space * 0.16),
    );
  }

  void _ledger(Canvas canvas, double x, double width, num step, Paint paint) {
    final y = layout.y(step);
    canvas.drawLine(
      Offset(x - layout.space * 0.4, y),
      Offset(x + width + layout.space * 0.4, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.ink != ink ||
      old.rules != rules ||
      old.marked != marked ||
      old.lines != lines ||
      old.tuplet != tuplet ||
      old.labelStyle != labelStyle ||
      old.layout.width != layout.width ||
      old.layout.height != layout.height ||
      !listEquals(old.beams, beams) ||
      !listEquals(old.ties, ties) ||
      // What is actually written on the stave. This used to be left out,
      // on the assumption that changing it would change the figure's
      // size, and it usually does, which is why it went unnoticed. But
      // marking a different note of the same run, or swapping a glyph
      // for one the same width, changes nothing about the layout and
      // everything about the picture, and the old one stayed on screen.
      !_sameSymbols(old.layout.columns, layout.columns);

  static bool _sameSymbols(List<StaveColumn> a, List<StaveColumn> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label ||
          a[i].over != b[i].over ||
          a[i].stem != b[i].stem) {
        return false;
      }
      // Sym is a record, so this is value equality down to the glyph,
      // the step and whether it is marked.
      if (!listEquals(a[i].symbols, b[i].symbols)) return false;
    }
    return true;
  }
}
