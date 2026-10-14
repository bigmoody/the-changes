// The sheet where a recording of real players is put in.
//
// The file picker cannot be driven from a test, so what is checked here is
// everything after it: that the takes already in say honestly what playing
// them here would cost, that the one in use is the one the sums choose,
// and that changing the tempo or the key changes both without anybody
// having to press anything.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/recorded_take.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/screens/import_recording_sheet.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

const f = 5;
const bFlat = 10;

final ref = TuneRef.standard('Jazz blues in F');

RecordedTake take(String name, double bpm, int key) => RecordedTake(
  name: name,
  files: const {
    TakeStem.bass: 'bass.wav',
    TakeStem.drums: 'drums.wav',
    TakeStem.comp: 'comp.wav',
  },
  bpm: bpm,
  key: key,
  bars: 12,
  choruses: 6,
);

void main() {
  late PracticeController controller;
  late RecordingStore store;

  Future<void> open(
    WidgetTester tester, {
    List<RecordedTake> takes = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    store = RecordingStore.inMemory();
    for (final one in takes) {
      await store.add(ref, one);
    }
    controller = PracticeController(
      // The blues, written in F, so the key is a known quantity.
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
            body: TextButton(
              onPressed: () => showImportRecording(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The words under one take's name.
  String says(String name) =>
      ((find.byKey(ValueKey('take-$name')).evaluate().single.widget as ListTile)
                  .subtitle!
              as Text)
          .data!;

  group('with nothing imported', () {
    testWidgets('it says what this is for and that nothing leaves', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Import a Recording'), findsOneWidget);
      expect(find.textContaining('go nowhere'), findsOneWidget);
      expect(find.byKey(const ValueKey('choose-recording')), findsOneWidget);
      expect(find.text('Choose the Stems'), findsOneWidget);
    });

    testWidgets('there is nothing to add until a file is chosen', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('add-recording')), findsNothing);
      expect(find.byKey(const ValueKey('recording-tempo')), findsNothing);
    });
  });

  group('the takes that are in', () {
    testWidgets('each says what it is and what playing it here costs', (
      tester,
    ) async {
      await open(tester, takes: [take('F 120', 120, f)]);
      expect(find.text('F 120'), findsOneWidget);
      final said = says('F 120');
      expect(said, contains('6 choruses'));
      expect(said, contains('3 stems'));
      // The blues is in F at 120 by default, so nothing is being asked of
      // the recording at all.
      expect(said, contains('same key'));
      expect(said, contains(TakeStrain.asRecorded.label));
    });

    testWidgets('a take in another key says how far it is being moved', (
      tester,
    ) async {
      await open(tester, takes: [take('B flat 120', 120, bFlat)]);
      final said = says('B flat 120');
      expect(said, contains('5 semitones'));
      expect(said, contains('down'), reason: 'B flat to F is down, not up');
    });

    testWidgets('the cost is in cents, not a word on its own', (tester) async {
      await open(tester, takes: [take('B flat 120', 120, bFlat)]);
      expect(says('B flat 120'), contains('cents'));
    });
  });

  group('which take is used', () {
    testWidgets('the four of the template put one in use, and only one', (
      tester,
    ) async {
      await open(
        tester,
        takes: [
          take('F 120', 120, f),
          take('F 180', 180, f),
          take('B flat 120', 120, bFlat),
          take('B flat 180', 180, bFlat),
        ],
      );
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      expect(controller.recordingInUse?.name, 'F 120');
    });

    testWidgets('changing the tempo changes which one, with no tap', (
      tester,
    ) async {
      await open(tester, takes: [take('F 120', 120, f), take('F 180', 180, f)]);
      expect(controller.recordingInUse?.name, 'F 120');
      expect(says('F 120'), contains('same tempo'));

      // Nobody touches the sheet: the tempo moves underneath it.
      controller.setTempo(180);
      await tester.pumpAndSettle();
      expect(controller.recordingInUse?.name, 'F 180');
      expect(
        says('F 180'),
        contains('same tempo'),
        reason: 'the sheet redrew from the new tempo',
      );
      expect(says('F 120'), contains('50% faster'));
    });

    testWidgets('transposing changes it too', (tester) async {
      await open(
        tester,
        takes: [take('F 120', 120, f), take('B flat 120', 120, bFlat)],
      );
      expect(controller.recordingInUse?.name, 'F 120');
      controller.transpose(5); // F up five is B flat
      await tester.pumpAndSettle();
      expect(controller.recordingInUse?.name, 'B flat 120');
      expect(says('B flat 120'), contains('same key'));
    });
  });

  group('taking one out', () {
    testWidgets('it goes, and the sheet says so without being reopened', (
      tester,
    ) async {
      await open(tester, takes: [take('F 120', 120, f), take('F 180', 180, f)]);
      expect(find.text('F 120'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forget-F 120')));
      await tester.pumpAndSettle();
      expect(find.text('F 120'), findsNothing);
      expect(find.text('F 180'), findsOneWidget);
      expect(controller.recordedTakes.length, 1);
    });
  });
}
