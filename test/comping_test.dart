// Comping: the figures the band plays, and whether the screen that
// teaches them is describing the same thing the band does.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/screens/comping_screen.dart';
import 'package:play_along/screens/learn_page.dart';
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
  group('the figures', () {
    test('every one lands inside the bar, or just before it', () {
      for (final figure in CompFigure.values) {
        final strikes = figure.strikes(tripletSwing);
        expect(strikes, isNotEmpty, reason: figure.name);
        for (final (at, length, weight) in strikes) {
          expect(at, greaterThanOrEqualTo(-1), reason: figure.name);
          expect(at, lessThan(4), reason: figure.name);
          expect(length, greaterThan(0), reason: figure.name);
          expect(weight, inInclusiveRange(0.1, 1), reason: figure.name);
        }
      }
    });

    test('only the push starts before its own bar', () {
      for (final figure in CompFigure.values) {
        final earliest = figure
            .strikes(tripletSwing)
            .map((s) => s.$1)
            .reduce(math.min);
        expect(
          earliest < 0,
          figure.startsEarly,
          reason: '${figure.name} starts at $earliest',
        );
      }
    });

    test('a push is early by what is left of the beat, not by the "and"', () {
      // Pushing by the "and" itself put the chord a third of a beat ahead
      // of the bass, on a triplet partial nobody plays.
      for (final and in [straight, tripletSwing, widestSwing]) {
        final (at, _, _) = CompFigure.pushed.strikes(and).single;
        expect(at, closeTo(and - 1, 1e-9), reason: 'at $and');
        // Which is to say: it lands on the last "and" of the bar before.
        expect(at + 1, closeTo(and, 1e-9));
      }
    });

    test('swinging harder moves the off-beat chords later', () {
      // The figures are written in terms of the "and", so they follow the
      // band's swing rather than sitting at a fixed two thirds.
      for (final figure in CompFigure.values) {
        final even = figure.strikes(straight).map((s) => s.$1).toList();
        final swung = figure.strikes(widestSwing).map((s) => s.$1).toList();
        for (var i = 0; i < even.length; i++) {
          expect(
            swung[i],
            greaterThanOrEqualTo(even[i]),
            reason: '${figure.name} strike $i',
          );
        }
      }
      // And at least one figure actually moves, or the claim is empty.
      expect(
        CompFigure.charleston.strikes(widestSwing).last.$1,
        greaterThan(CompFigure.charleston.strikes(straight).last.$1),
      );
    });

    test('the Charleston is what it is always said to be', () {
      // Beat 1 and the "and" of 2. If this ever stopped being true the
      // screen would be teaching the wrong thing under the right name.
      final strikes = CompFigure.charleston.strikes(tripletSwing);
      expect(strikes, hasLength(2));
      expect(strikes.first.$1, 0);
      expect(strikes.last.$1, closeTo(1 + tripletSwing, 1e-9));
    });

    test('the one nobody plays is the only one on all four beats', () {
      expect(CompFigure.everyBeat.strikes(tripletSwing).map((s) => s.$1), [
        0,
        1,
        2,
        3,
      ]);
      expect(CompFigure.everyBeat.playedByTheBand, isFalse);
      for (final figure in CompFigure.values) {
        if (figure == CompFigure.everyBeat) continue;
        expect(figure.playedByTheBand, isTrue, reason: figure.name);
        expect(
          figure.strikes(tripletSwing).length,
          lessThan(4),
          reason: '${figure.name} leaves room',
        );
      }
    });

    test('every figure says what it is and when you would want it', () {
      for (final figure in CompFigure.values) {
        expect(figure.label, isNotEmpty);
        expect(figure.about.length, greaterThan(60), reason: figure.name);
      }
    });
  });

  group('saying where it lands', () {
    test('a beat is counted from one, and an off-beat is an "and"', () {
      expect(beatName(0), '1');
      expect(beatName(2), '3');
      expect(beatName(1 + tripletSwing), 'the "and" of 2');
      expect(beatName(-0.33), 'the "and" of 4, before');
    });

    test('it reads as a sentence, however many chords there are', () {
      expect(
        whereItLands(CompFigure.charleston, tripletSwing),
        'on 1 and the "and" of 2',
      );
      expect(whereItLands(CompFigure.held, tripletSwing), 'on 1');
      expect(
        whereItLands(CompFigure.three, tripletSwing),
        'on 1, the "and" of 2 and 4',
      );
    });

    test('what it says is read off what is played', () {
      // Not a sentence written beside the figure and left to rot: the
      // count has to match the strikes for every one of them.
      for (final figure in CompFigure.values) {
        final written = whereItLands(figure, tripletSwing);
        expect(strikeCount(figure), figure.strikes(tripletSwing).length);
        for (final (at, _, _) in figure.strikes(tripletSwing)) {
          expect(written, contains(beatName(at)), reason: figure.name);
        }
      }
    });
  });

  group('the band plays these and no others', () {
    test('the figures it picks from are the ones on the screen', () {
      final offered = bandFigures(canPush: true).map((f) => f.$1).toSet();
      expect(offered, isNot(contains(CompFigure.everyBeat)));
      expect(offered, contains(CompFigure.charleston));
      expect(offered, hasLength(CompFigure.values.length - 1));
    });

    test('nothing can push at the top of a tune', () {
      // There is nothing yet for a push to be early against.
      expect(
        bandFigures(canPush: false).map((f) => f.$1),
        isNot(contains(CompFigure.pushed)),
      );
    });

    test('what the comper plays is one of them', () {
      // The real check that the screen and the band share a list: comp a
      // fresh chord many times over and every bar that comes back has to
      // be a figure the screen can draw.
      final wanted = {
        for (final figure in CompFigure.values)
          for (final and in [tripletSwing])
            figure.strikes(and).map((s) => s.$1.toStringAsFixed(4)).join(','),
      };
      var seen = 0;
      for (var seed = 0; seed < 200; seed++) {
        final comper = Comper(math.Random(seed));
        // A chord first, so the comper has started and a push is allowed.
        comper.comp(Chord.parse('C6'), 4, Feel.swing, swing: tripletSwing);
        final hits = comper.comp(
          Chord.parse('Dm7'),
          4,
          Feel.swing,
          swing: tripletSwing,
        );
        if (hits.isEmpty) continue;
        seen++;
        final shape = hits.map((hit) => hit.beat.toStringAsFixed(4)).join(',');
        expect(wanted, contains(shape), reason: 'seed $seed played $shape');
      }
      expect(seen, greaterThan(150), reason: 'it did comp, mostly');
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
          home: CompingScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, CompFigure figure) async {
      final chip = find.byKey(ValueKey('pick-${figure.name}'));
      await tester.dragUntilVisible(
        chip,
        find.byKey(ValueKey('pick-${CompFigure.offbeat.name}')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('the bar is drawn on opening, not below the fold', (
      tester,
    ) async {
      // The picture is the feature. Explanation has pushed the point of a
      // screen off the bottom of the phone before now.
      await open(tester);
      final where = find.byKey(const ValueKey('where-it-lands'));
      expect(where, findsOneWidget);
      expect(tester.getRect(where).bottom, lessThan(852));
      expect(find.textContaining('on 1 and the "and" of 2'), findsOneWidget);
    });

    testWidgets('it opens on the Charleston, which is the one to learn', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('bread-and-butter'), findsOneWidget);
      expect(find.byKey(const ValueKey('never-played')), findsNothing);
    });

    testWidgets('choosing a figure redraws it and says where it lands', (
      tester,
    ) async {
      await open(tester);
      await pick(tester, CompFigure.pushed);
      expect(
        find.textContaining('the "and" of 4, before'),
        findsOneWidget,
        reason: 'a push arrives before its bar',
      );
      expect(find.textContaining('says the change is coming'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the one the band never plays says so', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('never-played')), findsNothing);
      await pick(tester, CompFigure.everyBeat);
      expect(find.byKey(const ValueKey('never-played')), findsOneWidget);
      // And going back to a real one takes the warning away again.
      await pick(tester, CompFigure.charleston);
      expect(find.byKey(const ValueKey('never-played')), findsNothing);
    });

    testWidgets('hearing it is pinned, and quiet without a band', (
      tester,
    ) async {
      await open(tester);
      final button = find.byKey(const ValueKey('play-comping'));
      expect(button, findsOneWidget);
      expect(tester.getRect(button).bottom, lessThan(852));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
      final card = find.byKey(const ValueKey('learn-comping'));
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
      expect(find.byType(CompingScreen), findsOneWidget);
    });
  });
}
