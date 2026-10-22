// The chart itself: the whole tune at once, in bars, with the bar being
// played lit up.
//
// Everything in here serves one promise: the whole tune on one screen.
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
import '../settings/chord_colours.dart';
import '../theme.dart';

/// The whole chart, always fitted to the available space: no scrolling.
///
/// Bars are laid out four to a line, like a lead sheet (eight on wide screens
/// when four would make the rows too short). Each section of the form starts
/// with its rehearsal letter boxed in the margin, as on a Real Book chart,
/// and a little extra space before it.
class ChordChart extends StatefulWidget {
  const ChordChart({
    super.key,
    required this.controller,
    this.stage = false,
    this.follow = false,
    this.heardBeat,
    this.onBarTapped,
  });

  /// Where the music in the room is, when the chart follows that rather
  /// than the band: the beat to mark and scroll to, in place of the
  /// band's. Null marks nothing, which is what an unsure ear should do.
  final int? heardBeat;

  /// Called with the bar a finger lands on, where a tap means "we are
  /// here" rather than starting the band or setting a loop.
  final ValueChanged<int>? onBarTapped;

  /// Whether the chart is following an ear rather than the band.
  bool get listening => onBarTapped != null;

  /// On the stage the chart is read, not marked up: a tap starts the band
  /// rather than setting a loop, so nobody changes what they're playing by
  /// touching the screen to get it going.
  final bool stage;

  /// A few big rows that scroll with the band, rather than the whole tune
  /// shrunk to the screen: on a stand a metre away, a forty-bar chart
  /// fitted to a phone is too small to read, and nobody can scroll it
  /// with a horn in their hands. It keeps the bar being played near the
  /// top, with what is coming under it.
  final bool follow;

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

