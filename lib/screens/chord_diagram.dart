// Where the chord sits under your hands: a keyboard with its notes marked,
// or a guitar grid with a shape to grab.
//
// Both are drawn rather than laid out from widgets, because they're mostly
// lines and circles that have to keep their proportions in whatever space
// the practice screen can spare.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../music/chord.dart';
import '../music/barre_chords.dart';
import '../music/fretboard_arpeggio.dart';
import '../music/guitar_voicing.dart';
import '../settings/app_settings.dart';

/// Whichever [diagram] the player chose, drawn [height] tall at its own
/// proportions. Nothing at all for [ChordDiagram.none].
class FingeringDiagram extends StatelessWidget {
  const FingeringDiagram({
    super.key,
    required this.chord,
    required this.diagram,
    required this.height,
  });

  final Chord chord;
  final ChordDiagram diagram;
  final double height;

  @override
  Widget build(BuildContext context) => switch (diagram) {
    ChordDiagram.none => const SizedBox.shrink(),
    ChordDiagram.keyboard => SizedBox(
      height: height,
      width: height * KeyboardDiagram.aspectFor(chord),
      child: KeyboardDiagram(chord: chord),
    ),
    ChordDiagram.guitar || ChordDiagram.barre => SizedBox(
      height: height,
      width: height * GuitarDiagram.aspect,
      child: GuitarDiagram(chord: chord, barre: diagram == ChordDiagram.barre),
    ),
    ChordDiagram.bass => SizedBox(
      height: height,
      width: height * BassDiagram.aspect,
      child: BassDiagram(chord: chord),
    ),
  };
}

/// What a note on the keyboard diagram is to the chord.
enum KeyRole {
  /// The root: marked with a hole through it.
  root,

  /// The 3rd, 5th, 7th (or 6th): the chord itself.
  tone,

  /// A 9th, 11th or 13th, stacked above the chord and drawn as a ring.
  extension,

  /// A slash chord's bass note, below the root.
  bass,
}

/// The chord in root position, from the bottom up, as semitones from the C
/// at or below the lowest note. G7 is G B D F — never D F G B, which reads
/// as an inversion. Extensions stack above the 7th; a slash bass that isn't
/// the root goes underneath.
List<({int semitone, KeyRole role})> keyboardNotes(Chord chord) {
  final notes = <({int semitone, KeyRole role})>[
    for (final degree in chord.quality.formula)
      (
        semitone: chord.root + degreeToSemitones(degree),
        role: degree == '1'
            ? KeyRole.root
            : int.parse(degree.replaceAll(RegExp(r'[b#]'), '')) > 7
            ? KeyRole.extension
            : KeyRole.tone,
      ),
  ];
  if (chord.bass != chord.root) {
    notes.insert(0, (
      semitone: chord.root - (chord.root - chord.bass) % 12,
      role: KeyRole.bass,
    ));
  }
  // Start the drawing from the C at or below the lowest note.
  final shift = (notes.first.semitone / 12).floor() * 12;
  return [
    for (final note in notes)
      (semitone: note.semitone - shift, role: note.role),
  ];
}

bool _isWhiteKey(int semitone) =>
    const [0, 2, 4, 5, 7, 9, 11].contains(semitone % 12);

/// The white keys the diagram shows: from the one at or below the lowest
/// note to the one at or above the highest, and at least an octave's worth.
List<int> _whiteKeysFor(List<({int semitone, KeyRole role})> notes) {
  var first = notes.map((n) => n.semitone).reduce(math.min);
  var last = notes.map((n) => n.semitone).reduce(math.max);
  while (!_isWhiteKey(first)) {
    first--;
  }
  while (!_isWhiteKey(last)) {
    last++;
  }
  final whites = [
    for (var s = first; s <= last; s++)
      if (_isWhiteKey(s)) s,
  ];
  while (whites.length < 7) {
    var next = whites.last + 1;
    while (!_isWhiteKey(next)) {
      next++;
    }
    whites.add(next);
  }
  return whites;
}

