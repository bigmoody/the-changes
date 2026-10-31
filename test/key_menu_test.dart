// Every exercise on the Practice tab can be taken into any of the twelve
// keys: today's to start with, then round the cycle or straight to one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/practice/licks.dart';
import 'package:play_along/practice/line_exercise.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';
import 'package:play_along/practice/sound_exercise.dart';
import 'package:play_along/screens/key_menu.dart';
import 'package:play_along/screens/lick_screen.dart';
import 'package:play_along/screens/line_exercise_screen.dart';
import 'package:play_along/screens/scale_of_the_day_screen.dart';
import 'package:play_along/screens/sound_exercise_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: appTheme(Brightness.light), home: screen),
  );
}

/// Today's F, then the next key round the cycle, then D from the menu.
Future<void> _goesRound(
  WidgetTester tester,
  String Function(String) shows,
) async {
  expect(find.text('In F'), findsOneWidget);
  expect(find.textContaining(shows('F')), findsWidgets);
  await tester.tap(find.byKey(const ValueKey('key-next')));
  await tester.pump();
  expect(find.text('In B♭'), findsOneWidget);
  expect(find.textContaining(shows('B♭')), findsWidgets);
  await tester.tap(find.byKey(const ValueKey('key-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('In D').last);
  await tester.pumpAndSettle();
  expect(find.text('In D'), findsOneWidget);
  expect(find.textContaining(shows('D')), findsWidgets);
  expect(tester.takeException(), isNull);
}

void main() {
  test('round the cycle, and how far apart two keys are', () {
    expect(nextExerciseKey('C'), 'F');
    expect(nextExerciseKey('G'), 'C');
    expect(nextExerciseKey('F♯'), 'B');
    expect(semitonesBetween('C', 'F'), 5);
    expect(semitonesBetween('C', 'G'), -5);
    expect(semitonesBetween('F', 'B'), 6);
    expect(semitonesBetween('B♭', 'A'), -1);
    expect(exerciseKeys.toSet(), hasLength(12));
  });

  testWidgets('the scale of the day', (tester) async {
    await _pump(
      tester,
      ScaleOfTheDayScreen(
        title: 'Scale of the Day',
        modes: const ['Ionian'],
        keyName: 'F',
        exercise: const ScaleExercise(ways: ['Straight'], from: 70, to: 90),
        instrument: RoadmapInstrument.horn,
        progress: RoadmapProgress.inMemory(),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        onDone: () {},
      ),
    );
    await _goesRound(tester, (key) => '$key Ionian');
  });

  testWidgets('a horn line', (tester) async {
    await _pump(
      tester,
      LineExerciseScreen(
        title: 'Articulation',
        keyName: 'F',
        exercise: articulation,
        progress: RoadmapProgress.inMemory(),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        onDone: () {},
      ),
    );
    await _goesRound(tester, (key) => '$key major');
  });

  testWidgets('long tones', (tester) async {
    await _pump(
      tester,
      SoundExerciseScreen(
        title: 'Long Tones',
        exercise: longTones(5),
        keyName: 'F',
        day: 0,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        onDone: () {},
      ),
    );
    await _goesRound(tester, (key) => key);
  });

  testWidgets('the lick of the day, not only the one from Session Tools', (
    tester,
  ) async {
    await _pump(
      tester,
      LickScreen(
        licks: licks,
        keyName: 'F',
        instrument: RoadmapInstrument.horn,
        progress: RoadmapProgress.inMemory(),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        onDone: () {},
      ),
    );
    await _goesRound(tester, (key) => 'in $key');
  });
}
