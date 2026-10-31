// Importing from iReal Pro, as a player would: paste a playlist, choose,
// and find the songs in My Changes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('it says where a link can be copied and where it cannot', (
    tester,
  ) async {
    // The paste box is the fallback, not the way in. On a phone iReal
    // Pro will not put a playlist's link on the clipboard, so sharing to
    // the app is the route, and a paste box offered with no explanation
    // reads as a feature that does not work. Both halves have to be on
    // the screen: that sharing is the phone's way, and that a computer
    // will give you the link to paste.
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ImportScreen(store: ProgressionStore.inMemory()),
      ),
    );
    await tester.pumpAndSettle();
    final help = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(help, contains('Share'));
    expect(help, contains('computer'), reason: 'where a link can be copied');
    expect(
      help,
      contains('only copy an iReal Pro playlist link on a computer'),
      reason: 'and where it cannot',
    );
    // And where to find playlists to copy, with a button to copy it.
    expect(find.byKey(const ValueKey('import-playlists-url')), findsOneWidget);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('import-copy-url')));
    await tester.tap(find.byKey(const ValueKey('import-copy-url')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Link copied'), findsOneWidget);
    expect(copied, 'https://www.irealpro.com/main-playlists');
  });

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
    await tester.ensureVisible(find.byKey(const ValueKey('import-song-1')));
    await tester.pumpAndSettle();
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

  testWidgets('a whole book of charts: held out of the box, built as read', (
    tester,
  ) async {
    // A playlist is not a thing you type: a book of charts runs to
    // hundreds of thousands of characters and well over a thousand
    // songs. Neither the link nor the songs can be laid out all at
    // once, so the link is kept and shown as a line, and the songs are
    // built as they are scrolled to.
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final book =
        'irealbook://'
        '${Uri.encodeComponent([for (var i = 0; i < 400; i++) 'Song $i=Doe Jane=Medium Swing=F=n=[T44F7 |Bb7 |F7 |C7 Z', 'A Big Book'].join('==='))}';
    final store = ProgressionStore.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ImportScreen(store: store, handed: book),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Found 400 Songs'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('import-text'))),
      isA<TextField>().having((f) => f.controller?.text, 'in the box', ''),
      reason: 'the link is too long to lay out in a text field',
    );
    expect(
      find.byKey(const ValueKey('import-held')),
      findsOneWidget,
      reason: 'and is shown as the line it came in on',
    );
    expect(
      tester.widgetList(find.byType(CheckboxListTile)).length,
      lessThan(40),
      reason: 'only the songs on the screen are built',
    );

    await tester.tap(find.byKey(const ValueKey('import-go')));
    await tester.pumpAndSettle();
    expect(store.all, hasLength(400));
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
