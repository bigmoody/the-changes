// Playing Fast: the page, the claim it makes about swing, and the ladder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/screens/playing_fast_screen.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 6000) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PlayingFastScreen(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('what the page says about swing is what the band does', () {
    // "The eighths get straighter": at 260 the "and" is much nearer the
    // middle of the beat than at 120.
    expect(swingAt(260), lessThan(swingAt(120) - 0.05));
  });

  testWidgets('both halves are there, written plainly', (tester) async {
    await _open(tester);
    expect(find.text('What Fast Players Are Doing'), findsOneWidget);
    expect(find.text('How to Get From Slow to Fast'), findsOneWidget);
    expect(find.text('They Feel It in Two'), findsOneWidget);
    expect(find.text('9. Stop at Tension'), findsOneWidget);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.data ?? '', isNot(contains('—')));
    }
  });

  testWidgets('the ladder: Cherokee from 140, faster every chorus', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('fast-ladder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(screen.tune.title, 'Cherokee');
    expect(screen.startAt, 140);
    expect(screen.arrangement!.ramp.step, 4);
  });
}
