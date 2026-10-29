// The Practice tab: choosing an instrument, today's routine, and moving up
// the roadmap.

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

Future<RoadmapProgress> _open(
  WidgetTester tester, {
  RoadmapProgress? progress,
  Size size = const Size(393, 852),
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final shown = progress ?? RoadmapProgress.inMemory();
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticePage(
        progress: shown,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        library: LibraryStore.inMemory(),
        progressions: ProgressionStore.inMemory(),
        today: DateTime(2026, 10, 29),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return shown;
}

void main() {
  testWidgets('it asks what you play, then shows the day', (tester) async {
    final progress = await _open(tester);
    expect(find.text('A Roadmap to Playing Jazz'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('roadmap-for-horn')));
    await tester.pumpAndSettle();
    expect(progress.instrument, RoadmapInstrument.horn);
    expect(find.text('Stage 1: Time, Sound and the Blues'), findsOneWidget);
    expect(find.text('Long Tones'), findsOneWidget, reason: 'a horn warm-up');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the routine is cut to the time chosen', (tester) async {
    // Tall enough that the whole routine is built: the list is lazy.
    final progress = await _open(
      tester,
      size: const Size(393, 3000),
      progress: RoadmapProgress.inMemory(instrument: RoadmapInstrument.guitar),
    );
    int rows() => find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('routine-'),
        )
        .evaluate()
        .length;
    final thirty = rows();
    await tester.tap(find.byKey(const ValueKey('session-15')));
    await tester.pumpAndSettle();
    expect(progress.minutes, 15);
    expect(rows(), lessThan(thirty));
    expect(find.text('Tune of the Day'), findsOneWidget);
  });

  testWidgets('ticking a block crosses it off for today', (tester) async {
    final progress = await _open(
      tester,
      size: const Size(393, 3000),
      progress: RoadmapProgress.inMemory(instrument: RoadmapInstrument.bass),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('routine-0')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of'), findsOneWidget);
    expect(
      progress.isDone(dayNumber(DateTime(2026, 10, 29)), 0, 'Time'),
      isTrue,
    );
  });

  testWidgets('every goal ticked, and you can move up', (tester) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.piano,
    );
    final stage = stagesFor(RoadmapInstrument.piano).first;
    await _open(tester, progress: progress);
    final button = find.byKey(const ValueKey('move-up-1'));
    await tester.scrollUntilVisible(button, 200);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    for (final goal in stage.goals) {
      progress.tick(RoadmapInstrument.piano, goal, true);
    }
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(progress.stageOf(RoadmapInstrument.piano), 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('today-stage')),
      -200,
    );
    expect(find.text('Stage 2: Chord Tones and the ii–V–I'), findsOneWidget);
  });

  testWidgets('a scale block says where its mode is heard', (tester) async {
    await _open(
      tester,
      size: const Size(393, 3000),
      progress: RoadmapProgress.inMemory(instrument: RoadmapInstrument.horn),
    );
    final row = find.byKey(const ValueKey('routine-1'));
    expect(
      find.descendant(of: row, matching: find.text('Take the "A" Train')),
      findsOneWidget,
      reason: 'the Ionian tune, to play',
    );
    await tester.tap(find.byKey(const ValueKey('heard-in-Ionian')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Joy to the World'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a block opens the page it is done on', (tester) async {
    await _open(
      tester,
      progress: RoadmapProgress.inMemory(instrument: RoadmapInstrument.guitar),
    );
    await tester.tap(find.text('Scale of the Day'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Scales & Modes'), findsOneWidget);
  });

  for (final instrument in RoadmapInstrument.values) {
    testWidgets('nothing overflows for ${instrument.label}, on a phone and '
        'on an iPad, at a large text size', (tester) async {
      for (final size in const [Size(393, 852), Size(834, 1194)]) {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _open(
          tester,
          size: size,
          progress: RoadmapProgress.inMemory(instrument: instrument),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