/// A stretch of keyboard with the chord marked in root position — as many
/// keys as the chord needs, at least an octave.
class KeyboardDiagram extends StatelessWidget {
  const KeyboardDiagram({super.key, required this.chord});

  final Chord chord;

  /// Wider than it is tall: a keyboard shape, an octave at [aspect].
  static const aspect = 1.8;

  /// Wider for a chord that spans more than an octave (C13 reaches up to
  /// the A above the next C), so the keys stay a readable width.
  static double aspectFor(Chord chord) =>
      aspect * math.min(_whiteKeysFor(keyboardNotes(chord)).length, 12) / 7;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _KeyboardPainter(
        notes: keyboardNotes(chord),
        marked: scheme.tertiary,
        hole: scheme.surface,
        outline: scheme.outlineVariant,
        white: scheme.surface,
        black: scheme.onSurface,
      ),
    );
  }
}

/// A scale on the keys, from its root up to the octave: every note marked,
/// the roots with a hole through them, and its [colour] notes — the ones
/// that give it its sound — as rings.
class ScaleKeyboard extends StatelessWidget {
  const ScaleKeyboard({
    super.key,
    required this.root,
    required this.semitones,
    this.colour = const {},
  });

  /// The root's pitch class (0 = C).
  final int root;

  /// Each note's semitones above the root.
  final List<int> semitones;

  /// Which of [semitones] to draw as rings.
  final Set<int> colour;

  List<({int semitone, KeyRole role})> get _notes => [
    for (final s in semitones)
      (
        semitone: root + s,
        role: s == 0
            ? KeyRole.root
            : colour.contains(s)
            ? KeyRole.extension
            : KeyRole.tone,
      ),
    (semitone: root + 12, role: KeyRole.root),
  ];

  /// As wide as the octave it spans needs.
  double get aspect =>
      KeyboardDiagram.aspect * math.min(_whiteKeysFor(_notes).length, 12) / 7;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _KeyboardPainter(
        notes: _notes,
        marked: scheme.tertiary,
        hole: scheme.surface,
        outline: scheme.outlineVariant,
        white: scheme.surface,
        black: scheme.onSurface,
      ),
    );
  }
}

class _KeyboardPainter extends CustomPainter {
  _KeyboardPainter({
    required this.notes,
    required this.marked,
    required this.hole,
    required this.outline,
    required this.white,
    required this.black,
  });

  final List<({int semitone, KeyRole role})> notes;
  final Color marked;
  final Color hole;
  final Color outline;
  final Color white;
  final Color black;

  @override
  void paint(Canvas canvas, Size size) {
    final whites = _whiteKeysFor(notes);
    final roleOf = {for (final note in notes) note.semitone: note.role};

    final keyWidth = size.width / whites.length;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = outline;
    for (var i = 0; i < whites.length; i++) {
      final rect = Rect.fromLTWH(i * keyWidth, 0, keyWidth, size.height);
      canvas.drawRect(rect, Paint()..color = white);
      canvas.drawRect(rect.deflate(0.5), edge);
      final role = roleOf[whites[i]];
      if (role != null) {
        _mark(
          canvas,
          Offset(rect.center.dx, size.height * 0.82),
          keyWidth * 0.3,
          role,
        );
      }
    }

    final blackWidth = keyWidth * 0.62;
    final blackHeight = size.height * 0.62;
    for (var i = 0; i < whites.length - 1; i++) {
      final semitone = whites[i] + 1;
      if (_isWhiteKey(semitone)) continue; // E–F and B–C have no black key
      final rect = Rect.fromLTWH(
        (i + 1) * keyWidth - blackWidth / 2,
        0,
        blackWidth,
        blackHeight,
      );
      canvas.drawRect(rect, Paint()..color = black);
      final role = roleOf[semitone];
      if (role != null) {
        _mark(
          canvas,
          Offset(rect.center.dx, blackHeight * 0.76),
          blackWidth * 0.34,
          role,
        );
      }
    }
  }

