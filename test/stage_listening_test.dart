// The scrolling stage, listening to the room.
//
// A track of the band stands in for the microphone, handed to the stage
// a piece at a time, and the stage is watched to see whether it marks
// where the music is, says when it is not sure, and believes a tap.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/room_listener.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/stage_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

void main() {
  final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
  late Float32List track;
  late int samplesPerBeat;
  late int leadIn;

  setUpAll(() async {
    final bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
    final backing = renderBacking(
      BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: tune.defaultTempo,
        samples: bank,
        seed: 1,
      ),
    );
    samplesPerBeat = backing.samplesPerBeat;
    leadIn = backing.countInBeats * samplesPerBeat;
    Float32List? mix;
    for (final stem in backing.stems.values) {
      final wav = readWav(stem);
      mix ??= Float32List(wav.frames);
      for (var i = 0; i < math.min(wav.frames, mix.length); i++) {
        var sum = 0.0;
        for (var c = 0; c < wav.channels; c++) {
          sum += wav.samples[i * wav.channels + c];
        }
        mix[i] += sum / wav.channels;
      }
    }
    // Silence before the top, as a band starting from it would have.
    track = mix!..fillRange(0, leadIn, 0);
  });

  Future<
    ({
      PracticeController controller,
      StreamController<Float32List> room,
      RoomListener ear,
    })
  >
  openStage(WidgetTester tester, {bool follow = true}) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = PracticeController(
      tune: tune,
      player: PracticePlayer(),
      settings: AppSettings.inMemory(),
    );
    addTearDown(controller.dispose);
    final room = StreamController<Float32List>();
    // Not waited for: closing a stream nobody listened to never finishes.
    addTearDown(() {
      unawaited(room.close());
    });
    final ear = RoomListener(
      tune: controller.tune,
      source: () async => room.stream,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: StageScreen(
          controller: controller,
          follow: follow,
          listener: ear,
        ),
      ),
    );
    await tester.pump();
    return (controller: controller, room: room, ear: ear);
  }

  /// Plays [beats] of the track into the room, from beat [from] of it.
  Future<void> play(
    WidgetTester tester,
    StreamController<Float32List> room, {
    required int from,
    required int beats,
  }) async {
    final start = leadIn + from * samplesPerBeat;
    final end = start + beats * samplesPerBeat;
    for (var at = from == 0 ? 0 : start; at < end; at += 4096) {
      room.add(Float32List.sublistView(track, at, math.min(at + 4096, end)));
      await tester.pump();
    }
    await tester.pump();
  }

  testWidgets('only the scrolling stage listens', (tester) async {
    await openStage(tester, follow: false);
    expect(find.byKey(const ValueKey('stage-listen')), findsNothing);
  });

  testWidgets('it marks the bar the room is on', (tester) async {
    final stage = await openStage(tester);
    await tester.tap(find.byKey(const ValueKey('stage-listen')));
    await tester.pump();
    // Nothing heard yet: it says what to do, and there is a button to
    // tap the beat on.
    expect(find.textContaining('very quiet'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-tap-tempo')), findsOneWidget);

    // Sixteen bars of the band, from the top: it is told nothing about
    // the tempo, and hears it in the first few bars.
    await play(tester, stage.room, from: 0, beats: 64);
    expect(find.textContaining('Following the room'), findsOneWidget);
    // On bar sixteen, or just into the seventeenth: the last piece of
    // sound handed over runs up to its barline.
    expect(stage.ear.position!.bar, inInclusiveRange(15, 16));

    // A tap on a bar is believed at once.
    await tester.tap(find.text('1').first);
    await tester.pump();
    expect(stage.ear.position!.bar, 0);
  });

  testWidgets('the band and the ear take turns', (tester) async {
    final stage = await openStage(tester);
    await tester.tap(find.byKey(const ValueKey('stage-listen')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stage-play')));
    await tester.pumpAndSettle();
    expect(stage.ear.listening, isFalse);
    expect(find.byKey(const ValueKey('stage-hearing')), findsNothing);
    await stage.controller.stop();
    await tester.pump();
  });

  testWidgets('tapping the beat gives the count its tempo', (tester) async {
    // The record is half as fast again as the chart says: a few taps
    // along with it and the count is on it.
    final stage = await openStage(tester);
    await tester.tap(find.byKey(const ValueKey('stage-listen')));
    await tester.pump();
    final record = tune.defaultTempo * 1.5;
    final beat = (44100 * 60 / record).round();
    // A bar of the track at its own speed would need a new render; the
    // taps are what is being tested, so silence does for the sound.
    for (var i = 0; i < 4; i++) {
      stage.room.add(Float32List(beat));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('stage-tap-tempo')));
      await tester.pump();
    }
    // Three taps are enough to choose the tempo, without waiting to hear it.
    final following = stage.ear.follower.following;
    expect(following, isNotNull, reason: 'the taps choose the tempo');
    expect(following!.tempo, closeTo(record, record * 0.05));
  });

  test('what it heard can be saved and read back', () async {
    final room = StreamController<Float32List>();
    final ear = RoomListener(
      tune: tune,
      source: () async => room.stream,
      keepWhatItHears: true,
    );
    await ear.start();
    final second = Float32List.sublistView(track, leadIn, leadIn + 44100);
    room.add(second);
    await Future<void>.delayed(Duration.zero);
    ear.tap();
    await ear.stop();
    final heard = ear.whatItHeard()!;
    final wav = readWav(heard.wav);
    expect(wav.sampleRate, 44100);
    expect(wav.frames, 44100);
    expect(heard.log, contains('TAP THE BEAT'));
    expect(heard.log, contains(tune.title));
    unawaited(room.close());
    ear.dispose();
  });

  test('and nothing is kept unless asked', () async {
    final room = StreamController<Float32List>();
    final ear = RoomListener(
      tune: tune,
      source: () async => room.stream,
      keepWhatItHears: false,
    );
    await ear.start();
    room.add(Float32List(4410));
    await Future<void>.delayed(Duration.zero);
    await ear.stop();
    expect(ear.whatItHeard(), isNull);
    unawaited(room.close());
    ear.dispose();
  });
}
