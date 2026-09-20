// Guitar arpeggio shapes: every chord, from the 6th and 5th strings, in one
// position, climbing through each chord tone in turn.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drill_sounds.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/fretboard_arpeggio.dart';
import 'package:play_along/screens/chord_diagram.dart';
import 'package:play_along/screens/chord_tones_reference_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// "string:fret" for each note, strings numbered as guitarists do.
String frets(FretArpeggio shape) =>
    [for (final n in shape.notes) '${6 - n.string}:${n.fret}'].join(' ');

void main() {
  test('the standard shapes', () {
    // CΔ7 from the 8th fret: C E G B C E G B C across frets 7–10.
    expect(
      frets(guitarArpeggio(Chord.parse('C^7'), rootString: 6)!),
      '6:8 5:7 5:10 4:9 4:10 3:9 2:8 1:7 1:8',
    );
    // Cm7 in 8th position, the ♭3 under the little finger.
    expect(
      frets(guitarArpeggio(Chord.parse('Cm7'), rootString: 6)!),
      '6:8 6:11 5:10 4:8 4:10 3:8 2:8 2:11 1:8',
    );
    // CΔ7 from the 3rd fret of the A string.
    expect(
      frets(guitarArpeggio(Chord.parse('C^7'), rootString: 5)!),
      '5:3 4:2 4:5 3:4 3:5 2:5 1:3',
    );
    // Degrees are marked: the root, 3rd, 5th and 7th.
    expect(
      guitarArpeggio(
        Chord.parse('Cm7'),
        rootString: 6,
      )!.notes.take(4).map((n) => n.degree),
      ['1', '♭3', '5', '♭7'],
    );
  });

  test('the standard bass shapes', () {
    String bass(String chord, int string) => [
      for (final n in bassArpeggio(
        Chord.parse(chord),
        rootString: string,
      )!.notes)
        '${'EADG'[n.string]}${n.fret}',
    ].join(' ');
    expect(bass('G7', 4), 'E3 A2 A5 D3 D5 G4');
    expect(bass('C^7', 4), 'E8 A7 A10 D9 D10 G9');
    expect(bass('Cm7', 3), 'A3 A6 D5 G3 G5');
  });

  test('every chord, in every key, from both strings, is playable', () {
    const roots = [
      'C',
      'Db',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
    ];
    for (final quality in chordQualities) {
      for (final root in roots) {
        final chord = Chord.parse('$root${quality.symbols.first}');
        final tones = {
          for (final d in quality.formula)
            (chord.root + degreeToSemitones(d)) % 12,
        };
        for (final (string, tuning) in [
          (6, guitarOpenStrings),
          (5, guitarOpenStrings),
          (4, bassOpenStrings),
          (3, bassOpenStrings),
        ]) {
          final shape = fretArpeggio(chord, tuning, rootString: string);
          final what =
              '${chord.display} on ${tuning.length} strings from the '
              '${string}th: ${shape == null ? 'none' : frets(shape)}';
          expect(shape, isNotNull, reason: what);
          final notes = shape!.notes;
          // Starts on the root, on that string.
          expect(notes.first.string, tuning.length - string, reason: what);
          expect(notes.first.pitch % 12, chord.root, reason: what);
          // Each note is where it says, and a note of the chord.
          for (final n in notes) {
            expect(n.pitch, tuning[n.string] + n.fret, reason: what);
            expect(tones, contains(n.pitch % 12), reason: what);
          }
          // Climbing: up in pitch, never back to a lower string.
          for (var i = 1; i < notes.length; i++) {
            expect(
              notes[i].pitch,
              greaterThan(notes[i - 1].pitch),
              reason: what,
            );
            expect(
              notes[i].string,
              greaterThanOrEqualTo(notes[i - 1].string),
              reason: what,
            );
          }
          // Every note of the chord, at least an octave, in one position.
          expect(notes.map((n) => n.pitch % 12).toSet(), tones, reason: what);
          expect(notes.length, greaterThan(tones.length), reason: what);
          expect(
            shape.highestFret - shape.lowestFret,
            lessThanOrEqualTo(4),
            reason: what,
          );
          expect(shape.lowestFret, greaterThanOrEqualTo(1), reason: what);
        }
      }
    }
  });

  test('the sound goes up the shape and back down', () {
    final shape = guitarArpeggio(Chord.parse('C^7'), rootString: 6)!;
    final notes = fretArpeggioSnippet(shape);
    final up = [for (final n in shape.notes) n.pitch];
    expect(notes.map((n) => n.pitch), [...up, ...up.reversed.skip(1)]);
    expect(notes.where((n) => n.bass), isEmpty);
  });

  for (final (name, size) in [
    ('iPhone SE', Size(375, 667)),
    ('iPhone 15', Size(393, 852)),
  ]) {
    testWidgets('the Guitar view shows both shapes on a $name', (tester) async {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final settings = AppSettings.inMemory(ChartInstrument.bFlat);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: ChordTonesReferenceScreen(
            player: PracticePlayer(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('instrument-key')), findsOneWidget);
      expect(find.byType(ArpeggioDiagram), findsNothing);

      await tester.tap(find.text('Guitar'));
      await tester.pumpAndSettle();
      // The guitar reads at concert pitch: no transposing.
      expect(find.byKey(const ValueKey('instrument-key')), findsNothing);
      expect(find.textContaining('Sounds as'), findsNothing);
      expect(settings.instrument, ChartInstrument.bFlat);

      // The busiest chords still fit: 13ths and alt.
      for (final search in ['half', '13th', 'altered']) {
        await tester.enterText(find.byType(TextField), search);
        await tester.pumpAndSettle();
        expect(find.byType(ArpeggioDiagram), findsNWidgets(2), reason: search);
        expect(find.text('Root on 6th string'), findsOneWidget);
        expect(find.text('Root on 5th string'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: search);
      }
      await tester.tap(find.byKey(const ValueKey('shape-5')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Bass view: four strings, from the E and A strings', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(375, 667) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ChordTonesReferenceScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(ChartInstrument.eFlat),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bass'));
    await tester.pumpAndSettle();
    // Bass reads at concert pitch too.
    expect(find.byKey(const ValueKey('instrument-key')), findsNothing);
    for (final search in ['half', '13th', 'altered']) {
      await tester.enterText(find.byType(TextField), search);
      await tester.pumpAndSettle();
      final diagrams = tester
          .widgetList<ArpeggioDiagram>(find.byType(ArpeggioDiagram))
          .toList();
      expect(diagrams, hasLength(2), reason: search);
      expect(diagrams.every((d) => d.shape.isBass), isTrue);
      expect(find.text('Root on E string'), findsOneWidget);
      expect(find.text('Root on A string'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: search);
    }
    // Strings as far apart as the guitar's: narrower, not taller.
    final bassWidth = tester.getSize(find.byType(ArpeggioDiagram).first).width;
    await tester.tap(find.text('Guitar'));
    await tester.pumpAndSettle();
    final guitarWidth = tester
        .getSize(find.byType(ArpeggioDiagram).first)
        .width;
    expect(bassWidth / guitarWidth, closeTo(4.4 / 6.4, 0.01));
    await tester.tap(find.text('Bass'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shape-3')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bassists start on the Bass view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ChordTonesReferenceScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(
            ChartInstrument.concert,
            ChordDiagram.bass,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ArpeggioDiagram>(find.byType(ArpeggioDiagram).first)
          .shape
          .isBass,
      isTrue,
    );
  });

  testWidgets('guitarists start on the Guitar view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ChordTonesReferenceScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(
            ChartInstrument.concert,
            ChordDiagram.guitar,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArpeggioDiagram), findsWidgets);
  });
}