  void _mark(Canvas canvas, Offset centre, double radius, KeyRole role) {
    if (role == KeyRole.extension) {
      // Extensions as rings: part of the sound, not of the basic shape.
      canvas.drawCircle(
        centre,
        radius * 0.85,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, radius * 0.35)
          ..color = marked,
      );
      return;
    }
    canvas.drawCircle(centre, radius, Paint()..color = marked);
    if (role == KeyRole.root) {
      // A hole through the middle of the root, so which note is which reads
      // at a glance.
      canvas.drawCircle(centre, radius * 0.42, Paint()..color = hole);
    }
  }

  @override
  bool shouldRepaint(_KeyboardPainter old) =>
      old.notes.toString() != notes.toString() || old.marked != marked;
}

/// A guitar chord grid: four frets, six strings, a dot where a finger goes.
class GuitarDiagram extends StatelessWidget {
  const GuitarDiagram({
    super.key,
    required this.chord,
    this.barre = false,
    this.voicing,
  });

  final Chord chord;

  /// A shape to draw instead of the app's own grip for the chord — one of
  /// the many in the chord dictionary.
  final GuitarVoicing? voicing;

  /// Show the barre-chord shape rather than the compact jazz grip. Chords
  /// with no barre shape (°7, ø7, augmented) still get their usual grip.
  final bool barre;

  /// Taller than it is wide, like a chord box in a songbook.
  static const aspect = 0.78;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final voicing =
        this.voicing ??
        (barre ? barreVoicingFor(chord) : null) ??
        guitarVoicingFor(chord);
    if (voicing == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _GuitarPainter(
        voicing: voicing,
        dot: scheme.primary,
        line: scheme.outline,
        label: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _GuitarPainter extends CustomPainter {
  _GuitarPainter({
    required this.voicing,
    required this.dot,
    required this.line,
    required this.label,
  });

  final GuitarVoicing voicing;
  final Color dot;
  final Color line;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    // The grid starts at the shape's position, or at the nut if it's within
    // reach of it.
    final first = voicing.position <= 1 ? 1 : voicing.position;
    final showNut = first == 1;

    final top = size.height * 0.17; // room for the o/x row above the nut
    final left = size.width * (showNut ? 0.06 : 0.22);
    final right = size.width * 0.94;
    final bottom = size.height * 0.96;
    final stringGap = (right - left) / 5;
    final fretGap = (bottom - top) / 4;

    final wire = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var string = 0; string < 6; string++) {
      final x = left + string * stringGap;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), wire);
    }
    for (var fret = 0; fret <= 4; fret++) {
      final y = top + fret * fretGap;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        fret == 0 && showNut
            ? (Paint()
                ..color = line
                ..strokeWidth = 3.5)
            : wire,
      );
    }

    if (!showNut) {
      // The position number sits clear of the first string's dot.
      _text(
        canvas,
        '$first',
        Offset(left - stringGap * 0.8, top + fretGap / 2),
      );
    }

    final radius = stringGap * 0.36;
    final barre = voicing.barre;
    if (barre != null && barre.fret - first >= 0 && barre.fret - first <= 3) {
      // The first finger laid across the strings: one bar, not six dots.
      final y = top + (barre.fret - first + 0.5) * fretGap;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left + barre.from * stringGap - radius,
          y - radius,
          left + barre.to * stringGap + radius,
          y + radius,
          Radius.circular(radius),
        ),
        Paint()..color = dot,
      );
    }
    for (var string = 0; string < 6; string++) {
      final fret = voicing.frets[string];
      final x = left + string * stringGap;
      final underBarre =
          barre != null &&
          fret == barre.fret &&
          string >= barre.from &&
          string <= barre.to;
      if (underBarre) continue;
      if (fret == null || fret == 0) {
        _text(
          canvas,
          fret == null ? '×' : '○',
          Offset(x, top - fretGap * 0.42),
        );
        continue;
      }
      final row = fret - first;
      if (row < 0 || row > 3) continue;
      canvas.drawCircle(
        Offset(x, top + (row + 0.5) * fretGap),
        radius,
        Paint()..color = dot,
      );
    }
  }

  void _text(Canvas canvas, String text, Offset centre) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: label, fontSize: 11, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_GuitarPainter old) =>
      old.voicing.frets.toString() != voicing.frets.toString() ||
      old.voicing.barre != voicing.barre ||
      old.dot != dot;
}

