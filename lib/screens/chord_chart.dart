// The chart itself: the whole tune at once, in bars, with the bar being
// played lit up.
//
// Everything in here serves one promise — the whole tune on one screen.
// The bars are sized so the longest line fits across it, and every chord
// is drawn at the same size, because a chart you have to squint at in one
// corner isn't one you can read at tempo.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../music/chart_layout.dart';
import '../music/chord_aids.dart';
import '../music/tune.dart';
import '../practice/practice_controller.dart';
import '../theme.dart';

/// The whole chart, always fitted to the available space: no scrolling.
///
/// Bars are laid out four to a line, like a lead sheet (eight on wide screens
/// when four would make the rows too short). Each section of the form starts
/// with its rehearsal letter boxed in the margin, as on a Real Book chart,
/// and a little extra space before it.
class ChordChart extends StatefulWidget {
  const ChordChart({super.key, required this.controller, this.stage = false});

  /// On the stage the chart is read, not marked up: a tap starts the band
  /// rather than setting a loop, so nobody changes what they're playing by
  /// touching the screen to get it going.
  final bool stage;

  final PracticeController controller;

  @override
  State<ChordChart> createState() => _ChordChartState();
}

class _ChordChartState extends State<ChordChart> {
  static const _padding = 8.0;
  static const _spacing = 4.0;
  static const _sectionGap = 10.0;
  static const _railWidth = 22.0;

  /// The shortest a row may be at the phone's normal text size. Anyone who
  /// has turned up Larger Text in their phone's accessibility settings gets
  /// taller rows in proportion; if the tune then won't fit, the chart
  /// scrolls rather than shrinking the chords back down.
  static const _readableRow = 30.0;

