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

  test('bars tapped one after another give the tempo', () {
    // An up-tempo Cherokee, 340 to the minute: a bar every 0.706 seconds,
    // easier to tap than every beat.
    final taps = follower();
    const bar = Duration(microseconds: 705882);
    taps.placeAtBar(4);
    expect(taps.counting, isFalse, reason: 'one bar is not a tempo');
    for (var b = 5; b <= 7; b++) {
      now += bar;
      taps.placeAtBar(b);
    }
    expect(taps.tempo, closeTo(340, 1));
    now += bar * 3;
    expect(taps.beat, 40, reason: 'three bars on: bar 11');
  });

  test('two bars tapped a bar apart at twice the tempo double it', () {
    // Counting at half, 170 for a band at 340: bar 5, then bar 6 a bar
    // of the band's later, and it is at 340 at once.
    final taps = follower();
    for (var i = 0; i < 4; i++) {
      if (i > 0) now += const Duration(microseconds: 352941);
      taps.tapBeat();
    }
    expect(taps.tempo, closeTo(170, 1));
    now += const Duration(seconds: 2);
    taps.placeAtBar(4);
    now += const Duration(microseconds: 720000);
    taps.placeAtBar(5);
    expect(taps.tempo, closeTo(340, 1));
    expect(taps.beat, 20);
  });

  test('the screen shows the beat a little ahead of the count', () {
    final taps = follower();
    tapFour(taps);
    now += beat - TapFollower.lead + const Duration(milliseconds: 1);
    expect(taps.beat, isNot(0), reason: 'not bar 1 yet');
    expect(taps.shownBeat, 0);
  });

  test('three bars tapped near the tempo move it half way', () {
    // Counting at 340; three bars tapped a little slow, at 325, as hands
    // catching up are: half way, not all the way.
    final taps = follower();
    const bar340 = Duration(microseconds: 705882);
    for (var b = 0; b < 4; b++) {
      if (b > 0) now += bar340;
      taps.placeAtBar(b);
    }
    expect(taps.tempo, closeTo(340, 1));
    now += const Duration(seconds: 3);
    const bar325 = Duration(microseconds: 738462);
    for (var b = 9; b < 12; b++) {
      if (b > 9) now += bar325;
      taps.placeAtBar(b);
    }
    expect(taps.tempo, closeTo(332, 1.5));
  });

  test('a bar skipped still gives the tempo; a jump does not', () {
    final taps = follower();
    tapFour(taps);
    const bar = Duration(milliseconds: 1000); // 240 to the minute
    taps.placeAtBar(8);
    now += bar * 2;
    taps.placeAtBar(10);
    expect(
      taps.tempo,
      closeTo(240, 1),
      reason: 'two bars a bar of 240 apart: at half, doubled',
    );
    now += bar;
    taps.placeAtBar(11);
    expect(taps.tempo, closeTo(240, 1));
    now += bar;
    taps.placeAtBar(20);
    expect(taps.tempo, closeTo(240, 1), reason: 'bar 20 is somewhere else');
  });

  test('taps a little ahead of the beat do not lose beats', () {
    // Cherokee at 340, tapped along unevenly a little early, as hands do.
    final taps = follower();
    const beat = Duration(microseconds: 176471);
    for (var i = 0; i < 4; i++) {
      if (i > 0) now += beat;
      taps.tapBeat();
    }
    now += beat; // bar 1
    final start = now;
    for (var i = 1; i <= 24; i++) {
      // Some on it, some 25 ms ahead.
      now = start + beat * i - Duration(milliseconds: i.isOdd ? 25 : 0);
      taps.tapBeat();
    }
    now = start + beat * 24 + const Duration(milliseconds: 20);
    expect(taps.beat, 24, reason: 'bar 7, not bars behind');
  });

  test('the beat can be tapped up to 400', () {
    final taps = follower();
    for (var i = 0; i < 4; i++) {
      if (i > 0) now += const Duration(microseconds: 176471); // 340
      taps.tapBeat();
    }
    expect(taps.tempo, closeTo(340, 1));
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

    test('a barline left out does not stop it starting', () {
      final taps = follower();
      // Bars every 2 s from 0; the one at 4 s was not heard.
      for (final at in [0, 2, 6, 8, 10]) {
        now = Duration(seconds: at);
        taps.heardBarline(Duration.zero);
      }
      expect(taps.counting, isTrue);
      expect(taps.tempo, closeTo(120, 0.5));
      now = const Duration(seconds: 11);
      expect(taps.beat, 2);
      taps.stop();
    });

    test('one barline heard in the middle of a bar does not halve it', () {
      final taps = follower();
      // Bars every 2 s from 0, and one heard wrongly at 1 s: as halves
      // either side of it and two bars each after, it would count at 240.
      for (final at in [0, 1, 2, 4, 6, 8]) {
        now = Duration(seconds: at);
        taps.heardBarline(Duration.zero);
      }
      expect(taps.counting, isFalse);
      now = const Duration(seconds: 10);
      taps.heardBarline(Duration.zero);
      expect(taps.counting, isTrue);
      expect(taps.tempo, closeTo(120, 0.5));
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

    /// Beat This!'s beats, every [every], for the twelve seconds to now.
    List<Duration> beatsEvery(Duration every) => [
      for (
        var ago = Duration.zero;
        ago < const Duration(seconds: 12);
        ago += every
      )
        ago,
    ];

    test('halves itself on barlines every other bar and two beats to one', () {
      final taps = follower();
      var halved = 0;
      taps.onHalved = () => halved++;
      hear(taps, 5, every: bar ~/ 2); // half bars: counting at 240
      expect(taps.tempo, closeTo(240, 0.5));
      // Then the bars, every 2 s, on every other bar of the count's.
      hear(taps, 4, from: bar * 3);
      taps.heardBeats(beatsEvery(beat));
      expect(halved, 1);
      expect(taps.tempo, closeTo(120, 0.5));
      expect(taps.placeKnown, isFalse);
      taps.stop();
    });

    test(
      'does not halve on barlines every other bar with four beats to one',
      () {
        final taps = follower();
        hear(taps, 5, every: bar ~/ 2);
        hear(taps, 4, from: bar * 3);
        taps.heardBeats(beatsEvery(beat ~/ 2));
        expect(taps.tempo, closeTo(240, 0.5));
        taps.stop();
      },
    );

    test('does not halve on two beats to the bar with a barline on each', () {
      final taps = follower();
      hear(taps, 9, every: bar ~/ 2);
      taps.heardBeats(beatsEvery(beat));
      expect(taps.tempo, closeTo(240, 0.5));
      taps.stop();
    });

    test('says it cannot hear the bars when they stop falling on its own', () {
      final taps = follower();
      hear(taps, 5); // counting at 120, bars every 2 s
      expect(taps.losesTheBars, isFalse);
      // Then barlines a third of a bar out, none on the count's.
      hear(taps, 6, from: bar * 5 + bar ~/ 3);
      expect(taps.losesTheBars, isTrue);
      // A bar tapped: somebody knows.
      taps.placeAtBar(0);
      expect(taps.losesTheBars, isFalse);
      taps.stop();
    });

    test('the chords start the count when two in a row agree', () {
      final taps = follower();
      // A bar 3 that started 1 s ago, at 120.
      now = const Duration(seconds: 10);
      taps.heardChords(const Duration(seconds: 1), 2, 120);
      expect(taps.counting, isFalse, reason: 'one alone is not enough');
      // Three seconds on: bar 4 started 2 s ago, as the first puts it.
      now = const Duration(seconds: 13);
      taps.heardChords(const Duration(seconds: 2), 3, 121);
      expect(taps.counting, isTrue);
      expect(taps.byChords, isTrue);
      expect(taps.placeKnown, isTrue);
      expect(taps.tempo, closeTo(121, 0.5));
      expect(taps.barAt(const Duration(seconds: 12)), 3);
      taps.stop();
    });

    test('the chords are not taken when two disagree', () {
      final taps = follower();
      now = const Duration(seconds: 10);
      taps.heardChords(const Duration(seconds: 1), 2, 120);
      now = const Duration(seconds: 13);
      taps.heardChords(const Duration(seconds: 2), 6, 120);
      expect(taps.counting, isFalse);
      taps.stop();
    });

    test('the chords leave a count the barlines keep to alone', () {
      final taps = follower();
      hear(taps, 5); // counting at 120 by the barlines
      final at = now;
      taps.heardChords(Duration.zero, 6, 100);
      now = at + const Duration(milliseconds: 2400);
      taps.heardChords(Duration.zero, 7, 100);
      expect(taps.byChords, isFalse);
      expect(taps.tempo, closeTo(120, 0.5));
      taps.stop();
    });

    test('Double Time: bars half as long, from the barline it has', () {
      final taps = follower();
      hear(taps, 5); // 120, a bar every 2 s, the last at 8 s
      now += const Duration(milliseconds: 300);
      taps.doubleTime();
      expect(taps.tempo, closeTo(240, 0.5));
      expect(taps.placeKnown, isFalse);
      // From the barline at 8 s: a bar every second.
      now = const Duration(milliseconds: 8900);
      expect(taps.beat! % 4, 3);
      now = const Duration(milliseconds: 9100);
      expect(taps.beat! % 4, 0);
      taps.stop();
    });

    test('Half Time: bars twice as long, from the barline it has', () {
      final taps = follower();
      hear(taps, 5, every: bar ~/ 2); // half bars, at 240
      expect(taps.tempo, closeTo(240, 0.5));
      now += const Duration(milliseconds: 300);
      taps.halfTime();
      expect(taps.tempo, closeTo(120, 0.5));
      expect(taps.placeKnown, isFalse);
      // From the last barline, at 4 s: bar 1 until 6 s.
      now = const Duration(milliseconds: 5900);
      expect(taps.beat, 3);
      now = const Duration(milliseconds: 6100);
      expect(taps.beat, 4);
      taps.stop();
    });

    test('four barlines on another beat put bar 1 there', () {
      final taps = follower();
      var recounted = 0;
      taps.onRecounted = () => recounted++;
      tapFour(taps); // 120: bar 1 at 2 s, barlines every 2 s
      // Barlines heard on the third beat of each bar.
      hear(taps, 3, from: beat * 4 + bar + beat * 2);
      expect(recounted, 0, reason: 'three are not enough');
      hear(taps, 1, from: beat * 4 + bar * 4 + beat * 2);
      expect(recounted, 1);
      // The fourth was at 11 s: a bar starts there now.
      now = const Duration(milliseconds: 11100);
      expect(taps.beat! % 4, 0);
      taps.stop();
    });

    test('a bar tapped is not moved to another beat', () {
      final taps = follower();
      tapFour(taps);
      now = beat * 4;
      taps.placeAtBar(0); // at 2 s
      hear(taps, 6, from: beat * 4 + bar + beat * 2);
      now = beat * 4 + bar * 7 + const Duration(milliseconds: 100);
      expect(taps.beat! % 4, 0, reason: 'counted on from the tap');
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