  /// How many rows the stage shows at once when it follows the band: big
  /// enough to read from a metre away, with the next line or two in view.
  static const _stageRows = 5;

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
      // Following on the stage, the line just played stays above it and
      // the rest of the screen is what is coming.
      final above = widget.follow
          ? rowHeight + _spacing
          : position.viewportDimension / 3;
      final target = (rowTop - above).clamp(0.0, position.maxScrollExtent);
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
        final big = widget.follow ? height / _stageRows : 0.0;
        final rowHeight = math.max(fitted, math.max(readable, big));
        final scrolls = rowHeight > fitted + 0.5;
        // Back to the whole chart, and the next follow starts afresh.
        if (!scrolls) _followedRow = null;
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
        final chordSize = BarLayout.chartSize(
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

        final beat = widget.listening
            ? widget.heardBeat
            : controller.currentBeat;
        final currentBar = beat == null ? null : beat ~/ tune.beatsPerBar;
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
        // Never on the stage. That view is the chart and nothing else;
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
          onTapUp: widget.onBarTapped == null
              ? null
              : (details) => widget.onBarTapped!(barAt(details.localPosition)),
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
                                    beat: beat,
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
                                    ems: ems,
                                    chordSize: chordSize,
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

/// How one bar's chords sit in its box: on one line, read left to right as
/// on a page, and the biggest size they fit at.
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

  /// The space between two chords in a bar, in ems: as wide as a letter,
  /// so C6/G G7 never reads as C6/GG7.
  static const gapEms = 0.6;

  static BarLayout of(
    Tune tune,
    int barIndex,
    double width,
    double height, {
    double Function(String chord) ems = emsOf,
  }) {
    final slots = tune.bars[barIndex];
    final sideRoom = width - (height >= 28 ? 14.0 : 0);
    double fit(List<int> line, int lineCount) => math.min(
      height * 0.72 / lineCount,
      (sideRoom - 6.0 * line.length) /
          (line
                  .map((i) => ems(slots[i].chord.display))
                  .reduce((a, b) => a + b) +
              gapEms * (line.length - 1)),
    );
    final lines = [
      [for (var i = 0; i < slots.length; i++) i],
    ];
    return BarLayout(lines, [
      for (final line in lines) fit(line, lines.length),
    ]);
  }

  /// One size for the whole chart, so every bar looks alike, as on a
  /// printed lead sheet: every chord on its own in a bar is drawn at the
  /// one size they all fit at. Only a chord far longer than the rest, or
  /// two in a bar side by side, are left to shrink on their own, rather
  /// than shrinking the whole chart.
  /// As big as a chord is ever drawn while practising. Past this the
  /// chart stops looking like a chart and starts looking like a poster.
  static const biggestChord = 80.0;

  static double chartSize(
    Tune tune,
    List<int> bars,
    double width,
    double height, {
    double Function(String chord) ems = emsOf,
  }) {
    double median(List<double> values) =>
        ([...values]..sort())[values.length ~/ 2];
    // Each line's biggest size, with how many chords are on it.
    var all = [
      for (final bar in bars)
        for (final layout in [BarLayout.of(tune, bar, width, height, ems: ems)])
          for (var i = 0; i < layout.lines.length; i++)
            (fit: layout.fits[i], chords: layout.lines[i].length),
    ];
    // The one size every chord can be drawn at, with this layout. Chords
    // far too long for it are let off only if they're rare: one chord in
    // ten at most, counted as the eye sees them. Any more and they're part
    // of the tune's look, and everything matches them.
    // Sized by the bars of one chord, where there are any: a bar of two,
    // side by side, is drawn smaller rather than the whole chart, as in
    // iReal Pro.
    final singles = [
      for (final line in all)
        if (line.chords == 1) line,
    ];
    if (singles.isNotEmpty) all = singles;
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
}

class _BarCell extends StatelessWidget {
  const _BarCell({
    required this.controller,
    required this.beat,
    required this.cell,
    required this.simile,
    required this.aids,
    required this.stage,
    required this.section,
    required this.width,
    required this.height,
    required this.chordSize,
    required this.ems,
  });

  /// How wide a chord is drawn, in ems of the chart's font.
  final double Function(String chord) ems;

  /// The size every chord on the chart is drawn at, if it fits.
  final double chordSize;

  /// The beat being played, the band's or the one heard in the room.
  final int? beat;

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
    final currentBeat = beat;
    final currentBar = currentBeat == null
        ? null
        : currentBeat ~/ tune.beatsPerBar;
    final isCurrentBar = cell.bars.contains(currentBar);
    final mark = controller.settings.markTheBar;
    // Where the band comes in, when that isn't the top of the loop.
    final startsHere = controller.startBar == barIndex;
    // A loop is marked on the chart as you'd pencil it in: repeat signs
    // where it starts and ends.
    final marked = !loop.isWholeTune(tune);
    final opensLoop = marked && cell.bars.contains(loop.firstBar(tune));
    final closesLoop = marked && cell.bars.contains(loop.lastBar(tune));
    // A 1st or 2nd ending is labelled as one instead of with a bar number.
    final label = cell.ending != null ? '${cell.ending}.' : '${barIndex + 1}';

    final layout = BarLayout.of(tune, barIndex, width, height, ems: ems);
    final lines = layout.lines;
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
          // Filled, ruled round, or left alone: whichever the reader can
          // stand having travel across the page at them.
          color: isCurrentBar && mark.fills
              ? scheme.tertiaryContainer
              : cardColour(scheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(math.min(6, height / 5)),
            side: isCurrentBar && mark.marks
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
                            child: _playingMark(
                              scheme,
                              0,
                              sizes.first,
                              Text(
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
                          ),
                        )
                      : Column(
                          children: [
                            for (var l = 0; l < lines.length; l++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (final i in lines[l]) ...[
                                      // Keeps two chords in one bar well
                                      // apart, as fitting them allowed for.
                                      if (i != lines[l].first)
                                        SizedBox(
                                          width: sizes[l] * BarLayout.gapEms,
                                        ),
                                      Expanded(
                                        flex: charsOf(i),
                                        child: Padding(
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
                                                  child: _playingMark(
                                                    scheme,
                                                    i,
                                                    sizes[l],
                                                    _lettered(
                                                      scheme,
                                                      i,
                                                      sizes[l],
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

  /// Whether the [index]th chord in the box is being played, whichever
  /// time through.
  bool _playing(int index) {
    final beat = this.beat;
    if (beat == null) return false;
    final tune = controller.chart;
    return cell.bars.any((bar) {
      final slot = tune.bars[bar][index];
      return beat >= slot.startBeat && beat < slot.endBeat;
    });
  }

  /// [chord], underlined in the pencil red while it is being played: the
  /// bar's box says which bar, and this which of its chords.
  Widget _playingMark(
    ColorScheme scheme,
    int index,
    double size,
    Widget chord,
  ) {
    if (!_playing(index) || !controller.settings.markTheBar.marks) return chord;
    return DecoratedBox(
      key: const ValueKey('chord-playing'),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.tertiary,
            width: (size * 0.08).clamp(2.0, 6.0),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: size * 0.08),
        child: chord,
      ),
    );
  }

  /// The [index]th chord in the box, lettered at [size]: in its root's
  /// colour, and a slash bass in its own note's colour, being another
  /// note (C6/G's G is G's colour, not C's).
  Text _lettered(ColorScheme scheme, int index, double size) {
    final chord = controller.chart.bars[cell.bars.first][index].chord;
    final symbol = handSymbol(chord.display);
    final style = handLettered(
      TextStyle(
        fontSize: size,
        // Chord symbols have no descenders, so they don't need the space a
        // line of text keeps below and above itself; without it they fit
        // a third bigger.
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
        color: _chordColour(scheme, index),
      ),
    );
    final slash = symbol.lastIndexOf('/');
    // Sized from the box, which already grows with Larger Text.
    if (chord.bassLetter == null || slash < 0) {
      return Text(symbol, textScaler: TextScaler.noScaling, style: style);
    }
    return Text.rich(
      TextSpan(
        text: symbol.substring(0, slash),
        children: [
          TextSpan(
            text: symbol.substring(slash),
            style: TextStyle(color: _chordColour(scheme, index, bass: true)),
          ),
        ],
      ),
      textScaler: TextScaler.noScaling,
      style: style,
    );
  }

  /// The [index]th chord in the box (its slash [bass], if asked for):
  /// highlighted while it's being played (whichever time through), dimmed
  /// if no time through is in the loop.
  Color _chordColour(ColorScheme scheme, int index, {bool bass = false}) {
    final tune = controller.chart;
    final times = [for (final bar in cell.bars) tune.bars[bar][index]];
    final chord = times.first.chord;
    // The colour somebody sees this note as, if they see roots as
    // colours. Lifted or dropped only as far as it must be to be read on
    // whichever paper the app is on, which leaves the hue alone.
    final theirs = controller.settings.chordColourFor(
      bass ? chord.bass : chord.root,
    );
    final ink = theirs == null
        ? scheme.onSurface
        : readableOn(theirs, scheme.surface);
    if (_playing(index)) {
      // The bar being played is already boxed and tinted, so it does not
      // need the lettering as well, and taking somebody's colour away on
      // the one bar they are looking at would be the wrong way round.
      //
      // Unless the tint is not there, in which case the lettering has to
      // go back to the ordinary ink: a colour chosen to read on a tinted
      // box is the wrong one on plain paper.
      if (!controller.settings.markTheBar.fills) return ink;
      return theirs == null ? scheme.onTertiaryContainer : ink;
    }
    if (!times.any(controller.loop.containsSlot)) {
      return ink.withValues(alpha: 0.4);
    }
    return ink;
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
