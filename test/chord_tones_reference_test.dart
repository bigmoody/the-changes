// The Chord tones page in Settings: every chord's notes, in any key.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drill_sounds.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/screens/chord_tones_reference_screen.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  testWidgets('opens from Learn, and spells every chord in any key', (
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
    await tester.scrollUntilVisible(find.text('Chord Tones'), 200);
    await tester.ensureVisible(find.text('Chord Tones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chord Tones'));
    await tester.pumpAndSettle();
    expect(find.byType(ChordTonesReferenceScreen), findsOneWidget);

    // In C, a major 7th: C E G B under 1 3 5 7.
    await tester.enterText(find.byType(TextField), 'major 7th');
    await tester.pumpAndSettle();
    expect(find.text('CΔ7'), findsOneWidget);
    for (final text in ['C', 'E', 'G', 'B', '1', '3', '5', '7']) {
      expect(find.text(text), findsWidgets, reason: text);
    }

    // In E♭, a minor 7th, properly spelled: E♭ G♭ B♭ D♭ — not F♯ or C♯.
    await tester.tap(find.byKey(const ValueKey('root-E♭')));
    await tester.enterText(find.byType(TextField), 'minor 7th');
    await tester.pumpAndSettle();
    expect(find.text('E♭m7'), findsOneWidget);
    for (final text in ['E♭', 'G♭', 'B♭', 'D♭', '♭3', '♭7']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('F♯')),
      findsNothing,
    );

    // A 13th chord's 9th and 13th are part of it, beside its 1 3 5 ♭7.
    await tester.enterText(find.byType(TextField), '13th');
    await tester.pumpAndSettle();
    expect(find.text('E♭13'), findsOneWidget);
    expect(find.text('13'), findsWidgets);
    expect(find.text('9'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every chord type is listed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: ChordTonesReferenceScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'half');
    await tester.pumpAndSettle();
    expect(find.text('Cø7'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching chords'), findsOneWidget);
  });

  testWidgets('for a B♭ instrument, each chord says what it sounds as', (
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
        home: ChordTonesReferenceScreen(
          player: PracticePlayer(),
          settings: settings,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'major 7th');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sounds as'), findsNothing);
    expect(find.byTooltip('Hear CΔ7'), findsOneWidget);

    Finder instrument(String name) => find.descendant(
      of: find.byKey(const ValueKey('instrument-key')),
      matching: find.text(name),
    );
    await tester.tap(instrument('B♭'));
    await tester.pumpAndSettle();
    expect(settings.instrument, ChartInstrument.bFlat);
    expect(find.text('Sounds as B♭Δ7'), findsOneWidget);

    await tester.tap(instrument('E♭'));
    await tester.pumpAndSettle();
    expect(find.text('Sounds as E♭Δ7'), findsOneWidget);

    await tester.tap(instrument('F'));
    await tester.pumpAndSettle();
    expect(find.text('Sounds as FΔ7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the arpeggio climbs through the chord, comes back, then rings', () {
    final notes = chordArpeggioSnippet(Chord.parse('Cmaj7'));
    final line = [
      for (final note in notes)
        if (note.start < notes.last.start) note.pitch,
    ];
    // C E G B C, then B G E C.
    expect(line, [48, 52, 55, 59, 60, 59, 55, 52, 48]);
    // The chord together at the end, over the root in the bass.
    final ending = notes.where((n) => n.start == notes.last.start).toList();
    expect(ending.map((n) => n.pitch % 12).toSet(), {0, 4, 7, 11});
    expect(ending.where((n) => n.bass), hasLength(1));

    // A 13th chord reaches its 13th before coming back.
    final c13 = chordArpeggioSnippet(Chord.parse('C13'));
    expect(c13.map((n) => n.pitch), contains(48 + 21));
  });
}
