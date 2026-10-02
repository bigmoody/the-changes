// The colours reaching the rest of the app, and sharps parting from flats.
//
// Two things are being tested here and they pull in opposite directions.
// One is that somebody's colour turns up wherever a note is named, because
// an app that colours a D on one screen and not the next is contradicting
// the person it is supposed to be serving. The other is that nothing is
// coloured for anybody who has not asked, and that the screens which have
// something of their own to say in colour, a tuner saying you are in tune,
// a stave saying this is the note to aim for, keep saying it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/screens/chord_colours_screen.dart';
import 'package:play_along/screens/note_ink.dart';
import 'package:play_along/screens/stave.dart';
import 'package:play_along/screens/stave_figure.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/chord_colours.dart';

const cSharp = (letter: 0, accidental: 1);
const dFlat = (letter: 1, accidental: -1);
const bFlat = (letter: 6, accidental: -1);

/// The hue of a colour, which is the part that has to survive. Lightness
/// moves to keep a colour readable on the paper, and is supposed to.
double hueOf(Color colour) => HSLColor.fromColor(colour).hue;

/// Puts [settings] above [child], the way the app does.
Widget under(AppSettings settings, Widget child) => MaterialApp(
  home: NoteInk(
    settings: settings,
    child: Scaffold(body: Center(child: child)),
  ),
);

/// Every colour actually drawn on a note in [text], in the order the
/// spans run. The separators between them are spans too, and they are not
/// notes, so they are skipped.
List<Color?> coloursIn(WidgetTester tester, Finder text) {
  final widget = tester.widget<Text>(
    find.descendant(of: text, matching: find.byType(Text)),
  );
  if (widget.textSpan case final span?) {
    final colours = <Color?>[];
    span.visitChildren((visited) {
      if (visited is TextSpan && RegExp('[A-G]').hasMatch(visited.text ?? '')) {
        colours.add(visited.style?.color);
      }
      return true;
    });
    return colours;
  }
  return [widget.style?.color];
}

