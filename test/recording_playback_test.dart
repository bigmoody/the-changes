// From a file in the store to the engine's knobs.
//
// The sums live in recorded_take.dart and are tested there. What is
// checked here is that they are the ones that actually reach the player,
// that the right take is chosen at the moment Play is pressed, and that
// the stems arrive decoded rather than as bytes nobody read.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/recorded_take.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/settings/app_settings.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
  PlayableRecording? given;
  var starts = 0;

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {
    starts++;
    given = recording;
  }

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// A playable mono WAV of [seconds], holding a steady tone's worth of
/// something so it is not mistaken for an empty file.
Uint8List wavOf(double seconds, {int rate = 8000, int channels = 1}) {
  final frames = (seconds * rate).round();
  final body = Uint8List(frames * channels * 2);
  final view = ByteData.sublistView(body);
  for (var i = 0; i < frames * channels; i++) {
    view.setInt16(i * 2, (i % 100) * 300 - 15000, Endian.little);
  }
  final out = BytesBuilder();
  void u32(int v) =>
      out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      out.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  out.add('RIFF'.codeUnits);
  u32(36 + body.length);
  out.add('WAVE'.codeUnits);
  out.add('fmt '.codeUnits);
  u32(16);
  u16(1);
  u16(channels);
  u32(rate);
  u32(rate * channels * 2);
  u16(channels * 2);
  u16(16);
  out.add('data'.codeUnits);
  u32(body.length);
  out.add(body);
  return out.toBytes();
}

const f = 5;
const bFlat = 10;
final ref = TuneRef.standard('Jazz blues in F');

void main() {
  late _FakePlayer player;
  late RecordingStore store;
  late PracticeController controller;

  /// A take really put in, files and all, the way the sheet puts one in.
  Future<void> put(
    String name,
    double bpm,
    int key, {
    List<TakeStem> stems = TakeStem.values,
    double seconds = 144,
  }) async {
    final id = store.newId();
    final files = <TakeStem, String>{};
    for (final stem in stems) {
      files[stem] = await store.keep(id, stem, wavOf(seconds));
    }
    await store.add(
      ref,
      RecordedTake(
        name: name,
        files: files,
        bpm: bpm,
        key: key,
        bars: 12,
        choruses: 6,
      ),
    );
  }

  setUp(() {
    player = _FakePlayer();
    store = RecordingStore.inMemory();
    controller = PracticeController(
      tune: practiceProgressions.firstWhere(
        (tune) => tune.title == 'Jazz blues in F',
      ),
      player: player,
      settings: AppSettings.inMemory(),
      recordingStore: store,
      ref: ref,
    );
  });

  tearDown(() => controller.dispose());

  group('with no recording imported', () {
    test('the generated band plays, and nothing is handed over', () async {
      await controller.play();
      expect(player.starts, 1);
      expect(player.given, isNull);
      expect(controller.recordingInUse, isNull);
    });
  });

  group('with one imported', () {
    test('it reaches the player, decoded', () async {
      await put('F 120', 120, f);
      controller.setTempo(120);
      await controller.play();

      final given = player.given!;
      expect(given.take.name, 'F 120');
      expect(given.stems.keys, hasLength(3));
      expect(
        given.stems[TakeStem.bass]!.seconds,
        closeTo(144, 0.01),
        reason: 'the bytes were read, not just passed on',
      );
      expect(given.stems[TakeStem.bass]!.sampleRate, 8000);
    });

    test(
      'at its own tempo and key the engine is asked to do nothing',
      () async {
        await put('F 120', 120, f);
        controller.setTempo(120);
        await controller.play();
        expect(player.given!.shift.speed, closeTo(1, 0.0001));
        expect(player.given!.shift.shift, closeTo(1, 0.0001));
      },
    );

    test('a faster tempo arrives as speed, with the pitch put back', () async {
      await put('F 120', 120, f);
      controller.setTempo(180);
      await controller.play();
      expect(player.given!.shift.speed, closeTo(1.5, 0.0001));
      expect(player.given!.shift.cents, closeTo(-701.955, 0.01));
    });

    test('transposing arrives as the filter', () async {
      await put('F 120', 120, f);
      controller.setTempo(120);
      controller.transpose(1);
      await controller.play();
      expect(player.given!.shift.speed, closeTo(1, 0.0001));
      expect(player.given!.shift.cents, closeTo(100, 0.01));
    });

    test('a take missing a stem still plays with what it has', () async {
      // Bass and drums with no comp is still a rhythm section.
      await put('F 120', 120, f, stems: [TakeStem.bass, TakeStem.drums]);
      await controller.play();
      expect(player.given!.stems.keys, hasLength(2));
      expect(player.given!.stems.containsKey(TakeStem.comp), isFalse);
    });

    test('a take whose files have gone is not played at all', () async {
      await store.add(
        ref,
        RecordedTake(
          name: 'Lost',
          files: const {TakeStem.bass: 'gone.wav'},
          bpm: 120,
          key: f,
          bars: 12,
          choruses: 6,
        ),
      );
      await controller.play();
      expect(player.given, isNull, reason: 'the band plays instead');
    });
  });

  group('choosing between four', () {
    setUp(() async {
      await put('F 120', 120, f);
      await put('F 180', 180, f);
      await put('B flat 120', 120, bFlat);
      await put('B flat 180', 180, bFlat);
    });

    test('the awkward one lands on the take that needs least', () async {
      // G at 150: B flat at 180 slowed down drops almost exactly the
      // three semitones to G on its own.
      controller.setTempo(150);
      controller.transpose(2); // F up two is G
      await controller.play();
      expect(player.given!.take.name, 'B flat 180');
      expect(player.given!.shift.cents.abs(), lessThan(20));
    });

    test('and its own key and tempo win outright', () async {
      controller.setTempo(180);
      controller.transpose(5);
      await controller.play();
      expect(player.given!.take.name, 'B flat 180');
      expect(player.given!.shift.cents, closeTo(0, 0.0001));
    });
  });

  group('turning it off', () {
    test('the generated band comes back', () async {
      await put('F 120', 120, f);
      controller.setUseRecording(false);
      await controller.play();
      expect(player.given, isNull);
      expect(controller.recordingInUse, isNull);

      controller.setUseRecording(true);
      await controller.play();
      expect(player.given, isNotNull);
    });
  });
}
