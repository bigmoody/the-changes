// The arpeggio button's menu.
//
// How fast and how far belong under the button that turns arpeggios on,
// not only in the mixer. The mixer is where you set the band up; the chip
// is where your thumb is while you are playing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<AppSettings> openMenu(WidgetTester tester) async {
  final settings = AppSettings.inMemory();
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: standards.firstWhere((tune) => tune.title == 'A Foggy Day'),
        player: PracticePlayer(),
        settings: settings,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('arpeggio-chip')));
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  testWidgets('the rate is in there, and says where it is set', (tester) async {
    await openMenu(tester);
    expect(find.byKey(const ValueKey('arpeggio-rate-menu')), findsOneWidget);
    expect(find.text('Rate: eighths'), findsOneWidget);
  });

  testWidgets('and how far up it goes', (tester) async {
    await openMenu(tester);
    expect(find.byKey(const ValueKey('arpeggio-reach-menu')), findsOneWidget);
    expect(find.text('Up to: plain'), findsOneWidget);
  });

  testWidgets('choosing a rate sets it', (tester) async {
    final settings = await openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('arpeggio-rate-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arpeggio-rate-triplets')));
    await tester.pumpAndSettle();
    expect(settings.arpeggioRate, ArpeggioRate.triplets);
  });

  testWidgets('and choosing how far up sets that', (tester) async {
    final settings = await openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('arpeggio-reach-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arpeggio-reach-thirteenth')));
    await tester.pumpAndSettle();
    expect(settings.arpeggioReach, ArpeggioReach.thirteenth);
  });

  testWidgets('the starts and the sounds are still there', (tester) async {
    // Added to a menu rather than replacing it.
    await openMenu(tester);
    expect(find.byKey(const ValueKey('arpeggio-off')), findsOneWidget);
    expect(find.byKey(const ValueKey('arpeggio-root')), findsOneWidget);
    expect(find.text('On piano'), findsOneWidget);
  });
}
