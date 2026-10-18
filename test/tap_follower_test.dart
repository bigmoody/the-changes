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

  group('barlines heard by Beat This!', () {
    const bar = Duration(milliseconds: 2000); // four beats at 120

    /// Barlines [every] apart, from [from], each heard [late] after it.
    void hear(
      TapFollower taps,
      int count, {
      Duration every = bar,
      Duration? from,
      Duration late = Duration.zero,
    }) {
      var at = from ?? now;
      for (var i = 0; i < count; i++) {
        now = at + late;
        taps.heardBarline(late);
        at += every;
      }
      now = at - every + late;
    }

    test('five steady barlines start the count, on bar 1', () {
      final taps = follower();
      hear(taps, 4);
      expect(taps.counting, isFalse, reason: 'four are not yet steady');
      hear(taps, 1, from: bar * 4);
      expect(taps.counting, isTrue);
      expect(taps.tempo, closeTo(120, 0.5));
      // The fifth barline was bar 1; half a bar on is still bar 1.
      now = bar * 4 + bar ~/ 2;
      expect(taps.beat, 2);
      taps.stop();
    });

    test('barlines heard late are put where they were', () {
      final taps = follower();
      hear(taps, 5, late: const Duration(milliseconds: 900));
      // The fifth barline was at 8 s, heard at 8.9 s.
      now = bar * 4 + const Duration(milliseconds: 100);
      expect(taps.beat, 0);
      now = bar * 4 + const Duration(milliseconds: 600);
      expect(taps.beat, 1);
      taps.stop();
    });

    test('half bars do not start it', () {
      final taps = follower();
      hear(taps, 8, every: const Duration(milliseconds: 600));
      expect(taps.counting, isFalse);
    });

    test('a bar tapped before keeps its place when they start it', () {
      final taps = follower();
      taps.placeAtBar(4); // bar 5, at 0 s
      hear(taps, 5, from: bar * 2);
      // The barlines heard were bars 7 to 11: at 12 s, bar 11.
      expect(taps.beat, 10 * tune.beatsPerBar);
      taps.stop();
    });

    test('the count follows a band that slows down', () {
      final taps = follower();
      tapFour(taps); // 120, bar 1 at 2 s
      // The band is at 116 from bar 1: a bar of about 2.07 s.
      const slower = Duration(microseconds: 2068966);
      hear(taps, 16, from: beat * 4, every: slower);
      expect(taps.nudges, greaterThan(10));
      expect(taps.tempo, closeTo(116, 1.5));
      // The last barline heard is still a barline on the count.
      final last = beat * 4 + slower * 15;
      now = last + const Duration(milliseconds: 50);
      expect(taps.beat! % tune.beatsPerBar, 0);
      taps.stop();
    });

    test('never further than a tenth from the tempo it started at', () {
      final taps = follower();
      tapFour(taps);
      // Barlines at half the tempo's bar length would be half bars, and
      // gated out; these are slower, past where it may go.
      hear(taps, 40, from: beat * 4, every: const Duration(milliseconds: 2350));
      expect(taps.tempo, greaterThanOrEqualTo(120 / 1.1 - 0.5));
      taps.stop();
    });

    test('a barline in the middle of a bar is not taken', () {
      final taps = follower();
      tapFour(taps);
      now = beat * 4 + bar * 2 + bar ~/ 2;
      taps.heardBarline(Duration.zero);
      expect(taps.nudges, 0);
      expect(taps.tempo, closeTo(120, 0.5));
      taps.stop();
    });

    test('a bar tapped is still put right by the barline heard after', () {
      final taps = follower();
      tapFour(taps); // 120: bar 1 at 2 s
      // Bar 3 tapped 60 ms late, at 6.06 s; Beat This! hears its barline,
      // at 6 s, a second after.
      now = beat * 12 + const Duration(milliseconds: 60);
      taps.placeAtBar(2);
      now = beat * 12 + const Duration(seconds: 1);
      taps.heardBarline(const Duration(seconds: 1));
      expect(taps.nudges, 1);
      expect(
        taps.tempo,
        closeTo(120, 0.5),
        reason: 'the place, not the length',
      );
      // Half way back: bar 3 counted from 6.03 s.
      now = beat * 12 + const Duration(milliseconds: 25);
      expect(taps.beat, 7);
      now = beat * 12 + const Duration(milliseconds: 35);
      expect(taps.beat, 8);
      taps.stop();
    });
  });
}
