// The guitar chord dictionary: every shape a hand can play, and the page
// that shows them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_chord_shapes.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/screens/guitar_chords_screen.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

String written(GuitarVoicing shape) =>
    shape.frets.map((f) => f?.toString() ?? 'x').join(' ');

void main() {
  group('the shapes', () {
    test('the ones everyone plays are there', () {
      expect([
        for (final s in allGuitarShapes(Chord.parse('C'))) written(s),
      ], contains('x 3 2 0 1 0'));
      expect([
        for (final s in allGuitarShapes(Chord.parse('G'))) written(s),
      ], contains('3 2 0 0 0 3'));
      expect([
        for (final s in allGuitarShapes(Chord.parse('Am7'))) written(s),
      ], contains('x 0 2 0 1 0'));
      // The F barre, first finger across the first fret.
      final f = allGuitarShapes(Chord.parse('F7'))
          .firstWhere((s) => written(s) == '1 3 1 2 1 1');
      expect(f.barre?.fret, 1);
      expect(f.barre?.from, 0);
    });

    test('every shape is playable and really the chord', () {
      for (final symbol in [
        'C', 'Am7', 'C^7', 'F7', 'Bb13', 'F#7alt', 'Eo7', 'Gh7', 'Dsus4', //
        'Ab^9', 'Em6', 'B+7',
      ]) {
        final chord = Chord.parse(symbol);
        final shapes = allGuitarShapes(chord);
        expect(shapes, isNotEmpty, reason: symbol);
        final tones = {
          for (final degree in chord.quality.formula)
            chord.pitchClassFor(degree),
        };
        for (final shape in shapes) {
          final where = '$symbol ${written(shape)}';
          final frets = shape.frets.whereType<int>();
          // Every note belongs to the chord, and the root is in the bass.
          for (final pitch in shape.pitches) {
            expect(tones, contains(pitch % 12), reason: where);
          }
          expect(shape.pitches.first % 12, chord.root, reason: where);
          // Three strings at least, running together bar one damped inside.
          expect(shape.pitches.length, greaterThanOrEqualTo(3), reason: where);
          // Within a hand's span, and the 3rd and 7th are in it.
          final stretched = frets.where((f) => f > 0);
          if (stretched.isNotEmpty) {
            final span =
                stretched.reduce(GuitarVoicing.max) -
                stretched.reduce(GuitarVoicing.min);
            expect(span, lessThanOrEqualTo(3), reason: where);
          }
          for (final degree in chord.quality.formula) {
            final number = int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));
            if (number == 3 || number == 7 || number == 6) {
              expect(
                {for (final p in shape.pitches) p % 12},
                contains(chord.pitchClassFor(degree)),
                reason: '$where needs its $degree',
              );
            }
          }
        }
      }
    });

    test('inversions are left out unless asked for', () {
      final chord = Chord.parse('C^7');
      final rooted = allGuitarShapes(chord);
      final all = allGuitarShapes(chord, rootInBass: false);
      expect(all.length, greaterThan(rooted.length));
      expect(
        all.any((s) => s.pitches.first % 12 != chord.root),
        isTrue,
        reason: 'some have another note in the bass',
      );
      expect(bassDegreeOf(chord, rooted.first), 'Root');
    });
  });

  testWidgets('the page opens from Learn and shows a chord every way', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: LearnPage(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    // It's down the Look It Up list, past the end of a phone screen.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('learn-guitar-chords')),
      200,
      // The page's own list, not the search box's text field,
      // which is a scrollable too.
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('learn-guitar-chords')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learn-guitar-chords')));
    await tester.pumpAndSettle();
    expect(find.byType(GuitarChordsScreen), findsOneWidget);
    // C major to start, with the open shape among them.
    expect(find.textContaining('ways to play it'), findsOneWidget);
    expect(find.text('x 3 2 0 1 0'), findsOneWidget);

    // Another chord: A♭Δ7 has no open shape, so it starts up the neck.
    await tester.ensureVisible(find.byKey(const ValueKey('root-A♭')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('root-A♭')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quality-^7')));
    await tester.pumpAndSettle();
    expect(find.textContaining('A♭Δ7', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('shape-0')), findsOneWidget);

    // Inversions add shapes with another note in the bass.
    final rooted = tester
        .widgetList(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key as ValueKey).value}'.startsWith('shape-'),
          ),
        )
        .length;
    await tester.tap(find.byKey(const ValueKey('inversions')));
    await tester.pumpAndSettle();
    expect(find.textContaining('in the bass'), findsWidgets);
    final withInversions = tester
        .widgetList(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey &&
                '${(w.key as ValueKey).value}'.startsWith('shape-'),
          ),
        )
        .length;
    expect(withInversions, greaterThan(rooted));
    expect(tester.takeException(), isNull);
  });
}
