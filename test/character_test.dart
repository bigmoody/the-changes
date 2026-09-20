// The small touches that give the app its character: pencil repeat signs
// on a loop, a word from the bandstand at a streak, the hand-lettered chart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/chord_tones_screen.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  testWidgets('a loop is pencilled in with repeat signs', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title == 'Autumn Leaves'),
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The whole tune: nothing marked.
    expect(find.byKey(const ValueKey('loop-mark')), findsNothing);

    // One bar: opened and closed in the same box.
    await tester.tap(find.text('F7').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loop-mark')), findsOneWidget);

    // Back to the whole tune: the marks are rubbed out.
    await tester.tap(find.text('Whole tune'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loop-mark')), findsNothing);
  });

  testWidgets('the chart and its title are hand-lettered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title == 'Autumn Leaves'),
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chord = tester.widget<Text>(find.text('Cm7').first);
    expect(chord.style?.fontFamily, handFont);
    // The view options are a word, not a stock eye icon.
    expect(find.widgetWithText(TextButton, 'View'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  test('the band speaks up only at milestones', () {
    final remarks = [for (var n = 0; n <= 100; n++) ?streakRemark(n)];
    expect(streakRemark(1), isNull);
    expect(streakRemark(4), isNull);
    expect(streakRemark(5), isNotNull);
    expect(streakRemark(10), isNotNull);
    // Rare enough to mean something.
    expect(remarks.length, lessThanOrEqualTo(8));
  });

  test('the diminished sign is written the way a copyist writes it', () {
    expect(handSymbol('B°7'), 'B˚7');
    expect(handSymbol('CΔ7'), 'CΔ7');
  });
}
