// The Practice tab: choosing an instrument, today's routine, and moving up
// the roadmap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/mode_examples.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';
import 'package:play_along/screens/practice_page.dart';
import 'package:play_along/screens/practice_screen.dart';
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
      find.descendant(
        of: row,
        matching: find.textContaining('Take the "A" Train, in '),
      ),
      findsOneWidget,
      reason: 'the Ionian tune, to play',
    );
    // Named for the sound, since the tune is not in today's key.
    expect(find.text('Ionian Heard In'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heard-in-Ionian')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Take the "A" Train (in C'), findsOneWidget);
    expect(find.textContaining('Joy to the World'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a tune the mode is heard in opens in today's key", (
    tester,
  ) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.horn,
    );
    await _open(tester, size: const Size(393, 3000), progress: progress);
    final today = routineFor(
      stagesFor(RoadmapInstrument.horn).first,
      progress.minutes,
      day: dayNumber(DateTime(2026, 10, 29)),
    )[1];
    expect(today.block.modes, contains('Ionian'));
    await tester.tap(find.textContaining('Take the "A" Train, in '));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(screen.semitones, semitonesToKey('Take the "A" Train', today.key));
    expect(screen.tune.title, 'Take the "A" Train');
    // And the chart is in it: the tune's opening C6 is today's key's 6.
    await tester.pumpAndSettle();
    expect(find.textContaining('${today.key}6'), findsWidgets);
  });

  testWidgets('articulation is lines to play, step by step', (tester) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.horn,
    )..setMinutes(60);
    await _open(tester, size: const Size(393, 3000), progress: progress);
    final day = dayNumber(DateTime(2026, 10, 29));
    final routine = routineFor(
      stagesFor(RoadmapInstrument.horn).first,
      60,
      day: day,
    );
    final index = routine.indexWhere((b) => b.block.title == 'Articulation');
    expect(index, isNonNegative);
    await tester.tap(find.text('Articulation'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Swing'), findsNothing);
    expect(find.text('One Note, Legato Tongue'), findsOneWidget);
    expect(find.byKey(const ValueKey('line-stave')), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-15')), findsOneWidget);
    for (final title in [
      'Tongue the Off-Beats',
      'Accent the Off-Beats',
      'Accent the Top',
    ]) {
      await tester.tap(find.byKey(const ValueKey('line-next')));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('line-next')));
    await tester.pumpAndSettle();
    expect(progress.isDone(day, index, 'Articulation'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('licks in context: the stage\'s licks, in today\'s key, '
      'and it ticks itself off', (tester) async {
    final progress =
        RoadmapProgress.inMemory(instrument: RoadmapInstrument.horn)
          ..setStage(RoadmapInstrument.horn, 2)
          ..setMinutes(90);
    await _open(tester, size: const Size(393, 3000), progress: progress);
    final day = dayNumber(DateTime(2026, 10, 29));
    final routine = routineFor(
      stagesFor(RoadmapInstrument.horn)[1],
      90,
      day: day,
    );
    final index = routine.indexWhere(
      (b) => b.block.title == 'Licks in Context',
    );
    expect(index, isNonNegative);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('routine-$index')),
        matching: find.text('Licks in Context'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Lick'), findsOneWidget);
    expect(find.text('Lick 1 of 3 · in ${routine[index].key}'), findsOneWidget);
    expect(find.byKey(const ValueKey('lick-stave')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lick-changes')),
        matching: find.text('Dm7'),
      ),
      findsNothing,
      reason: 'in today\'s key, not C, unless today is C',
    );
    expect(find.byKey(const ValueKey('lick-changes')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lick-next')));
    await tester.pumpAndSettle();
    expect(find.text('1 2 3 5 Down the Changes'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lick-next')));
    await tester.pumpAndSettle();
    expect(find.text('The Blue Third'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lick-next')));
    await tester.pumpAndSettle();
    expect(progress.isDone(day, index, 'Licks in Context'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('licks are on the Practice tab from the first stage, and '
      'always there', (tester) async {
    await _open(
      tester,
      size: const Size(393, 3000),
      progress: RoadmapProgress.inMemory(instrument: RoadmapInstrument.guitar),
    );
    expect(
      stagesFor(RoadmapInstrument.guitar).first.blocks.map((b) => b.title),
      contains('Licks in Context'),
    );
    await tester.tap(find.byKey(const ValueKey('practice-licks')));
    await tester.pumpAndSettle();
    expect(find.text('The Lick'), findsOneWidget);
    expect(find.text('Lick 1 of 7 · in G'), findsOneWidget);
  });

  testWidgets('a block opens the page it is done on', (tester) async {
    await _open(
      tester,
      size: const Size(393, 3000),
      progress: RoadmapProgress.inMemory(instrument: RoadmapInstrument.guitar),
    );
    await tester.tap(find.text('Shell Voicings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Guitar Chords'), findsOneWidget);
  });

  testWidgets('the scale of the day is played, step by step, and ticks '
      'itself off', (tester) async {
    final progress = RoadmapProgress.inMemory(
      instrument: RoadmapInstrument.guitar,
    );
    await _open(tester, size: const Size(393, 3000), progress: progress);
    final day = dayNumber(DateTime(2026, 10, 29));
    await tester.tap(find.text('Scale of the Day'));
    await tester.pumpAndSettle();
    // Not the reference page: today's scale, to play.
    expect(find.widgetWithText(AppBar, 'Scales & Modes'), findsNothing);
    expect(find.text('G Ionian'), findsOneWidget);
    expect(find.text('Straight, Up and Down'), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('scale-stave-0')), findsOneWidget);

    // The tempo starts at the stage's, and is kept.
    expect(find.text('70'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scale-faster')));
    await tester.pumpAndSettle();
    expect(find.text('75'), findsOneWidget);
    expect(progress.scaleTempo('Ionian Straight', 0), 75);

    await tester.tap(find.byKey(const ValueKey('scale-next')));
    await tester.pumpAndSettle();
    expect(find.text('In 3rds'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scale-next')));
    await tester.pumpAndSettle();
    // Back on the routine, with the block ticked.
    expect(find.byType(PracticePage), findsOneWidget);
    expect(progress.isDone(day, 1, 'Scale of the Day'), isTrue);
    expect(tester.takeException(), isNull);
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
