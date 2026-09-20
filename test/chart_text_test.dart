// A chart written out as plain text, to send to someone or print.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chart_layout.dart';
import 'package:play_along/music/chart_text.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// The chart itself: everything under the title and the details.
List<String> _rows(String text) =>
    text.split('\n').skip(2).where((line) => line.trim().isNotEmpty).toList();

/// Where the barlines fall on a row.
List<int> _barlines(String row) => [
  for (var i = 0; i < row.length; i++)
    if (row[i] == '|') i,
];

/// The section letter shown at the left of a row, if any.
String _letter(String row) => row.substring(0, 3).trim();

void main() {
  group('the heading', () {
    test('says what the tune is, who wrote it and what to count', () {
      final lines = chartText(_standard('Autumn Leaves')).split('\n');
      expect(lines[0], 'Autumn Leaves');
      expect(lines[1], 'Joseph Kosma · 1945 · Key of G minor · 130 bpm');
      // Then a blank line before the chart starts.
      expect(lines[2], isEmpty);
    });

    test('a tune with a groove of its own says so', () {
      final lines = chartText(_standard('Blue Bossa')).split('\n');
      expect(lines[1], contains('Key of C minor'));
      expect(lines[1], contains('140 bpm'));
      expect(lines[1], contains('Bossa nova'));
    });

    test('a waltz says three to the bar; a tune in four says nothing', () {
      expect(chartText(_standard('Afro Blue')).split('\n')[1], contains('3/4'));
      expect(
        chartText(_standard('Autumn Leaves')).split('\n')[1],
        isNot(contains('/4')),
      );
    });

    test('a note at the bottom, when one is asked for', () {
      final text = chartText(_standard('Solar'), note: 'Take it at 180.');
      expect(text.trimRight(), endsWith('Take it at 180.'));
      expect(chartText(_standard('Solar')), isNot(contains('Take it')));
    });
  });

  group('the chart', () {
    test('four bars to a line, with the barlines under each other', () {
      final rows = _rows(chartText(_standard('Autumn Leaves')));
      expect(rows, hasLength(6)); // 24 bars written out, four to a row
      for (final row in rows) {
        expect(_barlines(row), [3, 19, 35, 51, 67], reason: row);
      }
    });

    test('a row never holds more than four bars, whatever the tune', () {
      for (final tune in standards.take(40)) {
        for (final row in _rows(chartText(tune))) {
          expect(_barlines(row).length, lessThanOrEqualTo(5), reason: row);
          for (final at in _barlines(row)) {
            expect([3, 19, 35, 51, 67], contains(at), reason: row);
          }
        }
      }
    });

    test('the section letters run down the left-hand side', () {
      final rows = _rows(chartText(_standard('Autumn Leaves')));
      expect(
        [
          for (final row in rows)
            if (_letter(row).isNotEmpty) _letter(row),
        ],
        ['A', 'B', 'C'],
      );
      // Only the row a section starts on carries its letter.
      expect(_letter(rows[0]), 'A');
      expect(_letter(rows[1]), isEmpty);
    });
  });

  group('a section played twice', () {
    test('Autumn Leaves\' A is written once and marked ×2 at the end of it, '
        'not on every row', () {
      final rows = _rows(chartText(_standard('Autumn Leaves')));
      // The A's eight bars are written once, over two rows.
      expect(rows[0], contains('Cm7'));
      expect(rows[0], isNot(contains('×')));
      expect(rows[1], endsWith('×2'));
      // And nowhere else on the chart.
      expect(rows.where((row) => row.contains('×2')), hasLength(1));
    });

    test('and the A is written out once though the band plays it twice', () {
      final tune = _standard('Autumn Leaves');
      final rows = _rows(chartText(tune));
      // The band plays 32 bars; the page holds 24, six rows of four.
      expect(tune.barCount, 32);
      expect(rows, hasLength(6));
      // One A on the page, marked ×2, rather than two As.
      expect(rows.where((row) => _letter(row) == 'A'), hasLength(1));
    });
  });

  group('first and second endings', () {
    test('Cherokee\'s A marks them 1. and 2.', () {
      final rows = _rows(chartText(_standard('Cherokee')));
      final first = rows.indexWhere((row) => row.endsWith('1.'));
      expect(first, isNonNegative);
      expect(rows[first], contains('Cm7 F7'));
      expect(rows[first + 1], endsWith('2.'));
      expect(rows[first + 1], contains('B♭6'));
      // One of each, on the A that repeats.
      expect(rows.where((row) => row.endsWith('1.')), hasLength(1));
      expect(rows.where((row) => row.endsWith('2.')), hasLength(1));
    });

    test('the 2nd ending sits under the 1st', () {
      final rows = _rows(chartText(_standard('Cherokee')));
      final first = rows.indexWhere((row) => row.endsWith('1.'));
      final second = rows[first + 1];
      // Its one bar is indented to the column the 1st ending's bar is in.
      expect(_barlines(second), [51, 67]);
      expect(second.trimLeft(), startsWith('|'));
      expect(_letter(second), isEmpty);
    });
  });

  group('written in another key', () {
    test('the heading and the chords both move', () {
      final up = chartText(_standard('Autumn Leaves'), semitones: 2);
      expect(up.split('\n')[1], contains('Key of A minor'));
      // The A section's ii–V is Cm7 F7 in G minor, Dm7 G7 in A minor.
      expect(_rows(up).first, contains('Dm7'));
      expect(_rows(up).first, contains('G7'));
      expect(up, isNot(contains('Cm7')));
      // The title and who wrote it don't move.
      expect(up.split('\n')[0], 'Autumn Leaves');
      expect(up.split('\n')[1], contains('Joseph Kosma'));
    });

    test('staying put changes nothing', () {
      expect(
        chartText(_standard('Cherokee'), semitones: 0),
        chartText(_standard('Cherokee')),
      );
    });
  });

  test('nothing but the changes is ever written: no melody, no lyric', () {
    for (final title in ['Autumn Leaves', 'Cherokee', 'Blue Bossa', 'Solar']) {
      final tune = _standard(title);
      final text = chartText(tune);
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty);

      // The title, the details, and one row per row of the chart. Nothing
      // else is written at all.
      expect(lines, hasLength(2 + layOutChart(tune, 4).length), reason: title);

      for (final row in _rows(text)) {
        // Strip the ×2 and the ending numbers; a chart row is then nothing
        // but a section letter and boxes of chords.
        final bars = row.replaceFirst(
          RegExp(r'\|\s+(?:×\d ?)?(?:\d\.)?$'),
          '|',
        );
        expect(bars, endsWith('|'), reason: row);
        expect(_letter(row), matches(RegExp(r'^[A-E]?$')), reason: row);
        for (final box in bars.substring(3).split('|')) {
          if (box.trim().isEmpty) continue;
          for (final symbol in box.trim().split(' ')) {
            // A repeated bar is the one mark that isn't a chord symbol.
            if (symbol == simileMark) continue;
            expect(
              () => Chord.parse(symbol),
              returnsNormally,
              reason: '"$symbol" in $row',
            );
          }
        }
      }
    }
  });

  group('a whole setlist at once', () {
    test('the heading, then a chart each, in the order they are played', () {
      final text = chartsText([
        _standard('Autumn Leaves'),
        _standard('Cherokee'),
        _standard('Solar'),
      ], heading: 'Friday at the Vortex');

      expect(text.split('\n').first, 'Friday at the Vortex');
      expect(text.indexOf('Autumn Leaves'), lessThan(text.indexOf('Cherokee')));
      expect(text.indexOf('Cherokee'), lessThan(text.indexOf('Solar')));
      // Each tune's own chart, whole, is in there.
      for (final title in ['Autumn Leaves', 'Cherokee', 'Solar']) {
        expect(text, contains(chartText(_standard(title))));
      }
      // A blank line or two between one tune and the next.
      expect(text, contains('\n\n\nCherokee\n'));
    });

    test('with no heading it starts straight in on the first tune', () {
      final text = chartsText([_standard('Solar')]);
      expect(text, chartText(_standard('Solar')));
    });

    test('an empty setlist writes nothing but its heading', () {
      expect(chartsText(const [], heading: 'Nothing on'), 'Nothing on\n\n');
      expect(chartsText(const []), isEmpty);
    });
  });
}
