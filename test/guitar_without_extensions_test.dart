// On the practice screen the guitar grip leaves out the chord's extensions:
// a 7th-chord shape is what you can read and grab at tempo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/chord_diagram.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';

String reduced(String symbol) => Chord.parse(symbol).withoutExtensions.display;

void main() {
  test('extensions come off; the chord itself stays', () {
    expect(reduced('D7#11'), 'D7');
    expect(reduced('Bb13'), 'B♭7');
    expect(reduced('Fm9'), 'Fm7');
    expect(reduced('Eb^9'), 'E♭Δ7');
    expect(reduced('C69'), 'C6');
    expect(reduced('A7alt'), 'A7');
    expect(reduced('G7b9'), 'G7');
    // Already plain: left alone.
    for (final symbol in ['C', 'Cm7', 'C^7', 'Ch7', 'Co7', 'C6', 'Cm6']) {
      expect(reduced(symbol), Chord.parse(symbol).display);
    }
    // An altered 5th is part of the chord, not an extension.
    expect(reduced('C+7'), 'C+7');
    // A slash bass stays.
    expect(reduced('C9/G'), 'C7/G');
  });

  test('every chord in the library has a playable plain shape', () {
    for (final tune in [...standards, ...practiceProgressions]) {
      for (final slot in tune.slots) {
        final plain = slot.chord.withoutExtensions;
        expect(guitarVoicingFor(plain), isNotNull, reason: plain.display);
      }
    }
  });

  testWidgets('the guitar grip for D7♯11 is a D7 shape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title.contains('A" Train')),
          player: PracticePlayer(),
          settings: AppSettings.inMemory(
            ChartInstrument.concert,
            ChordDiagram.guitar,
          ),
        ),
      ),
    );
    await tester.tap(find.text('D7♯11').first);
    await tester.pumpAndSettle();

    final grip = tester.widget<GuitarDiagram>(find.byType(GuitarDiagram));
    expect(grip.chord.display, 'D7');
    // No G♯ (the ♯11) anywhere in the shape.
    final sounded = guitarVoicingFor(grip.chord)!.pitches.map((p) => p % 12);
    expect(sounded, isNot(contains(8)));
    // The readout above it still names the chord as written, with its
    // extensions listed for when you want them.
    expect(find.text('D7♯11'), findsWidgets);
    expect(find.textContaining('ext '), findsOneWidget);
  });

  testWidgets('the keyboard shows D7♯11 as D7, in root position', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title.contains('A" Train')),
          player: PracticePlayer(),
          settings: AppSettings.inMemory(
            ChartInstrument.concert,
            ChordDiagram.keyboard,
          ),
        ),
      ),
    );
    await tester.tap(find.text('D7♯11').first);
    await tester.pumpAndSettle();

    final keys = tester.widget<KeyboardDiagram>(find.byType(KeyboardDiagram));
    expect(keys.chord.display, 'D7');
    // D F♯ A C, from D upwards.
    expect(
      [for (final n in keyboardNotes(keys.chord)) n.semitone],
      [2, 6, 9, 12],
    );
    expect(find.textContaining('ext '), findsOneWidget);
  });
}
