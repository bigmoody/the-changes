// The chart as a page of music, for printing or for sending to somebody
// who has no app at all.
//
// It is the chart as it is on screen: the same folding, so a section
// played twice is written once and marked ×2, the same 1st and 2nd
// endings, the same hand lettering. Drawn rather than typeset, because
// the lettering is the chart (see pdf_file.dart), and drawn on white
// because this one is for paper.
//
// Only the changes go on the page. There is no melody in this app and
// none is written here.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../theme.dart';
import 'chart_layout.dart';
import 'pdf_file.dart';
import 'tune.dart';

/// A4, in points, which is what a PDF measures in.
const _pageWidth = 595.0;
const _pageHeight = 842.0;
const _margin = 48.0;

/// How many pixels to a point: the page is drawn at twice paper size, so
/// it still looks like lettering when it comes out of a printer.
const _pixelsPerPoint = 2.0;

const _columns = 4;

/// The tallest and shortest a row of bars is drawn. A chart belongs on one
/// page, the way it belongs on one screen, so the rows are given whatever
/// room is left over rather than a fixed height: a short chart is written
/// large, a long one is written smaller, and only something longer than
/// any standard spills onto a second page.
const _tallestRow = 92.0;
const _shortestRow = 34.0;
const _rowGap = 14.0;

const _ink = Color(0xFF1C1B19);
const _graphite = Color(0xFF6B665D);
const _pencil = pencilLight;

/// [tunes] as the pages of a PDF: a tune to a page, and on to another
/// page where a long one does not fit.
///
/// [note] goes under the heading on every page: what the chart is written
/// for, when that is not concert pitch.
Future<Uint8List> chartPdf(
  List<Tune> tunes, {
  String? heading,
  String? note,
}) async {
  final pages = <PdfPage>[];
  for (final tune in tunes) {
    for (final picture in _pagesOf(tune, note)) {
      final image = await picture.toImage(
        (_pageWidth * _pixelsPerPoint).round(),
        (_pageHeight * _pixelsPerPoint).round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) continue;
      pages.add((
        rgb: _withoutAlpha(data.buffer.asUint8List()),
        pixelWidth: (_pageWidth * _pixelsPerPoint).round(),
        pixelHeight: (_pageHeight * _pixelsPerPoint).round(),
        width: _pageWidth,
        height: _pageHeight,
      ));
    }
  }
  return pdfOfPages(pages, title: heading ?? tunes.firstOrNull?.title ?? '');
}

/// Four bytes a pixel on the way in, three on the way out: a page of music
/// has nothing to be see-through over.
Uint8List _withoutAlpha(Uint8List rgba) {
  final out = Uint8List((rgba.length ~/ 4) * 3);
  for (var i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
    out[j] = rgba[i];
    out[j + 1] = rgba[i + 1];
    out[j + 2] = rgba[i + 2];
  }
  return out;
}

/// The pages one tune takes, drawn.
List<ui.Picture> _pagesOf(Tune tune, String? note) {
  final lines = layOutChart(tune, _columns);
  const top = _margin + 76;
  const room = _pageHeight - top - _margin;
  // As tall as the rows can be while the whole chart still fits on the
  // page, between the two limits.
  final rowHeight = (room / math.max(lines.length, 1) - _rowGap).clamp(
    _shortestRow,
    _tallestRow,
  );
  final fit = (room / (rowHeight + _rowGap)).floor().clamp(1, 40);
  // Where it takes more than one page, the rows are shared out evenly
  // rather than packed: a second page with one row on it looks like a
  // mistake, and two half pages read better than a full one and a scrap.
  final sheets = (lines.length / fit).ceil();
  final perPage = (lines.length / math.max(sheets, 1)).ceil().clamp(1, fit);
  final pages = <ui.Picture>[];
  for (var from = 0; from < lines.length || pages.isEmpty; from += perPage) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(_pixelsPerPoint);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _pageWidth, _pageHeight),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    _heading(canvas, tune, page: pages.length + 1, note: note);
    _rows(
      canvas,
      tune,
      lines.skip(from).take(perPage).toList(),
      top: top,
      rowHeight: rowHeight,
    );
    pages.add(recorder.endRecording());
  }
  return pages;
}

