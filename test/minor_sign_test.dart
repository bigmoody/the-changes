// How a minor chord is written: Dm7 or D-7.
//
// A fake book letters an "m"; iReal Pro draws a minus sign, and so do a
// lot of copyists. The one a player reads without thinking is theirs, so
// it is a setting, and like the font it has to reach the chart on the
// stand and the page that leaves the app: a chart that changes when you
// send it is not the chart you were reading.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chart_pdf.dart';
import 'package:play_along/music/chart_text.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/chord_chart.dart';
import 'package:play_along/screens/practice_sheets.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Tune _tune(String title) => standards.firstWhere((t) => t.title == title);

void main() {
  setUp(() => writeMinorAs(MinorSign.m));
  tearDown(() => writeMinorAs(MinorSign.m));

  test('a chart is written with an m until it is asked for a minus', () {
    final chord = Chord.parse('Dm7');
    expect(minorSign, MinorSign.m, reason: 'the m is what ships');
    expect(chord.display, 'Dm7');

    writeMinorAs(MinorSign.minus);
    expect(chord.display, 'D-7');
  });

  test('however the tune was typed, the chart reads one way', () {
    // The same chord is written three ways in print, and a tune brought
    // in from somewhere else may carry any of them.
    for (final typed in ['Cm7', 'C-7', 'Cmin7']) {
      expect(Chord.parse(typed).display, 'Cm7');
    }
    writeMinorAs(MinorSign.minus);
    for (final typed in ['Cm7', 'C-7', 'Cmin7']) {
      expect(Chord.parse(typed).display, 'C-7');
    }
  });

  test('every chord with a minor third in it, and nothing else', () {
    writeMinorAs(MinorSign.minus);
    expect(Chord.parse('Cm').display, 'C-');
    expect(Chord.parse('Cm6').display, 'C-6');
    expect(Chord.parse('Cm9').display, 'C-9');
    expect(Chord.parse('Cm^7').display, 'C-Δ7');
    expect(Chord.parse('Cm7b5').display, 'C-7♭5');
    expect(Chord.parse('Cm7/G').display, 'C-7/G');

    // A major 7th starts with an m and is the opposite chord; the rest
    // carry no minor mark to rewrite.
    expect(Chord.parse('Cmaj7').display, 'Cmaj7');
    expect(Chord.parse('C^7').display, 'CΔ7');
    expect(Chord.parse('C7').display, 'C7');
    expect(Chord.parse('Co7').display, 'C°7');
    expect(Chord.parse('Csus4').display, 'Csus4');
  });

  test('the chord reference still lists every way of writing one', () {
    writeMinorAs(MinorSign.minus);
    final chord = Chord.parse('C');
    final minor = chordQualities.firstWhere((q) => q.name == 'Minor 7th');
    expect(
      [for (final symbol in minor.symbols) chord.displayWith(symbol)],
      ['Cm7', 'C-7', 'Cmin7'],
      reason: 'the alternatives are the point of that screen',
    );
  });

  test('the text a player sends is the chart they were reading', () {
    final tune = _tune('Autumn Leaves');
    expect(chartText(tune), contains('Cm7'));
    writeMinorAs(MinorSign.minus);
    final text = chartText(tune);
    expect(text, contains('C-7'));
    expect(text, isNot(contains('Cm7')));
  });

  testWidgets('and so is the page', (tester) async {
    late String text;
    await tester.runAsync(() async {
      writeMinorAs(MinorSign.minus);
      text = latin1.decode(await chartPdf([_tune('Autumn Leaves')]));
    });
    // The page draws `Chord.display`, the same string the chart and the
    // text export are written from, and draws it into a picture: the
    // letters cannot be read back out of the file, and under the test
    // font every glyph is the same box anyway. So what is checked here
    // is that a page still comes out with the minus sign chosen; the
    // sign itself is checked on `display` above and on the chart below.
    expect(text, contains('/Type /Pages /Count 1'));
  });

  testWidgets('the View sheet writes the chart the other way', (tester) async {
    tester.view
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    final controller = PracticeController(
      tune: _tune('Autumn Leaves'),
      player: PracticePlayer(),
      settings: settings,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                Expanded(child: ChordChart(controller: controller)),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showViewOptions(context, controller),
                    child: const Text('View'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cm7'), findsWidgets);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('minor-minus')));
    await tester.pumpAndSettle();
    expect(settings.minorSign, MinorSign.minus);

    await tester.tap(find.byKey(const ValueKey('sheet-done')));
    await tester.pumpAndSettle();
    expect(find.text('C-7'), findsWidgets);
    expect(find.text('Cm7'), findsNothing);
  });
}
