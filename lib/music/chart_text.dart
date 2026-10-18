// A chart written out as plain text, to send to someone or print.
//
// It follows what's on screen rather than the bar-by-bar chords: four bars
// to a line, a line per section, repeats folded and marked ×2, and 1st and
// 2nd endings written under each other, so what comes out reads like the
// chart the player has been looking at.
//
// Only the changes are written. There is no melody and no lyric anywhere in
// this app, and none in what it writes out.

import 'chart_layout.dart';
import 'meter.dart';
import 'tune.dart';

/// How wide each bar is written, so the barlines line up under each other.
const _barWidth = 14;

/// [tune] as text: a heading, then the chart.
///
/// [semitones] writes it in the key the player has it in rather than the
/// key it's written in, so what comes out matches what they were reading.
String chartText(Tune tune, {int semitones = 0, String? note}) {
  final moved = tune.transposed(semitones);
  final out = StringBuffer()..writeln(moved.title);
  final details = [
    ?moved.composer,
    ?moved.year?.toString(),
    'Key of ${moved.key}',
    if (moved.meter != Meter.four) moved.meter.written,
    '${moved.defaultTempo} bpm',
    if (moved.feel != Feel.swing) moved.feel.label,
  ];
  out
    ..writeln(details.join(' · '))
    ..writeln();

  final lines = layOutChart(moved, 4);
  final similes = similesFor(moved, lines);
  for (final (index, line) in lines.indexed) {
    // A section written once and played twice is marked at the end of it,
    // where the repeat sign goes on a lead sheet, not on every row.
    final last = index == lines.length - 1 || lines[index + 1].startsSection;
    out.writeln(
      _line(moved, line, similes: similes[index], endOfSection: last),
    );
  }
  if (note != null && note.isNotEmpty) {
    out
      ..writeln()
      ..writeln(note);
  }
  return out.toString();
}

/// One row of the chart: its section letter down the left, then its bars.
String _line(
  Tune tune,
  ChartLine line, {
  required List<bool> similes,
  required bool endOfSection,
}) {
  final left = line.startsSection && line.section != null
      ? '${line.section}'.padRight(3)
      : '   ';
  final bars = StringBuffer(left);
  for (final (index, cell) in line.cells.indexed) {
    // A gap under a 1st ending, so the 2nd sits beneath it.
    if (cell == null) {
      bars.write(' ' * (_barWidth + 2));
      continue;
    }
    // A bar that repeats the one before it is marked, not written twice.
    final chords = similes[index]
        ? simileMark.padRight(_barWidth)
        : _cell(tune, cell);
    bars.write('| $chords');
  }
  var text = '$bars|';
  // The ending number belongs to the bars at the end of the row: the ones
  // that differ the second time round.
  final ending = line.cells
      .whereType<ChartCell>()
      .where((cell) => cell.ending != null)
      .lastOrNull
      ?.ending;
  final marks = [
    if (line.repeat > 1 && endOfSection) '×${line.repeat}',
    if (ending != null) '$ending.',
  ];
  if (marks.isNotEmpty) text = '$text  ${marks.join(' ')}';
  return text.trimRight();
}

/// The chords in one box, e.g. "Dm7 G7".
String _cell(Tune tune, ChartCell cell) {
  final symbols = [
    for (final slot in tune.bars[cell.bars.first]) slot.chord.display,
  ];
  return symbols.join(' ').padRight(_barWidth);
}

/// Several charts one after another, for a whole setlist.
String chartsText(Iterable<Tune> tunes, {String? heading}) {
  final out = StringBuffer();
  if (heading != null) {
    out
      ..writeln(heading)
      ..writeln();
  }
  for (final (index, tune) in tunes.indexed) {
    if (index > 0) out.writeln('\n');
    out.write(chartText(tune));
  }
  return out.toString();
}
