// The A–Z strip down the side of the tune list.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/alphabet_index.dart';
import 'package:play_along/screens/my_progressions_page.dart';
import 'package:play_along/screens/tunes_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

Future<void> _openTunes(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: TunesPage(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        library: LibraryStore.inMemory(),
        progressions: ProgressionStore.inMemory(),
        takes: TakeStore.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The tune list at a given text size, on the shortest phone we support:
/// where the strip has the least room for the most letters.
Future<void> _openTunesAt(WidgetTester tester, double textScale) async {
  tester.view
    ..physicalSize = const Size(375, 667) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: TunesPage(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        library: LibraryStore.inMemory(),
        progressions: ProgressionStore.inMemory(),
        takes: TakeStore.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The strip's own copy of a letter, not the one in a tune's title.
Finder _letter(String letter) => find.descendant(
  of: find.byType(AlphabetIndex),
  matching: find.text(letter),
);

/// Puts the list in a given order from the sort menu.
Future<void> _sortBy(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('sort')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// The book in the order the page lists it, so the tests don't have to
/// hard-code which tune happens to come first under a letter.
List<Tune> get _byTitle => sortedTunes(standards, TuneOrder.title);

Tune _firstUnder(String letter) =>
    _byTitle.firstWhere((tune) => letterOf(tune.title) == letter);

void main() {
  group('which letter a tune is filed under', () {
    test('by the first letter of its title', () {
      expect(letterOf('Autumn Leaves'), 'A');
      expect(letterOf('so what'), 'S');
      expect(letterOf('  Blue Bossa'), 'B');
    });

    test('a title that starts with a number or a quote goes under #', () {
      expect(letterOf('52nd Street Theme'), otherLetters);
      expect(letterOf("'Round Midnight"), otherLetters);
      expect(letterOf(''), otherLetters);
    });

    test('only the letters the list actually uses are offered', () {
      final letters = lettersIn(['All of Me', 'Blue Bossa', 'Blue Monk']);
      expect(letters, ['A', 'B']);
    });

    test('the strip runs the way the list does, not the alphabet', () {
      // Titles that start with a number or a quote sort before A.
      expect(lettersIn(['52nd Street Theme', 'Ana Maria', 'So What']), [
        '#',
        'A',
        'S',
      ]);
      // But a tune with nobody credited sorts after everyone, so its
      // place on the strip is at the bottom.
      expect(lettersIn(['Arlen', 'Waller', '']), ['A', 'W', '#']);
    });

    test('the whole book uses most of the alphabet', () {
      final letters = lettersIn([for (final tune in standards) tune.title]);
      expect(letters.first, otherLetters, reason: '52nd Street Theme');
      expect(letters, contains('A'));
      expect(letters, contains('W'));
      expect(letters.length, greaterThan(20));
    });
  });

  group('which composer a tune is filed under', () {
    test('by surname, the way a book of tunes indexes them', () {
      expect(filedUnder('Thelonious Monk'), 'Monk');
      expect(filedUnder('George Gershwin'), 'Gershwin');
      expect(filedUnder('Antônio Carlos Jobim'), 'Jobim');
      expect(filedUnder('W. C. Handy'), 'Handy');
      expect(filedUnder('Harry "Sweets" Edison'), 'Edison');
    });

    test('a name carried by a particle keeps it', () {
      expect(filedUnder('Jimmy Van Heusen'), 'Van Heusen');
      expect(filedUnder('Gene de Paul'), 'de Paul');
    });

    test('where two are credited, the first one names the entry', () {
      expect(filedUnder('Dizzy Gillespie & Chano Pozo'), 'Gillespie');
      expect(filedUnder('Miles Davis / Eddie Vinson'), 'Davis');
    });

    test('a band has no surname, so it keeps its own name', () {
      expect(
        filedUnder('New Orleans Rhythm Kings'),
        'New Orleans Rhythm Kings',
      );
      expect(letterOf(filedUnder('New Orleans Rhythm Kings')), 'N');
      // And it's left as written rather than turned round.
      expect(indexName('New Orleans Rhythm Kings'), 'New Orleans Rhythm Kings');
      // A person whose name happens to end that way is still a person.
      expect(filedUnder('Carole King'), 'King');
    });

    test('one word stands for itself, and nobody stands for nothing', () {
      expect(filedUnder('Traditional'), 'Traditional');
      expect(filedUnder(null), '');
      expect(filedUnder('  '), '');
    });

    test('and is written surname first, as an index writes it', () {
      expect(indexName('Thelonious Monk'), 'Monk, Thelonious');
      expect(indexName('Antônio Carlos Jobim'), 'Jobim, Antônio Carlos');
      expect(indexName('Jimmy Van Heusen'), 'Van Heusen, Jimmy');
      // Two people, or one word, read better left alone.
      expect(
        indexName('Dizzy Gillespie & Chano Pozo'),
        'Dizzy Gillespie & Chano Pozo',
      );
      expect(indexName('Traditional'), 'Traditional');
      expect(indexName(null), '');
    });

    test('the band sits among the Ns in the book, not the Ks', () {
      final byComposer = sortedTunes(standards, TuneOrder.composer);
      final where = byComposer.indexWhere(
        (tune) => tune.composer == 'New Orleans Rhythm Kings',
      );
      expect(where, greaterThan(0), reason: 'the band is in the book');
      for (final tune in [byComposer[where - 1], byComposer[where + 1]]) {
        expect(letterOf(filedUnder(tune.composer)), 'N', reason: tune.composer);
      }
    });

    test('the book sorts by surname, not by first name', () {
      final sorted = sortedTunes([
        _byTitle.firstWhere((tune) => tune.composer == 'Thelonious Monk'),
        _byTitle.firstWhere((tune) => tune.composer == 'George Gershwin'),
        _byTitle.firstWhere((tune) => tune.composer == 'Miles Davis'),
      ], TuneOrder.composer);
      expect(
        [for (final tune in sorted) tune.composer],
        ['Miles Davis', 'George Gershwin', 'Thelonious Monk'],
        reason: 'Davis, Gershwin, Monk',
      );
    });
  });

  group('the strip on the tune list', () {
    testWidgets('it is there, and only offers letters in the book', (
      tester,
    ) async {
      await _openTunes(tester);
      expect(find.byType(AlphabetIndex), findsOneWidget);
      expect(_letter('A'), findsOneWidget);
      expect(_letter('#'), findsOneWidget);
      // No tune starts with X, so there's no X to jump to.
      expect(_letter('X'), findsNothing);
    });

    testWidgets('tapping a letter puts its first tune at the top', (
      tester,
    ) async {
      await _openTunes(tester);
      final wanted = _firstUnder('S');
      expect(
        find.text(wanted.title),
        findsNothing,
        reason: 'far down the list',
      );

      await tester.tap(_letter('S'));
      await tester.pumpAndSettle();
      expect(find.text(wanted.title), findsOneWidget);
      // And what was at the top has gone.
      expect(find.text(_byTitle.first.title), findsNothing);
    });

    testWidgets('it works both ways down the alphabet', (tester) async {
      await _openTunes(tester);
      await tester.tap(_letter('W'));
      await tester.pumpAndSettle();
      expect(find.text(_firstUnder('W').title), findsOneWidget);

      await tester.tap(_letter('B'));
      await tester.pumpAndSettle();
      expect(find.text(_firstUnder('B').title), findsOneWidget);
      expect(find.text(_firstUnder('W').title), findsNothing);
    });

    testWidgets('running a finger down it sweeps the list along', (
      tester,
    ) async {
      await _openTunes(tester);
      final strip = tester.getRect(find.byType(AlphabetIndex));
      // From the top of the strip down to about two thirds of the way.
      final finger = await tester.startGesture(
        Offset(strip.center.dx, strip.top + 4),
      );
      await tester.pump();
      await finger.moveTo(
        Offset(strip.center.dx, strip.top + strip.height * 0.66),
      );
      await tester.pumpAndSettle();
      // The letter under the thumb is shown while it's down.
      expect(find.byType(AlphabetIndex), findsOneWidget);
      await finger.up();
      await tester.pumpAndSettle();
      // Wherever it landed, it's well past the top of the book.
      expect(find.text(_byTitle.first.title), findsNothing);
    });

    testWidgets('the letter under the thumb is shown, and fits on screen', (
      tester,
    ) async {
      await _openTunes(tester);
      final strip = tester.getRect(find.byType(AlphabetIndex));
      final finger = await tester.startGesture(
        Offset(strip.center.dx, strip.top + strip.height * 0.5),
      );
      await tester.pumpAndSettle();

      // The letter it landed on is now drawn twice: small in the strip, and
      // large beside the thumb.
      final showing = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlphabetIndex),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      final doubled = showing.where(
        (letter) => showing.where((other) => other == letter).length == 2,
      );
      expect(doubled, isNotEmpty, reason: 'a letter is written out big');

      // And the big one is on the screen, not clipped off the side of it.
      final bubble = tester.getRect(find.text(doubled.first!).last);
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(bubble.left, greaterThanOrEqualTo(screen.left));
      expect(bubble.right, lessThanOrEqualTo(screen.right));
      expect(bubble.top, greaterThanOrEqualTo(screen.top));
      expect(bubble.bottom, lessThanOrEqualTo(screen.bottom));

      await finger.up();
      await tester.pumpAndSettle();
      final after = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlphabetIndex),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data);
      expect(
        after.toSet().length,
        after.length,
        reason: 'it goes when the thumb lifts',
      );
    });

    testWidgets('it goes away when the list is in another order', (
      tester,
    ) async {
      await _openTunes(tester);
      expect(find.byType(AlphabetIndex), findsOneWidget);
      await _sortBy(tester, 'Tempo');
      expect(
        find.byType(AlphabetIndex),
        findsNothing,
        reason: 'A to Z means nothing down a list sorted by tempo',
      );
      await _sortBy(tester, 'Title');
      expect(find.byType(AlphabetIndex), findsOneWidget);
    });

    testWidgets('a search short enough to read has no need of it', (
      tester,
    ) async {
      await _openTunes(tester);
      await tester.enterText(find.byType(TextField).first, 'monk');
      await tester.pumpAndSettle();
      expect(find.byType(AlphabetIndex), findsNothing);
    });
  });

  group('the strip on My Changes', () {
    /// Enough progressions to be worth indexing, one per letter.
    ProgressionStore shelf(int howMany) => ProgressionStore.inMemory([
      for (var i = 0; i < howMany; i++)
        UserProgression(
          id: 'p$i',
          title: '${String.fromCharCode(0x41 + i)} Tune',
          key: 'C',
          tempo: 120,
          bars: const ['Dm7', 'G7'],
          style: BandStyle.of(Feel.swing),
        ),
    ]);

    Future<void> open(WidgetTester tester, ProgressionStore store) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: MyProgressionsPage(
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
            progressions: store,
            library: LibraryStore.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a handful of your own needs no strip', (tester) async {
      await open(tester, shelf(5));
      expect(find.byType(AlphabetIndex), findsNothing);
    });

    testWidgets('a bookful gets one, and it jumps', (tester) async {
      await open(tester, shelf(20));
      expect(find.byType(AlphabetIndex), findsOneWidget);
      expect(find.text('T Tune'), findsNothing);

      await tester.tap(_letter('T'));
      await tester.pumpAndSettle();
      expect(find.text('T Tune'), findsOneWidget);
      expect(find.text('A Tune'), findsNothing);
    });

    /// Progressions credited to one writer each, surnames running A, B, C…
    ProgressionStore shelfBy(int howMany, {int uncredited = 0}) =>
        ProgressionStore.inMemory([
          for (var i = 0; i < howMany; i++)
            UserProgression(
              id: 'p$i',
              title: 'Tune $i',
              composer: 'Jo ${String.fromCharCode(0x41 + i)}ell',
              key: 'C',
              tempo: 120,
              bars: const ['Dm7', 'G7'],
              style: BandStyle.of(Feel.swing),
            ),
          for (var i = 0; i < uncredited; i++)
            UserProgression(
              id: 'mine$i',
              title: 'Something Of Mine $i',
              key: 'C',
              tempo: 120,
              bars: const ['Dm7', 'G7'],
              style: BandStyle.of(Feel.swing),
            ),
        ]);

    testWidgets('by composer it files your own under their surnames', (
      tester,
    ) async {
      await open(tester, shelfBy(20));
      await _sortBy(tester, 'Composer');
      expect(find.byType(AlphabetIndex), findsOneWidget);
      expect(find.text('Tune 19'), findsNothing, reason: 'down at the T end');

      await tester.tap(_letter('T'));
      await tester.pumpAndSettle();
      expect(find.text('Tune 19'), findsOneWidget);
      expect(find.textContaining('Tell, Jo'), findsWidgets);
    });

    testWidgets('the ones nobody wrote sit at the bottom of the strip', (
      tester,
    ) async {
      await open(tester, shelfBy(14, uncredited: 3));
      await _sortBy(tester, 'Composer');

      // Uncredited tunes sort after everyone, so # is the last letter on
      // the strip rather than the first.
      final letters = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlphabetIndex),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .toList();
      expect(letters.first, 'A');
      expect(letters.last, otherLetters);

      await tester.tap(_letter(otherLetters));
      await tester.pumpAndSettle();
      expect(find.text('Something Of Mine 0'), findsOneWidget);
    });

    testWidgets('with nobody credited at all there is nothing to index', (
      tester,
    ) async {
      await open(tester, shelf(20));
      await _sortBy(tester, 'Composer');
      expect(
        find.byType(AlphabetIndex),
        findsNothing,
        reason: 'a strip of one letter is no use',
      );
    });

    testWidgets('choosing several to delete puts it away', (tester) async {
      await open(tester, shelf(20));
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.byType(AlphabetIndex), findsNothing);
    });
  });

  group('the strip by composer', () {
    testWidgets('it stays, and files everyone under their surname', (
      tester,
    ) async {
      await _openTunes(tester);
      await _sortBy(tester, 'Composer');
      expect(find.byType(AlphabetIndex), findsOneWidget);

      final byComposer = sortedTunes(standards, TuneOrder.composer);
      final firstUnderM = byComposer.firstWhere(
        (tune) => letterOf(filedUnder(tune.composer)) == 'M',
      );
      expect(filedUnder(firstUnderM.composer), startsWith('M'));

      await tester.tap(_letter('M'));
      await tester.pumpAndSettle();
      expect(find.text(firstUnderM.title), findsOneWidget);
    });

    testWidgets('Monk is under M, not under Thelonious', (tester) async {
      await _openTunes(tester);
      await _sortBy(tester, 'Composer');
      await tester.tap(_letter('M'));
      await tester.pumpAndSettle();
      // Somewhere in view is a tune of Monk's, credited surname first so
      // the list plainly reads in the order it's sorted in.
      final monk = sortedTunes(standards, TuneOrder.composer)
          .where((tune) => tune.composer == 'Thelonious Monk')
          .map((tune) => tune.title);
      expect(
        monk.any((title) => find.text(title).evaluate().isNotEmpty),
        isTrue,
      );
      expect(find.textContaining('Monk, Thelonious'), findsWidgets);
    });
  });

  group('however large the text is', () {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('the strip still fits beside the list at x$scale', (
        tester,
      ) async {
        await _openTunesAt(tester, scale);
        expect(tester.takeException(), isNull, reason: 'nothing overflows');
        final strip = tester.getRect(find.byType(AlphabetIndex));
        // Every letter is inside the strip rather than spilling past its
        // bottom, which is what the overflow stripes were saying.
        for (final letter in ['A', 'B', 'W']) {
          final found = _letter(letter);
          if (found.evaluate().isEmpty) continue;
          final box = tester.getRect(found);
          expect(
            box.bottom,
            lessThanOrEqualTo(strip.bottom + 0.5),
            reason: '$letter at x$scale',
          );
          expect(box.top, greaterThanOrEqualTo(strip.top - 0.5));
        }
      });
    }
  });
}
