// A scale run in a shape, on screen.
//
// The shapes are tested where they are worked out. What matters here is
// that the notes written under the stave are the ones the scale spells,
// in the key the round has reached, and that a shape too wide for one
// octave is given two rather than drawn empty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/screens/scale_patterns_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(393, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: ScalePatternsScreen(
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(Key key) =>
      (find.byKey(key).evaluate().single.widget as Text).data!;

  /// Picks a scale by its exact name. Matching on "contains" picks
  /// Dorian ♯4 when Dorian was meant, which is a mistake to make once.
  Future<void> pickScale(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('pattern-scale')));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) => w is Text && (w.data ?? '').startsWith('$name  ·'),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickShape(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('pattern-shape')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  group('what it opens on', () {
    testWidgets('C Ionian in 3rds, which is the plainest thing there is', (
      tester,
    ) async {
      await open(tester);
      expect(textOf(const ValueKey('pattern-key')), 'C Ionian');
      expect(
        textOf(const ValueKey('pattern-notes')),
        'C E D F E G F A G B A C',
      );
    });

    testWidgets('with the shape explained under it', (tester) async {
      await open(tester);
      expect(
        textOf(const ValueKey('pattern-about')),
        contains('two steps above'),
      );
    });
  });

  group('changing the shape and the scale', () {
    testWidgets('a different pattern rewrites the line', (tester) async {
      await open(tester);
      await pickShape(tester, 'Triads');
      expect(
        textOf(const ValueKey('pattern-notes')),
        'C E G D F A E G B F A C',
      );
    });

    testWidgets('a different scale spells its own notes', (tester) async {
      await open(tester);
      await pickScale(tester, 'Dorian');
      expect(textOf(const ValueKey('pattern-key')), 'C Dorian');
      expect(
        textOf(const ValueKey('pattern-notes')),
        'C E♭ D F E♭ G F A G B♭ A C',
      );
    });

    testWidgets('the pentatonics are there now, and run like anything else', (
      tester,
    ) async {
      await open(tester);
      await pickScale(tester, 'Major pentatonic');
      expect(textOf(const ValueKey('pattern-key')), 'C Major pentatonic');
      // Five notes, so a step of two is a wider jump than on a scale.
      expect(textOf(const ValueKey('pattern-notes')), 'C E D G E A G C');
    });

    testWidgets('a shape too wide for one octave is given two', (tester) async {
      await open(tester);
      await pickScale(tester, 'Major pentatonic');
      await pickShape(tester, 'Sevenths');
      expect(textOf(const ValueKey('pattern-progress')), contains('2 octaves'));
      expect(textOf(const ValueKey('pattern-notes')), isNotEmpty);
    });

    testWidgets('down is a different exercise, not the same one reversed', (
      tester,
    ) async {
      await open(tester);
      await pickShape(tester, '1 2 3 5');
      final up = textOf(const ValueKey('pattern-notes'));
      await tester.tap(find.text('Down'));
      await tester.pumpAndSettle();
      final down = textOf(const ValueKey('pattern-notes'));
      expect(down, isNot(up));
      expect(down.split(' ').take(4).join(' '), 'C B A F');
    });
  });

  group('round the keys', () {
    testWidgets('next key moves a fourth and respells the scale', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('pattern-key')), 'F Ionian');
      expect(
        textOf(const ValueKey('pattern-notes')),
        'F A G B♭ A C B♭ D C E D F',
      );
    });

    testWidgets('all twelve are there to jump to', (tester) async {
      await open(tester);
      for (var move = 0; move < 12; move++) {
        expect(find.byKey(ValueKey('round-key-$move')), findsOneWidget);
      }
    });

    testWidgets('the scale and the shape stay put as the key moves', (
      tester,
    ) async {
      await open(tester);
      await pickScale(tester, 'Lydian');
      await pickShape(tester, 'In 4ths');
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('pattern-key')), 'F Lydian');
      expect(textOf(const ValueKey('pattern-notes')).split(' ').first, 'F');
    });
  });
}
