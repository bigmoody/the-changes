import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord_drill.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/screens/home_screen.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/practice/part_store.dart';
import 'package:play_along/practice/lick_store.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';

Future<(AppSettings, ProgressionStore)> _openHome(
  WidgetTester tester, {
  HomeTab tab = HomeTab.tunes,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final settings = AppSettings.inMemory();
  final store = ProgressionStore.inMemory();
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: HomeScreen(
        player: PracticePlayer(),
        settings: settings,
        takes: TakeStore.inMemory(),
        partStore: PartStore.inMemory(),
        recordingStore: RecordingStore.inMemory(),
        licks: LickStore.inMemory(),
        progressions: store,
        library: LibraryStore.inMemory(),
        initialTab: tab,
      ),
    ),
  );
  return (settings, store);
}

final _list = find.byKey(const ValueKey('tune-list'));

/// Taps a genre chip, scrolling the row to it first.
Future<void> _pickGenre(WidgetTester tester, String name) async {
  final chip = find.byKey(ValueKey('genre-filter-$name'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists tunes and searches them', (tester) async {
    await _openHome(tester);
    await tester.scrollUntilVisible(
      find.text('Autumn Leaves'),
      200,
      scrollable: find.descendant(of: _list, matching: find.byType(Scrollable)),
    );
    expect(find.text('Autumn Leaves'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'coltrane');
    await tester.pump();
    expect(find.text('Giant Steps'), findsOneWidget);
    expect(find.text('Autumn Leaves'), findsNothing);
  });

  testWidgets('filter the tunes by genre', (tester) async {
    await _openHome(tester);
    await _pickGenre(tester, 'latin');
    expect(find.text('Blue Bossa'), findsOneWidget);
    expect(find.text('A Night in Tunisia'), findsOneWidget);
    expect(find.text('Autumn Leaves'), findsNothing);

    await _pickGenre(tester, 'blues');
    expect(find.text('Blue Bossa'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('C Jam Blues'),
      200,
      scrollable: find.descendant(of: _list, matching: find.byType(Scrollable)),
    );
    // The practice progressions are filtered too.
    await tester.scrollUntilVisible(
      find.text('Jazz blues in F'),
      200,
      scrollable: find.descendant(of: _list, matching: find.byType(Scrollable)),
    );
    expect(find.text('Rhythm changes in B♭'), findsNothing);

    // Tapping it again shows everything. The list stays where it was
    // scrolled to, and the library is long, so scroll back for a tune that
    // isn't a blues.
    await _pickGenre(tester, 'blues');
    // The list stays where the filtered one was scrolled to, so go back to
    // the top before looking for a tune that isn't a blues.
    final scrollable = find.descendant(
      of: _list,
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 6; i++) {
      await tester.drag(scrollable, const Offset(0, 2000));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      find.text('All of Me'),
      100,
      scrollable: scrollable,
    );
    expect(find.text('All of Me'), findsOneWidget);
  });

  testWidgets('the genre chips are in alphabetical order, after All', (
    tester,
  ) async {
    await _openHome(tester);
    final chips = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => (chip.label as Text).data!)
        .toList();
    expect(chips.first, 'All');
    expect(chips.skip(1), [...chips.skip(1)]..sort());
  });

  test('every standard has a genre, and the tagged ones are right', () {
    Tune named(String title) => standards.firstWhere((t) => t.title == title);
    expect(named('Blue Bossa').genres, {Genre.latin});
    expect(named("Now's the Time").genres, {
      Genre.swing,
      Genre.bebop,
      Genre.blues,
    });
    expect(named('Chameleon').genres, {Genre.funk, Genre.modal});
    for (final tune in standards) {
      expect(tune.genres, isNotEmpty, reason: tune.title);
    }
  });

  testWidgets('filter my progressions by genre', (tester) async {
    final (_, store) = await _openHome(tester, tab: HomeTab.mine);
    await store.save(
      UserProgression.starter(id: 'a')
        ..title = 'Minor blues'
        ..bars = ['Cm7']
        ..tags = {Genre.blues},
    );
    await store.save(
      UserProgression.starter(id: 'b')
        ..title = 'Bossa vamp'
        ..bars = ['Dm7 G7']
        ..style = BandStyle.of(Feel.bossa),
    );
    await tester.pumpAndSettle();
    expect(find.text('Minor blues'), findsOneWidget);
    expect(find.text('Bossa vamp'), findsOneWidget);

    await _pickGenre(tester, 'latin');
    expect(find.text('Minor blues'), findsNothing);
    expect(find.text('Bossa vamp'), findsOneWidget);

    await _pickGenre(tester, 'blues');
    expect(find.text('Minor blues'), findsOneWidget);
    expect(find.text('Bossa vamp'), findsNothing);
  });

  test('tags are saved with a progression, and old saves have none', () {
    final progression = UserProgression.starter(id: 'x')
      ..bars = ['C']
      ..tags = {Genre.ballad, Genre.modal};
    final back = UserProgression.fromJson(progression.toJson());
    expect(back.tags, {Genre.ballad, Genre.modal});
    expect(back.toTune().genres, {Genre.swing, Genre.ballad, Genre.modal});

    final old = progression.toJson()..remove('tags');
    expect(UserProgression.fromJson(old).tags, isEmpty);
  });

  testWidgets('the tuner opens from a tuning fork on the Tunes page', (
    tester,
  ) async {
    await _openHome(tester);
    final fork = find.byTooltip('Tuner');
    expect(fork, findsOneWidget);
    // Only there: it's not a tab any more.
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Tuner'),
      ),
      findsNothing,
    );
    await tester.tap(fork);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.widgetWithText(AppBar, 'Tuner'), findsOneWidget);
    // Back to the tunes.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'The Changes'), findsOneWidget);
  });

  testWidgets('the bottom bar goes to every page', (tester) async {
    final (settings, _) = await _openHome(tester);
    await tester.tap(find.text('My Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Start your own book'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'My Changes'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // The instrument, set once for the whole app.
    await tester.tap(find.text('E♭'));
    await tester.pumpAndSettle();
    expect(settings.instrument, ChartInstrument.eFlat);
    // What to look up isn't hidden in Settings any more.
    expect(find.text('Chord Symbols'), findsNothing);

    // It's all in Learn: the quiz, and the pages to look things up in.
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Learn'), findsOneWidget);
    for (final page in [
      'Chord Quiz',
      'Metronome',
      'Chord Symbols',
      'Guitar Chords',
      'Chord Tones',
      'Scales & Modes',
    ]) {
      await tester.scrollUntilVisible(
        find.text(page),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(page), findsOneWidget, reason: page);
    }
    await tester.scrollUntilVisible(
      find.text('Chord Symbols'),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Chord Symbols'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ø');
    await tester.pumpAndSettle();
    expect(find.text('Half-diminished'), findsOneWidget);
  });

  testWidgets('the Chord Quiz starts fresh, on Spell It, every time', (
    tester,
  ) async {
    await _openHome(tester);
    DrillMode mode() => tester
        .widget<SegmentedButton<DrillMode>>(
          find.byType(SegmentedButton<DrillMode>),
        )
        .selected
        .single;

    Future<void> openQuiz() async {
      await tester.tap(find.byKey(const ValueKey('learn-quiz')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await openQuiz();
    expect(find.widgetWithText(AppBar, 'Chord Quiz'), findsOneWidget);
    expect(mode(), DrillMode.spell);

    // Switch to Aim For and answer a question.
    await tester.tap(find.text('Aim For'));
    await tester.pumpAndSettle();
    expect(mode(), DrillMode.aim);
    final pad = find.byKey(const ValueKey('pad-0'));
    await tester.ensureVisible(pad);
    await tester.tap(pad);
    await tester.pump();
    expect(find.text('0/0'), findsNothing);

    // Out and back in: Spell It again, and no score.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openQuiz();
    expect(mode(), DrillMode.spell);
    expect(find.text('0/0'), findsOneWidget);
  });
}
