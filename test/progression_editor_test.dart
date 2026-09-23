// Writing, saving, editing and deleting a progression, as a player would.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/screens/home_screen.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/practice/part_store.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';

Future<ProgressionStore> _openHome(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = ProgressionStore.inMemory();
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: HomeScreen(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        takes: TakeStore.inMemory(),
        partStore: PartStore.inMemory(),
        progressions: store,
        library: LibraryStore.inMemory(),
        initialTab: HomeTab.mine,
      ),
    ),
  );
  return store;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Adds a bar holding [chords], typed in.
Future<void> _addBar(WidgetTester tester, String chords) async {
  await _tap(tester, find.byKey(const ValueKey('add-bar')));
  await tester.enterText(find.byKey(const ValueKey('bar-chords')), chords);
  await tester.pump();
  await _tap(tester, find.text('Done'));
}

/// Picks [option] from the dropdown next to [label].
Future<void> _choose(WidgetTester tester, String label, String option) async {
  final row = find.ancestor(of: find.text(label), matching: find.byType(Row));
  await _tap(
    tester,
    find.descendant(
      of: row.first,
      matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    ),
  );
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('write a progression, save it, find it, edit it, delete it', (
    tester,
  ) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    expect(find.text('New Progression'), findsOneWidget); // the editor title

    await tester.enterText(find.byType(TextField).first, 'My turnaround');

    // Nothing to start from, so nothing to save yet.
    expect(find.byKey(const ValueKey('bar-0')), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('Save'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    // Bar 1: typed.
    await _addBar(tester, 'Em7 A7');

    // Bar 2: built from a root and a chord type.
    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'D'));
    await _tap(tester, find.text('m7'));
    await _tap(tester, find.text('G'));
    await _tap(tester, find.text('7').last);
    expect(find.text('Dm7 G7'), findsOneWidget, reason: 'built chords');
    await _tap(tester, find.text('Done'));

    // Bar 3: home.
    await _addBar(tester, 'C^7');

    // A bossa groove under a walking bass.
    await _choose(tester, 'Drums', 'Bossa nova');
    await _choose(tester, 'Bass', 'Walking');
    await _choose(tester, 'Chords', 'Held chords');

    await _tap(tester, find.text('Save'));

    // Saved, and back on the list.
    final saved = store.all.single;
    expect(saved.title, 'My turnaround');
    expect(saved.bars, ['Em7 A7', 'Dm7 G7', 'C^7']);
    expect(
      saved.style,
      const BandStyle(
        drums: Feel.bossa,
        bass: BassStyle.walking,
        piano: PianoStyle.held,
      ),
    );
    // Ends on CΔ7, so it's in C.
    expect(saved.key, 'C');
    expect(find.text('My turnaround'), findsOneWidget);
    expect(
      find.textContaining('Bossa nova drums, walking bass'),
      findsOneWidget,
    );

    // Edit: rename it.
    await _tap(tester, find.byTooltip('Edit My turnaround'));
    await tester.enterText(find.byType(TextField).first, 'Turnaround in C');
    await _tap(tester, find.text('Save'));
    expect(store.all.single.title, 'Turnaround in C');

    // Delete it.
    await _tap(tester, find.byTooltip('Edit Turnaround in C'));
    await _tap(tester, find.byTooltip('Delete'));
    await _tap(tester, find.text('Delete').last);
    expect(store.all, isEmpty);
    expect(find.text('Turnaround in C'), findsNothing);
  });

  testWidgets('Next Bar writes a tune out without closing the sheet', (
    tester,
  ) async {
    // The point of it: a tune is bar after bar, and shutting the sheet
    // between each one was most of the work.
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await tester.enterText(find.byType(TextField).first, 'Straight through');

    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    for (final chords in ['Dm7', 'G7', 'C^7']) {
      await tester.enterText(find.byKey(const ValueKey('bar-chords')), chords);
      await tester.pump();
      // The sheet stays up and moves on, adding a bar when there is no
      // next one yet.
      await _tap(tester, find.byKey(const ValueKey('next-bar')));
      expect(
        find.byKey(const ValueKey('bar-chords')),
        findsOneWidget,
        reason: 'the sheet closed instead of carrying on',
      );
    }
    // The fourth is empty, so backing out of it leaves nothing behind.
    await _tap(tester, find.text('Done'));

    expect(find.text('Dm7'), findsOneWidget);
    expect(find.text('G7'), findsOneWidget);
    expect(find.text('CΔ7'), findsOneWidget);
    expect(find.byKey(const ValueKey('bar-3')), findsNothing);
  });

  testWidgets('Next Bar goes on to a bar that is already there', (
    tester,
  ) async {
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await tester.enterText(find.byType(TextField).first, 'Edit along');
    await _addBar(tester, 'Dm7');
    await _addBar(tester, 'G7');

    // Opening the first and carrying on lands on the second, with what is
    // already written in it rather than an empty field.
    await _tap(tester, find.byKey(const ValueKey('bar-0')));
    await _tap(tester, find.byKey(const ValueKey('next-bar')));
    expect(find.text('Bar 2'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('bar-chords')))
          .controller
          ?.text,
      'G7',
    );
    await _tap(tester, find.text('Done'));
  });

  testWidgets('an empty bar can always be closed', (tester) async {
    // Next Bar lands on one at the end of every tune, so this is the way
    // out of writing one. It used to be greyed out, which left the sheet
    // with no button that worked.
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const ValueKey('bar-done')))
          .onPressed,
      isNotNull,
      reason: 'no way out of an empty bar',
    );
    await _tap(tester, find.byKey(const ValueKey('bar-done')));
    expect(find.byKey(const ValueKey('bar-chords')), findsNothing);
    expect(find.byKey(const ValueKey('bar-0')), findsNothing);
  });

  testWidgets('clearing a bar and closing leaves it alone', (tester) async {
    // Delete bar is how a bar is removed. Emptying the field and closing
    // must not write a bar that cannot be played.
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await tester.enterText(find.byType(TextField).first, 'Keep it');
    await _addBar(tester, 'Dm7');
    await _tap(tester, find.byKey(const ValueKey('bar-0')));
    await tester.enterText(find.byKey(const ValueKey('bar-chords')), '');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('bar-done')));
    expect(find.text('Dm7'), findsOneWidget, reason: 'the bar was emptied');
  });

  testWidgets('Next Bar is not offered for an empty bar', (tester) async {
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    expect(
      tester
          .widget<ButtonStyleButton>(find.byKey(const ValueKey('next-bar')))
          .onPressed,
      isNull,
      reason: 'there is nothing to carry on from',
    );
  });

  testWidgets('tag a progression with genres', (tester) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _addBar(tester, 'Cm7');
    await _tap(tester, find.byKey(const ValueKey('genre-blues')));
    await _tap(tester, find.byKey(const ValueKey('genre-ballad')));
    await _tap(tester, find.byKey(const ValueKey('genre-ballad')));
    await _tap(tester, find.text('Save'));
    expect(store.all.single.tags, {Genre.blues});
  });

  testWidgets('a bar that is not a chord cannot be saved', (tester) async {
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    await tester.enterText(find.byKey(const ValueKey('bar-chords')), 'Hm7');
    await tester.pump();
    expect(find.textContaining('"Hm7"'), findsOneWidget);
    final done = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Done'), matching: find.byType(FilledButton)),
    );
    expect(done.onPressed, isNull);
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await tester.enterText(find.byType(TextField).first, 'Half-written');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard Changes?'), findsOneWidget);
    await _tap(tester, find.text('Discard'));
    expect(store.all, isEmpty);
    expect(find.text('New Progression'), findsOneWidget); // back on the list
  });

  testWidgets('save and play opens it with the band', (tester) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _addBar(tester, 'Cm7');
    await _tap(tester, find.text('Save and Play'));
    expect(store.all, hasLength(1));
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.text('Untitled'), findsOneWidget);
  });

  testWidgets('a new bar starts empty, and closing it adds nothing', (
    tester,
  ) async {
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));

    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('bar-chords')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.text('Bar 1'), findsOneWidget);

    // Dismissed without a chord: still no bars.
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bar-0')), findsNothing);

    // With a chord picked, it's added as that chord alone.
    await _tap(tester, find.byKey(const ValueKey('add-bar')));
    await _tap(tester, find.text('F'));
    await _tap(tester, find.text('Δ7'));
    await _tap(tester, find.text('Done'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bar-0')),
        matching: find.text('FΔ7'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking a chord for a bar replaces it; a second one adds', (
    tester,
  ) async {
    await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _addBar(tester, 'G7');
    await _tap(tester, find.byKey(const ValueKey('bar-0')));
    final field = find.byKey(const ValueKey('bar-chords'));

    await _tap(tester, find.widgetWithText(ChoiceChip, 'D♭'));
    await _tap(tester, find.text('7').last);
    expect(tester.widget<TextField>(field).controller!.text, 'D♭7');

    await _tap(tester, find.widgetWithText(ChoiceChip, 'G'));
    await _tap(tester, find.text('7').last);
    expect(tester.widget<TextField>(field).controller!.text, 'D♭7 G7');
  });

  testWidgets('your own progression can be edited while practising it', (
    tester,
  ) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await tester.enterText(find.byType(TextField).first, 'Mine');
    await _addBar(tester, 'Dm7');
    await _tap(tester, find.text('Save and Play'));
    expect(find.byType(PracticeScreen), findsOneWidget);

    await _tap(tester, find.byTooltip('Edit progression'));
    await _tap(tester, find.byKey(const ValueKey('bar-0')));
    await tester.enterText(find.byKey(const ValueKey('bar-chords')), 'Em7');
    await tester.pump();
    await _tap(tester, find.text('Done'));
    await _tap(tester, find.text('Save Changes'));

    // Back practising, with the change, and saved.
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.text('Em7'), findsWidgets);
    expect(store.all.single.bars.first, 'Em7');

    // Deleting it from there goes back to the list.
    await _tap(tester, find.byTooltip('Edit progression'));
    await _tap(tester, find.byTooltip('Delete'));
    await _tap(tester, find.text('Delete').last);
    expect(find.byType(PracticeScreen), findsNothing);
    expect(store.all, isEmpty);
  });

  testWidgets('standards have no edit button', (tester) async {
    await _openHome(tester);
    await _tap(tester, find.text('Tunes'));
    // The library is long, so the tune has to be scrolled to.
    await tester.scrollUntilVisible(
      find.text('All of Me'),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('tune-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await _tap(tester, find.text('All of Me'));
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.byTooltip('Edit progression'), findsNothing);
  });

  group('deleting from the list', () {
    Future<ProgressionStore> withOne(WidgetTester tester) async {
      final store = await _openHome(tester);
      await store.save(
        UserProgression.starter(id: 'x')
          ..title = 'Blues in F'
          ..bars = ['F7', 'Bb7'],
      );
      await tester.pumpAndSettle();
      expect(find.text('Blues in F'), findsOneWidget);
      return store;
    }

    testWidgets('asks first, and Cancel keeps it', (tester) async {
      final store = await withOne(tester);
      await _tap(tester, find.byTooltip('Delete Blues in F'));
      expect(find.text('Delete "Blues in F"?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect(store.all, hasLength(1));
      expect(find.text('Blues in F'), findsOneWidget);
    });

    testWidgets('Delete removes it without opening it', (tester) async {
      final store = await withOne(tester);
      await _tap(tester, find.byTooltip('Delete Blues in F'));
      await _tap(tester, find.text('Delete'));
      expect(store.all, isEmpty);
      expect(find.text('Blues in F'), findsNothing);
      expect(find.text('Edit progression'), findsNothing, reason: 'not opened');
    });

    testWidgets('swiping left deletes, after the same question', (
      tester,
    ) async {
      final store = await withOne(tester);
      await tester.drag(find.text('Blues in F'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Blues in F"?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect(store.all, hasLength(1));

      await tester.drag(find.text('Blues in F'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Delete'));
      expect(store.all, isEmpty);
      expect(find.text('Blues in F'), findsNothing);
    });
  });

  group('deleting several at once', () {
    Future<ProgressionStore> withThree(WidgetTester tester) async {
      final store = await _openHome(tester);
      for (final (id, title) in [('a', 'One'), ('b', 'Two'), ('c', 'Three')]) {
        await store.save(
          UserProgression.starter(id: id)
            ..title = title
            ..bars = ['C'],
        );
      }
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('select two, confirm, and only those go', (tester) async {
      final store = await withThree(tester);
      await _tap(tester, find.text('Select'));
      expect(find.text('0 selected'), findsOneWidget);
      // Nothing chosen: nothing to delete.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .onPressed,
        isNull,
      );

      await _tap(tester, find.text('One'));
      await _tap(tester, find.text('Three'));
      expect(find.text('2 selected'), findsOneWidget);

      await _tap(tester, find.byTooltip('Delete selected'));
      expect(find.text('Delete 2 progressions?'), findsOneWidget);
      await _tap(tester, find.text('Delete'));

      expect(store.all.map((p) => p.title), ['Two']);
      expect(
        find.widgetWithText(AppBar, 'My Changes'),
        findsOneWidget,
        reason: 'back to normal',
      );
    });

    testWidgets('cancelling the question keeps them all', (tester) async {
      final store = await withThree(tester);
      await _tap(tester, find.text('Select'));
      await _tap(tester, find.text('Select all'));
      expect(find.text('3 selected'), findsOneWidget);
      await _tap(tester, find.byTooltip('Delete selected'));
      await _tap(tester, find.text('Cancel'));
      expect(store.all, hasLength(3));
      expect(find.text('3 selected'), findsOneWidget, reason: 'still choosing');

      // Leaving selection changes nothing.
      await _tap(tester, find.byTooltip('Cancel'));
      expect(find.widgetWithText(AppBar, 'My Changes'), findsOneWidget);
      expect(store.all, hasLength(3));
    });

    testWidgets('a long press starts selecting with that one chosen', (
      tester,
    ) async {
      await withThree(tester);
      await tester.longPress(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      final two = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Two'),
      );
      expect(two.value, isTrue);
    });
  });

  group('slash chords', () {
    testWidgets('pick a chord, then / bass, then the bass note', (
      tester,
    ) async {
      await _openHome(tester);
      await _tap(tester, find.text('New Progression'));
      await _tap(tester, find.byKey(const ValueKey('add-bar')));
      final field = find.byKey(const ValueKey('bar-chords'));
      String text() => tester.widget<TextField>(field).controller!.text;

      // Nothing to put over a bass yet.
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('slash-bass')))
            .onSelected,
        isNull,
      );

      await _tap(tester, find.widgetWithText(ChoiceChip, 'F'));
      await _tap(tester, find.text('Δ7'));
      await _tap(tester, find.byKey(const ValueKey('slash-bass')));
      expect(find.text('…then the bass note for FΔ7'), findsOneWidget);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'C'));
      expect(text(), 'FΔ7/C');

      // A second chord in the bar, over its own bass.
      await _tap(tester, find.widgetWithText(ChoiceChip, 'D'));
      await _tap(tester, find.text('m7'));
      await _tap(tester, find.byKey(const ValueKey('slash-bass')));
      await _tap(tester, find.widgetWithText(ChoiceChip, 'G'));
      expect(text(), 'FΔ7/C Dm7/G');

      await _tap(tester, find.text('Done'));
      expect(find.text('FΔ7/C  Dm7/G'), findsOneWidget);
    });

    testWidgets('an existing chord can be put over a bass', (tester) async {
      await _openHome(tester);
      await _tap(tester, find.text('New Progression'));
      await _addBar(tester, 'Fmaj7');
      await _tap(tester, find.byKey(const ValueKey('bar-0')));
      await _tap(tester, find.byKey(const ValueKey('slash-bass')));
      await _tap(tester, find.widgetWithText(ChoiceChip, 'C'));
      final field = find.byKey(const ValueKey('bar-chords'));
      // Kept as it was typed, now over C.
      expect(tester.widget<TextField>(field).controller!.text, 'Fmaj7/C');
    });
  });

  test('typed slash chords may have spaces around the slash', () {
    expect(UserProgression.symbolsIn('Fmaj7 / C  Dm7/ G'), [
      'Fmaj7/C',
      'Dm7/G',
    ]);
    expect(UserProgression.problemWith('Fmaj7 / C'), isNull);
    final tune = (UserProgression.starter(
      id: 'x',
    )..bars = ['Fmaj7 / C']).toTune();
    final chord = tune.bars.single.single.chord;
    expect(chord.display, 'Fmaj7/C');
    expect(chord.bass, 0, reason: 'C in the bass');
  });

  testWidgets('a progression can have sections: A, then a B', (tester) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await tester.enterText(find.byType(TextField).first, 'My tune');
    // The A section: two bars.
    await _addBar(tester, 'Dm7');
    await _addBar(tester, 'G7');
    // Then a B section, from the tile that starts one.
    await _tap(tester, find.byKey(const ValueKey('add-section')));
    expect(
      tester
          .widget<SegmentedButton<String?>>(
            find.byKey(const ValueKey('section-picker')),
          )
          .selected,
      {'B'},
      reason: 'the new bar starts section B',
    );
    await tester.enterText(find.byKey(const ValueKey('bar-chords')), 'CΔ7');
    await tester.pump();
    await _tap(tester, find.text('Done'));

    // Both letters are on the bars: A on the first, which it now starts.
    expect(find.byKey(const ValueKey('section-mark-A')), findsOneWidget);
    expect(find.byKey(const ValueKey('section-mark-B')), findsOneWidget);

    // A bar can be moved into another section, or out of any.
    await _tap(tester, find.byKey(const ValueKey('bar-1')));
    await _tap(tester, find.byKey(const ValueKey('section-C')));
    await _tap(tester, find.text('Done'));
    expect(find.byKey(const ValueKey('section-mark-C')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('bar-1')));
    await _tap(tester, find.byKey(const ValueKey('section-none')));
    await _tap(tester, find.text('Done'));
    expect(find.byKey(const ValueKey('section-mark-C')), findsNothing);

    // Saved, and played with its rehearsal letters on the chart.
    await _tap(tester, find.text('Save and Play'));
    final saved = store.all.single;
    expect(saved.sections, {0: 'A', 2: 'B'});
    expect(saved.toTune().sections, {0: 'A', 2: 'B'});
    expect(find.byType(PracticeScreen), findsOneWidget);
  });

  testWidgets('a section can be played ×2', (tester) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    await _addBar(tester, 'Dm7');
    await _addBar(tester, 'G7');
    // Bar 1 starts the A section; play it twice.
    await _tap(tester, find.byKey(const ValueKey('bar-0')));
    expect(find.byKey(const ValueKey('section-repeats')), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('section-A')));
    await _tap(tester, find.byKey(const ValueKey('repeat-2')));
    await _tap(tester, find.text('Done'));
    expect(find.byKey(const ValueKey('section-repeat-A')), findsOneWidget);

    // Played: the chart writes the A once, marked ×2.
    await _tap(tester, find.text('Save and Play'));
    expect(store.all.single.repeats, {0: 2});
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('repeat-mark')), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('1st and 2nd endings', (tester) async {
    final store = await _openHome(tester);
    await _tap(tester, find.text('New Progression'));
    for (final chords in ['Dm7', 'G7', 'Em7 A7', 'CΔ7']) {
      await _addBar(tester, chords);
    }
    // Bar 3 goes back to the top; bar 4 is the way out.
    Future<void> mark(int bar, int ending) async {
      await _tap(tester, find.byKey(ValueKey('bar-${bar - 1}')));
      await _tap(tester, find.byKey(ValueKey('ending-$ending')));
      await _tap(tester, find.text('Done'));
    }

    await mark(3, 1);
    await mark(4, 2);
    expect(find.byKey(const ValueKey('ending-mark-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('ending-mark-4')), findsOneWidget);
    // Endings need a section: the bars became an A.
    expect(find.byKey(const ValueKey('section-mark-A')), findsOneWidget);

    // A section's first bar says how it's played rather than offering ×2.
    await _tap(tester, find.byKey(const ValueKey('bar-0')));
    expect(find.byKey(const ValueKey('section-repeats')), findsNothing);
    expect(find.textContaining('through the 1st ending'), findsOneWidget);
    await _tap(tester, find.text('Done'));

    await _tap(tester, find.text('Save and Play'));
    expect(store.all.single.endings, {2: 1, 3: 2});
    expect(find.byType(PracticeScreen), findsOneWidget);
    // On the chart: the endings labelled as on a lead sheet.
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });
}
