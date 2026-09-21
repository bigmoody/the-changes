// Enclosures: the notes that go round a target before landing on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/screens/chord_diagram.dart';
import 'package:play_along/screens/enclosures_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/enclosures.dart';
import 'package:play_along/screens/stave.dart';

/// The names of an enclosure onto [target], in playing order.
List<String> names(
  Enclosure enclosure, {
  int target = 64, // E4
  String targetName = 'E',
  List<String> scale = const ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
}) => [
  for (final note in enclosureOn(
    enclosure,
    target: target,
    targetName: targetName,
    scale: scale,
  ))
    note.name,
];

List<int> pitches(
  Enclosure enclosure, {
  int target = 64,
  List<String> scale = const ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
}) => [
  for (final note in enclosureOn(
    enclosure,
    target: target,
    targetName: 'E',
    scale: scale,
  ))
    note.pitch,
];

Enclosure named(String name) => enclosures.firstWhere((e) => e.name == name);

void main() {
  group('the shapes', () {
    test('above and below is a semitone each side', () {
      expect(pitches(named('Above and Below')), [65, 63, 64]);
      expect(names(named('Above and Below')), ['F', 'D♯', 'E']);
    });

    test('the scale note above depends on the scale', () {
      // In C the note above E is F; in D major it is F♯.
      expect(names(named('Scale Above, Semitone Below')), ['F', 'D♯', 'E']);
      expect(
        names(
          named('Scale Above, Semitone Below'),
          scale: const ['D', 'E', 'F♯', 'G', 'A', 'B', 'C♯'],
        ),
        ['F♯', 'D♯', 'E'],
      );
    });

    test('two from below climbs two semitones to it', () {
      expect(pitches(named('Two From Below')), [62, 63, 64]);
      expect(names(named('Two From Below')), ['D', 'D♯', 'E']);
    });

    test('two from above comes down to it', () {
      expect(pitches(named('Two From Above')), [66, 65, 64]);
      expect(names(named('Two From Above')), ['G♭', 'F', 'E']);
    });

    test('every shape ends on the target and nothing else does', () {
      for (final enclosure in enclosures) {
        final notes = enclosureOn(
          enclosure,
          target: 64,
          targetName: 'E',
          scale: const ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
        );
        expect(notes.last.pitch, 64, reason: enclosure.name);
        expect(notes.last.isTarget, isTrue);
        expect(notes.length, enclosure.length);
        expect(
          notes.take(notes.length - 1).every((n) => !n.isTarget),
          isTrue,
          reason: '${enclosure.name} touches the target early',
        );
      }
    });

    test('a note approached from below is a sharp, from above a flat', () {
      // The same pitch, spelled by where it is going.
      expect(names(named('Above and Below'))[1], 'D♯');
      expect(names(named('Two From Above')).first, 'G♭');
    });
  });

  group('the scale for a chord', () {
    test('a minor 7th gets Dorian, a major 7th Ionian', () {
      expect(scaleFor(Chord.parse('Dm7')).first, 'D');
      expect(scaleFor(Chord.parse('Dm7')), contains('C'));
      expect(scaleFor(Chord.parse('C^7')), contains('B'));
    });

    test('a dominant 7th gets a scale with a flat 7', () {
      final scale = scaleFor(Chord.parse('G7'));
      expect(scale, isNotEmpty);
      expect(scale, contains('F'), reason: 'not F♯');
    });
  });

  _screenTests();

  group('on the stave', () {
    test('a line that steps down then up is written where it sounds', () {
      // F, D♯, E: down a minor third, then up a semitone.
      final line = enclosureOn(
        named('Above and Below'),
        target: 64,
        targetName: 'E',
        scale: const ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
      );
      final notes = lineOnStave([
        for (final note in line) (pitch: note.pitch, name: note.name),
      ]);
      // In treble, E4 is the bottom line: step 0. F4 is the space above,
      // D♯4 the space below.
      expect([for (final n in notes) n.step], [1, -1, 0]);
      expect([for (final n in notes) n.accidental], [0, 1, 0]);
    });

    test('a sharp that sounds as the next letter stays on its own line', () {
      // B♯4 sounds as C5 but is written on the B line.
      final notes = lineOnStave([(pitch: 72, name: 'B♯')]);
      expect(notes.single.step, 4, reason: 'the middle line, not the space');
      expect(notes.single.accidental, 1);
    });

    test('an octave leap is an octave on the page', () {
      final notes = lineOnStave([
        (pitch: 64, name: 'E'),
        (pitch: 76, name: 'E'),
      ]);
      expect(notes[1].step - notes[0].step, 7);
    });
  });
}

void _screenTests() {
  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(402, 874) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: EnclosuresScreen(
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it aims at a note the chord has actually got', (tester) async {
    // The complaint this guards against: it opened on a Dm7 aiming at "the
    // 3", and wrote F♯, a note that chord hasn't got.
    await open(tester);
    expect(find.textContaining('Dm7'), findsWidgets);
    expect(find.textContaining('F♯'), findsNothing);
    expect(find.textContaining('Aiming at the ♭3 of Dm7: F.'), findsOneWidget);
  });

  testWidgets('every shape is shown, written out and under the fingers', (
    tester,
  ) async {
    await open(tester);
    // The list builds as it scrolls, so they're collected on the way down.
    final seen = <String>{};
    var staves = 0;
    for (var i = 0; i < 30; i++) {
      for (final enclosure in enclosures) {
        if (find
            .byKey(ValueKey('enclosure-${enclosure.name}'))
            .evaluate()
            .isNotEmpty) {
          seen.add(enclosure.name);
        }
      }
      staves = staves > 0 ? staves : find.byType(Stave).evaluate().length;
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
    }
    expect(seen, {for (final e in enclosures) e.name});
    expect(staves, greaterThan(0), reason: 'written out as well as named');
  });

  testWidgets('changing the chord changes the notes', (tester) async {
    await open(tester);
    expect(find.textContaining('Aiming at the ♭3 of Dm7: F.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pick-^7')));
    await tester.pumpAndSettle();
    // A Δ7 has a major 3rd, so the same chip now means F♯.
    expect(find.textContaining('Aiming at the 3 of DΔ7: F♯.'), findsOneWidget);
  });

  testWidgets('the neck is drawn for guitar and bass', (tester) async {
    await open(tester);
    await tester.tap(find.text('Guitar'));
    await tester.pumpAndSettle();
    expect(find.byType(ArpeggioDiagram), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Bass'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
