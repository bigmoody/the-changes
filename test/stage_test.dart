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
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final controller = PracticeController(
    tune: _standard(title),
    player: PracticePlayer(),
    settings: AppSettings.inMemory(),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: StageScreen(controller: controller),
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

  group('what is on it', () {
    testWidgets('the chart, and what you are playing', (tester) async {
      await _openStage(tester);
      expect(find.byType(ChordChart), findsOneWidget);
      // The first chord of Cherokee, written large in the bar below.
      expect(find.byKey(const ValueKey('stage-play')), findsOneWidget);
      expect(find.textContaining('BPM'), findsOneWidget);
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
      expect(find.byTooltip('Stop'), findsOneWidget);
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
