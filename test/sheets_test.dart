// Every sheet on the practice screen has to be closable.
//
// The Arrangement sheet grew long enough to fill the screen, which left no
// barrier to tap and nothing to drag — dragging its contents only scrolled
// them — so there was no way out of it. These check each sheet on a small
// phone with large text, where they are at their tallest.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// The ways into each sheet, and what it says at the top.
const _sheets = [
  (opener: 'View', title: 'Chart Written For'),
  (opener: 'Mixer', title: 'Mixer'),
  (opener: 'Arrangement', title: 'Arrangement'),
];

Future<void> _open(
  WidgetTester tester,
  String opener, {
  Size size = const Size(375, 667),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
      // The text size has to go on in builder, not around home. A sheet is
      // pushed onto the Navigator, which sits above home — so a MediaQuery
      // in there never reaches it, and these were all quietly running at
      // the ordinary size however large a scale they asked for.
      //
      // copyWith, not a fresh MediaQueryData: replacing it outright leaves
      // the screen size at zero and nothing lays out as it would.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PracticeScreen(
        // A tune with every option going: the arpeggios add a mixer
        // channel, and it swings, so the two-feel switch is there too.
        tune: standards.firstWhere((t) => t.title == 'All of Me'),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // "View" is a button with a label; the other two are icons with tooltips.
  final button = opener == 'View'
      ? find.widgetWithText(TextButton, 'View')
      : find.byTooltip(opener);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final sheet in _sheets) {
    group('the ${sheet.opener} sheet', () {
      testWidgets('closes with Done', (tester) async {
        await _open(tester, sheet.opener);
        expect(find.text(sheet.title), findsWidgets);
        final done = find.byKey(const ValueKey('sheet-done'));
        expect(done, findsOneWidget, reason: 'a way out that never scrolls');

        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sheet-done')), findsNothing);
      });

      testWidgets('leaves room above it to tap it away', (tester) async {
        // The worst case: a small phone with the text turned right up.
        await _open(tester, sheet.opener, textScale: 2);
        final top = tester.getRect(find.byType(BottomSheet)).top;
        expect(top, greaterThan(40), reason: 'the barrier has to be reachable');

        await tester.tapAt(Offset(187, top / 2));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      });

      testWidgets('you can scroll it to the end', (tester) async {
        // The worst case again: everything is at its tallest, so this is
        // the most scrolling there is to do.
        await _open(tester, sheet.opener, textScale: 2);
        final scroller = find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scroller).position;
        for (var i = 0; i < 60; i++) {
          if (position.pixels >= position.maxScrollExtent - 0.5) break;
          await tester.drag(scroller, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expect(
          position.pixels,
          closeTo(position.maxScrollExtent, 0.5),
          reason: 'the bottom of the sheet has to be reachable',
        );
      });

      testWidgets('the Done button is still reachable at large text', (
        tester,
      ) async {
        await _open(tester, sheet.opener, textScale: 2);
        final done = find.byKey(const ValueKey('sheet-done'));
        expect(done, findsOneWidget);
        // Not pushed off the bottom of the sheet by the content above it.
        final button = tester.getRect(done);
        final sheetBox = tester.getRect(find.byType(BottomSheet));
        expect(button.bottom, lessThanOrEqualTo(sheetBox.bottom + 0.5));
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      });
    });
  }

  testWidgets('the last control in Arrangement clears the Done button', (
    tester,
  ) async {
    await _open(tester, 'Arrangement', textScale: 2);
    final scroller = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scroller).position;
    for (var i = 0; i < 60; i++) {
      if (position.pixels >= position.maxScrollExtent - 0.5) break;
      await tester.drag(scroller, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    // Scrolled as far as it goes, Export is whole and inside the window
    // rather than half under the button that closes the sheet.
    final export = tester.getRect(find.byKey(const ValueKey('export')));
    final window = tester.getRect(scroller);
    expect(export.bottom, lessThanOrEqualTo(window.bottom + 0.5));
    expect(export.top, greaterThanOrEqualTo(window.top - 0.5));
  });
}
