// How a walking line is built, on screen.
//
// The shapes are tested where they are made. What matters here is that
// the screen shows the band's shapes rather than a description of them,
// that the notes follow the chord and the key, and that it goes round
// the keys like everything else.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/bass_moves.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/screens/walking_bass_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 5200) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: WalkingBassScreen(
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(Key key) =>
      (find.byKey(key).evaluate().single.widget as Text).data!;

  group('what it shows', () {
    testWidgets('every shape the bassist has, each one named', (tester) async {
      // The list is long and lazy, so each card has to be scrolled to
      // before it exists.
      await open(tester);
      for (final move in BassMove.values) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('bass-move-${move.name}')),
          200,
        );
        expect(
          find.byKey(ValueKey('bass-move-${move.name}')),
          findsOneWidget,
          reason: move.label,
        );
      }
    });

    testWidgets('it opens on a ii to V in C', (tester) async {
      await open(tester);
      expect(textOf(const ValueKey('bass-chords')), 'Dm7 to G7');
      expect(textOf(const ValueKey('bass-progress')), '1 of 12');
    });

    testWidgets('the notes shown are the notes the band would play', (
      tester,
    ) async {
      // Not a description of the shape: the shape.
      await open(tester);
      final line = bassMoveLine(
        BassMove.arpeggioUp,
        chord: Chord.parse('Dm7'),
        next: Chord.parse('G7'),
      );
      expect(line.length, 4);
      expect(
        textOf(const ValueKey('bass-notes-arpeggioUp')).split('  '),
        hasLength(4),
      );
      expect(
        textOf(const ValueKey('bass-notes-arpeggioUp')),
        startsWith('D'),
        reason: 'the root of the chord it is on',
      );
    });

    testWidgets('up the chord to the 7th is spelled out', (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('bass-notes-upToTheSeventh')),
        200,
      );
      expect(textOf(const ValueKey('bass-notes-upToTheSeventh')), 'D  F  A  C');
    });

    testWidgets('and the four that aim at the next chord say so', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('aims at the next chord'), findsNWidgets(4));
    });
  });

  group('changing the change', () {
    testWidgets('a different pair of chords rewrites every line', (
      tester,
    ) async {
      await open(tester);
      final before = textOf(const ValueKey('bass-notes-arpeggioUp'));
      await tester.tap(find.byKey(const ValueKey('bass-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('V to I').last);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('bass-chords')), 'G7 to CΔ7');
      expect(textOf(const ValueKey('bass-notes-arpeggioUp')), isNot(before));
      expect(textOf(const ValueKey('bass-notes-arpeggioUp')), startsWith('G'));
    });

    testWidgets('a minor ii V is a minor ii V', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('bass-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minor ii to V').last);
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('bass-chords')), contains('ø7'));
    });
  });

  group('round the keys', () {
    testWidgets('next key moves a fourth and the chords move with it', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('bass-chords')), 'Gm7 to C7');
      expect(textOf(const ValueKey('bass-notes-arpeggioUp')), startsWith('G'));
    });

    testWidgets('all twelve are there', (tester) async {
      await open(tester);
      for (var move = 0; move < 12; move++) {
        expect(find.byKey(ValueKey('round-key-$move')), findsOneWidget);
      }
    });

    testWidgets('a key left behind is marked', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('round-key-0')),
      );
      expect(chip.avatar, isNotNull);
    });
  });

  group('hearing one', () {
    testWidgets('without the instruments it says so rather than nothing', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('bass-hear-arpeggioUp')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('bass-problem')), contains('still loading'));
    });
  });
}
