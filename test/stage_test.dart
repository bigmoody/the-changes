// The stage: the chart and nothing else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/chord_chart.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/screens/stage_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// The stage on its own, with a controller the test can look at after.
Future<PracticeController> _openStage(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  String title = 'Cherokee',
  ChordAid aid = ChordAid.off,
  bool follow = false,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final settings = AppSettings.inMemory();
  await settings.setChordAid(aid);
  final controller = PracticeController(
    tune: _standard(title),
    player: PracticePlayer(),
    settings: settings,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: StageScreen(controller: controller, follow: follow),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// The practice screen, to walk onto the stage from.
Future<void> _openPractice(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: _standard('Cherokee'),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('getting there', () {
    testWidgets('the tune menu offers it', (tester) async {
      await _openPractice(tester);
      await tester.tap(find.byKey(const ValueKey('tune-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Stage View'), findsOneWidget);
    });

    testWidgets('and it opens over the chart', (tester) async {
      await _openPractice(tester);
      await tester.tap(find.byKey(const ValueKey('tune-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stage View'));
      await tester.pumpAndSettle();
      expect(find.byType(StageScreen), findsOneWidget);
    });
  });

  group('the scrolling one', () {
    testWidgets('is offered beside the other, which stays', (tester) async {
      await _openPractice(tester);
      await tester.tap(find.byKey(const ValueKey('tune-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Stage View'), findsOneWidget);
      await tester.tap(find.text('Scrolling Stage View'));
      await tester.pumpAndSettle();
      final stage = tester.widget<StageScreen>(find.byType(StageScreen));
      expect(stage.follow, isTrue);
    });

    // The chart's own scroll view, which the whole-chart stage has none of.
    Finder chartScroll() => find.descendant(
      of: find.byType(ChordChart),
      matching: find.byType(SingleChildScrollView),
    );

    testWidgets('a long tune scrolls, in rows big enough to read', (
      tester,
    ) async {
      await _openStage(tester, follow: true);
      expect(chartScroll(), findsOneWidget);
      Finder firstBar() => find
          .descendant(
            of: find.byType(ChordChart),
            matching: find.byType(Material),
          )
          .first;
      final bar = tester.getRect(firstBar());
      await _openStage(tester);
      expect(chartScroll(), findsNothing, reason: 'Stage View is unchanged');
      final fitted = tester.getRect(firstBar());
      expect(bar.height, greaterThan(fitted.height * 1.5));
    });
  });

  group('what is on it', () {
    testWidgets('the chart, and what you are playing', (tester) async {
      await _openStage(tester);
      expect(find.byType(ChordChart), findsOneWidget);
      // The first chord of Cherokee, written large in the bar below.
      expect(find.byKey(const ValueKey('stage-play')), findsOneWidget);
      expect(find.textContaining('BPM'), findsOneWidget);
    });

    testWidgets('nothing written under the chords, whatever is set', (
      tester,
    ) async {
      // The stage is the chart and nothing else. There is no loop bar on
      // it to say what small red letters are, so they do not go on it.
      await _openStage(tester, title: 'Blue Bossa', aid: ChordAid.roman);
      expect(find.byType(ChordChart), findsOneWidget);
      expect(find.text('Fm7'), findsWidgets, reason: 'the chords are there');
      expect(find.text('iv7'), findsNothing);
      expect(find.byKey(const ValueKey('chord-aid')), findsNothing);
    });

    testWidgets('the practice chart still has them', (tester) async {
      // Guarding the other half: turning them off on the stage must not
      // turn them off where they were asked for.
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final settings = AppSettings.inMemory();
      await settings.setChordAid(ChordAid.roman);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: _standard('Blue Bossa'),
            player: PracticePlayer(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('iv7'), findsWidgets);
    });

    testWidgets('and none of the practice controls', (tester) async {
      await _openStage(tester);
      // No mixer, no arrangement, no transposition, no loop bar.
      expect(find.text('View'), findsNothing);
      expect(find.text('Play'), findsNothing, reason: 'the icon, not a word');
      expect(find.text('Whole tune'), findsNothing);
      expect(find.text('Tap'), findsNothing);
    });

    testWidgets('the chart gets nearly the whole screen', (tester) async {
      await _openStage(tester);
      final chart = tester.getRect(find.byType(ChordChart));
      final screen = tester.getRect(find.byType(StageScreen));
      expect(chart.height, greaterThan(screen.height * 0.85));
    });
  });

  group('starting and stopping', () {
    testWidgets('a tap anywhere on the chart starts the band', (tester) async {
      final controller = await _openStage(tester);
      expect(controller.isPlaying, isFalse);

      await tester.tap(find.byKey(const ValueKey('stage-chart')));
      await tester.pump();
      expect(controller.isPlaying, isTrue);
    });

    testWidgets('and a tap on a bar does not set a loop', (tester) async {
      final controller = await _openStage(tester);
      final whole = controller.loop;

      // Right on a bar of the chart, which while practising would loop it.
      await tester.tap(find.text('Fm7').first);
      await tester.pump();
      expect(controller.loop.startBeat, whole.startBeat);
      expect(controller.loop.lengthBeats, whole.lengthBeats);
    });

    testWidgets('the button says what it will do', (tester) async {
      await _openStage(tester);
      expect(find.byTooltip('Play'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stage-play')));
      await tester.pump();
      expect(find.byTooltip('Pause'), findsOneWidget);
    });
  });

  group('sideways', () {
    for (final size in const [
      Size(852, 393),
      Size(667, 375),
      Size(1194, 834),
    ]) {
      testWidgets('it fits on ${size.width.toInt()}×${size.height.toInt()}', (
        tester,
      ) async {
        await _openStage(tester, size: size);
        expect(tester.takeException(), isNull);
        final chart = tester.getRect(find.byType(ChordChart));
        expect(chart.height, greaterThan(size.height * 0.8));
      });
    }
  });
}
