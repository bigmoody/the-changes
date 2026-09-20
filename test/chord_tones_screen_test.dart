// The chord-tone drill screen, driven the way a player would: read the chord,
// tap the notes, see the verdict.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_drill.dart';
import 'package:play_along/screens/chord_tones_screen.dart';
import 'package:play_along/settings/app_settings.dart';

/// Opens the drills, switched to Aim for unless [aim] is false (they start
/// on Spell it).
Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  bool aim = true,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: ChordTonesScreen(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  if (aim) {
    await tester.tap(find.text('Aim For'));
    await tester.pumpAndSettle();
  }
}

/// The chord on the question card.
Chord _shownChord(WidgetTester tester) => Chord.parse(
  tester.widget<Text>(find.byKey(const ValueKey('drill-chord'))).data!,
);

Future<void> _tapNote(WidgetTester tester, int pitchClass) async {
  final key = find.byKey(ValueKey('pad-$pitchClass'));
  await tester.ensureVisible(key);
  await tester.tap(key);
  await tester.pump();
}

void main() {
  testWidgets('the right 3rd is marked right, straight away', (tester) async {
    await _open(tester);
    // "Aim for the 3rd" through a ii–V–I.
    final chord = _shownChord(tester);
    final third = chord.pitchClassFor(degreeFor(chord, 3)!);

    await _tapNote(tester, third);

    expect(find.textContaining('Right'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    // The answer, spelled as the chord spells it.
    expect(
      find.textContaining(
        chord.noteFor(degreeFor(chord, 3)!),
        findRichText: true,
      ),
      findsWidgets,
    );
  });

  testWidgets('a wrong note is marked, and the right one shown', (
    tester,
  ) async {
    await _open(tester);
    final chord = _shownChord(tester);
    final third = chord.pitchClassFor(degreeFor(chord, 3)!);

    await _tapNote(tester, (third + 1) % 12);

    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    // Next moves on to the next chord of the progression.
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Not quite'), findsNothing);
  });

  testWidgets('spelling a chord waits for every note', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Spell It'));
    await tester.pump();

    final chord = _shownChord(tester);
    final notes = chord.pitchClasses.toSet().toList();
    for (final note in notes.take(notes.length - 1)) {
      await _tapNote(tester, note);
      expect(find.textContaining('Right'), findsNothing, reason: 'too soon');
    }
    await _tapNote(tester, notes.last);
    expect(find.textContaining('Right'), findsOneWidget);
  });

  for (final (name, size) in [
    ('iPhone SE', Size(375, 667)),
    ('iPad', Size(820, 1180)),
  ]) {
    testWidgets('fits on an $name', (tester) async {
      await _open(tester, size: size);
      // Answer one so the verdict, notes and diagram are all on screen too.
      final chord = _shownChord(tester);
      await _tapNote(tester, chord.pitchClassFor(degreeFor(chord, 3)!));
      expect(tester.takeException(), isNull);
    });
  }
}
