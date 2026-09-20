// The guide-tone exercise in Learn.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guide_tones.dart';
import 'package:play_along/screens/guide_tones_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(402, 874) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: GuideTonesScreen(
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the lesson itself: a ii–V–I barely moves', () {
    final lines = guideTonesThrough([
      Chord.parse('Dm7'),
      Chord.parse('G7'),
      Chord.parse('C^7'),
    ]);
    // Two semitones in the whole progression, and nothing else.
    expect(lines[1].totalMove, 1);
    expect(lines[2].totalMove, 1);
    // One line holds while the other falls, each time.
    expect(lines[1].upperHeld ^ lines[1].lowerHeld, isTrue);
    expect(lines[2].upperHeld ^ lines[2].lowerHeld, isTrue);
  });

  testWidgets('it opens on a ii–V–I in C and names the chords', (tester) async {
    await _open(tester);
    expect(find.textContaining('Dm7  G7  CΔ7'), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-tone-stave')), findsOneWidget);
    expect(find.text('held'), findsWidgets);
    // The first chord has nothing to have moved from.
    expect(find.text('start here'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing key moves the whole thing', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('guide-F')));
    await tester.pumpAndSettle();
    // ii–V–I in F is Gm7 C7 FΔ7.
    expect(find.textContaining('Gm7  C7  FΔ7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every set of changes draws without complaint', (tester) async {
    await _open(tester);
    for (final name in ['Minor ii–V–i', 'Turnaround', 'Round the Cycle']) {
      await tester.tap(find.byKey(ValueKey('guide-$name')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guide-tone-stave')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: name);
    }
  });

  testWidgets('the guitar and bass views draw too', (tester) async {
    await _open(tester);
    for (final under in ['Guitar', 'Bass']) {
      await tester.tap(find.text(under));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: under);
    }
  });
}