/// A bass fingerboard in one hand position, with every chord tone within
/// reach marked by its degree (R, 3, 5, ♭7 …): the map an improviser or a
/// bass player uses to find the notes, rather than a single chord shape.
class BassDiagram extends StatelessWidget {
  const BassDiagram({super.key, required this.chord});

  final Chord chord;

  /// Four strings across, five frets down.
  static const aspect = 0.72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _BassPainter(
        chord: chord,
        dot: scheme.primary,
        rootDot: scheme.tertiary,
        onDot: scheme.onPrimary,
        line: scheme.outline,
        label: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// Open strings of a four-string bass, lowest first: E1 A1 D2 G2.
const bassTuning = [28, 33, 38, 43];

/// Where the hand sits for [chord] on the bass, and the notes under it:
/// the root on the E string if it's low enough, otherwise on the A string,
/// with a five-fret window starting just below it.
({int firstFret, List<({int string, int fret, String degree})> notes})
bassPositionFor(Chord chord) {
  final onE = (chord.root - bassTuning[0]) % 12;
  final onA = (chord.root - bassTuning[1]) % 12;
  final rootFret = onE >= 1 && onE <= 5 ? onE : (onA == 0 ? 12 : onA);
  final firstFret = rootFret <= 1 ? 1 : rootFret - 1;
  final degrees = {
    for (final degree in chord.quality.formula)
      chord.pitchClassFor(degree): degree == '1' ? 'R' : prettyDegree(degree),
  };
  return (
    firstFret: firstFret,
    notes: [
      for (var string = 0; string < 4; string++)
        for (
          var fret = firstFret == 1 ? 0 : firstFret;
          fret < firstFret + 5;
          fret++
        )
          if (degrees[(bassTuning[string] + fret) % 12] case final degree?)
            (string: string, fret: fret, degree: degree),
    ],
  );
}

class _BassPainter extends CustomPainter {
  _BassPainter({
    required this.chord,
    required this.dot,
    required this.rootDot,
    required this.onDot,
    required this.line,
    required this.label,
  });

  final Chord chord;
  final Color dot;
  final Color rootDot;
  final Color onDot;
  final Color line;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final position = bassPositionFor(chord);
    final first = position.firstFret;
    final showNut = first == 1;

    final top = size.height * 0.14;
    final left = size.width * 0.22;
    final right = size.width * 0.92;
    final bottom = size.height * 0.98;
    final stringGap = (right - left) / 3;
    final fretGap = (bottom - top) / 5;

    final wire = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var string = 0; string < 4; string++) {
      final x = left + string * stringGap;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), wire);
    }
    for (var fret = 0; fret <= 5; fret++) {
      final y = top + fret * fretGap;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        fret == 0 && showNut
            ? (Paint()
                ..color = line
                ..strokeWidth = 3.5)
            : wire,
      );
    }
    _text(
      canvas,
      '$first',
      Offset(left - stringGap * 0.55, top + fretGap / 2),
      color: label,
      size: 11,
    );

    final radius = math.min(stringGap, fretGap) * 0.4;
    for (final note in position.notes) {
      final x = left + note.string * stringGap;
      final isRoot = note.degree == 'R';
      if (note.fret == 0) {
        // Open string: a ring above the nut, labelled underneath it.
        final centre = Offset(x, top - fretGap * 0.38);
        canvas.drawCircle(
          centre,
          radius * 0.55,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = isRoot ? rootDot : dot,
        );
        continue;
      }
      final centre = Offset(x, top + (note.fret - first + 0.5) * fretGap);
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = isRoot ? rootDot : dot,
      );
      _text(canvas, note.degree, centre, color: onDot, size: radius * 0.95);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset centre, {
    required Color color,
    required double size,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_BassPainter old) =>
      old.chord.display != chord.display || old.dot != dot;
}

