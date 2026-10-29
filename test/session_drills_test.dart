// Session skills, getting lost, and the tunes your own session calls.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';
import 'package:play_along/practice/session_drills.dart';
import 'package:play_along/screens/practice_page.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

Future<AppSettings> _open(WidgetTester tester, RoadmapProgress progress) async {
  tester.view
    ..physicalSize = const Size(393, 3000) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final settings = AppSettings.inMemory();
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticePage(
        progress: progress,
        player: PracticePlayer(),
        settings: settings,
        library: LibraryStore.inMemory(),
        progressions: ProgressionStore.inMemory(),
        today: DateTime(2026, 10, 29),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  test('every drill is written plainly, and the ones to play say how', () {
    for (final drill in [...sessionSkills, ...recoverDrills]) {
      expect(drill.how, isNot(contains('—')), reason: drill.title);
    }
    // Recovering is the band dropping out: trading against the time.
    for (final drill in recoverDrills.where((d) => d.setup != null)) {
      final arrangement = drill.setup!.arrangement;
      if (arrangement == null) continue;
      expect(arrangement.tradeWith, TradeWith.time);
      expect(arrangement.trading, isNot(Trading.off));
    }
  });

  test('every instrument has something to do in session skills', () {
    for (final instrument in RoadmapInstrument.values) {
      final mine = sessionSkills.where((d) => d.isFor(instrument));
      expect(mine.length, greaterThanOrEqualTo(7), reason: instrument.label);
    }
  });

  test('the session is on the roadmap: goals and blocks', () {
    for (final instrument in RoadmapInstrument.values) {
      final stages = stagesFor(instrument);
      for (final n in [2, 3, 4]) {
        expect(
          stages[n - 1].goals.where((g) => g.area == Area.session),
          isNotEmpty,
          reason: 'stage $n',
        );
      }
      expect(
        stages[1].blocks.map((b) => b.drills),
        contains(SessionDrillSet.recover),
      );
      expect(
        stages[3].blocks.map((b) => b.drills),
        contains(SessionDrillSet.skills),
      );
    }
  });

  test('ballads and bossas are in the tunes of the day', () {
    final tunes = {
      for (final stage in stagesFor(RoadmapInstrument.horn)) ...stage.tunes,
    };
    expect(tunes, containsAll(['Misty', 'Black Orpheus', 'Wave']));
  });

  test("your session's tunes come first, two days in three", () {
    final stage = stagesFor(RoadmapInstrument.guitar).first;
    final mine = ['Autumn Leaves', 'Blue Bossa'];
    final picked = [
      for (var day = 0; day < 9; day++)
        routineFor(stage, 30, day: day, sessionTunes: mine).last.tune,
    ];
    expect(picked.where(mine.contains).length, 6);
    expect(picked.toSet(), containsAll(mine), reason: 'both come round');
    // And the tune of the day is what session drills are played on.
    final routine = routineFor(stage, 30, day: 0, sessionTunes: mine);
    expect(routine.first.tuneOfTheDay, routine.last.tune);
  });

  test('session tunes are kept, once each', () {
    final progress = RoadmapProgress.inMemory();
    progress
      ..addSessionTune('Autumn Leaves')
      ..addSessionTune('Autumn Leaves')
      ..addSessionTune('Oleo');
    expect(progress.sessionTunes, ['Autumn Leaves', 'Oleo']);
    progress.removeSessionTune('Autumn Leaves');
    expect(progress.sessionTunes, ['Oleo']);
  });

  testWidgets('the last-four intro starts the band four bars from the end', (
    tester,
  ) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.horn,
    )..addSessionTune('Autumn Leaves');
    final settings = await _open(tester, progress);
    await tester.tap(find.byKey(const ValueKey('practice-session-skills')));
    await tester.pumpAndSettle();
    expect(find.text('Played on Autumn Leaves.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drill-play-0')));
    await tester.pumpAndSettle();
    final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    final leaves = standards.firstWhere((t) => t.title == 'Autumn Leaves');
    expect(screen.startBar, leaves.barCount - 4);
    expect(find.text('From ${leaves.barCount - 3}'), findsOneWidget);
    // A drill does not change the choruses kept for every tune.
    expect(settings.choruses, AppSettings.defaultChoruses);
  });

  testWidgets('getting lost: the band drops out against the time', (
    tester,
  ) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.bass,
    );
    final settings = await _open(tester, progress);
    await tester.tap(find.byKey(const ValueKey('practice-recover')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drill-play-1')));
    await tester.pumpAndSettle();
    final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(screen.arrangement?.trading, Trading.fours);
    expect(screen.arrangement?.tradeWith, TradeWith.time);
    expect(settings.choruses, AppSettings.defaultChoruses);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a tune is added to your session's list from the library", (
    tester,
  ) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.piano,
    );
    await _open(tester, progress);
    await tester.tap(find.byKey(const ValueKey('add-session-tune')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('session-tune-search')),
      'oleo',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oleo'));
    await tester.pumpAndSettle();
    expect(progress.sessionTunes, ['Oleo']);
    expect(find.byKey(const ValueKey('session-tune-Oleo')), findsOneWidget);
  });
}
