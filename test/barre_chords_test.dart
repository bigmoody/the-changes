import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/music/barre_chords.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/chord_diagram.dart';
import 'package:play_along/settings/app_settings.dart';

String grid(String symbol) {
  final voicing = barreVoicingFor(Chord.parse(symbol))!;
  return voicing.frets.map((f) => f ?? 'x').join('-');
}

void main() {
  test('the barre chords guitarists learn', () {
    expect(grid('F'), '1-3-3-2-1-1'); // E shape
    expect(grid('Fm'), '1-3-3-1-1-1');
    expect(grid('F7'), '1-3-1-2-1-1');
    expect(grid('Bb'), 'x-1-3-3-3-1'); // A shape
    expect(grid('Bbm7'), 'x-1-3-1-2-1');
    expect(grid('C^7'), 'x-3-5-4-5-3');
    expect(grid('Gm7'), '3-5-3-3-3-3');
    // E and A would be open chords at fret 0, so they're barred higher.
    expect(grid('E'), 'x-7-9-9-9-7');
    expect(grid('A'), '5-7-7-6-5-5');
  });

  test('every shape, in every key, is the chord it says', () {
    var shapes = 0;
    for (final quality in chordQualities) {
      for (final root in 'C Db D Eb E F F# G Ab A Bb B'.split(' ')) {
        final chord = Chord.parse('$root${quality.symbols.first}');
        final voicing = barreVoicingFor(chord);
        if (voicing == null) continue;
        shapes++;
        final frets = voicing.frets;
        final barre = voicing.barre!;
        final why = '${chord.display}: ${frets.map((f) => f ?? 'x').join('-')}';

        // Barred where the shape says; nothing under the barre is muted or
        // fretted lower than it.
        expect(barre.fret, inInclusiveRange(1, 12), reason: why);
        for (var s = barre.from; s <= barre.to; s++) {
          expect(frets[s], isNotNull, reason: why);
          expect(frets[s]!, greaterThanOrEqualTo(barre.fret), reason: why);
        }
        // Three fingers besides the barre (a finger can lie across
        // neighbouring strings on the same fret), within four frets.
        var fingers = 0;
        int? lastFret;
        for (var s = 0; s < 6; s++) {
          final f = frets[s];
          final pressed = f != null && f > barre.fret;
          if (pressed && f != lastFret) fingers++;
          lastFret = pressed ? f : null;
        }
        expect(fingers, lessThanOrEqualTo(3), reason: why);
        final played = frets.whereType<int>();
        expect(
          played.reduce((a, b) => a > b ? a : b) - barre.fret,
          lessThanOrEqualTo(3),
          reason: why,
        );

        // The right notes: the chord as written, or — for a chord with no
        // shape of its own, like C13 — its plain version (C7).
        final shown = barreShapeChord(chord)!;
        final sounded = voicing.pitches.map((p) => p % 12).toList();
        expect(sounded.first, chord.root, reason: why);
        expect(
          sounded.toSet(),
          everyElement(isIn(shown.pitchClasses)),
          reason: why,
        );
        for (final degree in [3, 4, 5, 9, 10, 11]) {
          if (shown.quality.intervals.contains(degree)) {
            expect(
              sounded,
              contains((shown.root + degree) % 12),
              reason: '$why is missing its $degree',
            );
          }
        }
      }
    }
    expect(shapes, greaterThan(150));
  });

  test('every chord in the library is barred or has a clear reason not', () {
    final noBarre = <String>{};
    for (final tune in standards) {
      for (final slot in tune.slots) {
        final chord = slot.chord.withoutExtensions;
        if (barreVoicingFor(chord) == null) noBarre.add(chord.quality.name);
      }
    }
    // Only chords that aren't played as barre chords.
    expect(
      noBarre,
      everyElement(
        isIn({
          'Half-diminished',
          'Diminished 7th',
          'Diminished',
          'Augmented',
          'Augmented 7th',
        }),
      ),
    );
  });

  testWidgets('the diagram draws the barre, or falls back to a grip', (
    tester,
  ) async {
    for (final symbol in ['F', 'Cø7']) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Center(
            child: FingeringDiagram(
              chord: Chord.parse(symbol),
              diagram: ChordDiagram.barre,
              height: 120,
            ),
          ),
        ),
      );
      final diagram = tester.widget<GuitarDiagram>(find.byType(GuitarDiagram));
      expect(diagram.barre, isTrue);
      expect(tester.takeException(), isNull);
    }
    // Cø7 has no barre shape, so the usual grip is used.
    expect(barreVoicingFor(Chord.parse('Cø7')), isNull);
    expect(guitarVoicingFor(Chord.parse('Cø7')), isNotNull);
  });
}
