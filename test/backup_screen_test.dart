// Backing up and restoring, as a player would: paste a backup, see what's
// in it, and either add it to what's here or put it in place of it.
//
// The share sheet isn't touched (it needs a platform channel), so nothing
// here taps "Save Backup…".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/backup.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/backup_screen.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

UserProgression _progression(String id, String title) => UserProgression(
  id: id,
  title: title,
  key: 'C',
  tempo: 120,
  bars: ['C'],
  style: BandStyle.of(Feel.swing),
);

/// A backup file made somewhere else: two progressions, a setlist and a
/// starred tune, none of which are on the phone below.
String _fileToPaste() => backupText(
  progressions: [
    _progression('old-1', 'Blues One'),
    _progression('old-2', 'Waltz Two'),
  ],
  library: LibraryStore.inMemory(
    favourites: {TuneRef.standard('Autumn Leaves')},
    setlists: [
      Setlist(
        id: 'list-1',
        name: 'Tuesday',
        tunes: [TuneRef.standard('Autumn Leaves')],
      ),
    ],
  ),
  at: DateTime(2026, 9, 19, 14, 32),
);

/// Opens the screen the way the app opens it (pushed onto a route) and
/// hands back a way to read what it popped, which is how the app learns how
/// many progressions came in.
Future<int? Function()> _open(
  WidgetTester tester, {
  required ProgressionStore progressions,
  required LibraryStore library,
  int takeCount = 0,
}) async {
  int? popped;
  // Taller than a phone, so the whole page is laid out at once: a list
  // only builds the rows it can show, and these tests are about what the
  // page says rather than about scrolling to it.
  tester.view
    ..physicalSize = const Size(393, 1800) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open-backup'),
              onPressed: () async {
                popped = await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                    builder: (_) => BackupScreen(
                      progressions: progressions,
                      library: library,
                      takeCount: takeCount,
                    ),
                  ),
                );
              },
              child: const Text('Back Up & Restore'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-backup')));
  await tester.pumpAndSettle();
  return () => popped;
}

void main() {
  testWidgets('a pasted backup says what is in it', (tester) async {
    await _open(
      tester,
      progressions: ProgressionStore.inMemory([_progression('mine', 'Mine')]),
      library: LibraryStore.inMemory(),
      takeCount: 3,
    );

    // The Back Up half says what's here, and that takes stay behind.
    expect(find.text('Right now that\'s 1 progression'), findsOneWidget);
    expect(find.textContaining('Your 3 takes aren\'t in it'), findsOneWidget);
    // Nothing to restore until something is pasted.
    expect(find.byKey(const ValueKey('restore-add')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('restore-text')),
      _fileToPaste(),
    );
    await tester.pumpAndSettle();
    expect(find.text('In That Backup'), findsOneWidget);
    expect(
      find.textContaining('2 progressions · 1 setlist · 1 starred'),
      findsOneWidget,
    );
    expect(find.textContaining('Made 19 Sep 2026 at 14:32'), findsOneWidget);
  });

  testWidgets('pasting something that is not a backup says so', (tester) async {
    await _open(
      tester,
      progressions: ProgressionStore.inMemory(),
      library: LibraryStore.inMemory(),
    );
    await tester.enterText(
      find.byKey(const ValueKey('restore-text')),
      'hello there',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('isn\'t a backup'), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-add')), findsNothing);
    expect(find.byKey(const ValueKey('restore-replace')), findsNothing);
  });

  testWidgets('Add To What\'s Here adds without deleting anything', (
    tester,
  ) async {
    final progressions = ProgressionStore.inMemory([
      _progression('mine', 'My Own Tune'),
    ]);
    final library = LibraryStore.inMemory(
      setlists: [Setlist(id: 'here', name: 'My Gig')],
    );
    final result = await _open(
      tester,
      progressions: progressions,
      library: library,
    );
    await tester.enterText(
      find.byKey(const ValueKey('restore-text')),
      _fileToPaste(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('restore-add')));
    await tester.pumpAndSettle();

    expect(find.byType(BackupScreen), findsNothing);
    expect(result(), 2);
    expect(progressions.all.map((p) => p.title), [
      'Blues One',
      'My Own Tune',
      'Waltz Two',
    ]);
    // Fresh ids, so nothing was overwritten, and the library is untouched.
    expect(progressions.all.map((p) => p.id).toSet(), hasLength(3));
    expect(progressions.byId('mine'), isNotNull);
    expect(library.setlists.map((list) => list.name), ['My Gig']);
    expect(library.favourites, isEmpty);
  });

  testWidgets('Replace Everything asks first, then replaces', (tester) async {
    final progressions = ProgressionStore.inMemory([
      _progression('mine-1', 'My Own Tune'),
      _progression('mine-2', 'Another Of Mine'),
    ]);
    final library = LibraryStore.inMemory(
      setlists: [Setlist(id: 'here', name: 'My Gig')],
    );
    final result = await _open(
      tester,
      progressions: progressions,
      library: library,
    );
    await tester.enterText(
      find.byKey(const ValueKey('restore-text')),
      _fileToPaste(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('restore-replace')));
    await tester.pumpAndSettle();
    expect(find.text('Replace Everything?'), findsOneWidget);
    expect(
      find.text(
        'The 2 progressions and 1 setlist on this phone will be '
        'replaced.',
      ),
      findsOneWidget,
    );
    // Nothing has happened yet.
    expect(progressions.all, hasLength(2));

    await tester.tap(find.widgetWithText(TextButton, 'Replace Everything'));
    await tester.pumpAndSettle();

    expect(find.byType(BackupScreen), findsNothing);
    expect(result(), 2);
    expect(progressions.all.map((p) => p.title), ['Blues One', 'Waltz Two']);
    expect(progressions.byId('mine-1'), isNull);
    expect(library.setlists.map((list) => list.name), ['Tuesday']);
    expect(library.favourites, {TuneRef.standard('Autumn Leaves')});
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    final progressions = ProgressionStore.inMemory([
      _progression('mine', 'My Own Tune'),
    ]);
    final library = LibraryStore.inMemory(
      setlists: [Setlist(id: 'here', name: 'My Gig')],
    );
    await _open(tester, progressions: progressions, library: library);
    await tester.enterText(
      find.byKey(const ValueKey('restore-text')),
      _fileToPaste(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('restore-replace')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Still on the screen, with everything as it was.
    expect(find.byType(BackupScreen), findsOneWidget);
    expect(progressions.all.map((p) => p.title), ['My Own Tune']);
    expect(library.setlists.map((list) => list.name), ['My Gig']);
  });
}
