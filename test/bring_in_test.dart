// One door for anything a tune can take.
//
// The point is the routing: the file says what it is, so nobody has to
// decide whether theirs is a "part" or a "recording" before the app will
// look at it. These check that each kind lands in the right sheet, and
// that a file at the wrong door is told which door.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/screens/bring_in_sheet.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'soundfont_test.dart' show buildFont, sample, zone;
import 'support/fake_player.dart';

/// A MIDI file with one note in it: enough to be read, which is all the
/// routing cares about.
Uint8List midiFile() {
  final bytes = BytesBuilder()
    ..add('MThd'.codeUnits)
    ..add([0, 0, 0, 6, 0, 0, 0, 1, 0, 96])
    ..add('MTrk'.codeUnits)
    ..add([0, 0, 0, 12])
    // A note on, a note off, and the end of the track.
    ..add([0, 0x90, 60, 100, 0x60, 0x80, 60, 0, 0, 0xFF, 0x2F, 0]);
  return bytes.toBytes();
}

/// A WAV header with a little silence after it.
Uint8List wavFile() {
  final data = ByteData(44);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + 200, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 44100, Endian.little);
  data.setUint32(28, 88200, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, 200, Endian.little);
  return Uint8List.fromList([
    ...data.buffer.asUint8List(),
    ...List.filled(200, 0),
  ]);
}

class _FakePlayer extends FakePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  Future<void> open(
    WidgetTester tester,
    List<({String name, Uint8List bytes})> files,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 1600) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = PracticeController(
      tune: practiceProgressions.firstWhere(
        (tune) => tune.title == 'Jazz blues in F',
      ),
      player: _FakePlayer(),
      settings: AppSettings.inMemory(),
      recordingStore: RecordingStore.inMemory(),
      ref: TuneRef.standard('Jazz blues in F'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => bringSomethingIn(
                context,
                controller,
                pick: () async => files,
              ),
              child: const Text('Bring'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Bring'));
    await tester.pumpAndSettle();
  }

  testWidgets('a MIDI file opens the part sheet, already read', (tester) async {
    await open(tester, [(name: 'bass.mid', bytes: midiFile())]);
    // The part sheet, and it has the file: nobody is asked to pick it
    // again having just picked it.
    expect(find.text('Import a Part'), findsOneWidget);
    expect(find.textContaining('bass.mid'), findsWidgets);
  });

  testWidgets('a WAV opens the recorded band sheet instead', (tester) async {
    await open(tester, [(name: 'blues-F-120-drums.wav', bytes: wavFile())]);
    expect(find.text('Import a Recording'), findsOneWidget);
  });

  testWidgets('three stems all go in at once', (tester) async {
    // What the template delivers, and the reason the picker takes several.
    await open(tester, [
      (name: 'blues-F-120-bass.wav', bytes: wavFile()),
      (name: 'blues-F-120-drums.wav', bytes: wavFile()),
      (name: 'blues-F-120-comp.wav', bytes: wavFile()),
    ]);
    expect(find.text('Import a Recording'), findsOneWidget);
  });

  testWidgets('a SoundFont is sent to Settings rather than refused', (
    tester,
  ) async {
    await open(tester, [
      (
        name: 'piano.sf2',
        bytes: buildFont(samples: [sample()], zones: [zone(0)]),
      ),
    ]);
    expect(find.text('piano.sf2'), findsOneWidget);
    expect(find.textContaining('Imported Sounds'), findsOneWidget);
    // And it says why it belongs there rather than here.
    expect(find.textContaining('every tune'), findsOneWidget);
  });

  testWidgets('anything else says what a tune can actually take', (
    tester,
  ) async {
    await open(tester, [
      (name: 'holiday.jpg', bytes: Uint8List.fromList(List.filled(64, 3))),
    ]);
    expect(find.textContaining('MIDI file'), findsOneWidget);
    expect(find.textContaining('WAV'), findsOneWidget);
  });

  testWidgets('backing out of the picker opens nothing', (tester) async {
    await open(tester, []);
    expect(find.text('Import a Part'), findsNothing);
    expect(find.text('Import a Recording'), findsNothing);
  });
}
