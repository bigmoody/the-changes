// Side by side: whether the columns can honestly be read across.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/side_by_side.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/side_by_side_screen.dart';
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

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// A comparison's tunes, moved into its key, as the screen does it.
List<Tune> _inKey(Comparison comparison) => [
  for (final title in comparison.titles)
    _standard(title)
        .transposed(semitonesInto(_standard(title), comparison.key)),
];

void main() {
  group('the sets', () {
    test('every version is a tune the app has got', () {
      final titles = {for (final tune in standards) tune.title};
      for (final comparison in comparisons) {
        for (final want in comparison.titles) {
          expect(titles, contains(want), reason: '${comparison.name}: $want');
        }
      }
    });

    test('a comparison is two or three versions, never more', () {
      for (final comparison in comparisons) {
        expect(comparison.titles.length, inInclusiveRange(2, 3));
        expect(comparison.about, isNotEmpty);
      }
    });

    test('the versions are the same length as each other', () {
      // Comparing a twelve-bar form against a thirty-two bar one row by
      // row would be nonsense dressed up as a table.
      for (final comparison in comparisons) {
        final lengths = {
          for (final title in comparison.titles) _standard(title).barCount,
        };
        expect(lengths, hasLength(1), reason: comparison.name);
      }
    });
  });

  group('why the key is the key', () {
    test('F and B♭ have an answer, because they are horn keys', () {
      for (final key in ['F', 'B♭']) {
        final note = whyThisKey(key);
        expect(note, isNotNull, reason: key);
        expect(note!.length, greaterThan(80), reason: '$key: say why');
      }
      // And it is the horns, not something about the notes: an answer
      // that did not mention the instruments would be the wrong one.
      expect(whyThisKey('F'), contains('B♭'));
      expect(whyThisKey('F'), contains('alto'));
      // And it does not open by asking the question again: the line you
      // tapped to get here already says "Why F?".
      for (final key in ['F', 'B♭']) {
        expect(whyThisKey(key), isNot(startsWith('Why')), reason: key);
      }
    });

    test('a key with nothing to say says nothing', () {
      // The contrafact set is in G and the minor one in C, and neither is
      // in that key for any reason worth a paragraph.
      expect(whyThisKey('G'), isNull);
      expect(whyThisKey('C'), isNull);
    });
  });

  group('putting them in one key', () {
    test('a tune already in the key does not move', () {
      final tune = _standard("Now's the Time");
      expect(tune.key, 'F');
      expect(semitonesInto(tune, 'F'), 0);
    });

    test('one in another key moves into it', () {
      final monk = _standard('Blue Monk');
      expect(monk.key, 'B♭');
      final moved = monk.transposed(semitonesInto(monk, 'F'));
      expect(moved.key, 'F');
    });

    test('a minor key is read off its tonic, not its word', () {
      // "C♯ minor" into C is a semitone down, not nought, and it stays
      // minor: moving a chart does not change its mode.
      final equinox = _standard('Equinox');
      expect(equinox.key, contains('minor'));
      final moved = equinox.transposed(semitonesInto(equinox, 'C'));
      expect(moved.key, 'C minor');
      expect(tonicOf(moved.key), tonicOf('C'));
    });

    test('once moved, every version is built on the same note', () {
      // The whole table rests on this: different keys make the columns a
      // lie, and a comparison nobody can read across is worse than none.
      // Tonics, not labels: a major and a minor blues on C line up fine.
      for (final comparison in comparisons) {
        final tonics = {
          for (final tune in _inKey(comparison)) tonicOf(tune.key),
        };
        expect(tonics, {tonicOf(comparison.key)}, reason: comparison.name);
      }
    });
  });

  group('lining the bars up', () {
    test('every blues agrees on bar 5, and that is the point', () {
      final tunes = _inKey(comparisons.first);
      final rows = alignBars(tunes);
      final five = rows.firstWhere((row) => row.bar == 5);
      expect(five.differs, isFalse, reason: 'the load-bearing wall');
      expect(five.cells.toSet(), hasLength(1));
      expect(five.cells.first, contains('B'), reason: 'the IV of F');
    });

    test('bebop fills the bars the plain blues leaves alone', () {
      final rows = alignBars(_inKey(comparisons.first));
      // The first column really is the plain blues: four bars of the I
      // before it moves at all.
      for (final bar in [1, 2, 3, 4]) {
        final row = rows.firstWhere((r) => r.bar == bar);
        expect(row.cells.first, 'F7', reason: 'bar $bar, plain');
      }
      // And the third has a ii–V where the first has one chord. That is
      // the difference the table exists to show.
      final two = rows.firstWhere((row) => row.bar == 2);
      expect(two.differs, isTrue);
      expect(two.cells.first.split(' '), hasLength(1));
      expect(two.cells.last.split(' ').length, greaterThan(1));
    });

    test('it is as long as the form and numbered from one', () {
      final rows = alignBars(_inKey(comparisons.first));
      expect(rows, hasLength(12));
      expect(rows.first.bar, 1);
      expect(rows.last.bar, 12);
    });

    test('some bars differ and some do not, in every set', () {
      // A table where everything differs, or nothing does, is not worth
      // the room it takes.
      for (final comparison in comparisons) {
        final rows = alignBars(_inKey(comparison));
        final differ = barsThatDiffer(rows);
        expect(differ, greaterThan(0), reason: comparison.name);
        expect(differ, lessThan(rows.length), reason: comparison.name);
      }
    });

    test('a shorter version leaves a gap rather than being cut off', () {
      final long = _standard('Oleo');
      final short = _standard("Now's the Time");
      final rows = alignBars([long, short]);
      expect(rows, hasLength(long.barCount));
      expect(rows.last.cells[1], isEmpty);
      expect(
        rows.last.differs,
        isFalse,
        reason: 'a bar one of them has not got is not a disagreement',
      );
    });

    test('nothing to compare, nothing to show', () {
      expect(alignBars(const []), isEmpty);
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
          home: SideBySideScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it draws a row per bar, headed by the versions', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Night Train'), findsOneWidget);
      expect(find.text('Blues for Alice'), findsOneWidget);
      expect(find.byKey(const ValueKey('bar-row-1')), findsOneWidget);
      expect(find.textContaining('All in F'), findsOneWidget);
      // The last bar is below the fold on a phone: it builds as it scrolls.
      final last = find.byKey(const ValueKey('bar-row-12'));
      await tester.scrollUntilVisible(last, 100);
      expect(last, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the table is on screen when it opens, not below the fold', (
      tester,
    ) async {
      // The table is the whole feature. It once grew enough explanation
      // above it that opening the screen showed no chords at all.
      await open(tester);
      for (final bar in [1, 2, 3, 4]) {
        expect(
          find.byKey(ValueKey('bar-row-$bar')),
          findsOneWidget,
          reason: 'bar $bar should be visible without scrolling',
        );
      }
      expect(find.text('F7'), findsWidgets, reason: 'chords, straight away');
    });

    testWidgets('why F is asked in one line and answered when tapped', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Why F?'), findsOneWidget);
      // Folded away to begin with, so the answer cannot push the table
      // off the bottom of a phone before anybody has asked for it.
      final note = find.byKey(const ValueKey('why-the-key-note'));
      expect(note, findsNothing);
      for (final bar in [1, 2, 3, 4]) {
        expect(find.byKey(ValueKey('bar-row-$bar')), findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('why-the-key')));
      await tester.pumpAndSettle();
      expect(note, findsOneWidget);
      expect(find.textContaining('tenor'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('why-the-key')));
      await tester.pumpAndSettle();
      expect(note, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a set in a key with no story does not ask the question', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('set-A Contrafact')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('why-the-key')), findsNothing);
    });

    testWidgets('the answer folds itself away when the set changes', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('why-the-key')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('why-the-key-note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('set-Monk and the Blues')));
      await tester.pumpAndSettle();
      // Still an F set, so the question is still there, but the table
      // comes back first.
      expect(find.text('Why F?'), findsOneWidget);
      expect(find.byKey(const ValueKey('why-the-key-note')), findsNothing);
      expect(find.byKey(const ValueKey('bar-row-4')), findsOneWidget);
    });

    testWidgets('choosing another set redraws it in that key', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('set-A Contrafact')));
      await tester.pumpAndSettle();
      expect(find.textContaining('All in G'), findsOneWidget);
      expect(find.text('Ornithology'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each version plays whole, and only one at a time', (
      tester,
    ) async {
      // A bar lifted out of three tunes and played end to end is not
      // music. Each column is played through instead, from the top.
      await open(tester);
      expect(find.byIcon(Icons.stop_circle), findsNothing);
      await tester.tap(find.byKey(const ValueKey('play-0')));
      await tester.pump();
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);

      // Starting another stops the first: two blues at once is a mess.
      await tester.tap(find.byKey(const ValueKey('play-2')));
      await tester.pump();
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);

      // And the same button again stops it.
      await tester.tap(find.byKey(const ValueKey('play-2')));
      await tester.pump();
      expect(find.byIcon(Icons.stop_circle), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the set stops whatever was playing', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('play-0')));
      await tester.pump();
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('set-A Contrafact')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.stop_circle), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bar is not a button any more', (tester) async {
      // It used to play that bar from each version in turn, which taught
      // nothing: you cannot hear a substitution without hearing it
      // resolve.
      await open(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bar-row-2')),
          matching: find.byType(InkWell),
        ),
        findsNothing,
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
      final card = find.byKey(const ValueKey('learn-side-by-side'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(SideBySideScreen), findsOneWidget);
    });
  });
}
