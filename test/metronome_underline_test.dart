// The underline under the chord being played beats like a metronome:
// full on each beat, fading across it, strongest on the first beat of
// the bar. Steady for anybody who has asked for less movement.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/chord_chart.dart';
import 'package:play_along/settings/app_settings.dart';
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
  PlaybackPosition? position() => at;
}

void main() {
  Future<({PracticeController controller, _FakePlayer player})> open(
    WidgetTester tester, {
    bool lessMovement = false,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final player = _FakePlayer();
    final controller = PracticeController(
      tune: Tune.fromChart(
        title: 'ii V I',
        key: 'C',
        defaultTempo: 120,
        chart: '| Dm7 | G7 | CΔ7 | A7 |',
      ),
      player: player,
      settings: AppSettings.inMemory(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: lessMovement),
          child: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => ChordChart(controller: controller),
            ),
          ),
        ),
      ),
    );
    await controller.play();
    return (controller: controller, player: player);
  }

  /// How strong the underline is drawn now, 0 to 1.
  double strength(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('chord-playing')),
    );
    final border = (box.decoration as BoxDecoration).border! as Border;
    return border.bottom.color.a;
  }

  Future<void> onBeat(WidgetTester tester, _FakePlayer player, int beat) async {
    player.at = PlaybackPosition(tuneBeat: beat, chorus: 0);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
  }

  testWidgets('it flashes on the beat and fades across it', (tester) async {
    final band = await open(tester);
    await onBeat(tester, band.player, 0);
    final early = strength(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final late = strength(tester);
    expect(early, greaterThan(0.6));
    expect(late, closeTo(0.25, 0.05), reason: 'faded by the end of the beat');
    // The next beat flashes it again.
    await onBeat(tester, band.player, 1);
    expect(strength(tester), greaterThan(0.5));
    await band.controller.stop();
  });

  testWidgets('the first beat of the bar is the strongest', (tester) async {
    final band = await open(tester);
    band.player.at = const PlaybackPosition(tuneBeat: 0, chorus: 0);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 1));
    final one = strength(tester);
    await tester.pump(const Duration(milliseconds: 500));
    band.player.at = const PlaybackPosition(tuneBeat: 1, chorus: 0);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 1));
    final two = strength(tester);
    expect(one, greaterThan(two));
    await band.controller.stop();
  });

  testWidgets('steady for somebody who wants less movement', (tester) async {
    final band = await open(tester, lessMovement: true);
    await onBeat(tester, band.player, 0);
    expect(strength(tester), 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(strength(tester), 1);
    await band.controller.stop();
  });
}
