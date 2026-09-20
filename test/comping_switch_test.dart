// Piano or guitar on the chords: switched in the mixer, remembered for every
// tune, and named on the practice screen's instrument buttons.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  testWidgets('switch the chords from piano to guitar in the mixer', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title == 'Blue Bossa'),
          player: PracticePlayer(),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Piano'), findsOneWidget);

    await tester.tap(find.byTooltip('Mixer'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('comping')),
        matching: find.text('Guitar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.comping, Comping.guitar);

    await tester.tapAt(const Offset(200, 100)); // close the mixer
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Guitar'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Piano'), findsNothing);
  });
}
