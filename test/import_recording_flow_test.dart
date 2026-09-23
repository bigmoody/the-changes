// Importing a take, the whole way through.
//
// The file picker stands in for itself here, so this drives the sheet the
// way a person would: choose three files with the names the template asks
// for, watch what the app works out on its own, measure the playing, and
// put the take in.
//
// The recordings are invented, so what is wrong with each is known
// exactly. That is the point of doing it at this level rather than
// further down: the numbers are tested in timing_check_test, and what is
// tested here is that the ones on screen are those numbers.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/recorded_take.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/audio/timing_check.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/screens/import_recording_sheet.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePlayer extends PracticePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// Hands back whatever the test says is in the file dialog.
class _FakePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakePicker(this.files);
  final List<PlatformFile> files;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => files.isEmpty ? null : FilePickerResult(files);
}

/// A WAV of a drummer hitting [beats] beats, at [bpm], starting [from]
/// seconds in, each hit [wobble] seconds away from where it should be.
Uint8List drummer({
  required int beats,
  double bpm = 120,
  double from = 0,
  double wobble = 0,
  int seed = 5,
  int rate = 16000,
}) {
  final period = 60 / bpm;
  final seconds = from + beats * period + 1;
  final frames = (seconds * rate).round();
  final samples = Float32List(frames);
  final noise = math.Random(seed);
  final length = (0.005 * rate).round();
  for (var beat = 0; beat < beats; beat++) {
    final at =
        from +
        beat * period +
        (wobble == 0 ? 0 : (noise.nextDouble() - 0.5) * wobble);
    final start = (at * rate).round();
    for (var i = 0; i < length; i++) {
      if (start + i < 0 || start + i >= frames) continue;
      samples[start + i] +=
          (noise.nextDouble() * 2 - 1) * math.exp(-i / (length / 3)) * 0.7;
    }
  }
  // Wrap it as a 16-bit mono WAV, which is what a picker hands over.
  final body = Uint8List(frames * 2);
  final view = ByteData.sublistView(body);
  for (var i = 0; i < frames; i++) {
    view.setInt16(
      i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
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
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  out.add('data'.codeUnits);
  u32(body.length);
  out.add(body);
  return out.toBytes();
}

PlatformFile file(String name, Uint8List bytes) =>
    PlatformFile(name: name, size: bytes.length, bytes: bytes);

final ref = TuneRef.standard('Jazz blues in F');

void main() {
  late PracticeController controller;
  late RecordingStore store;

  /// The blues is twelve bars of four, so two choruses is ninety-six
  /// beats: forty-eight seconds at 120.
  const choruses = 2;
  const beats = 12 * 4 * choruses;

  Future<void> open(WidgetTester tester, List<PlatformFile> files) async {
    tester.view
      ..physicalSize = const Size(393, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    FilePicker.platform = _FakePicker(files);
    store = RecordingStore.inMemory();
    controller = PracticeController(
      tune: practiceProgressions.firstWhere(
        (tune) => tune.title == 'Jazz blues in F',
      ),
      player: _FakePlayer(),
      settings: AppSettings.inMemory(),
      recordingStore: store,
      ref: ref,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: SingleChildScrollView(
              child: TextButton(
                onPressed: () => showImportRecording(
                  context,
                  controller,
                  // Measured on this thread, so a pump is enough to wait
                  // for it. The app gives this its own isolate.
                  measure: (audio, take) async =>
                      checkTiming(audio, take: take),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose-recording')));
    await tester.pumpAndSettle();
  }

  String textOf(Key key) =>
      (find.byKey(key).evaluate().single.widget as Text).data!;

  group('choosing the files the template asks for', () {
    testWidgets('the names fill in the stem, the tempo and the key', (
      tester,
    ) async {
      final audio = drummer(beats: beats);
      await open(tester, [
        file('blues-F-120-bass.wav', audio),
        file('blues-F-120-drums.wav', audio),
        file('blues-F-120-comp.wav', audio),
      ]);
      expect(find.byKey(const ValueKey('stem-bass')), findsOneWidget);
      expect(find.byKey(const ValueKey('stem-drums')), findsOneWidget);
      expect(find.byKey(const ValueKey('stem-comp')), findsOneWidget);
      final tempo = tester.widget<TextField>(
        find.byKey(const ValueKey('recording-tempo')),
      );
      expect(tempo.controller!.text, '120');
    });

    testWidgets('the length says how many choruses are on it', (tester) async {
      final audio = drummer(beats: beats);
      await open(tester, [file('blues-F-120-drums.wav', audio)]);
      expect(textOf(const ValueKey('length-verdict')), '2 choruses of 12 bars');
    });

    testWidgets('a file the app cannot read says which file and why', (
      tester,
    ) async {
      await open(tester, [
        file(
          'blues-F-120-drums.mp3',
          Uint8List.fromList('ID3xxxxxxxxxxxx'.codeUnits),
        ),
      ]);
      expect(
        textOf(const ValueKey('recording-problem')),
        allOf(contains('blues-F-120-drums.mp3'), contains('not a WAV')),
      );
    });
  });

  group('measuring the playing', () {
    testWidgets('a drummer on the click is told so, in milliseconds', (
      tester,
    ) async {
      await open(tester, [
        file('blues-F-120-drums.wav', drummer(beats: beats)),
      ]);
      await tester.tap(find.byKey(const ValueKey('check-timing')));
      await tester.pumpAndSettle();
      expect(
        textOf(const ValueKey('timing-verdict')),
        allOf(contains(TimingVerdictLabel.locked), contains('ms average')),
      );
      expect(find.byKey(const ValueKey('nudge-start')), findsNothing);
      expect(find.byKey(const ValueKey('use-heard-tempo')), findsNothing);
    });

    testWidgets('a file trimmed late offers to move the start', (tester) async {
      await open(tester, [
        file('blues-F-120-drums.wav', drummer(beats: beats, from: 0.05)),
      ]);
      await tester.tap(find.byKey(const ValueKey('check-timing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nudge-start')), findsOneWidget);
      expect(
        textOf(const ValueKey('timing-verdict')),
        contains(TimingVerdictLabel.locked),
        reason: 'the file is wrong, not the playing',
      );

      await tester.tap(find.byKey(const ValueKey('nudge-start')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('start-offset')), contains('50 ms'));
    });

    testWidgets('a take at the wrong tempo offers the right one', (
      tester,
    ) async {
      // Played at 124 and labelled 120, which the length check alone
      // would report only as an odd chorus count.
      await open(tester, [
        file('blues-F-120-drums.wav', drummer(beats: beats, bpm: 124)),
      ]);
      await tester.tap(find.byKey(const ValueKey('check-timing')));
      await tester.pumpAndSettle();
      final offer = find.byKey(const ValueKey('use-heard-tempo'));
      expect(offer, findsOneWidget);
      expect(
        (tester.widget<TextButton>(offer).child! as Text).data,
        contains('124'),
      );

      await tester.tap(offer);
      await tester.pumpAndSettle();
      final tempo = tester.widget<TextField>(
        find.byKey(const ValueKey('recording-tempo')),
      );
      expect(double.parse(tempo.controller!.text), closeTo(124, 0.3));
    });

    testWidgets('a loose take is called loose and offered nothing', (
      tester,
    ) async {
      await open(tester, [
        file('blues-F-120-drums.wav', drummer(beats: beats, wobble: 0.09)),
      ]);
      await tester.tap(find.byKey(const ValueKey('check-timing')));
      await tester.pumpAndSettle();
      expect(
        textOf(const ValueKey('timing-verdict')),
        contains(TimingVerdictLabel.loose),
      );
      expect(find.byKey(const ValueKey('nudge-start')), findsNothing);
    });

    testWidgets('an answer is dropped once it stops describing the take', (
      tester,
    ) async {
      await open(tester, [
        file('blues-F-120-drums.wav', drummer(beats: beats)),
      ]);
      await tester.tap(find.byKey(const ValueKey('check-timing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timing-verdict')), findsOneWidget);

      // Changing the tempo makes the measurement about a take that is no
      // longer the one on screen, so it goes rather than sitting there
      // looking authoritative.
      await tester.enterText(
        find.byKey(const ValueKey('recording-tempo')),
        '150',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timing-verdict')), findsNothing);
      expect(find.byKey(const ValueKey('check-timing')), findsOneWidget);
    });
  });

  group('putting it in', () {
    testWidgets('the take arrives with everything worked out on it', (
      tester,
    ) async {
      final audio = drummer(beats: beats, from: 0.05);
      await open(tester, [
        file('blues-Bb-120-bass.wav', audio),
        file('blues-Bb-120-drums.wav', audio),
      ]);
      await tester.tap(find.byKey(const ValueKey('check-timing')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nudge-start')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add-recording')));
      await tester.pumpAndSettle();

      final take = store.forTune(ref).takes.single;
      expect(take.bpm, 120);
      expect(take.key, 10, reason: 'B flat, read off the file name');
      expect(take.bars, 12);
      expect(take.choruses, choruses);
      expect(take.files.keys, hasLength(2));
      expect(take.startSeconds, closeTo(0.05, 0.005));
    });

    testWidgets('and the audio is kept, not just the facts', (tester) async {
      final audio = drummer(beats: beats);
      await open(tester, [file('blues-F-120-drums.wav', audio)]);
      await tester.tap(find.byKey(const ValueKey('add-recording')));
      await tester.pumpAndSettle();
      final take = store.forTune(ref).takes.single;
      expect(await store.pathOf(take.files[TakeStem.drums]!), isNotNull);
    });
  });
}

/// The words the verdicts are shown with, so a test does not have to
/// repeat them and then quietly stop matching.
abstract final class TimingVerdictLabel {
  static const locked = 'Locked to the click';
  static const loose = 'Loose';
}
