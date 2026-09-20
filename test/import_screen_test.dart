// Importing from iReal Pro, as a player would: paste a playlist, choose,
// and find the songs in My Changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/import_screen.dart';
import 'package:play_along/screens/my_progressions_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

/// Two songs in the old, unscrambled link format, and a playlist name.
final _playlist =
    'irealbook://${Uri.encodeComponent(['Blues One=Doe Jane=Medium Swing=F=n=[T44F7 |Bb7 |F7 |C7 Z', 'Waltz Two=Roe Rick=Jazz Waltz=Bb=n=[T34Bb^7 |G-7 |C-7 |F7 Z', 'My Jam List'].join('==='))}';

void main() {
  testWidgets('paste a playlist, choose, and they are in My Changes', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ProgressionStore.inMemory();
    // One of them is already here.
    await store.save(
      UserProgression(
        id: 'mine',
        title: 'Waltz Two',
        key: 'C',
        tempo: 120,
        bars: ['C'],
        style: BandStyle.of(Feel.swing),
      ),
    );
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
    await tester.tap(find.byKey(const ValueKey('import')));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('import-text')), 'hello');
    await tester.pump();
    expect(find.textContaining('No iReal Pro songs'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('import-text')),
      'Here you go: $_playlist',
    );
    await tester.pump();
    expect(find.text('Found 2 Songs'), findsOneWidget);
    expect(find.text('Jane Doe · F · Medium Swing'), findsOneWidget);
    // The one already in My Changes starts unticked; the waltz says how
    // it'll play.
    expect(find.text('Already in My Changes'), findsOneWidget);
    expect(find.textContaining('3/4'), findsOneWidget);
    expect(find.text('Import 1 Song'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-song-1')));
    await tester.pump();
    expect(find.text('Import 2 Songs'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('import-go')));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsNothing);
    expect(find.text('Imported 2 songs'), findsOneWidget);
    expect(store.all.map((p) => p.title), [
      'Blues One',
      'Waltz Two',
      'Waltz Two',
    ]);
    expect(store.all.map((p) => p.id).toSet(), hasLength(3));
    expect(find.text('Blues One'), findsOneWidget);
  });

  testWidgets('with nothing yet, the empty page offers an import', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: MyProgressionsPage(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
          progressions: ProgressionStore.inMemory(),
          library: LibraryStore.inMemory(),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('import-empty')));
    await tester.pumpAndSettle();
    expect(find.byType(ImportScreen), findsOneWidget);
  });
}
