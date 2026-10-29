// Each tab keeps its own pages: the bar stays at the bottom inside an
// exercise, tapping the tab you are on goes back to its first page, and
// switching tabs comes back to where you were. A tune's chart opens full
// screen over the tabs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/practice/part_store.dart';
import 'package:play_along/practice/phrase_store.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';
import 'package:play_along/practice/soundfont_store.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/screens/home_screen.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

Future<void> _openHome(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(834, 3000) * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: HomeScreen(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        takes: TakeStore.inMemory(),
        partStore: PartStore.inMemory(),
        recordingStore: RecordingStore.inMemory(),
        phrases: PhraseStore.inMemory(),
        soundFont: SoundFontStore.inMemory(),
        progressions: ProgressionStore.inMemory(),
        library: LibraryStore.inMemory(),
        roadmap: RoadmapProgress.inMemory(instrument: RoadmapInstrument.horn),
        initialTab: HomeTab.practice,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('inside an exercise the bar is still there, and Practice '
      'takes you back to the Practice page', (tester) async {
    await _openHome(tester);
    await tester.tap(find.byKey(const ValueKey('practice-playing-fast')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Playing Fast'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await _tapTab(tester, 'Practice');
    expect(find.widgetWithText(AppBar, 'Playing Fast'), findsNothing);
    expect(find.byKey(const ValueKey('today-stage')), findsOneWidget);
  });

  testWidgets('another tab and back: you are where you left off', (
    tester,
  ) async {
    await _openHome(tester);
    await tester.tap(find.byKey(const ValueKey('practice-session-skills')));
    await tester.pumpAndSettle();
    await _tapTab(tester, 'Learn');
    expect(find.widgetWithText(AppBar, 'Learn'), findsOneWidget);
    await _tapTab(tester, 'Practice');
    expect(find.widgetWithText(AppBar, 'Session Skills'), findsOneWidget);
    // And tapping Practice again goes to the top of it.
    await _tapTab(tester, 'Practice');
    expect(find.widgetWithText(AppBar, 'Session Skills'), findsNothing);
  });

  testWidgets('the same in Learn', (tester) async {
    await _openHome(tester);
    await _tapTab(tester, 'Learn');
    await tester.tap(find.text('Playing Fast'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await _tapTab(tester, 'Learn');
    expect(find.widgetWithText(AppBar, 'Learn'), findsOneWidget);
  });

  testWidgets("a tune's chart opens full screen over the tabs", (tester) async {
    await _openHome(tester);
    await tester.tap(find.byKey(const ValueKey('practice-playing-fast')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fast-ladder')));
    // The ladder starts the band, so the screen never goes still.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
