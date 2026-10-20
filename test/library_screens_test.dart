// Starring, sorting, recently played and setlists, on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/screens/setlists_screen.dart';
import 'package:play_along/screens/tunes_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

final _list = find.byKey(const ValueKey('tune-list'));

Finder get _listScrollable =>
    find.descendant(of: _list, matching: find.byType(Scrollable));

Future<void> _scrollTo(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(target, 200, scrollable: _listScrollable);

/// The Tunes tab on its own, with whatever library is passed in.
Future<void> _openTunes(
  WidgetTester tester, {
  required LibraryStore library,
  ProgressionStore? progressions,
}) async {
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
        library: library,
        progressions: progressions ?? ProgressionStore.inMemory(),
        takes: TakeStore.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSetlists(
  WidgetTester tester, {
  required LibraryStore library,
  ProgressionStore? progressions,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: SetlistsScreen(
        deps: LibraryContext(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
          library: library,
          progressions: progressions ?? ProgressionStore.inMemory(),
          takes: TakeStore.inMemory(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Puts the list in a given order from the sort menu.
Future<void> _sortBy(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('sort')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// The titles on screen, top to bottom, ignoring everything else.
List<String> _titlesIn(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
    if (tile.title case final Text text) ?text.data,
];

void main() {
  group('starring', () {
    testWidgets('the star marks a tune and keeps it', (tester) async {
      final library = LibraryStore.inMemory();
      await _openTunes(tester, library: library);
      await _scrollTo(tester, find.text('Autumn Leaves'));

      await tester.tap(find.byTooltip('Star Autumn Leaves'));
      await tester.pumpAndSettle();
      expect(library.isFavourite(TuneRef.standard('Autumn Leaves')), isTrue);
      expect(find.byTooltip('Unstar Autumn Leaves'), findsOneWidget);
    });

    testWidgets('Starred shows only what you have starred', (tester) async {
      final library = LibraryStore.inMemory(
        favourites: {TuneRef.standard('Blue Bossa')},
      );
      await _openTunes(tester, library: library);

      await tester.tap(find.byKey(const ValueKey('starred-only')));
      await tester.pumpAndSettle();
      expect(find.text('Blue Bossa'), findsOneWidget);
      expect(find.text('Autumn Leaves'), findsNothing);
      expect(find.textContaining('Standards (1)'), findsOneWidget);
    });

    testWidgets('with nothing starred it says so', (tester) async {
      await _openTunes(tester, library: LibraryStore.inMemory());
      await tester.tap(find.byKey(const ValueKey('starred-only')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing starred yet'), findsOneWidget);
    });
  });

  group('putting the list in order', () {
    testWidgets('by title to begin with', (tester) async {
      await _openTunes(tester, library: LibraryStore.inMemory());
      expect(find.text('By Title'), findsOneWidget);
      final titles = _titlesIn(tester);
      expect(
        titles.first.toLowerCase().compareTo(titles.last.toLowerCase()),
        lessThan(0),
      );
    });

    testWidgets('by tempo puts the slowest first and shows it', (tester) async {
      await _openTunes(tester, library: LibraryStore.inMemory());
      await _sortBy(tester, 'Tempo');
      expect(find.text('By Tempo'), findsOneWidget);
      // The ballads come first, and the tile now says how fast it goes.
      expect(find.textContaining(' bpm'), findsWidgets);
    });

    testWidgets('by key follows the circle of fifths', (tester) async {
      await _openTunes(tester, library: LibraryStore.inMemory());
      await _sortBy(tester, 'Key');
      expect(find.text('By Key'), findsOneWidget);
      // C comes before F, which comes before B♭, not alphabetically.
      expect(keyRank('C'), lessThan(keyRank('F')));
      expect(keyRank('F'), lessThan(keyRank('B♭')));
      expect(keyRank('B♭'), lessThan(keyRank('C minor')));
    });
  });

  group('recently played', () {
    testWidgets("it isn't there until you have played something", (
      tester,
    ) async {
      await _openTunes(tester, library: LibraryStore.inMemory());
      expect(find.text('Recently Played'), findsNothing);
    });

    testWidgets('what you played last is at the top, and can be cleared', (
      tester,
    ) async {
      final library = LibraryStore.inMemory();
      await library.justPlayed(TuneRef.standard('Blue Bossa'));
      await library.justPlayed(TuneRef.standard('So What'));
      await _openTunes(tester, library: library);

      expect(find.text('Recently Played'), findsOneWidget);
      final titles = _titlesIn(tester);
      expect(titles.first, 'So What', reason: 'newest first');
      expect(titles[1], 'Blue Bossa');

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Recently Played'), findsNothing);
      expect(library.played, isEmpty);
    });

    testWidgets('a search hides it, so the list is only what was found', (
      tester,
    ) async {
      final library = LibraryStore.inMemory();
      await library.justPlayed(TuneRef.standard('Blue Bossa'));
      await _openTunes(tester, library: library);
      expect(find.text('Recently Played'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'autumn');
      await tester.pumpAndSettle();
      expect(find.text('Recently Played'), findsNothing);
      expect(find.text('Autumn Leaves'), findsOneWidget);
    });

    testWidgets('the cross clears the whole search at once', (tester) async {
      final library = LibraryStore.inMemory();
      await library.justPlayed(TuneRef.standard('Blue Bossa'));
      await _openTunes(tester, library: library);
      expect(find.byKey(const ValueKey('tune-search-clear')), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'autumn');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tune-search-clear')));
      await tester.pumpAndSettle();
      expect(find.text('autumn'), findsNothing);
      expect(find.text('Recently Played'), findsOneWidget);
      expect(find.byKey(const ValueKey('tune-search-clear')), findsNothing);
    });

    testWidgets('one of your own progressions shows up in it too', (
      tester,
    ) async {
      final progressions = ProgressionStore.inMemory([
        UserProgression(
          id: 'mine-1',
          title: 'Blues in F',
          key: 'F',
          tempo: 120,
          bars: ['F7', 'Bb7'],
          style: BandStyle.of(Feel.swing),
        ),
      ]);
      final library = LibraryStore.inMemory();
      await library.justPlayed(TuneRef.mine('mine-1'));
      await _openTunes(tester, library: library, progressions: progressions);
      expect(find.text('Blues in F'), findsOneWidget);
    });

    testWidgets('a deleted progression quietly drops out of it', (
      tester,
    ) async {
      final library = LibraryStore.inMemory();
      await library.justPlayed(TuneRef.mine('gone'));
      await _openTunes(tester, library: library);
      expect(find.text('Recently Played'), findsNothing);
    });
  });

  group('setlists', () {
    testWidgets('with none yet, it says what a setlist is for', (tester) async {
      await _openSetlists(tester, library: LibraryStore.inMemory());
      expect(find.text('Nothing on the stand'), findsOneWidget);
    });

    testWidgets('making one opens it, ready for tunes', (tester) async {
      final library = LibraryStore.inMemory();
      await _openSetlists(tester, library: library);

      await tester.tap(find.byKey(const ValueKey('new-setlist')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('setlist-name')),
        'Friday at the Vortex',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(library.setlists.single.name, 'Friday at the Vortex');
      expect(find.text('Add the tunes you want, in playing order.'), findsOne);
    });

    testWidgets('tunes are picked, counted and listed in order', (
      tester,
    ) async {
      final library = LibraryStore.inMemory(
        setlists: [Setlist(id: 'gig', name: 'Friday')],
      );
      await _openSetlists(tester, library: library);
      await tester.tap(find.byKey(const ValueKey('setlist-gig')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-tunes')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pick-search')),
        'blue bossa',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-s:Blue Bossa')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-add')));
      await tester.pumpAndSettle();

      expect(library.setlistById('gig')!.tunes, [
        TuneRef.standard('Blue Bossa'),
      ]);
      expect(find.text('Blue Bossa'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: 'numbered from one');
    });

    testWidgets("a tune already on it can't be added twice", (tester) async {
      final library = LibraryStore.inMemory(
        setlists: [
          Setlist(
            id: 'gig',
            name: 'Friday',
            tunes: [TuneRef.standard('Blue Bossa')],
          ),
        ],
      );
      await _openSetlists(tester, library: library);
      await tester.tap(find.byKey(const ValueKey('setlist-gig')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-tunes')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pick-search')),
        'blue bossa',
      );
      await tester.pumpAndSettle();

      expect(find.text('Already in this setlist'), findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('pick-s:Blue Bossa')),
      );
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNull);
    });

    testWidgets('taking a tune out leaves the rest numbered again', (
      tester,
    ) async {
      final library = LibraryStore.inMemory(
        setlists: [
          Setlist(
            id: 'gig',
            name: 'Friday',
            tunes: [
              TuneRef.standard('Blue Bossa'),
              TuneRef.standard('So What'),
            ],
          ),
        ],
      );
      await _openSetlists(tester, library: library);
      await tester.tap(find.byKey(const ValueKey('setlist-gig')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Take out of the setlist').first);
      await tester.pumpAndSettle();
      expect(library.setlistById('gig')!.tunes, [TuneRef.standard('So What')]);
      expect(find.text('Blue Bossa'), findsNothing);
    });

    testWidgets('a tune that was deleted is shown as gone, not hidden', (
      tester,
    ) async {
      final library = LibraryStore.inMemory(
        setlists: [
          Setlist(id: 'gig', name: 'Friday', tunes: [TuneRef.mine('gone')]),
        ],
      );
      await _openSetlists(tester, library: library);
      await tester.tap(find.byKey(const ValueKey('setlist-gig')));
      await tester.pumpAndSettle();

      expect(find.text('Deleted progression'), findsOneWidget);
      expect(find.text('Not in the book any more'), findsOneWidget);
    });

    testWidgets('deleting a setlist asks first', (tester) async {
      final library = LibraryStore.inMemory(
        setlists: [Setlist(id: 'gig', name: 'Friday')],
      );
      await _openSetlists(tester, library: library);
      await tester.tap(find.byKey(const ValueKey('setlist-gig')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('setlist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Setlist'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Friday"?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(library.setlists, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('setlist-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Setlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(library.setlists, isEmpty);
    });

    testWidgets('a long press on a tune puts it on a setlist', (tester) async {
      final library = LibraryStore.inMemory(
        setlists: [Setlist(id: 'gig', name: 'Friday')],
      );
      await _openTunes(tester, library: library);
      await _scrollTo(tester, find.text('Blue Bossa'));

      await tester.longPress(find.text('Blue Bossa'));
      await tester.pumpAndSettle();
      expect(find.text('Add "Blue Bossa" To'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('to-setlist-gig')));
      await tester.pumpAndSettle();
      expect(library.setlistById('gig')!.tunes, [
        TuneRef.standard('Blue Bossa'),
      ]);
    });
  });

  group('the tune menu on the practice screen', () {
    Future<void> openMenu(WidgetTester tester, LibraryStore library) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: standards.firstWhere((tune) => tune.title == 'Blue Bossa'),
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
            library: library,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tune-menu')));
      await tester.pumpAndSettle();
    }

    testWidgets('offers starring, setlists and sharing', (tester) async {
      await openMenu(tester, LibraryStore.inMemory());
      expect(find.text('Star'), findsOneWidget);
      expect(find.text('Add to Setlist'), findsOneWidget);
      expect(find.text('Share Chart'), findsOneWidget);
    });

    testWidgets('starring from it marks the tune', (tester) async {
      final library = LibraryStore.inMemory();
      await openMenu(tester, library);
      await tester.tap(find.text('Star'));
      await tester.pumpAndSettle();
      expect(library.isFavourite(TuneRef.standard('Blue Bossa')), isTrue);
    });

    testWidgets('without a library it only offers to share', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: standards.firstWhere((tune) => tune.title == 'Blue Bossa'),
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tune-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Share Chart'), findsOneWidget);
      expect(find.text('Star'), findsNothing);
    });

    testWidgets('the app bar still fits on a small phone with it on', (
      tester,
    ) async {
      // The menu is the fifth thing in that bar, after Edit, Takes,
      // Arrangement and View.
      tester.view
        ..physicalSize = const Size(320, 568) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final progression = UserProgression(
        id: 'p1',
        title: 'A Very Long Progression Title Indeed',
        key: 'F',
        tempo: 120,
        bars: ['F7', 'Bb7'],
        style: BandStyle.of(Feel.swing),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: progression.toTune(),
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
            takes: TakeStore.inMemory(),
            library: LibraryStore.inMemory(),
            progression: progression,
            progressions: ProgressionStore.inMemory([progression]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