  final _scroll = ScrollController();
  int? _followedRow;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the bar being played in view when the chart scrolls.
  void _follow(int row, double rowTop, double rowHeight) {
    if (row == _followedRow) return;
    _followedRow = row;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      // Aim for a third of the way down, so what's coming next is visible.
      final target = (rowTop - position.viewportDimension / 3).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final tune = controller.chart;
    final hasSections = tune.sections.isNotEmpty;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 2 * _padding;
        final height = constraints.maxHeight - 2 * _padding;

        var columns = 4;
        if (width >= 700 &&
            height / (tune.barCount / 4).ceil() < 56 &&
            tune.barCount >= 8) {
          columns = 8;
        }
        // Repeats are folded: a section played twice is written once.
        final lines = layOutChart(tune, columns);
        final rowCount = lines.length;

        // Rows that begin a new section get extra space above them.
        final gaps = [
          for (var row = 0; row < rowCount; row++)
            row == 0
                ? 0.0
                : lines[row].startsSection
                ? _sectionGap
                : _spacing,
        ];
        final fitted = (height - gaps.fold(0.0, (a, b) => a + b)) / rowCount;
        final readable = textScale > 1 ? _readableRow * textScale : 12.0;
        final rowHeight = math.max(fitted, readable);
        final scrolls = rowHeight > fitted + 0.5;
        final railWidth = hasSections ? _railWidth : 0.0;
        final cellWidth =
            (width - railWidth - (columns - 1) * _spacing) / columns;
        // Chords are measured in the font they're drawn in, so every chord
        // meant to be one size comes out that size.
        final chordStyle = handLettered(DefaultTextStyle.of(context).style)
            .copyWith(fontSize: 100, height: 1);
        final measured = <String, double>{};
        double ems(String chord) => measured.putIfAbsent(chord, () {
          final painter = TextPainter(
            text: TextSpan(text: handSymbol(chord), style: chordStyle),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
          )..layout();
          final width = painter.width / 100;
          painter.dispose();
          return width;
        });
        final sizing = BarLayout.chartSizing(
          tune,
          [
            for (final line in lines)
              for (final cell in line.cells) ?cell?.bars.first,
          ],
          cellWidth,
          rowHeight,
          ems: ems,
        );

        // Which bar is under a point (e.g. a finger), in chart coordinates. A
        // folded box stands for its first time through.
        int barAt(Offset point) {
          final x = point.dx - _padding - railWidth;
          final column = (x / (cellWidth + _spacing)).floor().clamp(
            0,
            columns - 1,
          );
          var top = _padding;
          var row = 0;
          for (; row < rowCount - 1; row++) {
            top += gaps[row] + rowHeight;
            if (point.dy < top + gaps[row + 1] / 2) break;
          }
          final cells = lines[row].cells;
          final cell =
              cells[column] ??
              cells.whereType<ChartCell>().firstOrNull ??
              lines.expand((l) => l.cells).whereType<ChartCell>().first;
          return cell.bars.first;
        }

        final currentBar = controller.currentBeat == null
            ? null
            : controller.currentBeat! ~/ tune.beatsPerBar;
        if (scrolls && currentBar != null) {
          final row = lines.indexWhere(
            (line) =>
                line.cells.any((c) => c?.bars.contains(currentBar) ?? false),
          );
          if (row >= 0) {
            var top = 0.0;
            for (var r = 0; r <= row; r++) {
              top += gaps[r] + (r < row ? rowHeight : 0);
            }
            _follow(row, top, rowHeight);
          }
        }

        // What's written under each chord, bar by bar: the numbers, or the
        // guide tones, or nothing at all.
        //
        // Never on the stage. That view is the chart and nothing else —
        // there is no loop bar on it to say what the small red letters
        // are, and it is for playing off, not learning from.
        final aids = widget.stage
            ? const <int, List<String?>>{}
            : aidsFor(tune, controller.settings.chordAid);

        // Bars that repeat the one before them are written as a simile
        // mark rather than the same chords twice over.
        final similes = similesFor(tune, lines);

        final chart = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.stage
              ? null
              : (details) =>
                    controller.startLoopDrag(barAt(details.localPosition)),
          onPanUpdate: widget.stage
              ? null
              : (details) =>
                    controller.updateLoopDrag(barAt(details.localPosition)),
          onPanEnd: widget.stage ? null : (_) => controller.endLoopDrag(),
          onPanCancel: widget.stage ? null : controller.endLoopDrag,
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              children: [
                for (var row = 0; row < rowCount; row++) ...[
                  SizedBox(height: gaps[row]),
                  SizedBox(
                    height: rowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasSections)
                          _SectionRail(
                            section: lines[row].section,
                            showLetter: lines[row].startsSection,
                            repeat: lines[row].repeat,
                            width: _railWidth,
                          ),
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) const SizedBox(width: _spacing),
                          SizedBox(
                            width: cellWidth,
                            child: lines[row].cells[col] == null
                                ? null
                                : _BarCell(
                                    controller: controller,
                                    cell: lines[row].cells[col]!,
                                    simile: similes[row][col],
                                    aids:
                                        aids[lines[row]
                                            .cells[col]!
                                            .bars
                                            .first] ??
                                        const [],
                                    stage: widget.stage,
                                    section: lines[row].section,
                                    width: cellWidth,
                                    height: rowHeight,
                                    stack: sizing.stack,
                                    ems: ems,
                                    chordSize: sizing.size,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        return scrolls
            ? SingleChildScrollView(controller: _scroll, child: chart)
            : chart;
      },
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.section,
    required this.showLetter,
    required this.width,
    this.repeat = 1,
  });

  final String? section;
  final bool showLetter;
  final double width;

  /// How many times the section is played, when it's written once: ×2.
  final int repeat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!showLetter || section == null) return SizedBox(width: width);
    final box = width - 6;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SizedBox(
        width: box,
        // The letter and its ×2 shrink together when a row is shorter than
        // they are, which it can be on a phone held sideways with a long
        // tune on it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The rehearsal letter, boxed.
              Container(
                width: box,
                height: box,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.onSurface, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Text(
                      section!,
                      style: handLettered(TextStyle(color: scheme.onSurface)),
                    ),
                  ),
                ),
              ),
              if (repeat > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: FittedBox(
                    child: Text(
                      '×$repeat',
                      key: const ValueKey('repeat-mark'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How one bar's chords sit in its box: on one line, or stacked by half-bar
/// (first half on top), and the biggest size each line fits at.
class BarLayout {
  const BarLayout(this.lines, this.fits);

  /// Indexes into the bar's chords, a line at a time.
  final List<List<int>> lines;

  /// The biggest font size each line fits at.
  final List<double> fits;

  /// About how wide [symbol] is in bold, in ems: narrow ♭ and 1, wide m
  /// and Δ. Close enough that chords fit without being shrunk again.
  static double emsOf(String symbol) {
    var ems = 0.0;
    for (final char in symbol.runes.map(String.fromCharCode)) {
      ems += switch (char) {
        '♭' || '♯' => 0.56,
        '/' || '1' => 0.42,
        'm' || 'M' || 'W' => 0.9,
        'Δ' || 'ø' || '°' => 0.68,
        _ when RegExp(r'[A-Z]').hasMatch(char) => 0.7,
        _ when RegExp(r'[0-9]').hasMatch(char) => 0.58,
        _ => 0.52,
      };
    }
    return math.max(ems, 1.2);
  }

  static double emsOfSlot(ChordSlot slot) => emsOf(slot.chord.display);

  static BarLayout of(
    Tune tune,
    int barIndex,
    double width,
    double height, {
    required bool stack,
    double Function(String chord) ems = emsOf,
  }) {
    final slots = tune.bars[barIndex];
    final sideRoom = width - (height >= 28 ? 14.0 : 0);
    double fit(List<int> line, int lineCount) => math.min(
      height * 0.72 / lineCount,
      (sideRoom - 6.0 * line.length) /
          line.map((i) => ems(slots[i].chord.display)).reduce((a, b) => a + b),
    );
    final halfway = tune.barStartBeat(barIndex) + tune.beatsPerBar / 2;
    final halves = [
      [
        for (var i = 0; i < slots.length; i++)
          if (slots[i].startBeat < halfway) i,
      ],
      [
        for (var i = 0; i < slots.length; i++)
          if (slots[i].startBeat >= halfway) i,
      ],
    ];
    final lines = stack && halves.every((half) => half.isNotEmpty)
        ? halves
        : [
            [for (var i = 0; i < slots.length; i++) i],
          ];
    return BarLayout(lines, [
      for (final line in lines) fit(line, lines.length),
    ]);
  }

  /// One rule and one size for the whole chart, so every bar looks alike,
  /// as on a printed lead sheet:
  ///  • Busy bars stack if that lets the whole chart be drawn clearly
  ///    bigger (on a phone, where boxes are tall and narrow).
  ///  • Every chord is drawn at the one size they all fit at. Only a chord
  ///    far longer than the rest is left to shrink on its own, rather than
  ///    shrinking the whole chart.
  /// As big as a chord is ever drawn while practising. Past this the
  /// chart stops looking like a chart and starts looking like a poster.
  static const biggestChord = 80.0;

  static ({bool stack, double size}) chartSizing(
    Tune tune,
    List<int> bars,
    double width,
    double height, {
    double Function(String chord) ems = emsOf,
  }) {
    double median(List<double> values) =>
        ([...values]..sort())[values.length ~/ 2];
    final busyBars = [
      for (final bar in bars)
        if (tune.bars[bar].length > 1) bar,
    ];
    // Each line's biggest size, with how many chords are on it.
    List<({double fit, int chords})> fits(List<int> which, bool stack) => [
      for (final bar in which)
        for (final layout in [
          BarLayout.of(tune, bar, width, height, stack: stack, ems: ems),
        ])
          for (var i = 0; i < layout.lines.length; i++)
            (fit: layout.fits[i], chords: layout.lines[i].length),
    ];
    // The one size every chord can be drawn at, with this layout. Chords
    // far too long for it are let off only if they're rare — one chord in
    // ten at most, counted as the eye sees them. Any more and they're part
    // of the tune's look, and everything matches them.
    double sizeWith(bool stack) {
      final all = fits(bars, stack);
      final middle = median([for (final line in all) line.fit]);
      final roomy = [
        for (final line in all)
          if (line.fit >= middle * 0.6) line,
      ];
      int chordsIn(List<({double fit, int chords})> lines) =>
          lines.fold(0, (sum, line) => sum + line.chords);
      final lines = chordsIn(roomy) >= chordsIn(all) * 0.9 ? roomy : all;
      return lines
          .map((line) => line.fit)
          .reduce(math.min)
          .clamp(10.0, biggestChord);
    }

    // Stack the busy bars if that lets the whole chart be clearly bigger
    // (side by side reads more naturally, so it wins a near tie).
    final sideBySide = sizeWith(false);
    final stacked = busyBars.isEmpty ? 0.0 : sizeWith(true);
    final stack = stacked > sideBySide * 1.1;
    final size = stack ? stacked : sideBySide;
    return (stack: stack, size: size);
  }
}

class _BarCell extends StatelessWidget {
  const _BarCell({
    required this.controller,
    required this.cell,
    required this.simile,
    required this.aids,
    required this.stage,
    required this.section,
    required this.width,
    required this.height,
    required this.stack,
    required this.chordSize,
    required this.ems,
  });

  /// How wide a chord is drawn, in ems of the chart's font.
  final double Function(String chord) ems;

  /// Whether bars with chords in both halves stack them (the same for the
  /// whole chart, so neighbouring bars look alike).
  final bool stack;

  /// The size every chord on the chart is drawn at, if it fits.
  final double chordSize;

  final PracticeController controller;

  /// The box: the bar it shows, and every other time through it stands for.
  final ChartCell cell;

  /// Whether it plays the same as the box to its left, and so is written
  /// as a repeat mark rather than the same chords again.
  final bool simile;

  /// On the stage a bar isn't tapped to loop it; the tap starts the band.
  final bool stage;

  /// What to write under each chord in this bar, in the same order as its
  /// chords. Empty when nothing is written under them.
  final List<String?> aids;
  final String? section;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tune = controller.chart;
    final loop = controller.loop;
    // Mid-run the chart can be down to its bars: the box, the number and
    // the letter stay, so you can see where you are, and what is in it is
    // yours to remember.
    final blank = !controller.chartShows.hasChords;
    final barIndex = cell.bars.first;
    final slots = tune.bars[barIndex];
    final inLoop = cell.bars.any((bar) => loop.overlapsBar(tune, bar));
    final currentBeat = controller.currentBeat;
    final currentBar = currentBeat == null
        ? null
        : currentBeat ~/ tune.beatsPerBar;
    final isCurrentBar = cell.bars.contains(currentBar);
    // Where the band comes in, when that isn't the top of the loop.
    final startsHere = controller.startBar == barIndex;
    // A loop is marked on the chart as you'd pencil it in: repeat signs
    // where it starts and ends.
    final marked = !loop.isWholeTune(tune);
    final opensLoop = marked && cell.bars.contains(loop.firstBar(tune));
    final closesLoop = marked && cell.bars.contains(loop.lastBar(tune));
    // A 1st or 2nd ending is labelled as one instead of with a bar number.
    final label = cell.ending != null ? '${cell.ending}.' : '${barIndex + 1}';

    final layout = BarLayout.of(
      tune,
      barIndex,
      width,
      height,
      stack: stack,
      ems: ems,
    );
    final lines = layout.lines;
    final stacked = lines.length > 1;
    // The chart's one chord size, unless this line can't fit it.
    final sizes = [
      for (final fit in layout.fits)
        math.min(fit, chordSize).clamp(10.0, BarLayout.biggestChord),
    ];
    int charsOf(int i) => (ems(slots[i].chord.display) * 20).round();
    final numberSize = (height * 0.16).clamp(8.0, 14.0);
    final showNumber = height >= 28;
    final numberWidth = label.length * numberSize * 0.62;

    return Semantics(
      button: true,
      label:
          '${cell.ending != null
              ? '${cell.ending == 1 ? 'First' : 'Second'} ending, bar'
              : cell.bars.length > 1
              ? 'Bars'
              : 'Bar'} '
          '${startsHere ? 'Starts here, ' : ''}'
          '${cell.bars.map((b) => b + 1).join(' and ')}'
          // Read aloud it would give away exactly what the exercise is
          // taking off the screen.
          '${blank ? '' : ': ${slots.map((s) => s.chord.display).join(', ')}'}',
      child: Opacity(
        opacity: inLoop ? 1 : 0.35,
        // Paper, ruled off like a lead sheet's bars; the bar that's playing
        // marked in pencil.
        child: Material(
          color: isCurrentBar ? scheme.tertiaryContainer : cardColour(scheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(math.min(6, height / 5)),
            side: isCurrentBar
                ? BorderSide(color: scheme.tertiary, width: 2.5)
                : BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: stage ? null : () => controller.loopBar(barIndex),
            // Take it from here: the first time through starts on this bar.
            // A long press, so tapping to loop is untouched.
            onLongPress: stage
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    controller.startFromBar(barIndex);
                  },
            child: Stack(
              children: [
                // A 1st or 2nd ending is bracketed across the top, as on a
                // lead sheet.
                if (cell.ending != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 3,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                // A wedge in the margin, pointing in: this is where the
                // band comes in the first time through.
                if (startsHere)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        key: const ValueKey('starts-here'),
                        width: 5,
                        height: height * 0.55,
                        decoration: BoxDecoration(
                          color: scheme.tertiary,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (opensLoop || closesLoop)
                  Positioned.fill(
                    child: CustomPaint(
                      key: const ValueKey('loop-mark'),
                      painter: _RepeatSigns(
                        open: opensLoop,
                        close: closesLoop,
                        colour: scheme.tertiary,
                      ),
                    ),
                  ),
                if (showNumber || cell.ending != null)
                  Positioned(
                    left: opensLoop ? 9 : 4,
                    top: cell.ending != null ? 4 : 1,
                    child: Text(
                      label,
                      // A label, not something to read from across the room:
                      // it stays small even with Larger Text turned on, so
                      // it can't grow into the chord.
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: numberSize,
                        height: 1.1,
                        fontWeight: cell.ending != null
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: cell.ending != null
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                // The bar number gets its own strip down the left. Chords are
                // limited by the cell's height, not its width, so taking the
                // room from the side costs them nothing.
                Padding(
                  padding: EdgeInsets.only(
                    left: showNumber ? 6 + numberWidth : 4,
                    right: 4,
                  ),
                  child: blank
                      ? const SizedBox.shrink()
                      : simile
                      // The same as the bar before it: written once and
                      // then marked, the way it's written by hand.
                      ? Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              simileMark,
                              textScaler: TextScaler.noScaling,
                              semanticsLabel: 'the same again',
                              style: handLettered(
                                TextStyle(
                                  fontSize: sizes.first,
                                  height: 1,
                                  leadingDistribution:
                                      TextLeadingDistribution.even,
                                  color: _chordColour(scheme, 0),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (var l = 0; l < lines.length; l++)
                              Expanded(
                                child: Row(
                                  key: stacked
                                      ? const ValueKey('stacked')
                                      : null,
                                  children: [
                                    for (final i in lines[l])
                                      Expanded(
                                        flex: charsOf(i),
                                        child: Padding(
                                          // Keeps two chords in one bar from touching.
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    handSymbol(
                                                      slots[i].chord.display,
                                                    ),
                                                    // Sized from the box, which already
                                                    // grows with Larger Text.
                                                    textScaler:
                                                        TextScaler.noScaling,
                                                    style: handLettered(
                                                      TextStyle(
                                                        fontSize: sizes[l],
                                                        // Chord symbols have no descenders, so
                                                        // they don't need the space a line of
                                                        // text keeps below and above itself —
                                                        // without it they fit a third bigger.
                                                        height: 1,
                                                        leadingDistribution:
                                                            TextLeadingDistribution
                                                                .even,
                                                        color: _chordColour(
                                                          scheme,
                                                          i,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // What the chord is in the key,
                                              // or its guide tones: written
                                              // small under the chord, the
                                              // way you'd pencil it on
                                              // yourself.
                                              if (aids.elementAtOrNull(i)
                                                  case final aid?)
                                                Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      aid,
                                                      textScaler:
                                                          TextScaler.noScaling,
                                                      style: TextStyle(
                                                        fontSize:
                                                            (sizes[l] * 0.42)
                                                                .clamp(
                                                                  8.0,
                                                                  22.0,
                                                                ),
                                                        height: 1.25,
                                                        color: scheme.tertiary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The [index]th chord in the box: highlighted while it's being played
  /// (whichever time through), dimmed if no time through is in the loop.
  Color _chordColour(ColorScheme scheme, int index) {
    final tune = controller.chart;
    final beat = controller.currentBeat;
    final times = [for (final bar in cell.bars) tune.bars[bar][index]];
    if (beat != null &&
        times.any((slot) => beat >= slot.startBeat && beat < slot.endBeat)) {
      return scheme.onTertiaryContainer;
    }
    if (!times.any(controller.loop.containsSlot)) {
      return scheme.onSurface.withValues(alpha: 0.4);
    }
    return scheme.onSurface;
  }
}

/// Repeat signs in pencil, as a player marks a passage to loop on a chart:
/// ‖: at the start, :‖ at the end.
class _RepeatSigns extends CustomPainter {
  const _RepeatSigns({
    required this.open,
    required this.close,
    required this.colour,
  });

  final bool open;
  final bool close;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final thick = Paint()
      ..color = colour
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = colour
      ..strokeWidth = 1.3;
    final dot = Paint()..color = colour;
    final top = size.height * 0.12;
    final bottom = size.height * 0.88;
    final radius = (size.height * 0.035).clamp(1.5, 2.6);
    // Drawn from the edge inwards; mirrored for the end of the loop.
    void sign(double edge, double inward) {
      canvas
        ..drawLine(
          Offset(edge + inward * 2.5, top),
          Offset(edge + inward * 2.5, bottom),
          thick,
        )
        ..drawLine(
          Offset(edge + inward * 6, top),
          Offset(edge + inward * 6, bottom),
          thin,
        )
        ..drawCircle(
          Offset(edge + inward * 9.5, size.height * 0.4),
          radius,
          dot,
        )
        ..drawCircle(
          Offset(edge + inward * 9.5, size.height * 0.6),
          radius,
          dot,
        );
    }

    if (open) sign(0, 1);
    if (close) sign(size.width, -1);
  }

  @override
  bool shouldRepaint(_RepeatSigns old) =>
      old.open != open || old.close != close || old.colour != colour;
}

class CountInBubble extends StatelessWidget {
  const CountInBubble({super.key, required this.beat});

  final int beat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.biggest.shortestSide * 0.4).clamp(
          80.0,
          240.0,
        );
        return Center(
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            // The count, pencilled large over the chart.
            decoration: BoxDecoration(
              color: cardColour(scheme),
              shape: BoxShape.circle,
              border: Border.all(color: scheme.tertiary, width: 3),
            ),
            child: Text(
              '$beat',
              style: handLettered(
                TextStyle(fontSize: size * 0.62, color: scheme.tertiary),
              ),
            ),
          ),
        );
      },
    );
  }
}
