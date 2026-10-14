// The page about dominants leaning on each other.
//
// What is worth testing here is the music, not the layout: a run of four
// into B♭ has to actually be D7 G7 C7 F7, and the guide tones under it
// have to actually fall a semitone at a time, because that second claim
// is the whole argument the page makes and it would be embarrassing to
// make it with the wrong notes on the screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guide_tones.dart';
import 'package:play_along/screens/dominant_chains_screen.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
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
  Future<void> restoreAudioSession() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}

  @override
  PlaybackPosition? position() => null;
}

Future<void> open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(393, 1400) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: DominantChainsScreen(player: _FakePlayer()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the run it shows', () {
    testWidgets('four into B flat is the rhythm changes bridge', (
      tester,
    ) async {
      await open(tester);
      // The page opens on four, in B♭, which is where most people meet
      // this for the first time.
      for (final chord in ['D7', 'G7', 'C7', 'F7', 'B♭Δ7']) {
        expect(
          find.byKey(ValueKey('run-$chord')),
          findsOneWidget,
          reason: chord,
        );
      }
    });

    testWidgets('two is a pair, not four', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('chain-chip-Two')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('run-C7')), findsOneWidget);
      expect(find.byKey(const ValueKey('run-F7')), findsOneWidget);
      expect(find.byKey(const ValueKey('run-B♭Δ7')), findsOneWidget);
      expect(find.byKey(const ValueKey('run-D7')), findsNothing);
    });

    testWidgets('changing key moves the whole run', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('chain-chip-C')));
      await tester.pumpAndSettle();
      for (final chord in ['E7', 'A7', 'D7', 'G7', 'CΔ7']) {
        expect(
          find.byKey(ValueKey('run-$chord')),
          findsOneWidget,
          reason: chord,
        );
      }
    });
  });

  group('the claim the page makes', () {
    test('both guide tones fall a semitone between the dominants', () {
      // The argument the page makes, and it has to be true or the page
      // is showing somebody a pattern that is not there. It said "all
      // the way down" until this test was written, which is wrong at the
      // last chord, and the test is how that was found.
      final run = ['D7', 'G7', 'C7', 'F7', 'Bb^7'].map(Chord.parse).toList();
      final tones = guideTonesThrough(run);
      for (final at in tones.skip(1).take(3)) {
        expect(
          at.upperMove,
          -1,
          reason: '\${at.chord.display} upper line moved \${at.upperMove}',
        );
        expect(
          at.lowerMove,
          -1,
          reason: '\${at.chord.display} lower line moved \${at.lowerMove}',
        );
      }
    });

    test('and at the end one of them is held instead', () {
      // F7's 3rd is A, and A is already the 7th of BbMaj7. One line
      // falls into place and the other simply stays, which is a good
      // part of why the ending sounds like an ending.
      final run = ['D7', 'G7', 'C7', 'F7', 'Bb^7'].map(Chord.parse).toList();
      final home = guideTonesThrough(run).last;
      expect(home.upperMove, -1);
      expect(home.lowerMove, 0, reason: 'the held note');
      expect(home.lower, 'A');
    });

    testWidgets('and the page marks every one of those steps', (tester) async {
      await open(tester);
      final run = ['D7', 'G7', 'C7', 'F7', 'B♭^7'].map(Chord.parse).toList();
      final tones = guideTonesThrough(run);
      final scheme = appTheme(Brightness.light).colorScheme;
      var marked = 0;
      for (final (i, at) in tones.indexed) {
        for (final note in [at.upper, at.lower]) {
          final text = tester.widget<Text>(
            find.byKey(ValueKey('tone-$i-$note')),
          );
          if (text.style?.color?.toARGB32() == scheme.tertiary.toARGB32()) {
            marked++;
          }
        }
      }
      // Two lines falling through three changes of dominant, then one
      // of them falling into the last chord while the other is held:
      // seven steps, not eight.
      expect(marked, 7);
    });
  });
}
