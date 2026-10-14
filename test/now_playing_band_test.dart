// Whether the band puts its card on the lock screen, and when.
//
// The rule is about whose buttons they are. With "Keep Other Apps
// Playing" on, this app is a second source of sound alongside whatever
// you are playing along to, and the card belongs to them: taking it
// would mean the pause button on the lock screen stopped pausing
// Spotify, which is somebody else's control taken away without being
// asked. With it off, this app is the only thing making a sound, and a
// band coming out of a locked pocket with no way to stop it is the
// reason any of this exists.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/now_playing_centre.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

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
  void pause() {}

  @override
  void resume() {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// Remembers what the lock screen was told, and can press its buttons.
class _Phone {
  _Phone(this.channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show') {
            shown = Map<String, Object?>.from(call.arguments as Map);
          }
          if (call.method == 'hide') shown = null;
          return null;
        });
  }

  final MethodChannel channel;
  Map<String, Object?>? shown;

  Future<void> press(String button) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(button)),
          (_) {},
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('the_changes/test_band_card');
  late _Phone phone;
  late NowPlayingCentre card;

  ({PracticeController controller, AppSettings settings}) band({
    bool mixWithOthers = false,
  }) {
    final settings = AppSettings.inMemory();
    settings.setMixWithOthers(mixWithOthers);
    final controller = PracticeController(
      tune: standards.firstWhere((tune) => tune.title == 'Blue Bossa'),
      player: _FakePlayer(),
      settings: settings,
      nowPlaying: card,
    );
    addTearDown(controller.dispose);
    return (controller: controller, settings: settings);
  }

  setUp(() {
    phone = _Phone(channel);
    card = NowPlayingCentre(channel: channel);
  });

  tearDown(() {
    card.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('whose buttons they are', () {
    test('with the app on its own, the band takes the lock screen', () async {
      final (:controller, settings: _) = band(mixWithOthers: false);
      await controller.play(withCountIn: false);
      expect(phone.shown, isNotNull);
      expect(phone.shown!['title'], 'Blue Bossa');
      expect(phone.shown!['playing'], isTrue);
    });

    test('playing along to something else, it takes nothing', () async {
      // The one that matters. Their pause button has to go on pausing
      // them.
      final (:controller, settings: _) = band(mixWithOthers: true);
      await controller.play(withCountIn: false);
      expect(phone.shown, isNull);
    });

    test('the card says the key and the tempo, as a sleeve would', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);
      expect(
        phone.shown!['line'],
        '${controller.chart.key} · ${controller.currentTempo}',
      );
    });
  });

  group('the card keeping up with the band', () {
    test('pausing says paused rather than taking the card away', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);
      controller.pause();
      await Future<void>.delayed(Duration.zero);
      expect(phone.shown, isNotNull);
      expect(phone.shown!['playing'], isFalse);
    });

    test('and carrying on says playing again', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);
      controller.pause();
      controller.resume();
      await Future<void>.delayed(Duration.zero);
      expect(phone.shown!['playing'], isTrue);
    });

    test('stopping takes it away', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);
      await controller.stop();
      expect(phone.shown, isNull);
    });

    test('and so does leaving the screen', () async {
      final settings = AppSettings.inMemory();
      await settings.setMixWithOthers(false);
      final controller = PracticeController(
        tune: standards.first,
        player: _FakePlayer(),
        settings: settings,
        nowPlaying: card,
      );
      await controller.play(withCountIn: false);
      expect(phone.shown, isNotNull);
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(phone.shown, isNull);
    });
  });

  group('the switch being thrown mid-run', () {
    test('turning the mixing on hands the lock screen back', () async {
      // Somebody starts the band on its own, then puts a record on to
      // play along to. The card has to go with the switch.
      final (:controller, settings: _) = band(mixWithOthers: false);
      await controller.play(withCountIn: false);
      expect(phone.shown, isNotNull);
      await controller.setMixWithOthers(true);
      expect(phone.shown, isNull);
    });

    test('and turning it off takes it, without restarting anything', () async {
      final (:controller, settings: _) = band(mixWithOthers: true);
      await controller.play(withCountIn: false);
      expect(phone.shown, isNull);
      await controller.setMixWithOthers(false);
      expect(phone.shown, isNotNull);
      expect(controller.isPlaying, isTrue);
    });
  });

  group('the buttons on it', () {
    test('pause and play reach the band', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);

      await phone.press('pause');
      expect(controller.isPaused, isTrue);
      await phone.press('play');
      expect(controller.isPaused, isFalse);
    });

    test('the one big button turns the band on and off', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);

      await phone.press('toggle');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPaused, isTrue);
      await phone.press('toggle');
      await Future<void>.delayed(Duration.zero);
      expect(controller.isPaused, isFalse);
    });

    test('stop stops it, and the card goes with it', () async {
      final (:controller, settings: _) = band();
      await controller.play(withCountIn: false);

      await phone.press('stop');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.isPlaying, isFalse);
      expect(phone.shown, isNull);
    });
  });
}
