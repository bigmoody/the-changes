// The chip on the loop bar that says which instrument the chart is written
// for.
//
// It used to be a plain label that looked exactly like the tappable chips
// beside it and did nothing when you tapped it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<AppSettings> _open(
  WidgetTester tester, {
  required ChartInstrument instrument,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final settings = AppSettings.inMemory(instrument);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PracticeScreen(
        tune: standards.firstWhere((tune) => tune.title == '52nd Street Theme'),
        player: PracticePlayer(),
        settings: settings,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  group('the loop bar has room for everything in it', () {
    for (final size in const [Size(320, 568), Size(393, 852), Size(852, 393)]) {
      for (final textScale in const [1.0, 2.0, 3.0]) {
        testWidgets(
          'on ${size.width.toInt()}×${size.height.toInt()} at ×$textScale',
          (tester) async {
            await _open(
              tester,
              instrument: ChartInstrument.eFlat,
              size: size,
              textScale: textScale,
            );
            // Looping one bar of two chords is the fullest that row ever
            // gets: the bar's name, a chip for each chord, the chart's
            // instrument and the way back to the whole tune. Turn the text
            // size up and any one of them is wider than the phone.
            await tester.tap(find.text('A6').first, warnIfMissed: false);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'nothing overflows');
          },
        );
      }
    }
  });

  testWidgets('it says which instrument the chart is written for', (
    tester,
  ) async {
    await _open(tester, instrument: ChartInstrument.eFlat);
    // Just the letter on screen, in a row that hasn't the width to spell
    // it out, but a screen reader is told the whole thing.
    final chip = find.byKey(const ValueKey('chart-instrument'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.text('E♭')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)))
          .semanticsLabel,
      'Chart for E♭ instruments',
    );
  });

  testWidgets('at concert pitch there is nothing to say', (tester) async {
    await _open(tester, instrument: ChartInstrument.concert);
    expect(find.textContaining('chart'), findsNothing);
  });

  testWidgets('tapping it opens where the instrument is chosen', (
    tester,
  ) async {
    await _open(tester, instrument: ChartInstrument.eFlat);
    await tester.tap(find.byKey(const ValueKey('chart-instrument')));
    await tester.pumpAndSettle();
    expect(find.text('Chart Written For'), findsOneWidget);
  });

  testWidgets('and the chart can be changed from there', (tester) async {
    final settings = await _open(tester, instrument: ChartInstrument.eFlat);
    await tester.tap(find.byKey(const ValueKey('chart-instrument')));
    await tester.pumpAndSettle();

    // The picker in the sheet, set back to concert pitch.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('instrument-key')),
        matching: find.text('C'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.instrument, ChartInstrument.concert);
  });
}
