// Mine, in My Changes: the progressions written here, as against the ones
// imported from iReal Pro or copied out of the book.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/my_progressions_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

UserProgression _one(String id, String title, {bool written = false}) =>
    UserProgression(
      id: id,
      title: title,
      key: 'C',
      tempo: 120,
      bars: const ['Dm7 G7', 'C^7'],
      style: BandStyle.of(Feel.swing),
      written: written,
    );

Future<void> _open(WidgetTester tester, ProgressionStore store) async {
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

void main() {
  test('written here survives a save, and is not assumed', () {
    final mine = _one('a', 'Mine', written: true);
    expect(UserProgression.fromJson(mine.toJson()).written, isTrue);
    // Anything saved before it was written down is not counted.
    final old = _one('b', 'Old').toJson()..remove('written');
    expect(UserProgression.fromJson(old).written, isFalse);
  });

  testWidgets('Mine shows only the ones written here', (tester) async {
    await _open(
      tester,
      ProgressionStore.inMemory([
        _one('a', 'My Own Blues', written: true),
        _one('b', 'Imported Tune'),
      ]),
    );
    expect(find.text('Imported Tune'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('genre-filter-mine')));
    await tester.pumpAndSettle();
    expect(find.text('My Own Blues'), findsOneWidget);
    expect(find.text('Imported Tune'), findsNothing);

    // All brings the rest back.
    await tester.tap(find.byKey(const ValueKey('genre-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Imported Tune'), findsOneWidget);
  });

  testWidgets('no Mine chip when nothing was written here', (tester) async {
    await _open(tester, ProgressionStore.inMemory([_one('b', 'Imported')]));
    expect(find.byKey(const ValueKey('genre-filter-mine')), findsNothing);
  });
}
