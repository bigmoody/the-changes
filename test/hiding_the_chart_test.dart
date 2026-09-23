// Taking the chart away while the band plays on: which rung you are on,
// what is left on screen at each, and the way back to it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/hiding_the_chart.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// A band that makes no sound and is told where it has got to.
class _FakePlayer extends PracticePlayer {
  PlaybackPosition? at;

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
  PlaybackPosition? position() => at;
}

Tune _tune() => Tune.fromChart(
  title: 'ii V I',
  key: 'C',
  defaultTempo: 120,
  chart: '| Dm7 | G7 | CΔ7 | A7 |',
);

void main() {
  group('which rung', () {
    test('off leaves the chart alone however long you play', () {
      for (final chorus in [null, 1, 2, 9, 40]) {
        expect(
          FadeChart.never.showsOn(chorus),
          ChartShows.everything,
          reason: 'chorus $chorus',
        );
      }
    });

    test('two choruses of each, then nothing', () {
      const fade = FadeChart.afterTwo;
      expect(fade.showsOn(1), ChartShows.everything);
      expect(fade.showsOn(2), ChartShows.everything);
      expect(fade.showsOn(3), ChartShows.whereYouAre);
      expect(fade.showsOn(4), ChartShows.whereYouAre);
      expect(fade.showsOn(5), ChartShows.nothing);
      expect(fade.showsOn(50), ChartShows.nothing, reason: 'it stays gone');
    });

    test('one chorus of each is the short way round', () {
      const fade = FadeChart.afterOne;
      expect(fade.showsOn(1), ChartShows.everything);
      expect(fade.showsOn(2), ChartShows.whereYouAre);
      expect(fade.showsOn(3), ChartShows.nothing);
    });

    test('stopped or counting in, the chart is always there', () {
      // You cannot set up a run you cannot see.
      for (final fade in FadeChart.values) {
        expect(fade.showsOn(null), ChartShows.everything, reason: fade.label);
      }
    });

    test('only the whole chart has chords on it', () {
      expect(ChartShows.everything.hasChords, isTrue);
      expect(ChartShows.whereYouAre.hasChords, isFalse);
      expect(ChartShows.nothing.hasChords, isFalse);
    });
  });

  group('the controller', () {
    ({PracticeController controller, _FakePlayer player}) build(
      FadeChart fade,
    ) {
      final player = _FakePlayer();
      final settings = AppSettings.inMemory();
      settings.setFadeChart(fade);
      final controller = PracticeController(
        tune: _tune(),
        player: player,
        settings: settings,
      );
      addTearDown(controller.dispose);
      return (controller: controller, player: player);
    }

    /// Runs the band on until it reports [chorus] (counting from 1).
    Future<void> reach(
      PracticeController controller,
      _FakePlayer player,
      int chorus,
    ) async {
      if (!controller.isPlaying) {
        await controller.play();
        await pumpEventQueue();
      }
      player.at = PlaybackPosition(tuneBeat: 0, chorus: chorus - 1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    test('it follows the choruses as they go by', () async {
      final (:controller, :player) = build(FadeChart.afterOne);
      expect(controller.chartShows, ChartShows.everything, reason: 'stopped');
      await reach(controller, player, 1);
      expect(controller.chartShows, ChartShows.everything);
      await reach(controller, player, 2);
      expect(controller.chartShows, ChartShows.whereYouAre);
      await reach(controller, player, 3);
      expect(controller.chartShows, ChartShows.nothing);
    });

    test('asking for it back keeps it back for the rest of the run', () async {
      final (:controller, :player) = build(FadeChart.afterOne);
      await reach(controller, player, 3);
      expect(controller.chartShows, ChartShows.nothing);
      controller.showTheChart();
      expect(controller.chartShows, ChartShows.everything);
      // Still there a chorus later: it doesn't fade again mid-run.
      await reach(controller, player, 4);
      expect(controller.chartShows, ChartShows.everything);
    });

    test('stopping puts it back, and the next run fades again', () async {
      final (:controller, :player) = build(FadeChart.afterOne);
      await reach(controller, player, 3);
      controller.showTheChart();
      await controller.stop();
      expect(controller.chartShows, ChartShows.everything);
      expect(controller.chartIsFading, isFalse, reason: 'nothing playing');

      player.at = null;
      await reach(controller, player, 2);
      expect(
        controller.chartShows,
        ChartShows.whereYouAre,
        reason: 'giving in was only for that run',
      );
    });

    test('with it off, nothing fades and nothing is offered', () async {
      final (:controller, :player) = build(FadeChart.never);
      await reach(controller, player, 9);
      expect(controller.chartShows, ChartShows.everything);
      expect(controller.chartIsFading, isFalse);
    });
  });

  group('on the screen', () {
    Future<_FakePlayer> open(WidgetTester tester, FadeChart fade) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final player = _FakePlayer();
      final settings = AppSettings.inMemory();
      await settings.setFadeChart(fade);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: _tune(),
            player: player,
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return player;
    }

    Future<void> reach(
      WidgetTester tester,
      _FakePlayer player,
      int chorus,
    ) async {
      await tester.tap(find.text('Play'));
      await tester.pump();
      player.at = PlaybackPosition(tuneBeat: 0, chorus: chorus - 1);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
    }

    testWidgets('the chords go, and the bars stay', (tester) async {
      final player = await open(tester, FadeChart.afterOne);
      expect(find.text('Dm7'), findsWidgets, reason: 'read it first');

      await reach(tester, player, 2);
      expect(find.text('Dm7'), findsNothing);
      expect(find.text('G7'), findsNothing);
      // The boxes are still there: bar numbers and the bar being played.
      expect(find.text('1'), findsWidgets, reason: 'the bar numbers');
      expect(find.text('Chords Off'), findsOneWidget);
      expect(find.byKey(const ValueKey('blank-paper')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('then the bars go too', (tester) async {
      final player = await open(tester, FadeChart.afterOne);
      await reach(tester, player, 3);
      expect(find.byKey(const ValueKey('blank-paper')), findsOneWidget);
      expect(find.text('Dm7'), findsNothing);
      expect(find.text('Chart Off'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the chord readout does not give the answer away', (
      tester,
    ) async {
      // The strip under the chart says the chord in letters a foot high,
      // which would undo the whole thing.
      final player = await open(tester, FadeChart.afterOne);
      await reach(tester, player, 2);
      expect(find.byKey(const ValueKey('show-the-chart')), findsOneWidget);
      expect(find.text('Dm7'), findsNothing);
    });

    testWidgets('Show It brings the chart straight back', (tester) async {
      final player = await open(tester, FadeChart.afterOne);
      await reach(tester, player, 2);
      await tester.tap(find.byKey(const ValueKey('show-the-chart')));
      await tester.pumpAndSettle();
      expect(find.text('Dm7'), findsWidgets);
      expect(find.text('Chords Off'), findsNothing);
    });

    testWidgets('tapping the blank paper brings it back too', (tester) async {
      final player = await open(tester, FadeChart.afterOne);
      await reach(tester, player, 3);
      await tester.tap(find.byKey(const ValueKey('blank-paper')));
      await tester.pumpAndSettle();
      expect(find.text('Dm7'), findsWidgets);
      expect(find.byKey(const ValueKey('blank-paper')), findsNothing);
    });

    testWidgets('with it off the chart never moves', (tester) async {
      final player = await open(tester, FadeChart.never);
      await reach(tester, player, 6);
      expect(find.text('Dm7'), findsWidgets);
      expect(find.byKey(const ValueKey('show-the-chart')), findsNothing);
    });
  });
}
