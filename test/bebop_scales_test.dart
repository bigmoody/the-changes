// Bebop scales: whether the extra note really does what it is for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/bebop_scales.dart';
import 'package:play_along/screens/bebop_scales_screen.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

BebopScale _named(String name) =>
    bebopScales.firstWhere((scale) => scale.name == name);

void main() {
  group('the scales themselves', () {
    test('each is eight notes, one more than the scale it is built on', () {
      for (final scale in bebopScales) {
        expect(scale.degrees, hasLength(8), reason: scale.name);
        expect(scale.plain, hasLength(7), reason: scale.name);
        expect(scale.degrees.toSet(), hasLength(8), reason: 'no repeats');
      }
    });

    test('the extra note is the only difference', () {
      for (final scale in bebopScales) {
        final without = [...scale.degrees]..remove(scale.added);
        expect(without, scale.plain, reason: scale.name);
        expect(scale.addedAt, greaterThan(0), reason: scale.name);
      }
    });

    test('it climbs: every step is a semitone or a tone, never more', () {
      // A bebop scale with a gap in it would not be a scale, and the
      // whole thing rests on it being eight even steps to the octave.
      for (final scale in bebopScales) {
        final steps = semitonesOf(scale.degrees);
        for (var i = 1; i < steps.length; i++) {
          final gap = steps[i] - steps[i - 1];
          expect(gap, inInclusiveRange(1, 2), reason: '${scale.name} at $i');
        }
        expect(12 - steps.last, inInclusiveRange(1, 2), reason: 'and home');
      }
    });

    test('the chord tones are the ones the chord has got', () {
      expect(_named('Dominant Bebop').tones, ['1', '3', '5', 'b7']);
      // The major scale's passing note lands the 6th on a beat, not the
      // 7th, so the chord it belongs to is the 6th, which is why the
      // songbook is full of 6 chords where you expected a Δ7.
      expect(_named('Major Bebop').tones, ['1', '3', '5', '6']);
      expect(_named('Major Bebop').quality, '6');
      expect(_named('Minor Bebop').tones, ['1', 'b3', '5', 'b7']);
      for (final scale in bebopScales) {
        for (final tone in scale.tones) {
          expect(scale.degrees, contains(tone), reason: scale.name);
        }
      }
    });
  });

  group('where the beats land', () {
    test('the beats are the even quavers, and there are four to a bar', () {
      final run = runOf(_named('Dominant Bebop').degrees, {'1'});
      expect(run, hasLength(16), reason: 'two bars');
      expect(run.where((n) => n.onBeat), hasLength(8));
      expect(run.first.onBeat, isTrue);
      expect(run[1].onBeat, isFalse);
    });

    test('eight notes: every beat is a chord tone, both bars', () {
      // This is the entire claim the screen makes.
      for (final scale in bebopScales) {
        expect(
          tonesOnBeats(scale.degrees, {...scale.tones}),
          8,
          reason: scale.name,
        );
      }
    });

    test('and it keeps doing it however long you run', () {
      for (final scale in bebopScales) {
        expect(tonesOnBeats(scale.degrees, {...scale.tones}, bars: 8), 32);
      }
    });

    test('seven notes: it always does worse, and worse as it runs on', () {
      for (final scale in bebopScales) {
        final eight = tonesOnBeats(scale.degrees, {...scale.tones});
        final seven = tonesOnBeats(scale.plain, {...scale.tones});
        expect(seven, lessThan(eight), reason: scale.name);
        // And the gap grows: the eight-note scale never drifts, so the
        // longer you run the further apart they get.
        expect(
          tonesOnBeats(scale.plain, {...scale.tones}, bars: 8),
          lessThan(32),
          reason: '${scale.name}, eight bars',
        );
      }
    });

    test('the dominant scale is the plain case to reason from', () {
      // Mixolydian over a 7 chord: the first bar lands four from four,
      // which is exactly why the drift is easy to miss.
      final scale = _named('Dominant Bebop');
      expect(tonesOnBeats(scale.plain, {...scale.tones}, bars: 1), 4);
      expect(tonesOnBeats(scale.plain, {...scale.tones}), 5);
    });
  });

  group('spelling it', () {
    test('the passing note shares a letter with the one it passes', () {
      // C dominant bebop is B♭ then B, not B♭ then C♭.
      final names = spell(_named('Dominant Bebop').degrees, 'C', '7');
      expect(names, ['C', 'D', 'E', 'F', 'G', 'A', 'B♭', 'B']);
    });

    test('major bebop sharpens the 5th rather than flattening the 6th', () {
      final names = spell(_named('Major Bebop').degrees, 'C', '^7');
      expect(names, ['C', 'D', 'E', 'F', 'G', 'G♯', 'A', 'B']);
    });

    test('minor bebop takes its passing note where the dominant does', () {
      // A ii and the V after it are the same seven notes, so the note
      // that fixes one fixes the other. The ♮3-above-♭3 scale is a real
      // sound but it does not do this, so it is not the one here.
      final names = spell(_named('Minor Bebop').degrees, 'D', 'm7');
      expect(names, ['D', 'E', 'F', 'G', 'A', 'B', 'C', 'C♯']);
    });

    test('it spells in flat keys too', () {
      final names = spell(_named('Dominant Bebop').degrees, 'E♭', '7');
      expect(names.first, 'E♭');
      expect(names, contains('D♭'));
      expect(names.last, 'D');
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: BebopScalesScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it shows both rows and what each one scores', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('landed-Dominant Bebop')), findsOne);
      expect(find.text('8 of 8 beats'), findsOneWidget);
      // And the plain scale, doing worse, which is the lesson.
      expect(
        find.byKey(const ValueKey('landed-Mixolydian, for comparison')),
        findsOneWidget,
      );
      expect(find.text('5 of 8 beats'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the scale changes what is drawn', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pick-Minor')));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('landed-Minor Bebop'));
      // The page scrolls down; the chip strips and the staves scroll
      // sideways, so the one to drive has to be named.
      await tester.scrollUntilVisible(
        row,
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('bebop-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(row, findsOneWidget);
      expect(find.textContaining('Dorian'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all three scales are reachable without scrolling', (
      tester,
    ) async {
      // "Dominant Bebop / Major Bebop / Minor Bebop" ran off the side of
      // a phone and hid the third one.
      await open(tester);
      for (final scale in bebopScales) {
        final chip = find.byKey(ValueKey('pick-${scale.short}'));
        expect(chip, findsOneWidget, reason: scale.name);
        expect(
          tester.getCenter(chip).dx,
          lessThan(393),
          reason: '${scale.name} is off the edge',
        );
      }
    });

    testWidgets('changing the root respells it', (tester) async {
      await open(tester);
      expect(find.textContaining('C7'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('pick-E♭')));
      await tester.pumpAndSettle();
      expect(find.textContaining('E♭7'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('playing without a sample bank is harmless', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('play-Dominant Bebop')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('it opens from Learn', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LearnPage(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('learn-bebop-scales'));
      await tester.scrollUntilVisible(
        card,
        100,
        // The page's own list, not the search box's text field,
        // which is a scrollable too.
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(BebopScalesScreen), findsOneWidget);
    });
  });
}
