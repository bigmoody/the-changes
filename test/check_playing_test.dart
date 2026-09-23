// Checking what you play, end to end: switching it on, the microphone
// following the band, and the score at the end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord_drill.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tuning.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'fake_listener.dart';

/// A band that starts and stops without any real audio.
class _FakePlayer extends PracticePlayer {
  var restored = false;

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
  Future<void> restoreAudioSession() async => restored = true;

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Tune _tune() => Tune.fromChart(
  title: 'ii V I',
  key: 'C',
  defaultTempo: 120,
  chart: '| Dm7 | G7 | CΔ7 | CΔ7 |',
);

double _hz(int midi) => midiToHz(midi);

/// The band starts the microphone without waiting for it, so give the
/// permission check and the start a turn before looking.
Future<void> _started() => pumpEventQueue();

({PracticeController controller, FakeListener mic, _FakePlayer player}) _build({
  bool allowed = true,
}) {
  final mic = FakeListener(allowed: allowed);
  final player = _FakePlayer();
  final controller = PracticeController(
    tune: _tune(),
    player: player,
    settings: AppSettings.inMemory(),
    listener: mic,
  );
  addTearDown(controller.dispose);
  return (controller: controller, mic: mic, player: player);
}

void main() {
  group('switching it on', () {
    test('picks the 3rd to aim at when nothing is chosen', () async {
      final (:controller, :mic, :player) = _build();
      expect(controller.settings.aimFor, isNull);
      await controller.setChecking(true);
      expect(controller.checking, isTrue);
      expect(controller.settings.aimFor, DrillTarget.third);
      // It starts listening at once, before the band, so you can play a
      // note and see that it is heard.
      expect(controller.listenState, Listening.listening);
      expect(mic.listening, isTrue);
      expect(controller.hearingNothing, isTrue, reason: 'nothing played yet');
      mic.hear(midiToHz(65));
      expect(controller.hearingNothing, isFalse);
      expect(controller.heard!.midi % 12, 5, reason: 'an F');
      expect(controller.listenLevel, greaterThan(0));

      await controller.setChecking(false);
      expect(controller.listenState, Listening.off);
      expect(mic.stopped, isTrue);
    });

    test('keeps the note you had already chosen', () async {
      final (:controller, :mic, :player) = _build();
      await controller.settings.setAimFor(DrillTarget.seventh);
      await controller.setChecking(true);
      expect(controller.settings.aimFor, DrillTarget.seventh);
    });

    test('says so when the microphone is blocked', () async {
      final (:controller, :mic, :player) = _build(allowed: false);
      await controller.setChecking(true);
      await controller.play();
      await _started();
      expect(controller.listenState, Listening.denied);
      expect(mic.listening, isFalse);
    });

    test('listening does not stop the band', () async {
      final (:controller, :mic, :player) = _build();
      await controller.setChecking(true);
      await controller.play();
      await _started();
      expect(mic.listening, isTrue);
      expect(
        mic.alongside,
        isTrue,
        reason: 'the microphone and the speaker at once',
      );
      await controller.stop();
      expect(mic.stopped, isTrue);
      expect(player.restored, isTrue, reason: 'the band gets its audio back');
    });
  });

  group('marking a run', () {
    test('a chorus of ii–V–I, two found and one missed', () async {
      final (:controller, :mic, :player) = _build();
      await controller.setChecking(true);
      await controller.play();
      await _started();
      final check = controller.check!;

      check.moveTo(0, 0); // Dm7, the 3rd is F
      mic.hear(_hz(65)); // F4
      expect(check.current!.hit, isTrue);
      check.moveTo(4, 0); // G7, the 3rd is B
      mic.hear(_hz(71)); // B4
      check.moveTo(8, 0); // CΔ7, the 3rd is E
      mic.hear(_hz(62)); // D4, not the 3rd
      check.moveTo(12, 0);
      await controller.stop();

      final score = controller.lastCheck!;
      expect(score.asked, 3);
      expect(score.hits, 2);
      expect(controller.check, isNull, reason: 'the run is over');
    });

    test('what it hears is shown as your instrument reads it', () async {
      final (:controller, :mic, :player) = _build();
      await controller.settings.setInstrument(ChartInstrument.bFlat);
      await controller.setChecking(true);
      await controller.play();
      await _started();
      // A B♭ trumpet playing its written D sounds a concert C.
      mic.hear(_hz(60)); // concert C4
      expect(controller.heard!.midi % 12, 2, reason: 'written D');
      mic.hear(null);
      expect(controller.heard, isNull);
    });

    test('nothing is marked when it is switched off', () async {
      final (:controller, :mic, :player) = _build();
      await controller.play();
      await _started();
      expect(controller.check, isNull);
      expect(mic.listening, isFalse);
      await controller.stop();
      expect(controller.lastCheck, isNull);
    });
  });

  testWidgets('switch it on in View, play, and read the score', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final mic = FakeListener();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: PracticeScreen(
          tune: _tune(),
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
          listener: mic,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'View'));
    await tester.pumpAndSettle();
    final switchTile = find.byKey(const ValueKey('check-playing'));
    await tester.scrollUntilVisible(
      switchTile,
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining('Wear headphones'),
      findsOneWidget,
      reason: 'it has to say why a speaker will not do',
    );
    await tester.tap(switchTile);
    await tester.pumpAndSettle();
    // The meter comes up at once, so you can prove the microphone hears you
    // before committing to a chorus.
    expect(find.byKey(const ValueKey('mic-level')), findsOneWidget);
    expect(find.text('Too quiet: play a note'), findsOneWidget);

    mic.hear(midiToHz(65));
    await tester.pumpAndSettle();
    expect(find.text('Hearing F'), findsOneWidget);

    // Plenty of sound, but nothing nameable in it: what a band through a
    // speaker sounds like, and a different problem from silence.
    mic.level = 0.2;
    mic.hear(null);
    await tester.pumpAndSettle();
    expect(find.text('Sound, but no clear note'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sheet-done')));
    await tester.pumpAndSettle();
    // Aiming at the 3rd now, chosen for us.
    expect(find.textContaining('Aim: F'), findsOneWidget);
  });
}
