// Where phrases start: counting the quavers, and what the weight does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/phrasing.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/phrasing_screen.dart';
import 'package:play_along/screens/stave_figure.dart';
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
  group('counting the quavers', () {
    test('the even ones are beats and the odd ones are the ands', () {
      expect(isUpbeat(0), isFalse, reason: 'beat 1');
      expect(isUpbeat(1), isTrue, reason: 'the & of 1');
      expect(isUpbeat(6), isFalse, reason: 'beat 4');
      expect(isUpbeat(7), isTrue, reason: 'the & of 4');
    });

    test('a pick-up from the bar before counts as an upbeat too', () {
      // −1 is the last quaver of the bar before: the & of 4.
      expect(isUpbeat(-1), isTrue);
    });

    test('most of the placements offered are off the beat', () {
      // The whole point of the screen; if they were mostly downbeats it
      // would be teaching the opposite of what it says.
      final off = placements.where((p) => isUpbeat(p.at)).length;
      expect(off, greaterThan(placements.length / 2));
    });

    test('the counting reads as you would say it out loud', () {
      expect(countName(0), '1');
      expect(countName(1), '&');
      expect(countName(2), '2');
      expect(countName(7), '&');
      // A pick-up is counted inside the bar it is actually in: the
      // quaver before the bar line is the "&" of 4, not a minus one.
      expect(countName(-1), '&');
      expect(countName(8), '1', reason: 'the next bar starts again');
    });

    test('every placement says where it is and why', () {
      for (final placement in placements) {
        expect(placement.name, isNotEmpty);
        expect(placement.about.length, greaterThan(40), reason: placement.name);
      }
    });
  });

  group('where the notes land', () {
    test('a phrase runs on from where it starts, a quaver at a time', () {
      expect(positionsOf(3, 4), [3, 4, 5, 6]);
    });

    test('a pick-up starts before the bar and runs into it', () {
      expect(positionsOf(-1, 4), [-1, 0, 1, 2]);
    });

    test('rests fill the bar in front of it, and a pick-up has none', () {
      expect(restsBefore(0), 0);
      expect(restsBefore(3), 3);
      expect(restsBefore(-1), 0, reason: 'what is in front of it is a bar');
    });

    test('the good ones go over the bar line, at either end', () {
      // Out the back: a four-quaver phrase from the & of 3 spills into
      // the next bar.
      expect(crossesTheBar(5, 4), isTrue);
      // And in at the front: a pick-up starts before the line. Saying
      // that sits "inside the bar" because it happens to finish there
      // would be the opposite of what the screen is teaching.
      expect(crossesTheBar(-1, 4), isTrue);
      // Squarely inside is squarely inside.
      expect(crossesTheBar(0, 4), isFalse);
      expect(crossesTheBar(2, 4), isFalse);
    });
  });

  group('the weight', () {
    test('on the beats pushes the even quavers', () {
      expect(
        Accent.downbeats.weightAt(0),
        greaterThan(Accent.downbeats.weightAt(1)),
      );
    });

    test('off the beats pushes the odd ones, which is the point', () {
      expect(
        Accent.upbeats.weightAt(1),
        greaterThan(Accent.upbeats.weightAt(0)),
      );
      // And the two are genuinely opposite, not merely different.
      expect(Accent.upbeats.weightAt(0), Accent.downbeats.weightAt(1));
      expect(Accent.upbeats.weightAt(1), Accent.downbeats.weightAt(0));
    });

    test('flat pushes neither', () {
      expect(Accent.even.weightAt(0), Accent.even.weightAt(1));
    });

    test('nothing is silent or clipped, whatever is chosen', () {
      for (final accent in Accent.values) {
        for (var at = 0; at < 8; at++) {
          expect(
            accent.weightAt(at),
            inExclusiveRange(0, 1),
            reason: '$accent',
          );
        }
      }
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
          home: PhrasingScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Picks from a chip strip, dragging it along if the chip is off the
    /// side: six placements with names this long never all fit.
    Future<void> pick(
      WidgetTester tester,
      String value,
      String inSameRow,
    ) async {
      final chip = find.byKey(ValueKey('pick-$value'));
      await tester.dragUntilVisible(
        chip,
        find.byKey(ValueKey('pick-$inSameRow')),
        const Offset(-140, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('it opens on the pick-up, which is the default to learn', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('already moving'), findsOneWidget);
      // A pick-up crosses the bar line going in, and the screen has to
      // say so; it is the reason this placement is the default.
      expect(find.textContaining('Over the bar line'), findsOneWidget);
    });

    testWidgets('hearing it is pinned, not left under the reading', (
      tester,
    ) async {
      await open(tester);
      final button = find.byKey(const ValueKey('play-phrase'));
      expect(button, findsOneWidget);
      expect(tester.getRect(button).bottom, lessThan(852));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('moving the start redraws it and says what changed', (
      tester,
    ) async {
      await open(tester);
      await pick(tester, 'On 1', 'The & of 4, Before');
      expect(find.textContaining('Square'), findsOneWidget);
      expect(find.text('Inside the bar.'), findsOneWidget);

      await pick(tester, 'The & of 3', 'On 1');
      expect(
        find.textContaining('Over the bar line'),
        findsOneWidget,
        reason: 'a phrase from the & of 3 spills over',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('flipping the weight moves the marks on the stave', (
      tester,
    ) async {
      // The figure is the same size whichever weight is chosen, and the
      // painter used to decide it had nothing to redraw on that basis,
      // so the marks stayed where they were and the buttons appeared to
      // do nothing at all.
      await open(tester);
      await pick(tester, 'On 1', 'The & of 4, Before');

      List<bool> markedNow() => [
        for (final column
            in tester.widget<StaveFigure>(find.byType(StaveFigure)).columns)
          column.symbols.any((s) => s.marked),
      ];

      await pick(tester, 'downbeats', 'upbeats');
      final onTheBeats = markedNow();
      await pick(tester, 'upbeats', 'downbeats');
      final offTheBeats = markedNow();

      expect(onTheBeats.any((m) => m), isTrue, reason: 'something is marked');
      expect(offTheBeats.any((m) => m), isTrue);
      expect(
        onTheBeats,
        isNot(offTheBeats),
        reason: 'and they are not the same notes',
      );

      await pick(tester, 'even', 'upbeats');
      expect(
        markedNow().any((m) => m),
        isFalse,
        reason: 'flat pushes nothing, so nothing is marked',
      );
    });

    testWidgets('the weight can be flipped and says what it is for', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('where bebop puts it'), findsOneWidget);
      await pick(tester, 'downbeats', 'upbeats');
      expect(find.textContaining('if you are counting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stave is drawn, and says what it is showing', (
      tester,
    ) async {
      // The counting under the notes is painted rather than laid out as
      // widgets, so what can be checked here is that the figure is there
      // and names itself; the counting itself is tested on its own.
      await open(tester);
      expect(find.byType(StaveFigure), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('the phrase starting', caseSensitive: false),
        ),
        findsOneWidget,
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
      final card = find.byKey(const ValueKey('learn-phrasing'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(PhrasingScreen), findsOneWidget);
    });
  });
}
