// Trading: whose bar is whose, and whether anybody fills the ones that
// are not yours.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/trading_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
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
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  group('whose bar it is', () {
    test('the first four are yours, the next four are not', () {
      const a = Arrangement(trading: Trading.fours);
      for (var bar = 0; bar < 4; bar++) {
        expect(a.yours(0, bar), isTrue, reason: 'bar $bar');
      }
      for (var bar = 4; bar < 8; bar++) {
        expect(a.yours(0, bar), isFalse, reason: 'bar $bar');
      }
      expect(a.yours(0, 8), isTrue, reason: 'and back to you');
    });

    test('every bar is yours when nobody is trading', () {
      const a = Arrangement();
      for (var bar = 0; bar < 12; bar++) {
        expect(a.yours(0, bar), isTrue);
        expect(a.traded(0, bar), isFalse);
      }
    });

    test('twos and eights swap at their own length', () {
      expect(const Arrangement(trading: Trading.twos).yours(0, 2), isFalse);
      expect(const Arrangement(trading: Trading.eights).yours(0, 2), isTrue);
      expect(const Arrangement(trading: Trading.eights).yours(0, 8), isFalse);
    });

    test('the head is played straight through by everybody', () {
      const a = Arrangement(
        choruses: 3,
        headInAndOut: true,
        trading: Trading.fours,
      );
      for (var bar = 0; bar < 12; bar++) {
        expect(a.yours(0, bar), isTrue, reason: 'first head, bar $bar');
        expect(a.yours(2, bar), isTrue, reason: 'last head, bar $bar');
      }
      expect(a.yours(1, 4), isFalse, reason: 'but the solo chorus trades');
    });
  });

  group('who answers', () {
    test('the band is out on the traded bars either way', () {
      // That is what makes it your four: nothing to hide behind.
      for (final who in TradeWith.values) {
        final a = Arrangement(trading: Trading.fours, tradeWith: who);
        for (final part in LayOut.values) {
          expect(a.plays(part, 0, 4), isFalse, reason: '$who, $part');
          expect(a.plays(part, 0, 0), isTrue, reason: '$who, $part, yours');
        }
      }
    });

    test('the drummer takes them only when the drummer is answering', () {
      const drums = Arrangement(trading: Trading.fours);
      const time = Arrangement(
        trading: Trading.fours,
        tradeWith: TradeWith.time,
      );
      expect(drums.drummerHas(0, 4), isTrue);
      expect(time.drummerHas(0, 4), isFalse, reason: 'nobody fills it');
      // Both agree the bar is not yours.
      expect(drums.traded(0, 4), isTrue);
      expect(time.traded(0, 4), isTrue);
    });

    test('a solo bar and a time bar are not the same bar', () {
      // The audible difference: one is a drum solo, the other is the
      // ordinary groove carrying on with nobody over it.
      final solo = drumSoloBar(
        feel: Feel.swing,
        bar: 0,
        of: 4,
        beatsPerBar: 4,
        random: math.Random(1),
        swing: tripletSwing,
      );
      final time = drumBar(
        feel: Feel.swing,
        bar: 0,
        beatsPerBar: 4,
        random: math.Random(1),
        swing: tripletSwing,
      );
      expect([
        for (final h in solo) h.beat,
      ], isNot([for (final h in time) h.beat]));
      // And the time one keeps a ride on every beat, which is what you
      // would be counting against.
      final ride = [
        for (final hit in time)
          if (hit.drum == Drum.ride && hit.beat == hit.beat.roundToDouble())
            hit.beat,
      ];
      expect(ride, [0.0, 1.0, 2.0, 3.0]);
    });

    test('it says which it is, and the arrangement carries it', () {
      const a = Arrangement(trading: Trading.fours);
      expect(a.describe(), contains('trading fours'));
      expect(a.describe(), isNot(contains('against the time')));
      expect(
        a.copyWith(tradeWith: TradeWith.time).describe(),
        contains('against the time'),
      );
    });

    test('two arrangements differing only in who answers are not equal', () {
      const drums = Arrangement(trading: Trading.fours);
      final time = drums.copyWith(tradeWith: TradeWith.time);
      expect(drums == time, isFalse);
      expect(drums.hashCode == time.hashCode, isFalse);
      expect(drums.copyWith(tradeWith: TradeWith.drums), drums);
    });

    test('it defaults to the drummer, as it always did', () {
      expect(const Arrangement().tradeWith, TradeWith.drums);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: TradingScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the cue is the biggest thing on it, and on screen', (
      tester,
    ) async {
      // The whole reason for a screen rather than an arrangement
      // setting: you cannot look away to find out whose four it is.
      await open(tester);
      final cue = find.byKey(const ValueKey('whose-four'));
      expect(cue, findsOneWidget);
      expect(tester.getRect(cue).bottom, lessThan(852));
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('it opens on fours, with the drummer answering', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('What a band does'), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-fours')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-off')), findsNothing);
    });

    testWidgets('choosing nobody says what that costs you', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pick-time')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nobody fills the four'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('starting and stopping it changes the button', (tester) async {
      await open(tester);
      expect(find.text('Start Trading'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('play-trading')));
      await tester.pumpAndSettle();
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('play-trading')));
      await tester.pumpAndSettle();
      expect(find.text('Start Trading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the length stops whatever was going', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('play-trading')));
      await tester.pumpAndSettle();
      expect(find.text('Stop'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-twos')));
      await tester.pumpAndSettle();
      expect(find.text('Start Trading'), findsOneWidget);
    });

    testWidgets('the tempo can be moved, and says what it is', (tester) async {
      // Trading at 200 is a different exercise from trading at 100, so
      // walking it up is the point rather than a convenience.
      await open(tester);
      expect(find.byKey(const ValueKey('trading-tempo')), findsOneWidget);
      final shown = tester
          .widget<Text>(find.byKey(const ValueKey('trading-tempo')))
          .data!;
      await tester.tap(find.byKey(const ValueKey('trading-faster')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trading-tempo'))).data,
        '${int.parse(shown) + 1}',
      );
      await tester.tap(find.byKey(const ValueKey('trading-slower')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trading-tempo'))).data,
        shown,
      );
    });

    testWidgets('dragging the tempo does not stop it', (tester) async {
      // The band is picked up again at the new tempo rather than left
      // stopped, because you are in the middle of practising.
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('play-trading')));
      await tester.pumpAndSettle();
      expect(find.text('Stop'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('trading-tempo-slider')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stop'), findsOneWidget, reason: 'still going');
      expect(tester.takeException(), isNull);
    });

    testWidgets('it does not run past the ends of the dial', (tester) async {
      await open(tester);
      await tester.drag(
        find.byKey(const ValueKey('trading-tempo-slider')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(
        int.parse(
          tester
              .widget<Text>(find.byKey(const ValueKey('trading-tempo')))
              .data!,
        ),
        40,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('trading-slower')))
            .onPressed,
        isNull,
        reason: 'nothing slower to go to',
      );
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
      final card = find.byKey(const ValueKey('learn-trading'));
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
      expect(find.byType(TradingScreen), findsOneWidget);
    });
  });
}
