// The exercises screen: levels, kept per tune.
//
// The thing worth guarding is that a tune nobody wrote into the app works
// the same as one out of the book, because that is the whole point of
// generating the exercises rather than writing them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chart_exercises.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/chart_exercises_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// A tune that is not in the library: somebody's own, written or imported.
Tune theirs() => Tune.fromChart(
  title: 'A Tune Of My Own',
  key: 'F',
  defaultTempo: 120,
  chart: '| [A] Fm7 | B♭7 | E♭Δ7 | A♭Δ7 |',
);

/// Taps a level's chip, scrolling the row sideways to reach it first: the
/// five of them do not fit across a phone, and a tap at an off-screen
/// position does nothing and says nothing, which is how the first version
/// of this file passed a test by not pressing the button.
Future<void> pick(WidgetTester tester, ChartExercise which) async {
  final chip = find.byKey(ValueKey('exercise-${which.name}'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<AppSettings> open(WidgetTester tester, Tune tune) async {
  final settings = AppSettings.inMemory();
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: ChartExercisesScreen(
        tune: tune,
        player: _FakePlayer(),
        settings: settings,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  group('it opens on the first level', () {
    testWidgets('for a tune out of the book', (tester) async {
      await open(tester, standards.firstWhere((t) => t.title == 'Blue Bossa'));
      expect(find.text('1. Arpeggios'), findsOneWidget);
      expect(find.textContaining('The chord tones in order'), findsOneWidget);
    });

    testWidgets('and for a tune somebody wrote themselves', (tester) async {
      // Nothing about the generator knows a tune's name, so this is the
      // same screen doing the same thing.
      await open(tester, theirs());
      expect(find.text('A Tune Of My Own'), findsOneWidget);
      expect(find.text('1. Arpeggios'), findsOneWidget);
    });

    testWidgets('all five are offered', (tester) async {
      await open(tester, theirs());
      for (final which in ChartExercise.values) {
        expect(
          find.byKey(ValueKey('exercise-${which.name}')),
          findsOneWidget,
          reason: which.label,
        );
      }
    });
  });

  group('the level is kept per tune', () {
    testWidgets('choosing one remembers it against that tune', (tester) async {
      final settings = await open(tester, theirs());
      await pick(tester, ChartExercise.bebop);
      expect(settings.exerciseFor('A Tune Of My Own'), ChartExercise.bebop);
    });

    testWidgets('and leaves every other tune where it was', (tester) async {
      // Per tune and not per app: what you can do on a blues you cannot
      // necessarily do on Stella.
      final settings = await open(tester, theirs());
      await pick(tester, ChartExercise.enclosure);
      // The one that was chosen moved, so the check below means something.
      expect(settings.exerciseFor('A Tune Of My Own'), ChartExercise.enclosure);
      expect(
        settings.exerciseFor('Blue Bossa'),
        ChartExercise.arpeggio,
        reason: 'another tune moved too',
      );
    });

    testWidgets('a tune nobody has started opens on the first', (tester) async {
      final settings = AppSettings.inMemory();
      expect(settings.exerciseFor('Never Opened'), ChartExercise.arpeggio);
    });
  });

  group('what is on the page', () {
    testWidgets('the exercise is written out, bar by bar', (tester) async {
      await open(tester, theirs());
      expect(find.byKey(const ValueKey('exercise-bar-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('exercise-bar-1')), findsOneWidget);
    });

    testWidgets('with the chord over the note it lands on', (tester) async {
      await open(tester, theirs());
      expect(find.text('Fm7'), findsWidgets);
    });

    testWidgets('and changing level rewrites the page', (tester) async {
      await open(tester, theirs());
      final before = find.byKey(const ValueKey('exercise-written-arpeggio'));
      expect(before, findsOneWidget);
      await pick(tester, ChartExercise.guideTones);
      expect(before, findsNothing);
      expect(
        find.byKey(const ValueKey('exercise-written-guideTones')),
        findsOneWidget,
      );
    });

    testWidgets('there is something to play it with', (tester) async {
      await open(tester, theirs());
      expect(find.byKey(const ValueKey('hear-exercise')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop-exercise')), findsOneWidget);
    });
  });
}
