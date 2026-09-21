// A bar that plays the same as the one before it is written as a repeat
// mark, the way a chart is written by hand.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chart_layout.dart';
import 'package:play_along/music/chart_text.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// The marks down one row of a chart, as the rule reads them.
List<bool> _marks(Tune tune, int row) =>
    similesFor(tune, layOutChart(tune, 4))[row];

/// The marks on the first row of a chart written out here.
List<bool> _firstRow(String chart, {int beats = 4}) {
  final tune = Tune.fromChart(
    title: 'Made Up',
    key: 'C',
    defaultTempo: 120,
    beatsPerBar: beats,
    chart: chart,
  );
  return similesFor(tune, layOutChart(tune, 4)).first;
}

/// How many boxes on the whole chart are marked as a repeat.
int _markedIn(Tune tune) =>
    [for (final row in similesFor(tune, layOutChart(tune, 4))) ...row]
        .where((marked) => marked)
        .length;

/// The chart rows of [tune] written out, without the heading.
List<String> _rows(Tune tune) =>
    chartText(tune)
        .split('\n')
        .skip(2)
        .where((line) => line.trim().isNotEmpty)
        .toList();

void main() {
  group('which bars are marked', () {
    test('a bar the same as the one before it', () {
      // So What is four bars of Dm7 at a time.
      expect(_marks(_standard('So What'), 0), [false, true, true, true]);
    });

    test('a bar that changes is written out', () {
      // Autumn Leaves moves every bar: Cm7, F7, B♭Δ7, E♭Δ7.
      expect(_marks(_standard('Autumn Leaves'), 0), [
        false,
        false,
        false,
        false,
      ]);
    });

    test('two chords in a bar only repeat as the pair they are', () {
      expect(_firstRow('| Dm7 G7 | Dm7 G7 | Dm7 | G7 |'), [
        false,
        true,
        false,
        false,
      ]);
    });

    test('the same chord split differently is not the same bar', () {
      // One bar of C, then a bar of C twice over: they sound different, so
      // the second is written out.
      expect(_firstRow('| C | C C | C | C |'), [false, false, false, true]);
    });

    test('every row opens with the chord written out', () {
      final tune = _standard('So What');
      // Eight bars of Dm7 laid out four to a row. A mark says "the same as
      // the box to my left", and the first box of a row hasn't got one;
      // you would have to look back to the end of the row above, which is
      // slower than reading the chord.
      expect(_marks(tune, 0), [false, true, true, true]);
      expect(_marks(tune, 1), [false, true, true, true]);
      expect(_rows(tune)[1], contains('Dm7'));
    });

    test('a new phrase says what it is, even after the same chord', () {
      // The complaint: bar 5 came up as a repeat because bar 4 happened to
      // be the same chord, which hid where the second four bars began.
      final tune = Tune.fromChart(
        title: 'Turnaround',
        key: 'C',
        defaultTempo: 120,
        chart:
            '| C6 | Em7b5 A7 | Dm7 G7 | C6 |'
            '| C6 | Em7b5 A7 | Dm7 G7 | C6 |',
      );
      final marks = similesFor(tune, layOutChart(tune, 4));
      expect(marks[0], [false, false, false, false]);
      expect(marks[1].first, isFalse, reason: 'bar 5 is written out');
    });

    test('a section still says what it is, however long the run', () {
      // You can arrive at a rehearsal letter from somewhere else, so a
      // mark there would point at a bar you never played.
      final tune = Tune.fromChart(
        title: 'Letters',
        key: 'C',
        defaultTempo: 120,
        chart: '| [A] C | C | C | C | [B] C | F | G | C |',
      );
      final marks = similesFor(tune, layOutChart(tune, 4));
      expect(marks[0], [false, true, true, true]);
      expect(marks[1].first, isFalse, reason: 'B says C');
    });

    test('a 2nd ending under a 1st has nothing to its left to repeat', () {
      final tune = _standard('Cherokee');
      final lines = layOutChart(tune, 4);
      final ending = lines.indexWhere(
        (line) => line.cells.any((cell) => cell?.ending == 2),
      );
      expect(ending, greaterThan(0), reason: 'Cherokee has two endings');
      final marks = similesFor(tune, lines)[ending];
      final cells = lines[ending].cells;
      for (var i = 0; i < cells.length; i++) {
        if (cells[i] == null) continue;
        expect(marks[i], isFalse, reason: 'the box after a gap');
      }
    });
  });

  group('written out', () {
    test('four bars of one chord are the chord and three marks', () {
      expect(
        _rows(_standard('So What')).first,
        matches(RegExp(r'A\s+\| Dm7\s+\| %\s+\| %\s+\| %\s+\|')),
      );
    });

    test('a row that moves every bar has no marks at all', () {
      // Autumn Leaves' first four bars: Cm7, F7, B♭Δ7, E♭Δ7.
      expect(
        _rows(_standard('Autumn Leaves')).first,
        isNot(contains(simileMark)),
      );
    });

    test('a 1st and 2nd ending each say what they are', () {
      // Cherokee's endings both land on B♭6, but an ending is where the
      // chart stops running straight on, so each is written out.
      final rows = _rows(_standard('Cherokee'));
      final first = rows.firstWhere((row) => row.trimRight().endsWith('1.'));
      final second = rows.firstWhere((row) => row.trimRight().endsWith('2.'));
      expect(second, contains('B♭6'));
      expect(second, isNot(contains(simileMark)));
      expect(first, isNot(endsWith('$simileMark  1.')));
    });
  });

  group('on the chart', () {
    testWidgets('a repeated bar shows the mark instead of the chord', (
      tester,
    ) async {
      final tune = _standard('So What');
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: tune,
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Every bar the rule marks is drawn as a mark, and there are plenty
      // of them: So What is four bars of a chord at a time.
      expect(find.text(simileMark), findsNWidgets(_markedIn(tune)));
      expect(_markedIn(tune), greaterThan(8), reason: 'most of the chart');
      expect(find.text('Dm7'), findsWidgets, reason: 'said at least once');
    });

    testWidgets('a chart where every bar changes shows no marks', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: Tune.fromChart(
              title: 'Never The Same Twice',
              key: 'C',
              defaultTempo: 120,
              chart: '| CΔ7 | Dm7 | Em7 | FΔ7 | G7 | Am7 | Bø7 | CΔ7 |',
            ),
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(simileMark), findsNothing);
    });
  });
}
