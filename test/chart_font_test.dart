// The font system: which hand a chart is written in.
//
// iReal Pro lets you pick the face your charts are set in, and so does
// this: the copyist's hand it ships with, or print, for anyone who reads
// that faster. The choice has to reach every chord on the screen and the
// PDF that leaves the app, because a chart that changes when you send it
// is not the chart you were reading.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/chord_chart.dart';
import 'package:play_along/screens/practice_sheets.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  setUp(() => letterChartsIn(ChartFont.hand));
  tearDown(() => letterChartsIn(ChartFont.hand));

  test(
    'each face letters in its own hand, and keeps the signs a chart needs',
    () {
      letterChartsIn(ChartFont.hand);
      expect(handLettered().fontFamily, 'PetalumaScript');
      expect(handLettered().fontWeight, FontWeight.w400);

      letterChartsIn(ChartFont.serif);
      expect(handLettered().fontFamily, 'Georgia');

      // Print has no family of its own: it keeps the one it is given, which
      // is the app's, which is the system face on a phone.
      letterChartsIn(ChartFont.printed);
      expect(handLettered().fontFamily, isNull);
      expect(
        handLettered(const TextStyle(fontFamily: 'Roboto')).fontFamily,
        'Roboto',
      );

      // A serif has to name one the phone in hand actually has.
      expect(ChartFont.serif.fallback, contains('serif'));
    },
  );

  test('the chooser can show each face without changing the chart', () {
    expect(letteredIn(ChartFont.serif).fontFamily, 'Georgia');
    expect(chartFont, ChartFont.hand, reason: 'the chart is still in hand');
  });

  testWidgets('picking a face writes the chart in it', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    final controller = PracticeController(
      tune: standards.firstWhere((t) => t.title == 'Autumn Leaves'),
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

    String? chordFace() => tester
        .widgetList<Text>(find.text('Cm7'))
        .firstOrNull
        ?.style
        ?.fontFamily;
    expect(chordFace(), 'PetalumaScript');

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('font-printed')));
    await tester.pumpAndSettle();
    expect(settings.chartFont, ChartFont.printed);

    await tester.tap(find.byKey(const ValueKey('sheet-done')));
    await tester.pumpAndSettle();
    expect(chordFace(), isNull, reason: 'the chart is in print now');

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('font-serif')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sheet-done')));
    await tester.pumpAndSettle();
    expect(chordFace(), 'Georgia');
  });
}
