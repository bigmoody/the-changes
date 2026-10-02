// Where am I? The question the exercise asks, and whether it can be
// answered honestly.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/where_am_i.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/where_am_i_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  PlaybackPosition? at;

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> restoreAudioSession() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}

  @override
  PlaybackPosition? position() => at;
}

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// The six the screen offers.
const _offered = [
  'Take the "A" Train',
  'Autumn Leaves',
  'All of Me',
  'Blue Bossa',
  "Now's the Time",
  'Cherokee',
];

void main() {
  group('choosing where to stop', () {
    test('it is always inside the tune, and never on a downbeat', () {
      final tune = _standard('Autumn Leaves');
      for (var seed = 0; seed < 200; seed++) {
        final stop = chooseStop(tune, math.Random(seed));
        expect(stop.bar, inInclusiveRange(0, tune.barCount - 1));
        expect(stop.chorus, inInclusiveRange(0, mostChoruses - 1));
        // Plainly inside a bar: "going into bar 9" and "in bar 9" would
        // otherwise be two right answers to the same sound.
        expect(stop.beatInBar, greaterThan(0));
        expect(stop.beatInBar, lessThan(tune.beatsPerBar));
      }
    });

    test('it plays long enough to be a question', () {
      final tune = _standard('Blue Bossa');
      for (var seed = 0; seed < 200; seed++) {
        final stop = chooseStop(tune, math.Random(seed));
        final bars = stop.chorus * tune.barCount + stop.bar;
        expect(bars, greaterThanOrEqualTo(leastBars), reason: 'seed $seed');
      }
    });

    test('it never asks for more listening than anyone will do', () {
      // Three choruses of a thirty-two bar tune is the best part of three
      // minutes for one question.
      for (final title in _offered) {
        final tune = _standard(title);
        for (var seed = 0; seed < 100; seed++) {
          final stop = chooseStop(tune, math.Random(seed));
          final bars = stop.chorus * tune.barCount + stop.bar;
          expect(bars, lessThan(mostBars), reason: '$title, seed $seed');
        }
      }
    });

    test('it does ask about later choruses, not just the first', () {
      final tune = _standard('Blue Bossa');
      final choruses = {
        for (var seed = 0; seed < 200; seed++)
          chooseStop(tune, math.Random(seed)).chorus,
      };
      expect(choruses.length, greaterThan(1), reason: 'it goes round');
    });
  });

  group('marking an answer', () {
    test('the right bar is the right bar', () {
      expect(markAnswer(8, 8, 32), Marking.spotOn);
      expect(Marking.spotOn.isRight, isTrue);
    });

    test('a bar out is its own answer, and is not right', () {
      expect(markAnswer(9, 8, 32), Marking.nearly);
      expect(Marking.nearly.isRight, isFalse);
    });

    test('anything else is lost', () {
      expect(markAnswer(20, 8, 32), Marking.lost);
    });

    test('the form is round: bar 32 is a bar from bar 1', () {
      // Answering the last bar when it was the first is one bar out, not
      // thirty-one; it is the same mistake as answering bar 2.
      expect(barsOut(31, 0, 32), 1);
      expect(markAnswer(31, 0, 32), Marking.nearly);
      expect(barsOut(1, 0, 32), 1);
      expect(barsOut(16, 0, 32), 16, reason: 'as far as it gets');
    });
  });

  group('knowing when to cut out', () {
    final tune = _standard('Autumn Leaves');

    test('not while it is still counting in', () {
      const stop = (chorus: 0, bar: 4, beatInBar: 2);
      expect(reached(stop, tune, chorus: null, beat: null), isFalse);
    });

    test('not before the bar, and yes once inside it', () {
      const stop = (chorus: 0, bar: 4, beatInBar: 2);
      final downbeat = 4 * tune.beatsPerBar;
      expect(reached(stop, tune, chorus: 0, beat: downbeat), isFalse);
      expect(reached(stop, tune, chorus: 0, beat: downbeat + 1), isFalse);
      expect(reached(stop, tune, chorus: 0, beat: downbeat + 2), isTrue);
    });

    test('a later chorus is past it however early the bar', () {
      const stop = (chorus: 1, bar: 20, beatInBar: 2);
      expect(reached(stop, tune, chorus: 0, beat: 999), isFalse);
      expect(reached(stop, tune, chorus: 2, beat: 0), isTrue);
    });
  });

  group('the tally', () {
    test('it says nothing until something has been asked', () {
      expect(describeTally((asked: 0, right: 0)), '');
      expect(describeTally((asked: 3, right: 2)), '2 of 3');
    });
  });

  group('the screen', () {
    Future<_FakePlayer> open(WidgetTester tester, {int seed = 1}) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final player = _FakePlayer();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: WhereAmIScreen(
            player: player,
            settings: AppSettings.inMemory(),
            random: math.Random(seed),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return player;
    }

    testWidgets('every tune it offers is one the app has got', (tester) async {
      // firstWhere would throw on a title that is a typo, so this is the
      // guard: pick each one in turn and nothing blows up.
      await open(tester);
      for (final title in _offered) {
        expect(
          standards.where((tune) => tune.title == title),
          hasLength(1),
          reason: title,
        );
        await tester.tap(find.byKey(ValueKey('tune-$title')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: title);
      }
    });

    testWidgets('nothing to read while it plays', (tester) async {
      final player = await open(tester);
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pump();
      expect(find.byKey(const ValueKey('listening')), findsOneWidget);
      // No grid to count off, and no chord to read.
      expect(find.byKey(const ValueKey('bar-1')), findsNothing);
      expect(find.textContaining('Which bar'), findsNothing);
      expect(player.at, isNull);
    });

    testWidgets('it cuts out where the question says, and asks', (
      tester,
    ) async {
      const seed = 7;
      final tune = _standard('Take the "A" Train');
      final stop = chooseStop(tune, math.Random(seed));
      final player = await open(tester, seed: seed);

      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pump();
      // Just short of it: still listening.
      player.at = PlaybackPosition(
        tuneBeat: stop.bar * tune.beatsPerBar,
        chorus: stop.chorus,
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('listening')), findsOneWidget);

      // And now inside the bar.
      player.at = PlaybackPosition(
        tuneBeat: stop.bar * tune.beatsPerBar + stop.beatInBar,
        chorus: stop.chorus,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('Which bar did it stop in?'), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-1')), findsOneWidget);
    });

    testWidgets('a right answer is marked right and counted', (tester) async {
      const seed = 7;
      final tune = _standard('Take the "A" Train');
      final stop = chooseStop(tune, math.Random(seed));
      final player = await open(tester, seed: seed);
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pump();
      player.at = PlaybackPosition(
        tuneBeat: stop.bar * tune.beatsPerBar + stop.beatInBar,
        chorus: stop.chorus,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      final answer = find.byKey(ValueKey('bar-${stop.bar + 1}'));
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      await tester.tap(answer);
      await tester.pumpAndSettle();
      expect(find.textContaining('Spot on'), findsOneWidget);
      expect(find.textContaining('bar ${stop.bar + 1}'), findsWidgets);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrong answer says how far out, and is not counted', (
      tester,
    ) async {
      const seed = 7;
      final tune = _standard('Take the "A" Train');
      final stop = chooseStop(tune, math.Random(seed));
      final player = await open(tester, seed: seed);
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pump();
      player.at = PlaybackPosition(
        tuneBeat: stop.bar * tune.beatsPerBar + stop.beatInBar,
        chorus: stop.chorus,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      // Four bars away, whichever bar it was.
      final wrong = (stop.bar + 4) % tune.barCount;
      final answer = find.byKey(ValueKey('bar-${wrong + 1}'));
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      await tester.tap(answer);
      await tester.pumpAndSettle();
      expect(find.textContaining('Lost'), findsOneWidget);
      expect(find.textContaining('4 bars out'), findsOneWidget);
      expect(find.text('0 of 1'), findsOneWidget);
    });

    testWidgets('right and wrong are said, not only coloured', (tester) async {
      // The two marked boxes sit side by side in near-enough the same
      // shade, so what each one means has to be readable as well.
      const seed = 7;
      final tune = _standard('Take the "A" Train');
      final stop = chooseStop(tune, math.Random(seed));
      final player = await open(tester, seed: seed);
      await tester.tap(find.byKey(const ValueKey('ask')));
      await tester.pump();
      player.at = PlaybackPosition(
        tuneBeat: stop.bar * tune.beatsPerBar + stop.beatInBar,
        chorus: stop.chorus,
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      final wrong = (stop.bar + 4) % tune.barCount;
      final answer = find.byKey(ValueKey('bar-${wrong + 1}'));
      await tester.ensureVisible(answer);
      await tester.pumpAndSettle();
      await tester.tap(answer);
      await tester.pumpAndSettle();

      String? spoken(int bar) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('bar-${bar + 1}')),
              matching: find.byType(Text),
            ),
          )
          .semanticsLabel;

      expect(spoken(stop.bar), 'Bar ${stop.bar + 1}, where it stopped');
      expect(spoken(wrong), 'Bar ${wrong + 1}, what you said');
      // And a box that is neither says only what it is.
      final plain = (stop.bar + 2) % tune.barCount;
      expect(spoken(plain), 'Bar ${plain + 1}');
    });

    testWidgets('it opens from Learn', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LearnPage(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('learn-where-am-i'));
      await tester.scrollUntilVisible(
        card,
        100,
        // The page's own list, not the search box's text field,
        // which is a scrollable too.
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(WhereAmIScreen), findsOneWidget);
    });
  });
}
