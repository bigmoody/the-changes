// Notes on the stave: where each goes, spelled as the chord or scale
// spells it, and the staves on the pages that show them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/scales.dart';
import 'package:play_along/screens/chord_tones_reference_screen.dart';
import 'package:play_along/screens/chord_tones_screen.dart';
import 'package:play_along/screens/scales_reference_screen.dart';
import 'package:play_along/screens/stave.dart';
import 'package:play_along/screens/stave_figure.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

List<int> steps(List<StaveNote> notes) => [for (final n in notes) n.step];
List<int> accidentals(List<StaveNote> notes) => [
  for (final n in notes) n.accidental,
];

void main() {
  _repaintTests();
  group('chords', () {
    test('CΔ7: middle C on its ledger line, then E G B up the stave', () {
      final notes = chordOnStave(Chord.parse('C^7'));
      // Steps up from the bottom line (E4): C4 is two below.
      expect(steps(notes), [-2, 0, 2, 4]);
      expect(accidentals(notes), [0, 0, 0, 0]);
    });

    test('flats and sharps as the chord spells them', () {
      expect(accidentals(chordOnStave(Chord.parse('Ebm7'))), [-1, -1, -1, -1]);
      // B°7: B D F A♭ — a flat on the A, not a sharp on G.
      final dim = chordOnStave(Chord.parse('Bo7'));
      expect(accidentals(dim), [0, 0, 0, -1]);
      // F♯7♯9's 9th is G𝄪: a double sharp.
      expect(
        accidentals(chordOnStave(Chord.parse('F#7#9'))),
        containsAll([1, 2]),
      );
    });

    test('a 9th goes a ninth up, and sits as low as the stave allows', () {
      final notes = chordOnStave(Chord.parse('C9'));
      expect(steps(notes), [-2, 0, 2, 4, 6]); // C E G B♭ D
      // A high chord comes down an octave rather than climbing off the top.
      final a = chordOnStave(Chord.parse('A^7'));
      expect(steps(a).reduce((x, y) => x > y ? x : y), lessThanOrEqualTo(10));
    });

    test('in bass clef, G sits on the bottom line', () {
      expect(steps(chordOnStave(Chord.parse('G'), clef: Clef.bass)), [0, 2, 4]);
    });

    test('a note to aim for can be added and marked', () {
      final notes = chordOnStave(
        Chord.parse('Dm7'),
        extra: ['9'],
        marked: {'9'},
      );
      expect(notes, hasLength(5));
      expect(notes.where((n) => n.marked), hasLength(1));
      expect(notes.last.marked, isTrue, reason: 'the 9th, on top');
    });
  });

  group('scales', () {
    test('a scale climbs one letter a note, root to root', () {
      final dorian = modes.firstWhere((m) => m.name == 'Dorian');
      final notes = scaleOnStave(dorian.notesFrom('E♭'));
      // E♭ shares E's line: a flat changes the note, not its place.
      expect(steps(notes), [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(accidentals(notes), [-1, 0, -1, -1, -1, 0, -1, -1]);
    });

    test('a scale with two of a letter keeps them on one line', () {
      // E altered: E F G G♯ A♯ C D E.
      final altered = modes.firstWhere((m) => m.name == 'Altered');
      final notes = scaleOnStave(altered.notesFrom('E'));
      expect(steps(notes), [0, 1, 2, 2, 3, 5, 6, 7]);
      expect(accidentals(notes), [0, 0, 0, 1, 1, 0, 0, 0]);
    });
  });

  group('on the pages', () {
    Future<void> open(WidgetTester tester, Widget page) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: appTheme(Brightness.light), home: page),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('every chord tones card has its chord on a stave', (
      tester,
    ) async {
      await open(
        tester,
        ChordTonesReferenceScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      );
      expect(find.byKey(const ValueKey('chord-stave')), findsWidgets);
      // On the bass, in bass clef.
      await tester.tap(find.text('Bass'));
      await tester.pumpAndSettle();
      final stave = tester.widget<Stave>(
        find.byKey(const ValueKey('chord-stave')).first,
      );
      expect(stave.clef, Clef.bass);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every mode is written out on a stave', (tester) async {
      await open(
        tester,
        ScalesReferenceScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      );
      final stave = tester.widget<Stave>(
        find.byKey(const ValueKey('scale-stave')).first,
      );
      // C Ionian: C to C, its 7th (B) marked.
      expect(stave.notes, hasLength(8));
      expect([for (final n in stave.notes) n.marked].indexOf(true), 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the quiz shows the chord on a stave once answered', (
      tester,
    ) async {
      await open(
        tester,
        ChordTonesScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      );
      expect(find.byKey(const ValueKey('quiz-stave')), findsNothing);
      await tester.tap(find.text('Aim For'));
      await tester.pumpAndSettle();
      final pad = find.byKey(const ValueKey('pad-0'));
      await tester.ensureVisible(pad);
      await tester.tap(pad);
      await tester.pumpAndSettle();
      final stave = tester.widget<Stave>(
        find.byKey(const ValueKey('quiz-stave')),
      );
      // The 3rd it asked for, in pencil.
      expect(stave.notes.where((n) => n.marked), hasLength(1));
    });
  });
}

/// The figure's painter, so what it decides about redrawing can be asked
/// directly rather than inferred from pixels.
CustomPainter _painterIn(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(StaveFigure),
            matching: find.byType(CustomPaint),
          )
          .first,
    )
    .painter!;

Future<void> _show(WidgetTester tester, List<StaveColumn> columns) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: Scaffold(
        body: StaveFigure(columns: columns, clef: Clef.treble),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Four quavers, with the one at [marked] in the accent colour.
List<StaveColumn> _four(int marked) => [
  for (var i = 0; i < 4; i++)
    StaveColumn([
      sym(Smufl.noteheadBlack, step: i.toDouble(), marked: i == marked),
    ], stem: true),
];

void _repaintTests() {
  group('redrawing the figure', () {
    testWidgets('marking a different note redraws it', (tester) async {
      // The bug this guards against: the painter decided whether to
      // redraw from the figure's size alone, so moving the marks around
      // a run of the same length changed nothing on screen. On the
      // phrasing screen that made the weight buttons appear dead.
      await _show(tester, _four(0));
      final before = _painterIn(tester);
      await _show(tester, _four(2));
      final after = _painterIn(tester);
      expect(after.shouldRepaint(before), isTrue);
    });

    testWidgets('swapping a glyph for one the same width redraws it', (
      tester,
    ) async {
      await _show(tester, _four(0));
      final before = _painterIn(tester);
      await _show(tester, [
        StaveColumn([sym(Smufl.restQuarter)], stem: false),
        ..._four(0).skip(1),
      ]);
      expect(_painterIn(tester).shouldRepaint(before), isTrue);
    });

    testWidgets('and an identical figure is left alone', (tester) async {
      // The check still has to be worth having: redrawing everything on
      // every build would make it pointless.
      await _show(tester, _four(1));
      final before = _painterIn(tester);
      await _show(tester, _four(1));
      expect(_painterIn(tester).shouldRepaint(before), isFalse);
    });
  });
}
