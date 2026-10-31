// How It Works: the first thing in Settings, every section opens, and it
// is written plainly.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/screens/how_it_works_screen.dart';
import 'package:play_along/screens/settings_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';

void main() {
  testWidgets('it is the first row in Settings and opens the page', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
          progressions: ProgressionStore.inMemory(),
          library: LibraryStore.inMemory(),
        ),
      ),
    );
    final row = tester.getTopLeft(find.byKey(const ValueKey('how-it-works')));
    final instrument = tester.getTopLeft(find.text('Your Instrument'));
    expect(row.dy, lessThan(instrument.dy));

    await tester.tap(find.byKey(const ValueKey('how-it-works')));
    await tester.pumpAndSettle();
    expect(find.byType(HowItWorksScreen), findsOneWidget);

    // Every section opens onto its steps.
    for (var i = 0; i < 19; i++) {
      final section = find.byKey(ValueKey('how-$i'));
      await tester.scrollUntilVisible(section, 200);
      final header = find.descendant(
        of: section,
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();
      // Recording Yourself, opened onto its first step.
      if (i == 9) expect(find.text('Record a Take'), findsOneWidget);
    }
    // And that was all of them.
    expect(find.byKey(const ValueKey('how-19')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('no em dashes', () {
    final text = File('lib/screens/how_it_works_screen.dart')
        .readAsStringSync();
    expect(text.contains('—'), isFalse);
  });
}
