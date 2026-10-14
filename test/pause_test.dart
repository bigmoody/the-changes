// Pause holds the band's place; Stop goes back to the top.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

import 'support/fake_player.dart';

/// Stands in for the audio engine: records what the controller asks of it.

void main() {
  late FakePlayer player;
  late PracticeController controller;

  setUp(() {
    player = FakePlayer();
    controller = PracticeController(
      tune: standards.first,
      player: player,
      settings: AppSettings.inMemory(),
    );
  });

  test('the main button plays, pauses, then carries on', () async {
    await controller.togglePlay();
    expect(controller.isPlaying, isTrue);
    expect(controller.isPaused, isFalse);

    await controller.togglePlay();
    expect(controller.isPaused, isTrue);
    expect(controller.isPlaying, isTrue, reason: 'paused is not stopped');

    await controller.togglePlay();
    expect(controller.isPaused, isFalse);
    // Carrying on must not re-render: that would start from the top.
    expect(player.calls, ['start', 'pause', 'resume']);
  });

  test('stop from a pause goes back to the top', () async {
    await controller.togglePlay();
    controller.pause();
    await controller.stop();
    expect(controller.isPlaying, isFalse);
    expect(controller.isPaused, isFalse);

    await controller.togglePlay();
    expect(player.calls.last, 'start', reason: 'should start afresh');
  });

  test('changing the tempo while paused ends the pause', () async {
    await controller.togglePlay();
    controller.pause();

    controller.setTempo(controller.tempo + 20);
    await pumpEventQueue();

    // Nothing starts playing behind the player's back; Play starts the new
    // tempo from the top.
    expect(controller.isPlaying, isFalse);
    expect(controller.isPaused, isFalse);
    expect(player.calls, ['start', 'pause', 'stop']);
    expect(player.playing, isFalse);
  });

  test('pausing while nothing plays does nothing', () {
    controller.pause();
    expect(controller.isPaused, isFalse);
    expect(player.calls, isEmpty);
  });
}
