// Between the chords: whether the passing chords are spelled the way a
// chart would spell them, and whether they land where the screen says.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/passing_chords.dart';
import 'package:play_along/music/tritone_subs.dart' show bassMoves, isDominant;
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/passing_chords_screen.dart';
import 'package:play_along/settings/app_settings.dart';
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

PassingMove _move(String name) =>
    passingMoves.firstWhere((m) => m.name == name);

void main() {
  group('what goes in the gap', () {
    test('the filled version is the plain one with a chord added', () {
      // Not a different progression: the same chords, plus one. If the
      // rest moved, the comparison the screen offers would be a lie.
      for (final move in passingMoves) {
        expect(move.filled.length, move.plain.length + 1, reason: move.name);
        final without = [...move.filled]..removeAt(move.at);
        expect(without, move.plain, reason: move.name);
      }
    });

    test('the passing diminished lands between the I and the ii', () {
      final filled = chordsIn(_move('Passing Diminished').filled, 'C');
      expect(filled.map((c) => c.display), ['C6', 'C♯°7', 'Dm7']);
      expect(bassMoves(filled), [1, 1], reason: 'the bass walks up');
    });

    test('it is spelled sharp because it is climbing', () {
      // A chromatic chord on its way up is written sharp. D♭°7 between C
      // and Dm7 would be the same keys on a piano and the wrong reading
      // on the page.
      for (final key in ['C', 'F', 'B♭', 'E♭', 'G']) {
        final added = chordsIn(_move('Passing Diminished').filled, key)[1];
        expect(added.rootName, isNot(contains('♭')), reason: key);
      }
      expect(
        chordsIn(_move('Passing Diminished').filled, 'B♭')[1].display,
        'B°7',
      );
    });

    test('a chord arriving from above keeps its flat', () {
      // The chromatic approach slides down into the ii, so it is not
      // climbing and the sharp rule must leave it alone.
      final filled = chordsIn(_move('Chromatic Approach').filled, 'C');
      expect(filled.map((c) => c.display), ['C6', 'E♭m7', 'Dm7']);
      expect(bassMoves(filled).last, -1, reason: 'down a semitone into it');
    });

    test('the one that fills a gap is the one that says it does', () {
      // fillsTheGap is a claim about the bass, so it has to be true
      // exactly where it is shown and nowhere else.
      for (final move in passingMoves) {
        final filled = chordsIn(move.filled, 'C');
        final claimed = fillsTheGap(move, 'C');
        if (claimed) {
          expect(bassMoves(filled).take(2), [1, 1], reason: move.name);
        } else {
          expect(bassMoves(filled).take(2), isNot([1, 1]), reason: move.name);
        }
      }
    });

    test('adding the ii keeps the bass in fourths', () {
      final filled = chordsIn(_move('Adding the ii').filled, 'C');
      expect(filled.map((c) => c.display), ['Dm7', 'G7', 'CΔ7']);
      expect(bassMoves(filled), [5, 5]);
    });

    test('a secondary dominant really is a dominant', () {
      final move = _move('Secondary Dominant');
      final filled = chordsIn(move.filled, 'C');
      expect(isDominant(filled[move.at]), isTrue);
      // And it is the V of what comes after it.
      final target = filled[move.at + 1].root;
      expect((target - filled[move.at].root + 12) % 12, 5);
    });
  });

  group('the app already plays one of these', () {
    test('bar six of the jazz blues is this exact move', () {
      // The screen is not teaching a device the band does not use: the
      // library's own blues has IV7, the diminished a semitone up, then
      // the I written into it.
      final blues = standards.firstWhere((t) => t.title == 'Blue Monk');
      final written = [
        for (final bar in blues.bars)
          if (bar.length == 1) bar.single.chord.display,
      ];
      final move = chordsIn(
        _move('Coming Back From the IV').filled,
        'B♭',
      ).map((c) => c.display).toList();
      expect(move, ['E♭7', 'E°7', 'B♭7']);
      for (final chord in move) {
        expect(written, contains(chord), reason: '$chord is in the chart');
      }
    });
  });

  group('every move', () {
    test('says what it is and why it works', () {
      for (final move in passingMoves) {
        expect(move.name, isNotEmpty);
        expect(move.about.length, greaterThan(80), reason: move.name);
      }
    });

    test('works in every key offered, spelled with one letter per note', () {
      for (final move in passingMoves) {
        for (final key in ['C', 'F', 'B♭', 'E♭', 'G']) {
          final filled = chordsIn(move.filled, key);
          expect(filled, hasLength(move.filled.length));
          for (final chord in filled) {
            expect(
              chord.rootName.length,
              lessThanOrEqualTo(2),
              reason: '${move.name} in $key: ${chord.display}',
            );
          }
        }
      }
    });

    test('the added chord is never one already there', () {
      for (final move in passingMoves) {
        final filled = chordsIn(move.filled, 'C');
        final added = filled[move.at];
        final rest = [...filled]..removeAt(move.at);
        expect(
          rest.map((c) => c.display),
          isNot(contains(added.display)),
          reason: move.name,
        );
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
          home: PassingChordsScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String value, String near) async {
      final chip = find.byKey(ValueKey('pick-$value'));
      await tester.dragUntilVisible(
        chip,
        find.byKey(ValueKey('pick-$near')),
        const Offset(-140, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('both rows are on screen when it opens', (tester) async {
      // The comparison is the feature, and a comparison with half of it
      // below the fold is not one.
      await open(tester);
      final plain = find.byKey(const ValueKey('row-plain'));
      final filled = find.byKey(const ValueKey('row-filled'));
      expect(plain, findsOneWidget);
      expect(filled, findsOneWidget);
      expect(tester.getRect(filled).bottom, lessThan(852));
      // Asked the way the screen writes it: the lettering swaps the
      // degree sign for a ring the hand font actually has.
      expect(find.text(handSymbol('C♯°7')), findsOneWidget);
    });

    testWidgets('it says the bass was going past that note anyway', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('fills-the-gap')), findsOneWidget);
      expect(find.textContaining('walk over C♯ anyway'), findsOneWidget);
    });

    testWidgets('a move that is not a gap filler does not claim to be', (
      tester,
    ) async {
      await open(tester);
      await pick(tester, 'Secondary Dominant', 'Passing Diminished');
      expect(find.byKey(const ValueKey('fills-the-gap')), findsNothing);
      expect(
        find.textContaining('Any chord can be arrived at'),
        findsOneWidget,
      );
    });

    testWidgets('changing the key respells it, still sharp', (tester) async {
      await open(tester);
      // The key chips live near the bottom, so they have to be scrolled
      // to before they exist at all. Five short chips fit across, so no
      // sideways drag is needed once they are there.
      final chip = find.byKey(const ValueKey('pick-B♭'));
      await tester.scrollUntilVisible(
        chip,
        120,
        // The chip rows scroll sideways, so the page has several
        // scrollables in it and the outer one has to be named.
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('passing-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      // The diminished is only in the filled row; the I is in both,
      // which is the whole idea of showing two rows.
      expect(find.text(handSymbol('B°7')), findsOneWidget);
      expect(find.text('B♭6'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('both versions can be played', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('play-plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-filled')));
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
      final card = find.byKey(const ValueKey('learn-passing'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(PassingChordsScreen), findsOneWidget);
    });
  });
}
