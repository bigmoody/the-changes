// The beat as something you feel.
//
// Two things to test and they need different tools. Where the taps fall is
// arithmetic and is tested as arithmetic. That they actually reach the
// phone is a platform call, so those tests listen on the channel Flutter
// sends haptics down and count what arrives.
//
// What cannot be tested here is whether any of it feels right, because a
// simulator has no taptic engine and a test has no wrist. The timing in
// particular is only as good as the clock underneath it, and that is a
// claim for a real phone to settle.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/felt_beat.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';

import 'support/fake_player.dart';

/// A band that makes no sound and is told where it has got to.
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

Tune _tune() => Tune.fromChart(
  title: 'ii V I',
  key: 'C',
  defaultTempo: 120,
  chart: '| Dm7 | G7 | CΔ7 | A7 |',
);

/// Every haptic that reached the platform, in order, as the method name
/// Flutter sends: "HapticFeedback.vibrate" with a light or heavy
/// argument.
List<String> watchHaptics(WidgetTester tester) {
  final felt = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        felt.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return felt;
}

void main() {
  group('where the taps fall', () {
    test('every beat is every beat', () {
      for (var beat = 0; beat < 4; beat++) {
        expect(FeelTheBeat.everyBeat.taps(beat, 4), isTrue);
      }
    });

    test('off is nothing at all', () {
      for (var beat = 0; beat < 4; beat++) {
        expect(FeelTheBeat.off.taps(beat, 4), isFalse);
      }
    });

    test('the backbeat is 2 and 4, counted from nought', () {
      expect(FeelTheBeat.backbeat.taps(0, 4), isFalse);
      expect(FeelTheBeat.backbeat.taps(1, 4), isTrue, reason: 'the 2');
      expect(FeelTheBeat.backbeat.taps(2, 4), isFalse);
      expect(FeelTheBeat.backbeat.taps(3, 4), isTrue, reason: 'the 4');
    });

    test('the 1 is only the 1', () {
      expect(FeelTheBeat.theOne.taps(0, 4), isTrue);
      for (var beat = 1; beat < 4; beat++) {
        expect(FeelTheBeat.theOne.taps(beat, 4), isFalse);
      }
      // And in a waltz it is still the one beat in three.
      expect(FeelTheBeat.theOne.taps(0, 3), isTrue);
      expect(FeelTheBeat.theOne.taps(2, 3), isFalse);
    });

    test('a backbeat in odd time taps every beat rather than nothing', () {
      // There is no 4 in a bar of three. A setting that quietly did
      // nothing would read as the feature being broken.
      expect(FeelTheBeat.backbeat.suits(3), isFalse);
      for (var beat = 0; beat < 3; beat++) {
        expect(FeelTheBeat.backbeat.taps(beat, 3), isTrue);
      }
      expect(FeelTheBeat.backbeat.suits(4), isTrue);
    });
  });

  group('reaching the phone', () {
    testWidgets('nothing is felt when it is off', (tester) async {
      final felt = watchHaptics(tester);
      for (var beat = 0; beat < 8; beat++) {
        feelBeat(FeelTheBeat.off, beat: beat, beatsPerBar: 4);
      }
      await tester.pump();
      expect(felt, isEmpty);
    });

    testWidgets('a bar of four is four taps, the 1 the heavier', (
      tester,
    ) async {
      final felt = watchHaptics(tester);
      for (var beat = 0; beat < 4; beat++) {
        feelBeat(FeelTheBeat.everyBeat, beat: beat, beatsPerBar: 4);
      }
      await tester.pump();
      expect(felt, [
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
      ]);
    });

    testWidgets('the backbeat leaves the 1 alone entirely', (tester) async {
      final felt = watchHaptics(tester);
      for (var beat = 0; beat < 4; beat++) {
        feelBeat(FeelTheBeat.backbeat, beat: beat, beatsPerBar: 4);
      }
      await tester.pump();
      // Two taps, both the same weight: leaning on a 1 you are not being
      // given would undo the exercise.
      expect(felt, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.lightImpact',
      ]);
    });

    testWidgets('a tune beat past the first bar still knows where it is', (
      tester,
    ) async {
      final felt = watchHaptics(tester);
      // Beat 8 of the tune is the 1 of the third bar.
      feelBeat(FeelTheBeat.theOne, beat: 8, beatsPerBar: 4);
      feelBeat(FeelTheBeat.theOne, beat: 9, beatsPerBar: 4);
      await tester.pump();
      expect(felt, ['HapticFeedbackType.heavyImpact']);
    });

    testWidgets('a count-in is tapped out whatever the setting says', (
      tester,
    ) async {
      final felt = watchHaptics(tester);
      // Somebody who only wants the 1 still needs all four of these: the
      // count-in is what tells them when to come in.
      for (var beat = 0; beat < 4; beat++) {
        feelCountIn(FeelTheBeat.theOne);
      }
      await tester.pump();
      expect(felt, hasLength(4));
      feelCountIn(FeelTheBeat.off);
      await tester.pump();
      expect(felt, hasLength(4), reason: 'off is still off');
    });

    testWidgets('a bar of no beats is not a division by zero', (tester) async {
      final felt = watchHaptics(tester);
      feelBeat(FeelTheBeat.everyBeat, beat: 3, beatsPerBar: 0);
      await tester.pump();
      expect(felt, isEmpty);
    });
  });

  group('the setting', () {
    test('is off until somebody asks for it', () async {
      final settings = AppSettings.inMemory();
      expect(settings.feelTheBeat, FeelTheBeat.off);
      await settings.setFeelTheBeat(FeelTheBeat.backbeat);
      expect(settings.feelTheBeat, FeelTheBeat.backbeat);
    });

    test('every choice has a Title Case name', () {
      for (final feel in FeelTheBeat.values) {
        expect(feel.label, isNotEmpty);
        expect(
          feel.label[0],
          feel.label[0].toUpperCase(),
          reason: '${feel.name} should start capitalised',
        );
      }
    });
  });

  group('from the band', () {
    testWidgets('each beat that goes by is one tap', (tester) async {
      final felt = watchHaptics(tester);
      final player = _FakePlayer();
      final settings = AppSettings.inMemory();
      await settings.setFeelTheBeat(FeelTheBeat.everyBeat);
      final controller = PracticeController(
        tune: _tune(),
        player: player,
        settings: settings,
      );
      addTearDown(controller.dispose);

      await controller.play();
      await tester.pump();
      for (var beat = 0; beat < 4; beat++) {
        player.at = PlaybackPosition(tuneBeat: beat, chorus: 0);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(felt, hasLength(4));
      expect(felt.first, 'HapticFeedbackType.heavyImpact', reason: 'the 1');
      await controller.stop();
    });

    testWidgets('a beat that has not moved is not tapped again', (
      tester,
    ) async {
      // The clock is read far more often than the beat changes, so the
      // tap has to come from the change and not from the reading.
      final felt = watchHaptics(tester);
      final player = _FakePlayer();
      final settings = AppSettings.inMemory();
      await settings.setFeelTheBeat(FeelTheBeat.everyBeat);
      final controller = PracticeController(
        tune: _tune(),
        player: player,
        settings: settings,
      );
      addTearDown(controller.dispose);

      await controller.play();
      await tester.pump();
      player.at = const PlaybackPosition(tuneBeat: 1, chorus: 0);
      for (var read = 0; read < 10; read++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(felt, hasLength(1));
      await controller.stop();
    });

    testWidgets('nothing is felt when the setting is off', (tester) async {
      final felt = watchHaptics(tester);
      final player = _FakePlayer();
      final controller = PracticeController(
        tune: _tune(),
        player: player,
        settings: AppSettings.inMemory(),
      );
      addTearDown(controller.dispose);

      await controller.play();
      await tester.pump();
      for (var beat = 0; beat < 4; beat++) {
        player.at = PlaybackPosition(tuneBeat: beat, chorus: 0);
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(felt, isEmpty);
      await controller.stop();
    });
  });
}
