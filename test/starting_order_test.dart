// Where to start: the path through the book, and the way in to it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/library/starting_order.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/setlists_screen.dart' show LibraryContext;
import 'package:play_along/screens/starting_order_screen.dart';
import 'package:play_along/screens/tunes_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  group('the path', () {
    test('every tune on it is one the app has actually got', () {
      // Written by hand against a book that changes, so this is the guard:
      // a typo or a tune that got renamed would otherwise be a card that
      // silently isn't there.
      final titles = {for (final tune in standards) tune.title};
      for (final want in pathTitles) {
        expect(titles, contains(want), reason: want);
      }
    });

    test('nothing is on it twice', () {
      expect(pathTitles.toSet(), hasLength(pathTitles.length));
    });

    test('every stage says what it is for, and has tunes in it', () {
      expect(startingOrder, isNotEmpty);
      for (final stage in startingOrder) {
        expect(stage.name, isNotEmpty);
        expect(stage.about, isNotEmpty);
        expect(stage.tunes, isNotEmpty, reason: stage.name);
        for (final step in stage.tunes) {
          expect(step.why, isNotEmpty, reason: step.title);
          // A reason, not a label: if it doesn't say anything it is
          // taking up room a beginner has to read past.
          expect(step.why.length, greaterThan(40), reason: step.title);
        }
      }
    });

    test('it gets harder: the forms grow and the keys start moving', () {
      // A rough shape check rather than a claim about music: the tunes in
      // the first stage have fewer changes per bar than those in the last.
      double changesPerBar(String title) {
        final tune = standards.firstWhere((t) => t.title == title);
        final chords = {for (final slot in tune.slots) slot.chord.display};
        return chords.length / tune.barCount;
      }

      double stageAverage(Stage stage) {
        final all = [for (final s in stage.tunes) changesPerBar(s.title)];
        return all.reduce((a, b) => a + b) / all.length;
      }

      expect(
        stageAverage(startingOrder.first),
        lessThan(stageAverage(startingOrder.last)),
        reason: 'the last stage has more going on than the first',
      );
    });
  });

  group('the screen', () {
    LibraryContext deps(LibraryStore library) => LibraryContext(
      player: _FakePlayer(),
      settings: AppSettings.inMemory(),
      library: library,
      progressions: ProgressionStore.inMemory(),
    );

    Future<void> open(WidgetTester tester, LibraryStore library) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: StartingOrderScreen(deps: deps(library)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it lists the stages and the tunes under them', (tester) async {
      await open(tester, LibraryStore.inMemory());
      expect(find.text('1. Start Here'), findsOneWidget);
      final seen = <String>{};
      for (var i = 0; i < 40; i++) {
        for (final title in pathTitles) {
          if (find.byKey(ValueKey('start-$title')).evaluate().isNotEmpty) {
            seen.add(title);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump();
      }
      expect(seen, {...pathTitles}, reason: 'all of them, as it scrolls');
    });

    testWidgets('a tune you have worked on says so, and how fast', (
      tester,
    ) async {
      final library = LibraryStore.inMemory(
        runs: {
          TuneRef.standard('So What'): [
            (at: DateTime.now(), tempo: 132, asked: 12, hits: 12),
          ],
          TuneRef.standard('Blue Bossa'): [
            (at: DateTime.now(), tempo: 120, asked: 0, hits: 0),
          ],
        },
      );
      await open(tester, library);
      // Marked for playing it, not for opening it. A marked run that was
      // clean says how fast; one nobody was listening to just says so.
      expect(find.text('Clean at 132'), findsOneWidget);
      final bossa = find.byKey(const ValueKey('start-Blue Bossa'));
      await tester.scrollUntilVisible(bossa, 100);
      await tester.ensureVisible(bossa);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('done-Blue Bossa')), findsOneWidget);
      expect(find.text('Played'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('done-Summertime')),
        findsNothing,
        reason: 'never touched',
      );
    });

    testWidgets('tapping a tune opens it', (tester) async {
      await open(tester, LibraryStore.inMemory());
      await tester.tap(find.byKey(const ValueKey('start-So What')));
      await tester.pumpAndSettle();
      expect(find.byType(StartingOrderScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the way in', () {
    Future<void> openTunes(WidgetTester tester, LibraryStore library) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: TunesPage(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
            library: library,
            progressions: ProgressionStore.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a library nobody has played offers the path outright', (
      tester,
    ) async {
      await openTunes(tester, LibraryStore.inMemory());
      expect(find.byKey(const ValueKey('start-here-card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-here-card')));
      await tester.pumpAndSettle();
      expect(find.byType(StartingOrderScreen), findsOneWidget);
    });

    testWidgets('once something has been played the card goes', (tester) async {
      final library = LibraryStore.inMemory(
        played: [(tune: TuneRef.standard('So What'), at: DateTime.now())],
      );
      await openTunes(tester, library);
      expect(find.byKey(const ValueKey('start-here-card')), findsNothing);
      // But the signpost in the bar stays, so it can be found again.
      expect(find.byKey(const ValueKey('where-to-start')), findsOneWidget);
    });

    testWidgets('the signpost opens it whatever the library looks like', (
      tester,
    ) async {
      await openTunes(tester, LibraryStore.inMemory());
      await tester.tap(find.byKey(const ValueKey('where-to-start')));
      await tester.pumpAndSettle();
      expect(find.byType(StartingOrderScreen), findsOneWidget);
      expect(find.text('Where To Start'), findsWidgets);
    });
  });
}
