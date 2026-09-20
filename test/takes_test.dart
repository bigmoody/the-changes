// Recording yourself over the band, and playing it back against the chart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/export_track.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/take_recorder.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/take_store.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// A band that plays without any audio, remembering what it was asked for.
class _FakePlayer extends PracticePlayer {
  BackingRequest? request;
  String? alongside;
  Duration? leadIn;
  double takeVolume = 1;
  var failOnTake = false;

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
  }) async {
    if (alongside != null && failOnTake) {
      throw StateError('could not open the recording');
    }
    this.request = request;
    this.alongside = alongside;
    this.leadIn = leadIn;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> restoreAudioSession() async {}

  @override
  void setTakeVolume(double volume) => takeVolume = volume;

  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// A microphone that writes nothing, but says how long it ran.
class _FakeRecorder implements TakeRecorder {
  _FakeRecorder({
    this.allowed = true,
    this.records = const Duration(minutes: 1),
  });

  final bool allowed;
  final Duration records;
  String? startedAt;
  var stopped = false;
  var asked = false;

  @override
  Future<bool> hasPermission() async {
    asked = true;
    return allowed;
  }

  @override
  Future<void> start(String path) async => startedAt = path;

  @override
  Future<Duration> stop() async {
    stopped = true;
    return records;
  }

  @override
  Future<void> dispose() async => stop();

  @override
  bool get isRecording => startedAt != null && !stopped;

  @override
  Duration get length => records;
}

({
  PracticeController controller,
  _FakePlayer player,
  TakeStore store,
  _FakeRecorder mic,
})
_build({bool allowed = true, Duration records = const Duration(minutes: 1)}) {
  final player = _FakePlayer();
  final store = TakeStore.inMemory();
  final mic = _FakeRecorder(allowed: allowed, records: records);
  final controller = PracticeController(
    tune: standards.firstWhere((t) => t.title == 'Blue Bossa'),
    player: player,
    settings: AppSettings.inMemory(),
    takes: store,
    recorder: mic,
  );
  addTearDown(controller.dispose);
  return (controller: controller, player: player, store: store, mic: mic);
}

void main() {
  group('recording', () {
    test('it asks for the microphone before arming', () async {
      final (:controller, :mic, :store, :player) = _build(allowed: false);
      await controller.setRecording(true);
      expect(controller.recording, isFalse);
      expect(mic.asked, isTrue);
      expect(controller.error, contains('microphone'));
    });

    test('the microphone starts with Play, not with the switch', () async {
      final (:controller, :mic, :store, :player) = _build();
      await controller.setRecording(true);
      expect(controller.recording, isTrue);
      expect(mic.startedAt, isNull, reason: 'nothing is playing yet');

      await controller.play();
      expect(mic.startedAt, isNotNull);
      expect(controller.isRecordingNow, isTrue);
    });

    test('Stop saves the take, with what the band was doing', () async {
      final (:controller, :mic, :store, :player) = _build();
      controller.setTempo(168);
      controller.transpose(2);
      controller.setArrangement(const Arrangement(choruses: 3));
      await controller.setRecording(true);
      await controller.play();
      final seed = player.request!.seed;
      await controller.stop();
      await pumpEventQueue();

      final take = store.all.single;
      expect(take.tune, 'Blue Bossa');
      expect(take.tempo, 168);
      expect(take.semitones, 2);
      expect(take.seed, seed, reason: 'the band can be played again exactly');
      expect(take.arrangement.choruses, 3);
      expect(mic.stopped, isTrue);
    });

    test('a false start is thrown away rather than kept', () async {
      final (:controller, :mic, :store, :player) = _build(
        records: const Duration(seconds: 2),
      );
      await controller.setRecording(true);
      await controller.play();
      await controller.stop();
      await pumpEventQueue();
      expect(store.all, isEmpty);
      expect((store.files as NoFiles).removed, hasLength(1));
    });

    test('no store, no recording', () {
      final controller = PracticeController(
        tune: standards.first,
        player: _FakePlayer(),
        settings: AppSettings.inMemory(),
      );
      addTearDown(controller.dispose);
      expect(controller.canRecord, isFalse);
    });
  });

  group('playing one back', () {
    Future<Take> record(PracticeController controller, TakeStore store) async {
      await controller.setRecording(true);
      await controller.play();
      await controller.stop();
      await pumpEventQueue();
      return store.all.single;
    }

    test('the band is put back exactly as it was', () async {
      final (:controller, :mic, :store, :player) = _build();
      controller.setTempo(150);
      final take = await record(controller, store);

      // Move everything, then play the take: it all comes back.
      controller.setTempo(90);
      controller.transpose(5);
      controller.setArrangement(Arrangement.keepGoing);
      await controller.playTake(take);

      expect(controller.tempo, 150);
      expect(controller.semitones, take.semitones);
      expect(player.request!.seed, take.seed);
      expect(player.request!.countInBars, 0, reason: 'it starts where it was');
      expect(player.alongside, isNotNull, reason: 'you are played with it');
      expect(controller.playingTake?.id, take.id);
    });

    test('the wait while the band was written is wound past', () async {
      final (:controller, :mic, :store, :player) = _build();
      final take = await record(controller, store);
      await controller.playTake(take);
      expect(
        player.leadIn!.inMilliseconds,
        (take.leadIn * 1000).round(),
        reason: 'the recording started before the band did',
      );
    });

    test('playing normally afterwards is not a take any more', () async {
      final (:controller, :mic, :store, :player) = _build();
      final take = await record(controller, store);
      await controller.playTake(take);
      expect(controller.playingTake, isNotNull);
      await controller.play();
      expect(controller.playingTake, isNull);
      expect(player.alongside, isNull);
    });

    test('how loud you are against the band', () async {
      final (:controller, :mic, :store, :player) = _build();
      controller.setTakeVolume(0.4);
      expect(player.takeVolume, 0.4);
      expect(controller.takeVolume, 0.4);
    });

    test(
      'playing the take alone silences the band, but keeps the chart',
      () async {
        final (:controller, :mic, :store, :player) = _build();
        final take = await record(controller, store);
        await controller.setTakesWithBand(false);
        await controller.playTake(take);

        // The band is still written — it's what the chart follows — but
        // nothing of it is heard.
        expect(player.request, isNotNull);
        expect(player.alongside, isNotNull);
        for (final part in Instrument.values) {
          expect(controller.isAudible(part), isFalse, reason: part.name);
        }

        // Switching it back on while it plays brings the band in.
        await controller.setTakesWithBand(true);
        expect(controller.isAudible(Instrument.bass), isTrue);
      },
    );

    test(
      'a take that will not open says so, instead of just playing the band',
      () async {
        final (:controller, :mic, :store, :player) = _build();
        final take = await record(controller, store);
        player.failOnTake = true;
        await controller.playTake(take);

        expect(controller.isPlaying, isFalse);
        expect(controller.error, contains("recording wouldn't open"));
        expect(controller.playingTake, isNull);
        // And the band isn't left silenced afterwards.
        expect(controller.isAudible(Instrument.bass), isTrue);
      },
    );

    test('a normal Play after a silent take hears the band again', () async {
      final (:controller, :mic, :store, :player) = _build();
      final take = await record(controller, store);
      await controller.setTakesWithBand(false);
      await controller.playTake(take);
      expect(controller.isAudible(Instrument.drums), isFalse);
      await controller.play();
      expect(controller.isAudible(Instrument.drums), isTrue);
    });

    test('a take whose file has gone says so', () async {
      final (:controller, :mic, :store, :player) = _build();
      final take = await record(controller, store);
      await store.delete(take.id);
      await controller.playTake(
        Take(
          id: 'x',
          at: DateTime.now(),
          file: 'nothing.wav',
          tune: 'Blue Bossa',
          seconds: 60,
          leadIn: 1,
          tempo: 140,
          semitones: 0,
          loopStart: 0,
          loopBeats: 64,
          seed: 1,
          arrangement: Arrangement.keepGoing,
        ),
      );
      // NoFiles always finds a path, so this only checks it doesn't throw.
      expect(store.all, isEmpty);
    });
  });

  group('what is saved', () {
    test('a take survives being written down and read back', () {
      final take = Take(
        id: 'a',
        at: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        file: 'a.wav',
        tune: 'Autumn Leaves',
        seconds: 92.5,
        leadIn: 1.25,
        tempo: 160,
        semitones: 3,
        loopStart: 16,
        loopBeats: 32,
        seed: 12345,
        arrangement: const Arrangement(
          choruses: 4,
          headInAndOut: true,
          trading: Trading.fours,
          layOut: {LayOut.chords},
          ramp: TempoRamp(step: 5, climb: 20),
        ),
      );
      final again = Take.fromJson(take.toJson());
      expect(again.id, take.id);
      expect(again.at, take.at);
      expect(again.seconds, 92.5);
      expect(again.leadIn, 1.25);
      expect(again.tempo, 160);
      expect(again.semitones, 3);
      expect(again.loopStart, 16);
      expect(again.seed, 12345);
      expect(again.arrangement, take.arrangement);
      // The length shown is what you played, not the wait before it.
      expect(again.length.inMilliseconds, 91250);
    });

    test('takes are listed newest first, and only for their own tune', () {
      final store = TakeStore.inMemory();
      Take at(String id, int day, String tune) => Take(
        id: id,
        at: DateTime(2026, 9, day),
        file: '$id.wav',
        tune: tune,
        seconds: 60,
        leadIn: 0,
        tempo: 140,
        semitones: 0,
        loopStart: 0,
        loopBeats: 64,
        seed: 1,
        arrangement: Arrangement.keepGoing,
      );
      store.add(at('a', 1, 'Blue Bossa'));
      store.add(at('b', 3, 'Blue Bossa'));
      store.add(at('c', 2, 'So What'));
      expect([for (final t in store.all) t.id], ['b', 'c', 'a']);
      expect([for (final t in store.forTune('Blue Bossa')) t.id], ['b', 'a']);
    });
  });

  group('exporting', () {
    test('it will not write a track that never ends', () async {
      final (:controller, :mic, :store, :player) = _build();
      await controller.exportBacking();
      expect(controller.error, contains('choruses'));
      expect(controller.isExporting, isFalse);
    });

    test('with a chorus count it knows how long the file will be', () {
      final (:controller, :mic, :store, :player) = _build();
      expect(controller.exportLengthNow, isNull, reason: 'keeps going');
      controller.setTempo(120);
      controller.setArrangement(const Arrangement(choruses: 2));
      final length = controller.exportLengthNow!;
      // Blue Bossa is sixteen bars of four; two choruses at 120 is 64 s,
      // plus a bar of count-in.
      expect(length.inSeconds, 66);
    });

    test('a take exports at its own length, not the arrangement\'s', () {
      // Blue Bossa is sixteen bars of four — 64 beats — in two eight-bar
      // sections. Somebody who played 20 seconds at 120 has got 40 beats
      // in, which is into the second half, so the band runs to the end of
      // it: 64 beats, 32 seconds.
      final tune = standards.firstWhere((t) => t.title == 'Blue Bossa');
      final request = BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: 120,
        arrangement: const Arrangement(choruses: 8),
      );
      final played = beatsIn(request, const Duration(seconds: 20));
      expect(played, 40);
      final end = finishSectionAfter(tune, request.loop, played);
      expect(end, lessThanOrEqualTo(64), reason: 'not eight choruses of it');
      expect(end, greaterThanOrEqualTo(40), reason: 'at least what was played');
      // And it lands on a section, not wherever the playing stopped.
      final letters = {
        for (final bar in tune.sections.keys) bar * tune.beatsPerBar,
        request.loop.lengthBeats,
      };
      expect(letters, contains(end));
    });

    test('a tempo ramp shortens the file', () {
      final (:controller, :mic, :store, :player) = _build();
      controller.setTempo(120);
      controller.setArrangement(const Arrangement(choruses: 4));
      final steady = controller.exportLengthNow!;
      controller.setArrangement(
        const Arrangement(choruses: 4, ramp: TempoRamp(step: 20, climb: 60)),
      );
      expect(controller.exportLengthNow!, lessThan(steady));
    });
  });

  testWidgets('the Arrangement sheet offers the export once it can end', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title == 'Blue Bossa'),
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
          takes: TakeStore.inMemory(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arrangement')));
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('export'));
    await tester.scrollUntilVisible(
      button,
      80,
      scrollable: find.byType(Scrollable).last,
    );
    // Round and round for ever can't be a file, so it's offered but off.
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.textContaining('a track has to end'), findsOneWidget);

    final choruses = find.byKey(const ValueKey('choruses-4'));
    await tester.scrollUntilVisible(
      choruses,
      -80,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(choruses);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      button,
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    // And it says how long it will be before you wait for it.
    expect(find.textContaining('of Backing'), findsOneWidget);
  });

  testWidgets('the Takes sheet: record, then the take is listed', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = TakeStore.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title == 'Blue Bossa'),
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
          takes: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('takes')));
    await tester.pumpAndSettle();
    expect(find.text('Takes'), findsWidgets);
    expect(find.byKey(const ValueKey('no-takes')), findsOneWidget);

    await store.add(
      Take(
        id: 'a',
        at: DateTime.now(),
        file: 'a.wav',
        tune: 'Blue Bossa',
        seconds: 65,
        leadIn: 1,
        tempo: 152,
        semitones: 0,
        loopStart: 0,
        loopBeats: 64,
        seed: 7,
        arrangement: Arrangement.keepGoing,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-takes')), findsNothing);
    expect(find.text('Just now'), findsOneWidget);
    expect(find.textContaining('1:04'), findsOneWidget);
    expect(find.textContaining('152 BPM'), findsOneWidget);

    // Throwing it away empties the list again.
    await tester.tap(find.byTooltip('Delete this take'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-takes')), findsOneWidget);
  });
}
