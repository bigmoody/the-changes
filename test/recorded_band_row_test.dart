// The Recorded Band row in the mixer.
//
// The mixer is where somebody goes when the band is not doing what they
// want, so it is where the app has to say what the band actually is: how
// hard the recording in use is being pushed to reach this tempo and this
// key, and which take that is. It is also the only way in to importing
// one, so a tune that can hold a recording has to offer it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/recorded_take.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/screens/practice_sheets.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

const f = 5;
final ref = TuneRef.standard('Jazz blues in F');

RecordedTake take(String name, double bpm, int key) => RecordedTake(
  name: name,
  files: const {TakeStem.bass: 'bass.wav'},
  bpm: bpm,
  key: key,
  bars: 12,
  choruses: 6,
);

void main() {
  late PracticeController controller;

  Future<void> openMixer(
    WidgetTester tester, {
    List<RecordedTake> takes = const [],
    bool withStore = true,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = withStore ? RecordingStore.inMemory() : null;
    for (final one in takes) {
      await store!.add(ref, one);
    }
    controller = PracticeController(
      tune: practiceProgressions.firstWhere(
        (tune) => tune.title == 'Jazz blues in F',
      ),
      player: _FakePlayer(),
      settings: AppSettings.inMemory(),
      recordingStore: store,
      ref: withStore ? ref : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMixer(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Key key) async {
    // The mixer is a list, so the row may be below the fold.
    await tester.scrollUntilVisible(find.byKey(key), 120);
    await tester.pumpAndSettle();
  }

  String rowSays() =>
      ((find.byKey(const ValueKey('import-recording')).evaluate().single.widget
                      as ListTile)
                  .subtitle!
              as Text)
          .data!;

  group('the way in', () {
    testWidgets('a tune with nowhere to keep one is not offered it', (
      tester,
    ) async {
      // The Learn screens build a controller with no library reference,
      // so there is nothing for a recording to belong to.
      await openMixer(tester, withStore: false);
      expect(find.byKey(const ValueKey('import-recording')), findsNothing);
    });

    testWidgets('a tune with none yet is still offered it', (tester) async {
      await openMixer(tester);
      await scrollTo(tester, const ValueKey('import-recording'));
      expect(find.text('Recorded Band'), findsOneWidget);
      expect(rowSays(), contains('real players'));
    });

    testWidgets('and there is nothing to switch off yet', (tester) async {
      await openMixer(tester);
      expect(find.byKey(const ValueKey('use-recording')), findsNothing);
    });
  });

  group('when one is in', () {
    testWidgets('the row names the take and what it costs', (tester) async {
      await openMixer(tester, takes: [take('F 120', 120, f)]);
      await scrollTo(tester, const ValueKey('import-recording'));
      final said = rowSays();
      expect(said, contains('F 120'));
      expect(said, contains(TakeStrain.asRecorded.label));
      expect(said, contains('cents'));
    });

    testWidgets('the row follows the tempo without being reopened', (
      tester,
    ) async {
      await openMixer(
        tester,
        takes: [take('F 120', 120, f), take('F 180', 180, f)],
      );
      await scrollTo(tester, const ValueKey('import-recording'));
      expect(rowSays(), contains('F 120'));

      controller.setTempo(180);
      await tester.pumpAndSettle();
      expect(rowSays(), contains('F 180'));
    });

    testWidgets('it can be turned off, and says the band comes back', (
      tester,
    ) async {
      await openMixer(tester, takes: [take('F 120', 120, f)]);
      await scrollTo(tester, const ValueKey('use-recording'));
      expect(find.text('Play the Recording'), findsOneWidget);
      expect(controller.useRecording, isTrue);

      await tester.tap(find.byKey(const ValueKey('use-recording')));
      await tester.pumpAndSettle();
      expect(controller.useRecording, isFalse);
      expect(controller.recordingInUse, isNull);
      expect(
        rowSays(),
        contains('not being played'),
        reason: 'the row says the take is there but idle',
      );
    });
  });
}
