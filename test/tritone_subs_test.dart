// Tritone substitution: whether the reason given for it is actually true.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guide_tones.dart';
import 'package:play_along/music/tritone_subs.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/tritone_subs_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Chord _c(String name) => Chord.parse(name);

void main() {
  group('which chords can be swapped', () {
    test('a dominant can, and comes back a tritone away', () {
      expect(subFor(_c('G7'))?.display, 'D♭7');
      expect(subFor(_c('C7'))?.display, 'G♭7');
      expect(subFor(_c('D♭7'))?.display, 'G7');
    });

    test('an altered or extended dominant still is one', () {
      expect(subFor(_c('G13')), isNotNull);
      expect(subFor(_c('A7b9')), isNotNull);
      expect(subFor(_c('G7alt')), isNotNull);
    });

    test('anything that is not a dominant comes back null', () {
      // No tritone between a 3rd and a ♭7 it hasn't got.
      for (final name in ['Dm7', 'C^7', 'C6', 'Am7b5', 'Co7', 'C']) {
        expect(subFor(_c(name)), isNull, reason: name);
        expect(isDominant(_c(name)), isFalse, reason: name);
      }
    });

    test('swapping twice comes back where it started', () {
      for (final name in ['G7', 'C7', 'E♭7', 'A7', 'B7']) {
        final there = subFor(_c(name))!;
        expect(subFor(there)!.root, _c(name).root, reason: name);
      }
    });
  });

  group('the reason it works', () {
    test('the pair really do share their 3rd and ♭7', () {
      // The whole claim the screen makes, in every key.
      for (var root = 0; root < 12; root++) {
        final chord = Chord.parse(
          '${['C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B'][root]}7',
        );
        final sub = subFor(chord)!;
        expect(
          shareGuideTones(chord, sub),
          isTrue,
          reason: '${chord.display} and ${sub.display}',
        );
        expect(guideToneClasses(chord), hasLength(2));
      }
    });

    test('and they are swapped over, not merely equal', () {
      // If the pair were the same way up it would be the same chord. The
      // ♭7 of one is the 3rd of the other, and here the F is not even
      // respelled — it is the same letter doing both jobs.
      final g = guideTonesThrough([_c('G7')]).single;
      final sub = guideTonesThrough([_c('D♭7')]).single;
      expect(g.lower, 'F', reason: "G7's ♭7");
      expect(g.upper, 'B', reason: "G7's 3rd");
      expect(sub.lower, 'C♭', reason: "D♭7's ♭7, which is G7's 3rd");
      expect(sub.upper, 'F', reason: "D♭7's 3rd, which is G7's ♭7");
      expect(g.lower, sub.upper, reason: 'the same note, both ways');
    });

    test('two chords that do not share them are not a pair', () {
      expect(shareGuideTones(_c('G7'), _c('C7')), isFalse);
      expect(shareGuideTones(_c('Dm7'), _c('G7')), isFalse);
    });
  });

  group('what the bass does', () {
    test('a plain ii–V–I leaps fourths', () {
      expect(bassMoves([_c('Dm7'), _c('G7'), _c('C^7')]), [5, 5]);
    });

    test('with the sub it walks down by semitones', () {
      // This is the audible difference, and it is the whole of it.
      expect(bassMoves([_c('Dm7'), _c('D♭7'), _c('C^7')]), [-1, -1]);
    });

    test('it counts the short way round, never the long one', () {
      // C up to B is a semitone down, not eleven up.
      expect(bassMoves([_c('C7'), _c('B7')]), [-1]);
      expect(bassMoves([_c('B7'), _c('C7')]), [1]);
    });

    test('every set of changes gets smoother when the sub is made', () {
      for (final changes in subChanges) {
        final written = [
          for (final (step, quality) in changes.chords)
            Chord.parse(
              '${['C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B'][step % 12]}$quality',
            ),
        ];
        final subbed = [...written];
        final sub = subFor(written[changes.at]);
        expect(sub, isNotNull, reason: '${changes.name} must be a dominant');
        subbed[changes.at] = sub!;
        final before = bassMoves(written)
            .map((m) => m.abs())
            .reduce((a, b) => a + b);
        final after = bassMoves(subbed)
            .map((m) => m.abs())
            .reduce((a, b) => a + b);
        expect(after, lessThan(before), reason: changes.name);
      }
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
          home: TritoneSubsScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it leads with the two chords and why they swap', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('dyad-G7')), findsOneWidget);
      expect(find.byKey(const ValueKey('dyad-D♭7')), findsOneWidget);
      expect(find.textContaining('The same two notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both versions are written out, with the change marked', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('As Written-G7')), findsOneWidget);
      expect(find.byKey(const ValueKey('With The Sub-D♭7')), findsOneWidget);
      // The chords either side are untouched.
      expect(find.byKey(const ValueKey('With The Sub-Dm7')), findsOneWidget);
      expect(find.byKey(const ValueKey('With The Sub-CΔ7')), findsOneWidget);
    });

    testWidgets('the bass movement is named, not just counted', (tester) async {
      // "↑ 5" beside "↓ semitone" reads as two different kinds of thing.
      await open(tester);
      expect(find.text('↓ semitone'), findsNWidgets(2));
      expect(find.text('↑ a 4th'), findsNWidgets(2));
      expect(find.textContaining('↑ 5'), findsNothing);
    });

    testWidgets('changing the key moves both versions', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pick-F')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dyad-C7')), findsOneWidget);
      expect(find.byKey(const ValueKey('dyad-G♭7')), findsOneWidget);
      expect(find.byKey(const ValueKey('With The Sub-G♭7')), findsOneWidget);
    });

    testWidgets('playing either version is harmless without audio', (
      tester,
    ) async {
      await open(tester);
      for (final which in ['As Written', 'With The Sub']) {
        final button = find.byKey(ValueKey('play-$which'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
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
      final card = find.byKey(const ValueKey('learn-tritone-subs'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(TritoneSubsScreen), findsOneWidget);
    });
  });
}
