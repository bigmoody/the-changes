// Practice by level: a beginner and a professional on the same stage do
// not do the same day.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';
import 'package:play_along/screens/practice_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

int _minutesOn(List<RoutineBlock> routine, Area area) => routine
    .where((b) => b.block.area == area)
    .fold(0, (sum, b) => sum + b.minutes);

void main() {
  final stage = stagesFor(RoadmapInstrument.guitar)[3];

  test('a beginner spends longer on sound and scales, a pro on the ear '
      'and the tunes', () {
    var beginnerBasics = 0, proBasics = 0, beginnerEar = 0, proEar = 0;
    var beginnerTune = 0, proTune = 0;
    for (var day = 0; day < 12; day++) {
      final beginner = routineFor(
        stage,
        90,
        day: day,
        level: PlayerLevel.beginner,
      );
      final pro = routineFor(
        stage,
        90,
        day: day,
        level: PlayerLevel.professional,
      );
      beginnerBasics +=
          _minutesOn(beginner, Area.sound) + _minutesOn(beginner, Area.scales);
      proBasics += _minutesOn(pro, Area.sound) + _minutesOn(pro, Area.scales);
      beginnerEar += _minutesOn(beginner, Area.language);
      proEar += _minutesOn(pro, Area.language);
      beginnerTune += beginner.last.minutes;
      proTune += pro.last.minutes;
      // Every level's day still adds up.
      for (final routine in [beginner, pro]) {
        expect(routine.fold(0, (sum, b) => sum + b.minutes), 90);
      }
    }
    expect(beginnerBasics, greaterThan(proBasics));
    expect(proEar, greaterThan(beginnerEar));
    expect(proTune, greaterThan(beginnerTune));
  });

  test('a beginner stays in the easier keys; a pro takes them all', () {
    final keys = <String>{}, proKeys = <String>{};
    for (var day = 0; day < 24; day++) {
      keys.add(
        routineFor(stage, 30, day: day, level: PlayerLevel.beginner).first.key,
      );
      proKeys.add(
        routineFor(
          stage,
          30,
          day: day,
          level: PlayerLevel.professional,
        ).first.key,
      );
    }
    expect(keys, everyElement(isIn(['C', 'F', 'B♭', 'E♭', 'G', 'D'])));
    expect(proKeys.length, 12);
  });

  test('the tempos are the level\'s, in the instructions too', () {
    final first = stagesFor(RoadmapInstrument.horn).first;
    // A professional's day does not always have room for the scale, so
    // the first day that does.
    String scaleHow(PlayerLevel level) => [
      for (var day = 0; day < 14; day++)
        ...routineFor(first, 90, day: day, level: level),
    ].firstWhere((b) => b.block.title == 'Scale of the Day').how;
    expect(scaleHow(PlayerLevel.intermediate), contains('at 70 to 90'));
    expect(scaleHow(PlayerLevel.beginner), contains('at 55 to 70'));
    expect(scaleHow(PlayerLevel.professional), contains('at 90 to 115'));
  });

  test('choosing a level starts you on its stage, and keeps the ticks', () {
    final progress = RoadmapProgress.inMemory(level: null);
    final goal = stagesFor(RoadmapInstrument.bass).first.goals.first;
    progress.tick(RoadmapInstrument.bass, goal, true);
    progress.setLevel(PlayerLevel.advanced, RoadmapInstrument.bass);
    expect(progress.stageOf(RoadmapInstrument.bass), 4);
    expect(progress.minutes, 60, reason: 'the level\'s session, first time');
    expect(progress.isTicked(RoadmapInstrument.bass, goal), isTrue);
  });

  testWidgets('it asks for the level after the instrument', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final progress = RoadmapProgress.inMemory(level: null);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticePage(
          progress: progress,
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
          library: LibraryStore.inMemory(),
          progressions: ProgressionStore.inMemory(),
          today: DateTime(2026, 10, 29),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roadmap-for-piano')));
    await tester.pumpAndSettle();
    expect(find.text('Where Are You Now?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('level-professional')));
    await tester.pumpAndSettle();
    expect(progress.level, PlayerLevel.professional);
    expect(find.text('Stage 5: Colour and Tension'), findsOneWidget);
    // The levels stay in view as tabs once one is chosen.
    expect(find.byKey(const ValueKey('roadmap-level')), findsOneWidget);
    for (final level in PlayerLevel.values) {
      expect(find.byKey(ValueKey('level-tab-${level.name}')), findsOneWidget);
    }
    // Changing one asks first, then moves to its stage.
    await tester.tap(find.byKey(const ValueKey('level-tab-beginner')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('level-confirm')));
    await tester.pumpAndSettle();
    expect(progress.level, PlayerLevel.beginner);
    expect(find.text('Stage 1: Time, Sound and the Blues'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