void _heading(ui.Canvas canvas, Tune tune, {required int page, String? note}) {
  _write(
    canvas,
    tune.title,
    at: const Offset(_margin, _margin),
    size: 30,
    colour: _ink,
  );
  final under = [
    ?tune.composer,
    if (tune.year != null) '${tune.year}',
  ].join(' · ');
  if (under.isNotEmpty) {
    _write(
      canvas,
      under,
      at: const Offset(_margin, _margin + 36),
      size: 13,
      colour: _graphite,
    );
  }
  final about = [
    'Key of ${tune.key}',
    if (tune.beatsPerBar != 4) '${tune.beatsPerBar}/4',
    '${tune.defaultTempo} bpm',
    ?note,
  ].join(' · ');
  _write(
    canvas,
    about,
    at: const Offset(_margin, _margin + 54),
    size: 13,
    colour: _graphite,
  );
  if (page > 1) {
    _write(
      canvas,
      'page $page',
      at: const Offset(_pageWidth - _margin - 60, _margin + 54),
      size: 12,
      colour: _graphite,
    );
  }
}

void _rows(
  ui.Canvas canvas,
  Tune tune,
  List<ChartLine> lines, {
  required double top,
  required double rowHeight,
}) {
  final width = _pageWidth - _margin * 2;
  final cellWidth = width / _columns;
  final line = Paint()
    ..color = _ink
    ..strokeWidth = 1.2;
  for (final (row, chartLine) in lines.indexed) {
    final y = top + row * (rowHeight + _rowGap);
    if (chartLine.startsSection && chartLine.section != null) {
      _write(
        canvas,
        chartLine.section!,
        at: Offset(_margin - 28, y + rowHeight * 0.25),
        size: 17,
        colour: _pencil,
      );
    }
    final cells = chartLine.cells;
    _endings(canvas, cells, y: y, cellWidth: cellWidth);
    for (var column = 0; column < _columns; column++) {
      final cell = cells[column];
      if (cell == null) continue;
      final x = _margin + column * cellWidth;
      // The barline at the head of every bar, and the one that closes the
      // row off at the end.
      canvas.drawLine(Offset(x, y), Offset(x, y + rowHeight), line);
      final closes = column == _columns - 1 || cells[column + 1] == null;
      if (closes) {
        canvas.drawLine(
          Offset(x + cellWidth, y),
          Offset(x + cellWidth, y + rowHeight),
          line,
        );
      }
      _chords(canvas, tune, cell, x, y, cellWidth, rowHeight);
      // ×2 sits after the last bar of a section written once and played
      // more, where a copyist would pencil it.
      if (closes && chartLine.repeat > 1 && _lastOfSection(lines, row)) {
        _write(
          canvas,
          '×${chartLine.repeat}',
          at: Offset(x + cellWidth + 6, y + rowHeight * 0.3),
          size: 15,
          colour: _pencil,
        );
      }
    }
  }
}

/// Whether [row] is the last row of its section, which is where a ×2 goes.
bool _lastOfSection(List<ChartLine> lines, int row) =>
    row == lines.length - 1 || lines[row + 1].startsSection;

/// The bracket over a 1st or 2nd ending: one over the whole run of bars
/// it covers, numbered once at its left, the way it is written by hand.
void _endings(
  ui.Canvas canvas,
  List<ChartCell?> cells, {
  required double y,
  required double cellWidth,
}) {
  final bracket = Paint()
    ..color = _ink
    ..strokeWidth = 1.0;
  var column = 0;
  while (column < cells.length) {
    final ending = cells[column]?.ending;
    if (ending == null) {
      column++;
      continue;
    }
    var last = column;
    while (last + 1 < cells.length && cells[last + 1]?.ending == ending) {
      last++;
    }
    final left = _margin + column * cellWidth;
    final right = _margin + (last + 1) * cellWidth;
    canvas
      ..drawLine(Offset(left, y - 12), Offset(right, y - 12), bracket)
      ..drawLine(Offset(left, y - 12), Offset(left, y - 2), bracket);
    _write(
      canvas,
      '$ending.',
      at: Offset(left + 4, y - 28),
      size: 12,
      colour: _ink,
    );
    column = last + 1;
  }
}

void _chords(
  ui.Canvas canvas,
  Tune tune,
  ChartCell cell,
  double x,
  double y,
  double cellWidth,
  double rowHeight,
) {
  final bar = cell.bars.first;
  if (bar >= tune.bars.length) return;
  final chords = [
    for (final slot in tune.bars[bar]) handSymbol(slot.chord.display),
  ];
  if (chords.isEmpty) return;
  // One chord sits in the bar; two or more share it along the bar, as
  // they are played.
  final size = (rowHeight * (chords.length > 2 ? 0.22 : 0.3)).clamp(11.0, 26.0);
  final share = cellWidth / chords.length;
  for (final (i, chord) in chords.indexed) {
    _write(
      canvas,
      chord,
      at: Offset(x + 10 + i * share, y + rowHeight * 0.26),
      size: size,
      colour: _ink,
    );
  }
}

void _write(
  ui.Canvas canvas,
  String text, {
  required Offset at,
  required double size,
  required Color colour,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: handLettered(TextStyle(color: colour, fontSize: size)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at);
  painter.dispose();
}
