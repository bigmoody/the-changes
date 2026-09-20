// The piano diagram shows chords in root position, so G7 reads G B D F —
// never D F G B, which looks like an inversion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/screens/chord_diagram.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

List<int> semitones(String symbol) => [
  for (final note in keyboardNotes(Chord.parse(symbol))) note.semitone,
];

List<KeyRole> roles(String symbol) => [
  for (final note in keyboardNotes(Chord.parse(symbol))) note.role,
];

void main() {
  test('root position, from the root up', () {
    expect(semitones('G7'), [7, 11, 14, 17]); // G B D F
    expect(semitones('Cmaj7'), [0, 4, 7, 11]);
    expect(semitones('Bbm7'), [10, 13, 17, 20]); // B♭ D♭ F A♭
    expect(roles('G7').first, KeyRole.root);
    for (final symbol in ['C7', 'F#m7b5', 'Ab^7', 'Bo7', 'Eb6']) {
      final notes = semitones(symbol);
      expect(notes, [...notes]..sort(), reason: '$symbol goes upwards');
      expect(notes.first, lessThan(12), reason: '$symbol starts low');
    }
  });

  test('extensions stack above the chord, as rings', () {
    expect(semitones('C13'), [0, 4, 7, 10, 14, 21]); // …B♭, then D, A
    expect(roles('C13'), [
      KeyRole.root,
      KeyRole.tone,
      KeyRole.tone,
      KeyRole.tone,
      KeyRole.extension,
      KeyRole.extension,
    ]);
  });

  test('a slash bass goes underneath', () {
    // D/E♭: E♭ below the D chord.
    expect(semitones('D/Eb'), [3, 14, 18, 21]);
    expect(roles('D/Eb').first, KeyRole.bass);
    // C/E: E, then C E G above it.
    expect(semitones('C/E'), [4, 12, 16, 19]);
  });

  testWidgets('big chords get a wider keyboard, and draw cleanly', (
    tester,
  ) async {
    expect(
      KeyboardDiagram.aspectFor(Chord.parse('C13')),
      greaterThan(KeyboardDiagram.aspectFor(Chord.parse('C7'))),
    );
    for (final symbol in ['G7', 'C13', 'D/Eb', 'B7alt', 'F#m7b5']) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: Center(
            child: FingeringDiagram(
              chord: Chord.parse(symbol),
              diagram: ChordDiagram.keyboard,
              height: 60,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: symbol);
    }
  });
}
