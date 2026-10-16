// The tempo dialog owns a text field, and the dialog keeps building while it
// animates away. Disposing that field too early took the whole screen down
// with it, so these tests close the dialog every way there is and let the
// animation finish.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';

void main() {
  Future<void> openTheTune(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.first,
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.tap(find.textContaining('BPM').first);
    await tester.pumpAndSettle();
    expect(find.text('Tempo'), findsOneWidget);
  }

  testWidgets('closes on Done without taking the screen with it', (
    tester,
  ) async {
    await openTheTune(tester);
    await tester.enterText(find.byType(TextField), '176');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Tempo'), findsNothing);
    expect(find.text('176 BPM'), findsOneWidget);
  });

  testWidgets('there is a way back to the tempo the tune is written at', (
    tester,
  ) async {
    // Everything else a player can move says what the tune says and
    // offers a way back to it. The tempo did not, which is how this was
    // asked for: you nudge it ten at a time to try something and then
    // have to remember where it started.
    final written = standards.first.defaultTempo;
    await openTheTune(tester);
    expect(
      find.byKey(const ValueKey('tempo-as-written')),
      findsNothing,
      reason: 'nothing to go back to yet',
    );

    await tester.enterText(find.byType(TextField), '176');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('BPM').first);
    await tester.pumpAndSettle();

    expect(find.text('As Written ($written)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tempo-as-written')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tempo-as-written')),
      findsNothing,
      reason: 'and it is gone once you are back',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('$written BPM'), findsOneWidget);
  });

  testWidgets('closes when tapped outside', (tester) async {
    await openTheTune(tester);
    // The barrier is the area outside the dialog.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Tempo'), findsNothing);
  });

  testWidgets('the slider sets the tempo as it moves', (tester) async {
    await openTheTune(tester);
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Tempo'), findsNothing);
    expect(find.textContaining('BPM'), findsOneWidget);
  });
}
