// Finding one of your own: an imported playlist can run to hundreds, and
// scrolling is not finding.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/my_progressions_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

ProgressionStore _shelf() => ProgressionStore.inMemory([
  UserProgression(
    id: 'a',
    title: 'Blue Monday',
    key: 'F',
    tempo: 120,
    bars: const ['F7', 'Bb7'],
    style: BandStyle.of(Feel.swing),
    composer: 'Ada Lovelace',
  ),
  UserProgression(
    id: 'b',
    title: 'Praia Grande',
    key: 'A',
    tempo: 140,
    bars: const ['Am7', 'D7'],
    style: BandStyle.of(Feel.bossa),
    composer: 'Grace Hopper',
  ),
  UserProgression(
    id: 'c',
    title: 'Night Shift',
    key: 'Eb',
    tempo: 100,
    bars: const ['Ebm7', 'Ab7'],
    style: BandStyle.of(Feel.funk),
    composer: 'Ada Lovelace',
  ),
]);

Future<void> _open(WidgetTester tester, ProgressionStore store) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: MyProgressionsPage(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        progressions: store,
        library: LibraryStore.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey('progression-search')),
    text,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('by title', (tester) async {
    await _open(tester, _shelf());
    expect(find.text('Praia Grande'), findsOneWidget);
    await _search(tester, 'night');
    expect(find.text('Night Shift'), findsOneWidget);
    expect(find.text('Praia Grande'), findsNothing);
    expect(find.text('Blue Monday'), findsNothing);
  });

  testWidgets('by composer, which finds every one of theirs', (tester) async {
    await _open(tester, _shelf());
    await _search(tester, 'lovelace');
    expect(find.text('Blue Monday'), findsOneWidget);
    expect(find.text('Night Shift'), findsOneWidget);
    expect(find.text('Praia Grande'), findsNothing);
  });

  testWidgets('by key', (tester) async {
    await _open(tester, _shelf());
    await _search(tester, 'Eb');
    expect(find.text('Night Shift'), findsOneWidget);
    expect(find.text('Blue Monday'), findsNothing);
  });

  testWidgets('and by feel, so "bossa" finds the bossas', (tester) async {
    await _open(tester, _shelf());
    await _search(tester, 'bossa');
    expect(find.text('Praia Grande'), findsOneWidget);
    expect(find.text('Blue Monday'), findsNothing);
  });

  testWidgets('clearing it brings them all back', (tester) async {
    await _open(tester, _shelf());
    await _search(tester, 'night');
    expect(find.text('Blue Monday'), findsNothing);
    await _search(tester, '');
    expect(find.text('Blue Monday'), findsOneWidget);
    expect(find.text('Praia Grande'), findsOneWidget);
    expect(find.text('Night Shift'), findsOneWidget);
  });
}