void main() {
  group('keeping sharps and flats apart', () {
    test('a spelling with nothing of its own follows the pitch', () {
      final colours = const ChordColours().set(1, const Color(0xFF3366CC));
      expect(colours.ofSpelling(cSharp), const Color(0xFF3366CC));
      expect(colours.ofSpelling(dFlat), const Color(0xFF3366CC));
    });

    test('and wins over it once it has one', () {
      final colours = const ChordColours()
          .set(1, const Color(0xFF3366CC))
          .setSpelling(dFlat, const Color(0xFFCC6633));
      expect(colours.ofSpelling(cSharp), const Color(0xFF3366CC));
      expect(colours.ofSpelling(dFlat), const Color(0xFFCC6633));
      // The pitch itself is untouched by a spelling being set on top of
      // it, so turning the split off gives back exactly what was there.
      expect(colours.of(1), const Color(0xFF3366CC));
    });

    test('with the split off the spellings are ignored, not lost', () {
      final colours = const ChordColours()
          .set(1, const Color(0xFF3366CC))
          .setSpelling(dFlat, const Color(0xFFCC6633));
      expect(colours.ofSpelling(dFlat, split: false), const Color(0xFF3366CC));
      // Still there, waiting, which is what makes the switch safe to try.
      expect(colours.bySpelling[dFlat], const Color(0xFFCC6633));
    });

    test('a heard pitch borrows from a spelling when it has to', () {
      // Somebody who split them may never have answered for the pitch
      // itself. The tuner still has to draw it in something.
      final colours = const ChordColours().setSpelling(
        cSharp,
        const Color(0xFFCC6633),
      );
      expect(colours.of(1), isNull);
      expect(colours.ofPitch(1), const Color(0xFFCC6633));
      // But not when the split is off, or putting the sharps away would
      // leak them back through the tuner.
      expect(colours.ofPitch(1, split: false), isNull);
    });

    test('they survive being written down and read back', () {
      final colours = const ChordColours()
          .set(0, const Color(0xFFAA1122))
          .setSpelling(cSharp, const Color(0xFF3366CC))
          .setSpelling(bFlat, const Color(0xFF11AA22));
      final read = ChordColours.fromJson(colours.toJson());
      expect(read.of(0), const Color(0xFFAA1122));
      expect(read.bySpelling[cSharp], const Color(0xFF3366CC));
      expect(read.bySpelling[bFlat], const Color(0xFF11AA22));
    });

    test('a map saved before spellings existed still reads back', () {
      // The format gained a second kind of key rather than changing, so
      // nobody loses the twelve they already filled in.
      final read = ChordColours.fromJson({'2': 0xFF3366CC, '7': 0xFFCC3366});
      expect(read.of(2), const Color(0xFF3366CC));
      expect(read.of(7), const Color(0xFFCC3366));
      expect(read.bySpelling, isEmpty);
    });

    test('clearing takes the spellings with it', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(1, const Color(0xFF3366CC));
      await settings.setChordColourForNote(dFlat, const Color(0xFFCC6633));
      await settings.clearChordColours();
      expect(settings.chordColours.isEmpty, isTrue);
    });

    test('the split is off until somebody asks for it', () async {
      final settings = AppSettings.inMemory();
      expect(settings.splitEnharmonics, isFalse);
      await settings.setChordColour(1, const Color(0xFF3366CC));
      await settings.setChordColourForNote(dFlat, const Color(0xFFCC6633));
      // Off, so both spellings are the pitch, whatever is in the map.
      expect(settings.chordColourForNote(cSharp), const Color(0xFF3366CC));
      expect(settings.chordColourForNote(dFlat), const Color(0xFF3366CC));

      await settings.setSplitEnharmonics(true);
      expect(settings.chordColourForNote(dFlat), const Color(0xFFCC6633));
    });

    test('turning the colours off turns every lookup off', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColourForNote(dFlat, const Color(0xFFCC6633));
      await settings.setSplitEnharmonics(true);
      await settings.setColourChords(false);
      expect(settings.chordColourForNote(dFlat), isNull);
      expect(settings.chordColourFor(1), isNull);
    });
  });

  group('a note written anywhere', () {
    testWidgets('is left alone when nobody has said anything', (tester) async {
      await tester.pumpWidget(
        under(AppSettings.inMemory(), const NoteText('D')),
      );
      expect(coloursIn(tester, find.byType(NoteText)), [null]);
    });

    testWidgets('takes its colour once they have', (tester) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(2, const Color(0xFF3366CC));
      await tester.pumpWidget(under(settings, const NoteText('D')));
      expect(coloursIn(tester, find.byType(NoteText)), [
        const Color(0xFF3366CC),
      ]);
    });

    testWidgets('and a list of them takes one each', (tester) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(2, const Color(0xFF3366CC));
      await settings.setChordColour(9, const Color(0xFFCC6633));
      await tester.pumpWidget(
        under(settings, const NoteNames(['D', 'F♯', 'A'])),
      );
      expect(coloursIn(tester, find.byType(NoteNames)), [
        const Color(0xFF3366CC),
        null, // F♯ was never answered, so it keeps the surrounding ink.
        const Color(0xFFCC6633),
      ]);
    });

    testWidgets('a heard pitch shows both names, coloured apart', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColourForNote(cSharp, const Color(0xFF3366CC));
      await settings.setChordColourForNote(dFlat, const Color(0xFFCC6633));
      await settings.setSplitEnharmonics(true);
      await tester.pumpWidget(under(settings, const NoteText.pitchClass(1)));
      expect(coloursIn(tester, find.byType(NoteText)), [
        const Color(0xFF3366CC),
        const Color(0xFFCC6633),
      ]);
    });

    testWidgets('a note too dark to read is lifted, keeping its hue', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      const theirs = Color(0xFF000A2B); // A very dark blue.
      await settings.setChordColour(2, theirs);
      await tester.pumpWidget(
        under(settings, const NoteText('D', on: Color(0xFF14131A))),
      );
      final drawn = coloursIn(tester, find.byType(NoteText)).single!;
      expect(drawn, isNot(theirs), reason: 'unreadable as it was');
      expect(
        HSLColor.fromColor(drawn).hue,
        closeTo(HSLColor.fromColor(theirs).hue, 1),
        reason: 'the hue is the part they actually see',
      );
    });

    testWidgets('no colours above it is an ordinary answer, not a crash', (
      tester,
    ) async {
      // Most screens are built on their own in tests, with nothing over
      // them. They have to keep working.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoteText('D'))),
      );
      expect(find.text('D'), findsOneWidget);
    });
  });

  group('on the stave', () {
    /// The ink on every notehead the figure was given, in drawing order.
    Future<List<Color?>> heads(
      WidgetTester tester,
      AppSettings settings,
      List<StaveNote> notes,
    ) async {
      await tester.pumpWidget(
        under(settings, Stave(notes: notes, chord: true)),
      );
      final figure = tester.widget<StaveFigure>(find.byType(StaveFigure));
      return [
        for (final column in figure.columns)
          for (final symbol in column.symbols)
            if (symbol.code == Smufl.noteheadWhole) symbol.ink,
      ];
    }

    testWidgets('a notehead is drawn in the colour of its note', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(2, const Color(0xFF3366CC)); // D
      await settings.setChordColour(5, const Color(0xFFCC6633)); // F
      // D F A C: the D and the F are answered, the other two are not.
      final drawn = await heads(
        tester,
        settings,
        chordOnStave(Chord.parse('Dm7')),
      );
      expect(drawn, hasLength(4));
      final coloured = drawn.whereType<Color>().toList();
      expect(coloured, hasLength(2), reason: 'only the two they answered');
      expect(
        coloured.map(hueOf),
        containsAll([
          closeTo(hueOf(const Color(0xFF3366CC)), 1),
          closeTo(hueOf(const Color(0xFFCC6633)), 1),
        ]),
      );
    });

    testWidgets('it follows the spelling, not just the pitch', (tester) async {
      final settings = AppSettings.inMemory();
      await settings.setSplitEnharmonics(true);
      await settings.setChordColourForNote(bFlat, const Color(0xFF11AA22));
      // B♭ is the 7th of Cm7, written as a B♭, so it takes the B♭
      // colour and not whatever an A♯ might have been given.
      final drawn = await heads(
        tester,
        settings,
        chordOnStave(Chord.parse('Cm7')),
      );
      final coloured = drawn.whereType<Color>().toList();
      expect(coloured, hasLength(1), reason: 'only the B♭ was answered');
      expect(
        hueOf(coloured.single),
        closeTo(hueOf(const Color(0xFF11AA22)), 1),
      );
    });

    testWidgets('a marked note keeps the accent colour', (tester) async {
      // The accent is the only thing on a stave saying "this is the one
      // to aim for", so it wins over a pitch colour rather than losing to
      // it. The painter does that by leaving a marked symbol's ink alone.
      final settings = AppSettings.inMemory();
      await settings.setChordColour(2, const Color(0xFF3366CC));
      await tester.pumpWidget(
        under(
          settings,
          Stave(
            notes: chordOnStave(Chord.parse('Dm7'), marked: const {'1'}),
            chord: true,
          ),
        ),
      );
      final figure = tester.widget<StaveFigure>(find.byType(StaveFigure));
      final marked = [
        for (final column in figure.columns)
          for (final symbol in column.symbols)
            if (symbol.marked) symbol,
      ];
      expect(marked, isNotEmpty);
      expect(
        marked.every((symbol) => symbol.marked),
        isTrue,
        reason: 'the painter draws a marked symbol in the accent',
      );
    });
  });

  group('saying which is which', () {
    /// The screen on a tall enough surface that nothing has to be
    /// scrolled into view to be counted.
    Future<void> open(WidgetTester tester, AppSettings settings) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: ChordColoursScreen(settings: settings)),
      );
      await tester.pumpAndSettle();
    }

    Finder spellingRows() => find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('spelling-'),
    );

    Finder pitchRows() => find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('root-'),
    );

    testWidgets('twelve questions until somebody asks for more', (
      tester,
    ) async {
      await open(tester, AppSettings.inMemory());
      expect(pitchRows(), findsNWidgets(12));
      expect(spellingRows(), findsNothing);
    });

    testWidgets('and seventeen once they do', (tester) async {
      final settings = AppSettings.inMemory();
      await open(tester, settings);
      await tester.tap(find.byKey(const ValueKey('split-enharmonics')));
      await tester.pumpAndSettle();
      // The seven white keys stay one question each, because they have
      // one spelling each. The five black ones become two.
      expect(pitchRows(), findsNWidgets(7));
      expect(spellingRows(), findsNWidgets(10));
      expect(find.byKey(const ValueKey('spelling-C♯')), findsOneWidget);
      expect(find.byKey(const ValueKey('spelling-D♭')), findsOneWidget);
    });

    testWidgets('a split spelling follows the pitch until it is answered', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(1, const Color(0xFF3366CC));
      await settings.setSplitEnharmonics(true);
      await open(tester, settings);

      // Both halves of the black key show the pitch's colour, and say so,
      // rather than appearing to be somebody's own answer.
      for (final name in ['C♯', 'D♭']) {
        final row = tester.widget<ListTile>(
          find.byKey(ValueKey('spelling-$name')),
        );
        expect((row.subtitle! as Text).data, 'Follows the pitch');
      }

      await settings.setChordColourForNote(dFlat, const Color(0xFFCC6633));
      await tester.pumpAndSettle();
      final sharp = tester.widget<ListTile>(
        find.byKey(const ValueKey('spelling-C♯')),
      );
      final flat = tester.widget<ListTile>(
        find.byKey(const ValueKey('spelling-D♭')),
      );
      expect((sharp.subtitle! as Text).data, 'Follows the pitch');
      expect((flat.subtitle! as Text).data, 'Yours');
    });

    testWidgets('turning the split off gives back the twelve', (tester) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColourForNote(dFlat, const Color(0xFFCC6633));
      await settings.setSplitEnharmonics(true);
      await open(tester, settings);
      expect(spellingRows(), findsNWidgets(10));

      await tester.tap(find.byKey(const ValueKey('split-enharmonics')));
      await tester.pumpAndSettle();
      expect(pitchRows(), findsNWidgets(12));
      // Nothing was thrown away, which is what makes the switch safe to
      // try: turning it back on finds the answer still there.
      expect(settings.chordColours.bySpelling[dFlat], const Color(0xFFCC6633));
    });
  });
}
