// How a tune is laid out on screen, with repeats folded the way a lead sheet
// writes them.
//
//  • A section played twice with the same chords (Autumn Leaves' A) is
//    written once and marked ×2.
//  • A section played twice with a different last bar or two (Cherokee's A,
//    rhythm changes) is written once, with 1st and 2nd endings.
//
// Each box on screen stands for every bar it's played as: the folded A of
// Autumn Leaves has bar 1 standing for bars 1 and 9. The band still plays
// the whole tune; only the drawing is shorter.

import 'tune.dart';

/// One box on the chart.
class ChartCell {
  const ChartCell(this.bars, {this.ending});

  /// The tune bars (0-based) this box stands for, in the order they're
  /// played. More than one when a repeat is folded.
  final List<int> bars;

  /// 1 or 2 when this bar is part of a 1st or 2nd ending.
  final int? ending;
}

/// One row of boxes.
class ChartLine {
  const ChartLine({
    required this.cells,
    required this.section,
    this.startsSection = false,
    this.repeat = 1,
  });

  /// Exactly as many as there are columns; null leaves a gap (2nd endings
  /// line up under the 1st).
  final List<ChartCell?> cells;

  /// The section letter this row belongs to, if the tune has sections.
  final String? section;

  /// Whether the section's letter is shown on this row.
  final bool startsSection;

  /// How many times the section is played, when it's folded: 2 for ×2.
  final int repeat;
}

/// Lays [tune] out [columns] boxes to a row, each section starting a new
/// row, with repeated sections folded.
List<ChartLine> layOutChart(Tune tune, int columns) {
  final sections = _sections(tune);
  final lines = <ChartLine>[];

  void addRows(
    List<ChartCell?> cells,
    String? letter, {
    required bool first,
    int repeat = 1,
  }) {
    for (var start = 0; start < cells.length; start += columns) {
      final row = cells.sublist(
        start,
        (start + columns).clamp(0, cells.length),
      );
      lines.add(
        ChartLine(
          cells: [
            ...row,
            ...List<ChartCell?>.filled(columns - row.length, null),
          ],
          section: letter,
          startsSection: first && start == 0 && letter != null,
          repeat: repeat,
        ),
      );
    }
  }

  var i = 0;
  while (i < sections.length) {
    final section = sections[i];

    // The same section again, straight after: fold as many as there are.
    var times = 1;
    while (i + times < sections.length &&
        _sameChords(tune, section, sections[i + times])) {
      times++;
    }
    if (times > 1) {
      addRows(
        [
          for (var b = 0; b < section.length; b++)
            ChartCell([
              for (var t = 0; t < times; t++) sections[i + t].start + b,
            ]),
        ],
        section.letter,
        first: true,
        repeat: times,
      );
      i += times;
      continue;
    }

    // Played again with a different ending.
    final next = i + 1 < sections.length ? sections[i + 1] : null;
    final ending = next == null ? 0 : _endingLength(tune, section, next);
    if (next != null && ending > 0) {
      final shared = section.length - ending;
      final firstPass = [
        for (var b = 0; b < shared; b++)
          ChartCell([section.start + b, next.start + b]),
        for (var b = shared; b < section.length; b++)
          ChartCell([section.start + b], ending: 1),
      ];
      addRows(firstPass, section.letter, first: true);
      // The 2nd ending goes on its own row, lined up under the 1st.
      final column = shared % columns;
      final secondEnding = [
        for (var b = shared; b < section.length; b++)
          ChartCell([next.start + b], ending: 2),
      ];
      addRows(
        [
          if (column + ending <= columns)
            ...List<ChartCell?>.filled(column, null),
          ...secondEnding,
        ],
        section.letter,
        first: false,
      );
      i += 2;
      continue;
    }

    addRows(
      [
        for (var b = 0; b < section.length; b++) ChartCell([section.start + b]),
      ],
      section.letter,
      first: true,
    );
    i++;
  }
  return lines;
}

typedef _Section = ({String? letter, int start, int length});

/// The tune's sections in order; the whole tune if it has none.
List<_Section> _sections(Tune tune) {
  if (tune.sections.isEmpty) {
    return [(letter: null, start: 0, length: tune.barCount)];
  }
  final starts = tune.sections.keys.toList()..sort();
  return [
    // Any bars before the first marked section.
    if (starts.first > 0) (letter: null, start: 0, length: starts.first),
    for (var k = 0; k < starts.length; k++)
      (
        letter: tune.sections[starts[k]],
        start: starts[k],
        length:
            (k + 1 < starts.length ? starts[k + 1] : tune.barCount) - starts[k],
      ),
  ];
}

String _barText(Tune tune, int bar) => tune.bars[bar]
    .map((slot) => '${slot.chord.display}:${slot.beats}')
    .join(' ');

bool _sameChords(Tune tune, _Section a, _Section b) {
  if (a.letter == null || a.letter != b.letter || a.length != b.length) {
    return false;
  }
  for (var bar = 0; bar < a.length; bar++) {
    if (_barText(tune, a.start + bar) != _barText(tune, b.start + bar)) {
      return false;
    }
  }
  return true;
}

/// How many bars at the end of [b] differ from [a], when everything before
/// them is the same — the length of the 1st and 2nd endings. Zero if they
/// aren't the same section with a new ending. Endings are at most half the
/// section; more than that is a different section, not a repeat.
int _endingLength(Tune tune, _Section a, _Section b) {
  if (a.letter == null || a.letter != b.letter || a.length != b.length) {
    return 0;
  }
  var shared = 0;
  while (shared < a.length &&
      _barText(tune, a.start + shared) == _barText(tune, b.start + shared)) {
    shared++;
  }
  final ending = a.length - shared;
  return ending > 0 && ending <= a.length ~/ 2 ? ending : 0;
}

/// Which boxes are written as a simile mark — "play the bar before again"
/// — instead of having the same chords written out twice.
///
/// This is how a chart is written by hand, and how iReal Pro and the fake
/// books show it: four bars of Cm7 are Cm7 and then three repeat marks, so
/// the eye sees at a glance that nothing changes. The run carries on down
/// the page, across the end of a row, as iReal Pro's does.
///
/// Two boxes always say what they are, however long the run. A section's
/// first bar does, because you can arrive at a rehearsal letter from
/// somewhere else and a mark there would point at a bar you never played.
/// And a 1st or 2nd ending does, because an ending is where the chart
/// stops running straight on.
///
/// Comes back one list of marks per row, to match [lines].
List<List<bool>> similesFor(Tune tune, List<ChartLine> lines) {
  final marks = [
    for (final line in lines) List.filled(line.cells.length, false),
  ];
  // The last box actually written out or marked, which is what the next
  // one repeats — the box to its left, or the end of the row above.
  String? before;
  int? beforeEnding;
  for (var row = 0; row < lines.length; row++) {
    final line = lines[row];
    for (var col = 0; col < line.cells.length; col++) {
      final cell = line.cells[col];
      // A gap, where a 2nd ending sits under a 1st: nothing is written.
      if (cell == null) continue;
      final chords = _barText(tune, cell.bars.first);
      final startsSection = line.startsSection && col == 0;
      marks[row][col] =
          !startsSection &&
          before != null &&
          chords == before &&
          cell.ending == beforeEnding;
      before = chords;
      beforeEnding = cell.ending;
    }
  }
  return marks;
}

/// What a repeated bar is written as, on screen and in text: the simile
/// mark, which a player reads as "the same again".
const simileMark = '%';
