// Choosing a comping figure while a tune is playing.
//
// The choice lives in the mixer, beside the rest of the band, because
// that is where you go when the band is not doing what you want. It only
// appears where it would do something, and it is kept with the tune, so a
// chorus spent listening to the Charleston is still there tomorrow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/theme.dart';

final tune = standards.firstWhere((one) => one.style.piano == PianoStyle.swing);

void main() {
  late LibraryStore library;
  late AppSettings settings;

  Future<void> openMixer(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1600) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: PracticeScreen(
          tune: tune,
          player: PracticePlayer(),
          settings: settings,
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mixer'));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    library = await LibraryStore.load(MemoryStorage());
    settings = AppSettings.inMemory();
  });

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('band-Figure')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('where it appears', () {
    testWidgets('beside the rest of the band, in a swing tune', (tester) async {
      await openMixer(tester);
      expect(find.byKey(const ValueKey('band-Figure')), findsOneWidget);
      expect(find.text('As it comes'), findsOneWidget);
    });

    testWidgets('every figure Learn has is offered, and the band as well', (
      tester,
    ) async {
      await openMixer(tester);
      await tester.tap(find.byKey(const ValueKey('band-Figure')));
      await tester.pumpAndSettle();
      for (final figure in CompFigure.values) {
        expect(find.text(figure.label), findsWidgets, reason: figure.label);
      }
      expect(find.text('As it comes'), findsWidgets);
    });

    testWidgets('and not where it would do nothing', (tester) async {
      // Held chords have a rhythm of their own and never look at these.
      await openMixer(tester);
      await tester.tap(find.byKey(const ValueKey('band-Comping')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(PianoStyle.held.label).last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('band-Figure')), findsNothing);
    });
  });

  group('choosing one', () {
    testWidgets('the band is told, and says what it will do', (tester) async {
      await openMixer(tester);
      await pick(tester, CompFigure.charleston.label);
      expect(library.styleFor(TuneRef.of(tune))?.figure, CompFigure.charleston);
      final said =
          (find
                      .byKey(const ValueKey('about-band-figure'))
                      .evaluate()
                      .single
                      .widget
                  as Text)
              .data!;
      expect(said, contains('2 chords'));
      expect(said, contains('the "and" of 2'));
      expect(said, contains('every bar'));
    });

    testWidgets('and it is still there when the tune is opened again', (
      tester,
    ) async {
      await openMixer(tester);
      await pick(tester, CompFigure.offbeat.label);
      await tester.tap(find.byKey(const ValueKey('sheet-done')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await openMixer(tester);
      expect(find.text(CompFigure.offbeat.label), findsWidgets);
      expect(library.styleFor(TuneRef.of(tune))?.figure, CompFigure.offbeat);
    });

    testWidgets('putting it back to the band clears it', (tester) async {
      await openMixer(tester);
      await pick(tester, CompFigure.three.label);
      expect(library.styleFor(TuneRef.of(tune))?.figure, CompFigure.three);
      await pick(tester, 'As it comes');
      expect(library.styleFor(TuneRef.of(tune))?.figure, isNull);
      expect(find.byKey(const ValueKey('about-band-figure')), findsNothing);
    });
  });

  group('it is not lost by the other controls', () {
    testWidgets('changing the drums keeps the figure', (tester) async {
      await openMixer(tester);
      await pick(tester, CompFigure.twice.label);
      await tester.tap(find.byKey(const ValueKey('band-Drums')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Feel.shuffle.label).last);
      await tester.pumpAndSettle();
      final style = library.styleFor(TuneRef.of(tune))!;
      expect(style.drums, Feel.shuffle);
      expect(style.figure, CompFigure.twice, reason: 'not dropped');
    });

    testWidgets('and so does choosing a whole groove', (tester) async {
      await openMixer(tester);
      await pick(tester, CompFigure.held.label);
      await tester.tap(find.byKey(const ValueKey('groove-shuffle')));
      await tester.pumpAndSettle();
      final style = library.styleFor(TuneRef.of(tune))!;
      expect(style.drums, Feel.shuffle);
      expect(style.figure, CompFigure.held);
    });

    testWidgets('a groove chip is still shown as chosen with a figure on', (
      tester,
    ) async {
      await openMixer(tester);
      await pick(tester, CompFigure.held.label);
      await tester.tap(find.byKey(const ValueKey('groove-shuffle')));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('groove-shuffle')),
      );
      expect(
        chip.selected,
        isTrue,
        reason: 'a shuffle with a figure on it is still a shuffle',
      );
    });
  });
}