/// An arpeggio on the guitar or bass in one position: a chord box a few
/// frets tall, a line per string, with
/// every note of the [shape] marked by the degree it is — the roots filled
/// in, so the shape can be found from them.
class ArpeggioDiagram extends StatelessWidget {
  const ArpeggioDiagram({super.key, required this.shape});

  final FretArpeggio shape;

  /// The frets shown: at least four, from the shape's lowest.
  static int rowsFor(FretArpeggio shape) =>
      math.max(4, shape.highestFret - shape.lowestFret + 1);

  /// Width over height, for [shape]'s number of frets and strings.
  static double aspectFor(FretArpeggio shape) =>
      widthInStrings(shape) / (rowsFor(shape) * 1.1 + 0.6);

  /// How wide it is, in the gaps between strings (with room for the fret
  /// number): a bass's is narrower than a guitar's, at the same spacing.
  static double widthInStrings(FretArpeggio shape) => shape.tuning.length + 0.4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _ArpeggioPainter(
        shape: shape,
        font: Theme.of(context).textTheme.labelMedium ?? const TextStyle(),
        line: scheme.outline,
        label: scheme.onSurfaceVariant,
        root: scheme.primary,
        onRoot: scheme.onPrimary,
        tone: scheme.secondaryContainer,
        onTone: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _ArpeggioPainter extends CustomPainter {
  _ArpeggioPainter({
    required this.shape,
    required this.font,
    required this.line,
    required this.label,
    required this.root,
    required this.onRoot,
    required this.tone,
    required this.onTone,
  });

  final FretArpeggio shape;

  /// The app's lettering, for the degrees and the fret number.
  final TextStyle font;
  final Color line;
  final Color label;
  final Color root;
  final Color onRoot;
  final Color tone;
  final Color onTone;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = ArpeggioDiagram.rowsFor(shape);
    final strings = shape.tuning.length;
    final first = shape.lowestFret;
    final gap = size.width / ArpeggioDiagram.widthInStrings(shape);
    final left = gap * 0.9;
    final top = gap * 0.3;
    final fretGap = gap * 1.1;

    final wire = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var string = 0; string < strings; string++) {
      final x = left + string * gap;
      canvas.drawLine(Offset(x, top), Offset(x, top + rows * fretGap), wire);
    }
    for (var fret = 0; fret <= rows; fret++) {
      final y = top + fret * fretGap;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + (strings - 1) * gap, y),
        wire,
      );
    }
    _text(
      canvas,
      '$first',
      Offset(left - gap * 0.55, top + fretGap / 2),
      color: label,
      size: gap * 0.5,
    );

    final radius = gap * 0.44;
    for (final note in shape.notes) {
      final centre = Offset(
        left + note.string * gap,
        top + (note.fret - first + 0.5) * fretGap,
      );
      final isRoot = note.degree == '1';
      canvas.drawCircle(centre, radius, Paint()..color = isRoot ? root : tone);
      _text(
        canvas,
        note.degree,
        centre,
        color: isRoot ? onRoot : onTone,
        size: radius * (note.degree.length > 2 ? 0.8 : 1.0),
        maxWidth: radius * 1.9,
        bold: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset centre, {
    required Color color,
    required double size,
    double? maxWidth,
    bool bold = false,
  }) {
    var painter = _layout(text, color, size, bold);
    if (maxWidth != null && painter.width > maxWidth) {
      painter = _layout(text, color, size * maxWidth / painter.width, bold);
    }
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  TextPainter _layout(String text, Color color, double size, bool bold) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: font.copyWith(
            color: color,
            fontSize: size,
            height: 1,
            letterSpacing: 0,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  bool shouldRepaint(_ArpeggioPainter old) =>
      old.shape != shape || old.root != root || old.tone != tone;
}
