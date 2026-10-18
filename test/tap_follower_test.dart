// Following a band by being told: taps on the beat, the top of the
// chorus, a bar on the chart. On a clock the test moves itself.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/tap_follower.dart';
import 'package:play_along/screens/stage_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
  var now = Duration.zero;
  Duration clock() => now;
  const beat = Duration(milliseconds: 500); // 120 to the minute

  TapFollower follower() {
    now = Duration.zero;
    final taps = TapFollower(tune: tune, clock: clock);
    addTearDown(taps.dispose);
    return taps;
  }

  void tapFour(TapFollower taps) {
    for (var i = 0; i < 4; i++) {
      if (i > 0) now += beat;
      taps.tapBeat();
    }
  }

  test('nothing is counted until the beat is tapped', () {
    final taps = follower();
    expect(taps.counting, isFalse);
    expect(taps.beat, isNull);
    taps.tapBeat();
    now += beat;
    taps.tapBeat();
    expect(taps.counting, isFalse, reason: 'two taps are not a tempo');
  });

  test('a count-off: bar 1 comes on the next beat', () {
    final taps = follower();
    tapFour(taps);
    expect(taps.tempo, closeTo(120, 0.5));
    now += beat;
    expect(taps.beat, 0);
    now += beat * 4;
    expect(taps.beat, 4, reason: 'the first beat of bar 2');
  });

  test('tapping again while counting keeps the place, moves the beat', () {
    final taps = follower();
    tapFour(taps);
    now += beat * 9; // beat 8: bar 3
    expect(taps.beat, 8);
    // The band has pushed on to 130: three taps at the new tempo.
    const quicker = Duration(microseconds: 461538);
    for (var i = 0; i < 3; i++) {
      now += quicker;
      taps.tapBeat();
    }
    expect(taps.tempo, closeTo(130, 0.5));
    final there = taps.beat!;
    now += quicker * 4;
    expect(taps.beat, there + 4);
  });

  test('top of the chorus puts it at bar 1, now', () {
    final taps = follower();
    tapFour(taps);
    now += beat * 37;
    taps.topOfChorus();
    expect(taps.beat, 0);
    now += beat * 5;
    expect(taps.beat, 5);
  });

  test('a bar tapped is the bar now', () {
    final taps = follower();
    tapFour(taps);
    now += beat * 3;
    taps.placeAtBar(16);
    expect(taps.beat, 64);
    now += beat;
    expect(taps.beat, 65);
  });

  test('a bar tapped before the tempo is counted on from', () {
    // Somebody comes in mid-tune: taps the bar, then taps the beat. The
    // band has gone on by the beats tapped since.
    final taps = follower();
    taps.placeAtBar(8);
    tapFour(taps);
    expect(taps.beat, 32 + 3);
  });

  group('on the stage', () {
    Future<TapFollower> openStage(
      WidgetTester tester, {
      bool follow = true,
    }) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final controller = PracticeController(
        tune: tune,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      );
      addTearDown(controller.dispose);
      now = Duration.zero;
      final taps = TapFollower(tune: controller.tune, clock: clock);
      addTearDown(taps.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: StageScreen(controller: controller, follow: follow, taps: taps),
        ),
      );
      await tester.pumpAndSettle();
      return taps;
    }

    testWidgets('only the scrolling stage follows by taps', (tester) async {
      await openStage(tester, follow: false);
      expect(find.byKey(const ValueKey('stage-follow-taps')), findsNothing);
    });

    testWidgets('the buttons tap the beat and find the top', (tester) async {
      final taps = await openStage(tester);
      await tester.tap(find.byKey(const ValueKey('stage-follow-taps')));
      await tester.pump();
      expect(find.byKey(const ValueKey('stage-tapping')), findsOneWidget);
      expect(find.textContaining('Count the band in'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        if (i > 0) now += beat;
        await tester.tap(find.byKey(const ValueKey('stage-tap-beat')));
        await tester.pump();
      }
      expect(taps.counting, isTrue);
      now += beat * 6;
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.textContaining('Counting at 120 BPM'), findsOneWidget);
      expect(find.text('120 BPM'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stage-top')));
      await tester.pump();
      expect(taps.beat, 0);
      // And off again, with nothing left counting.
      await tester.tap(find.byKey(const ValueKey('stage-follow-taps')));
      await tester.pump();
      expect(find.byKey(const ValueKey('stage-tapping')), findsNothing);
      expect(taps.counting, isFalse);
    });

    testWidgets('a pedal: right taps the beat, left is the top', (
      tester,
    ) async {
      final taps = await openStage(tester);
      await tester.tap(find.byKey(const ValueKey('stage-follow-taps')));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        if (i > 0) now += beat;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump();
      }
      expect(taps.counting, isTrue);
      expect(taps.tempo, closeTo(120, 0.5));
      now += beat * 10;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(taps.beat, 0);
      taps.stop();
    });
  });
}
