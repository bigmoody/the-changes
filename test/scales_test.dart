// The Scales & modes page in Settings: every mode, in any key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drill_sounds.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/scales.dart';
import 'package:play_along/screens/chord_tones_reference_screen.dart';
import 'package:play_along/screens/scales_reference_screen.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Mode named(String name) => modes.firstWhere((m) => m.name == name);

/// The pitch class of a spelled note, double flats and sharps included.
int pitchOf(String note) {
  var pc = const {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  }[note[0]]!;
  for (final rune in note.substring(1).runes) {
    pc += switch (String.fromCharCode(rune)) {
      '♭' => -1,
      '♯' => 1,
      '𝄫' => -2,
      '𝄪' => 2,
      _ => throw FormatException(note),
    };
  }
  return pc % 12;
}

void main() {
  group('spelling', () {
    test('modes of C major are the white keys from each note', () {
      expect(named('Dorian').notesFrom('D'), 'D E F G A B C'.split(' '));
      expect(named('Lydian').notesFrom('F'), 'F G A B C D E'.split(' '));
      expect(named('Locrian').notesFrom('B'), 'B C D E F G A'.split(' '));
    });

    test('flat keys spell with flats, one letter per note', () {
      expect(named('Dorian').notesFrom('E♭'), 'E♭ F G♭ A♭ B♭ C D♭'.split(' '));
      expect(
        named('Mixolydian').notesFrom('B♭'),
        'B♭ C D E♭ F G A♭'.split(' '),
      );
    });

    test('a double flat is avoided by respelling the root', () {
      // D♭ Locrian needs E𝄫 and B𝄫; C♯ Locrian doesn't.
      expect(named('Locrian').spelledRoot('D♭'), 'C♯');
      expect(named('Locrian').notesFrom('D♭'), 'C♯ D E F♯ G A B'.split(' '));
      // But D♭ major stays D♭.
      expect(named('Ionian').spelledRoot('D♭'), 'D♭');
    });

    test('scales that aren\'t one note per letter are spelled plainly', () {
      expect(named('Altered').notesFrom('E'), 'E F G G♯ A♯ C D'.split(' '));
      expect(named('Altered').notesFrom('D♭'), 'D♭ D E F G A B'.split(' '));
      expect(named('Whole tone').notesFrom('B'), 'B C♯ D♯ F G A'.split(' '));
      expect(
        named('Whole-half diminished').notesFrom('E♭'),
        'E♭ F G♭ A♭ A B C D'.split(' '),
      );
    });

    test('the altered scale is spelled as its tensions', () {
      // ♭9 ♯9 3 ♯11 ♭13 ♭7 over G7alt.
      expect(named('Altered').notesFrom('G'), 'G A♭ A♯ B C♯ E♭ F'.split(' '));
    });

    test('every mode, in every key, has the right pitches', () {
      for (final mode in modes) {
        for (final root in ChordTonesReferenceScreen.roots) {
          final spelled = mode.spelledRoot(root);
          final rootPc = Chord.parse(spelled).root;
          expect(rootPc, Chord.parse(root).root, reason: '$root ${mode.name}');
          final notes = mode.notesFrom(root);
          expect(notes, hasLength(mode.degrees.length));
          for (var i = 0; i < notes.length; i++) {
            expect(
              pitchOf(notes[i]),
              (rootPc + mode.semitones[i]) % 12,
              reason: '$root ${mode.name}: ${notes[i]}',
            );
          }
          final doubles = notes.where(
            (n) => n.contains('𝄫') || n.contains('𝄪'),
          );
          // Only where theory insists: C Ultralocrian's F♭ and B𝄫 (the
          // 𝄫7 of C°7).
          if (mode.name != 'Ultralocrian') {
            expect(doubles, isEmpty, reason: '$spelled ${mode.name}: $notes');
          }
          // Seven-note modes use each letter once, bar the altered scale,
          // spelled as its tensions: ♭9 and ♯9 are both 9ths.
          if (mode.degrees.length == 7 && mode.name != 'Altered') {
            expect(
              notes.map((n) => n[0]).toSet(),
              hasLength(7),
              reason: '$root ${mode.name}: $notes',
            );
          }
          // The blues scale is the exception, and is the exception on
          // purpose: it has the ♭3 in it and is played over a dominant
          // chord with a natural 3rd. That rub is the entire idiom, and
          // a rule that made it go away would be the wrong rule.
          if (mode.name == 'Blues scale') continue;
          // The chord it goes with fits inside it (the plain chord, at
          // least: a 7alt's tensions are the scale's own).
          final chordPcs = mode.chordOn(root).withoutExtensions.pitchClasses;
          final scalePcs = {for (final s in mode.semitones) (rootPc + s) % 12};
          expect(
            scalePcs.containsAll(
              mode.name == 'Altered'
                  ? chordPcs.toSet().difference({(rootPc + 7) % 12})
                  : chordPcs,
            ),
            isTrue,
            reason: '${mode.name} over ${mode.chordOn(root).display}',
          );
        }
      }
    });

    test('each mode says which scale it comes from', () {
      expect(named('Dorian').parentFrom('D'), 'Mode 2 of C major');
      expect(named('Altered').parentFrom('B'), 'Mode 7 of C melodic minor');
      expect(
        named('Lydian dominant').parentFrom('E♭'),
        'Mode 4 of B♭ melodic minor',
      );
      expect(
        named('Phrygian dominant').parentFrom('G'),
        'Mode 5 of C harmonic minor',
      );
    });
  });

  test('the sound: just the scale, up an octave and back down', () {
    final mode = named('Dorian');
    final notes = modeSnippet(mode.semitones, mode.chordOn('D').root);
    // D E F G A B C D, and back down; one note at a time, no bass or chord.
    expect(notes.map((n) => n.pitch).toList(), [
      62,
      64,
      65,
      67,
      69,
      71,
      72,
      74,
      72,
      71,
      69,
      67,
      65,
      64,
      62,
    ]);
    expect(notes.where((n) => n.bass), isEmpty);
    expect(notes.map((n) => n.start).toSet(), hasLength(notes.length));
  });

  testWidgets('opens from Learn; a B♭ player sees what each mode sounds as', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: LearnPage(player: PracticePlayer(), settings: settings),
      ),
    );
    // The Learn page keeps growing, and this card is near the bottom of
    // it: a hundred pixels at a time ran out of iterations once the page
    // passed five thousand pixels long.
    await tester.scrollUntilVisible(find.text('Scales & Modes'), 400);
    // Built is not the same as on screen: it can stop with the card still
    // under the bottom edge, and a tap there lands on nothing.
    await tester.ensureVisible(find.text('Scales & Modes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scales & Modes'));
    await tester.pumpAndSettle();
    expect(find.byType(ScalesReferenceScreen), findsOneWidget);

    // In D, the major modes: D Dorian is the white keys, over Dm7.
    // The keys are a round now, so D is two semitones along from C.
    await tester.tap(find.byKey(const ValueKey('round-key-2')));
    await tester.tap(find.byKey(const ValueKey('family-major')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('D Dorian'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Mode 2 of C major'), findsOneWidget);
    expect(find.byTooltip('Hear D Dorian'), findsOneWidget);
    expect(find.textContaining('Sounds as'), findsNothing);
    expect(find.text('Over Dm7', findRichText: true), findsOneWidget);

    // Only the major family's modes are listed.
    expect(find.textContaining('melodic minor'), findsNothing);

    // A B♭ player's written D Dorian sounds as C Dorian.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('instrument-key')),
      -150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('instrument-key')),
        matching: find.text('B♭'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.instrument, ChartInstrument.bFlat);
    await tester.scrollUntilVisible(
      find.text('D Dorian'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Sounds as C Dorian'), findsOneWidget);

    // Every family's chip shows just that family.
    await tester.ensureVisible(find.byKey(const ValueKey('family-symmetric')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('family-symmetric')));
    await tester.pumpAndSettle();
    expect(find.text('D Whole tone'), findsOneWidget);
    expect(find.text('D Dorian'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('the twelve keys round', () {
    Future<void> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 1400) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
          home: ScalesReferenceScreen(
            player: PracticePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('all twelve keys are there, chromatic to begin with', (
      tester,
    ) async {
      // Chromatic here and not the cycle, because this is somewhere you
      // look a key up as well as somewhere you work.
      await open(tester);
      for (var move = 0; move < 12; move++) {
        expect(find.byKey(ValueKey('round-key-$move')), findsOneWidget);
      }
      expect(find.text('C'), findsWidgets);
      expect(find.text('D♭'), findsWidgets);
    });

    testWidgets('next key steps up a semitone and the modes follow', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('family-major')));
      await tester.pumpAndSettle();
      expect(find.text('C Ionian'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(find.text('D♭ Ionian'), findsOneWidget);
    });

    testWidgets('back from the first key wraps to the last', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('family-major')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('previous-key')));
      await tester.pumpAndSettle();
      expect(find.text('B Ionian'), findsOneWidget);
    });

    testWidgets('the order can be changed to the cycle', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('key-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Round the cycle').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('family-major')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(
        find.text('F Ionian'),
        findsOneWidget,
        reason: 'a fourth up, not a semitone',
      );
    });

    testWidgets('a key left behind is marked as been through', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('round-key-0')),
      );
      expect(chip.avatar, isNotNull);
    });
  });
}
