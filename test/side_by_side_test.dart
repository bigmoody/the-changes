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
  /// What the band was last asked to play, so a test can tell what is on
  /// the page from what comes out of the speaker.
  BackingRequest? asked;

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {
    asked = request;
  }

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

    testWidgets('a transposing player reads their own key', (tester) async {
      // Every other key control in the app names the key you read, and
      // the point of this table is to be read. A B♭ player opening the
      // blues set, which is meant to be heard in F, reads it in G.
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final settings = AppSettings.inMemory(ChartInstrument.bFlat);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: SideBySideScreen(player: _FakePlayer(), settings: settings),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('summary'))).data,
        startsWith('All in G'),
      );
      expect(find.textContaining('G7'), findsWidgets);
      // And the note about the key still belongs: this is where the set
      // was meant to be read, in the only key this player has.
      expect(find.textContaining('Why F'), findsOneWidget);
    });

    testWidgets('and it says whose key that is', (tester) async {
      // The table did move for a transposing player and nothing on it
      // said so, which reads as a transposition that was never applied
      // rather than one that was.
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: SideBySideScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(ChartInstrument.eFlat),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final said = tester
          .widget<Text>(find.byKey(const ValueKey('as-you-read-it')))
          .data!;
      expect(said, contains('E♭ instrument'));
      expect(said, contains('F'), reason: 'what the band plays');
    });

    testWidgets('and says nothing of the sort to a concert player', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('as-you-read-it')), findsNothing);
    });

    testWidgets('and the band plays what that sounds, not what it says', (
      tester,
    ) async {
      // The one mistake a transposing instrument makes everybody make at
      // least once: handing the band the page and hearing it a tone high.
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final player = _FakePlayer();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: SideBySideScreen(
            player: player,
            settings: AppSettings.inMemory(ChartInstrument.bFlat),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      expect(player.asked, isNotNull);
      expect(
        tonicOf(player.asked!.tune.key),
        tonicOf('F'),
        reason: 'read in G, sounds in F',
      );
    });

    testWidgets('the table moves into whatever key you ask for', (
      tester,
    ) async {
      // The reason to read three blues against each other is usually
      // that you are about to play one, and the key it reads best in is
      // not always the key you are about to play it in.
      await open(tester);
      expect(
        find.text(
          'All in F · 6 of 12 bars differ · play one to hear it '
          'through',
        ),
        findsNothing,
        reason:
            'the summary is one line, checked '
            'by its key below',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('summary'))).data,
        startsWith('All in F'),
      );

      await tester.tap(find.byKey(const ValueKey('key-B♭')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('summary'))).data,
        startsWith('All in B♭'),
      );
      // And the chords moved with it: a blues in B♭ starts on a B♭.
      expect(find.textContaining('B♭7'), findsWidgets);
    });

    testWidgets('the note about the key goes when the key does', (
      tester,
    ) async {
      // It says why this comparison reads best in F. Over a table
      // somebody has moved to B♭ it would be answering a question that
      // is no longer being asked.
      await open(tester);
      expect(find.textContaining('Why F'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('key-B♭')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Why F'), findsNothing);
    });

    testWidgets('changing the set goes back to the key it reads best in', (
      tester,
    ) async {
      // Keeping the last key would carry a choice made about one set of
      // tunes onto another it was never made about.
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('key-B♭')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('set-${comparisons[1].name}')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('summary'))).data,
        startsWith('All in ${comparisons[1].key}'),
      );
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
      expect(find.byType(SideBySideScreen), findsOneWidget);
    });
  });
}
