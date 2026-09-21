// Repeats on the chart: a section played twice is written once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chart_layout.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';

Tune _tune(String title) =>
    [...standards, ...practiceProgressions].firstWhere((t) => t.title == title);

/// Every bar on the chart, in the order it would be read, with what it
/// stands for: "1+9", "7(1.)".
List<String> _read(List<ChartLine> lines) => [
  for (final line in lines)
    for (final cell in line.cells)
      if (cell != null)
        cell.bars.map((b) => b + 1).join('+') +
            (cell.ending == null ? '' : '(${cell.ending}.)'),
];

void main() {
  test('an A played twice the same is written once, ×2', () {
    final lines = layOutChart(_tune('Autumn Leaves'), 4);
    expect(lines, hasLength(6)); // A (2 rows) + B (2) + C (2)
    expect(lines.first.section, 'A');
    expect(lines.first.repeat, 2);
    expect(_read(lines).take(8), [
      '1+9', '2+10', '3+11', '4+12', '5+13', '6+14', '7+15', '8+16', //
    ]);
    expect(_read(lines).skip(8).first, '17'); // then B, as written
  });

  test('an A with a new ending gets 1st and 2nd endings', () {
    // Rhythm changes: the two As differ in their last two bars.
    final lines = layOutChart(_tune('Rhythm changes in B♭'), 4);
    final read = _read(lines);
    expect(read.take(6), ['1+9', '2+10', '3+11', '4+12', '5+13', '6+14']);
    expect(read.skip(6).take(4), ['7(1.)', '8(1.)', '15(2.)', '16(2.)']);
    // The 2nd ending sits under the 1st: two gaps, then its bars.
    final second = lines.firstWhere((l) => l.cells.any((c) => c?.ending == 2));
    expect(second.cells.take(2), [null, null]);
    expect(second.startsSection, isFalse);
  });

  test('sections that only look alike are not folded', () {
    // All the Things You Are: its two As are in different keys.
    final lines = layOutChart(_tune('All the Things You Are'), 4);
    expect(_read(lines), [for (var b = 1; b <= 36; b++) '$b']);
    // A tune with no sections is laid out as it is.
    expect(_read(layOutChart(_tune('Jazz blues in F'), 4)), [
      for (var b = 1; b <= 12; b++) '$b',
    ]);
  });

  test('every bar of every tune is on the chart exactly once', () {
    for (final tune in [...standards, ...practiceProgressions]) {
      for (final columns in [4, 8]) {
        final lines = layOutChart(tune, columns);
        final bars = [
          for (final line in lines)
            for (final cell in line.cells) ...?cell?.bars,
        ]..sort();
        expect(bars, [
          for (var b = 0; b < tune.barCount; b++) b,
        ], reason: '${tune.title}, $columns columns');
        for (final line in lines) {
          expect(line.cells, hasLength(columns));
        }
        // Folded boxes all show the same chords every time through.
        for (final line in lines) {
          for (final cell in line.cells.whereType<ChartCell>()) {
            final chords = {
              for (final bar in cell.bars)
                tune.bars[bar].map((s) => s.chord.display).join(' '),
            };
            expect(chords, hasLength(1), reason: tune.title);
          }
        }
      }
    }
  });

  group('on screen', () {
    /// Pretends to play from a given beat.
    Future<void> open(WidgetTester tester, Tune tune) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: tune,
            player: _FixedPlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1)); // start-up work
    }

    testWidgets('the repeat is marked ×2', (tester) async {
      await open(tester, _tune('Autumn Leaves'));
      expect(find.byKey(const ValueKey('repeat-mark')), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
    });

    testWidgets('a new ending is marked 1. and 2.', (tester) async {
      await open(tester, _tune('Take the "A" Train'));
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('tapping a folded bar loops its first time through', (
      tester,
    ) async {
      await open(tester, _tune('Autumn Leaves'));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Bars 3 and 11: B♭Δ7',
        ),
      );
      await tester.pump();
      expect(find.text('Bar 3'), findsOneWidget);
    });
  });
}

class _FixedPlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}
