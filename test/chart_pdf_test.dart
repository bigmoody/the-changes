// The chart as a page of music: a file a printer will take, with the
// pages the tune actually needs.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chart_pdf.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

Tune _tune(String title) => standards.firstWhere((t) => t.title == title);

/// Every offset in the table points at the object that claims that
/// number, which is the whole of what a reader needs to open the file.
void expectTableIsRight(String text) {
  // "startxref" ends in "xref" too, so the table is found by the newline
  // in front of it.
  final xref = text.lastIndexOf('\nxref\n') + 1;
  expect(xref, greaterThan(0), reason: 'no table of objects');
  final header = RegExp(r'xref\n0 (\d+)\n').firstMatch(text.substring(xref))!;
  final count = int.parse(header[1]!);
  final rows = text
      .substring(xref + header.end)
      .split('\n')
      .take(count)
      .toList();
  expect(rows.first, startsWith('0000000000 65535 f'), reason: 'object zero');
  for (var number = 1; number < count; number++) {
    final offset = int.parse(rows[number].split(' ').first);
    expect(
      text.substring(offset, offset + '$number 0 obj'.length),
      '$number 0 obj',
      reason: 'object $number is not where the table says',
    );
  }
}

void main() {
  testWidgets('a standard comes out as a page of music', (tester) async {
    late String text;
    await tester.runAsync(() async {
      final bytes = await chartPdf([_tune('Autumn Leaves')]);
      text = latin1.decode(bytes);
    });
    expect(text, startsWith('%PDF-1.4'));
    expect(text, endsWith('%%EOF\n'));
    expect(text, contains('/Type /Catalog'));
    expect(text, contains('/Producer (The Changes)'));
    expect(text, contains('/Title (Autumn Leaves)'));
    // One tune, one page, and a picture of the music on it.
    expect(text, contains('/Type /Pages /Count 1'));
    expect(text, contains('/Subtype /Image'));
    expect(text, contains('/ColorSpace /DeviceRGB'));
    expectTableIsRight(text);
  });

  testWidgets('a setlist is a page each, in order', (tester) async {
    late String text;
    await tester.runAsync(() async {
      final bytes = await chartPdf([
        _tune('Blue Bossa'),
        _tune('All of Me'),
      ], heading: 'Second Set');
      text = latin1.decode(bytes);
    });
    expect(text, contains('/Type /Pages /Count 2'));
    expect(text, contains('/Title (Second Set)'));
    expectTableIsRight(text);
  });
}
