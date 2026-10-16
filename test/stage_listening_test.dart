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
      tempo: tune.defaultTempo.toDouble(),
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

    // Ten bars of the band, from the top.
    await play(tester, stage.room, from: 0, beats: 40);
    expect(find.textContaining('Following the room'), findsOneWidget);
    // On bar ten, or just into the eleventh: the last piece of sound
    // handed over runs up to its barline.
    expect(stage.ear.position!.bar, inInclusiveRange(9, 10));

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
    expect(stage.ear.position, isNotNull, reason: 'the taps start the count');
    expect(stage.ear.position!.tempo, closeTo(record, record * 0.05));
  });
}
