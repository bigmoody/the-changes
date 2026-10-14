// The practice record, end to end: a run gets written down, the tune
// opens where you left off, and the record says what to play next.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tuning.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/practice_record.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'fake_listener.dart';
import 'support/fake_player.dart';

/// A band that starts and stops without any real audio, and can be told
/// where it has got to.
class _FakePlayer extends FakePlayer {
  /// What the ticker reads. Null is "nothing playing", which is what a
  /// silent test band reports unless it is told otherwise.

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

// Long enough to be marked: a run has to go past [gradeableChanges] before
// the record will call it good or bad, and four bars never does.
Tune _tune() => Tune.fromChart(
  title: 'Twelve Changes',
  key: 'C',
  defaultTempo: 120,
  chart:
      '| Dm7 | G7 | CΔ7 | Am7 | Dm7 | G7 |'
      '| Em7 | A7 | Fm7 | B♭7 | E♭Δ7 | E♭Δ7 |',
);

/// The 3rd of each bar's chord, in concert pitch. The last bar repeats the
/// one before it, so it is one change rather than two.
const _thirds = [65, 71, 64, 60, 65, 71, 67, 61, 68, 62, 67];

final _ref = TuneRef.standard('Twelve Changes');

({PracticeController controller, FakeListener mic, _FakePlayer player}) _build(
  LibraryStore library,
) {
  final mic = FakeListener();
  final player = _FakePlayer();
  final controller = PracticeController(
    tune: _tune(),
    player: player,
    settings: AppSettings.inMemory(),
    library: library,
    ref: _ref,
    listener: mic,
  );
  addTearDown(controller.dispose);
  return (controller: controller, mic: mic, player: player);
}

/// Plays a marked chorus, landing on [found] of the 3rds and missing the
/// rest by a semitone, then stops.
Future<void> _markedRun(
  PracticeController controller,
  FakeListener mic, {
  required int found,
}) async {
  await controller.setChecking(true);
  await controller.play();
  await pumpEventQueue();
  final check = controller.check!;
  for (final (i, third) in _thirds.indexed) {
    check.moveTo(i * 4, 0);
    // A semitone off is a miss here and a miss on the next change too:
    // none of these lands on the chord after it.
    mic.hear(midiToHz(i < found ? third : third + 1));
  }
  check.moveTo(_thirds.length * 4, 0);
  await controller.stop();
}

/// A run the record will call clean, and one it won't.
Future<void> _cleanRun(PracticeController c, FakeListener mic) =>
    _markedRun(c, mic, found: _thirds.length);
Future<void> _scruffyRun(PracticeController c, FakeListener mic) =>
    _markedRun(c, mic, found: 4);

void main() {
  group('writing a run down', () {
    test('a marked run is kept, with the tempo it was at', () async {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      controller.setTempo(144);
      await _cleanRun(controller, mic);

      final runs = library.runsFor(_ref);
      expect(runs, hasLength(1));
      expect(runs.single.tempo, 144);
      expect(runs.single.asked, _thirds.length);
      expect(runs.single.hits, _thirds.length);
      expect(runs.single.isClean, isTrue);
    });

    test('the misses are kept too, not just the good runs', () async {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      await _scruffyRun(controller, mic);
      expect(library.runsFor(_ref).single.hits, 4);
      expect(library.runsFor(_ref).single.asked, _thirds.length);
      expect(library.runsFor(_ref).single.isClean, isFalse);
    });

    test('a false start is not practice', () async {
      // Play, change your mind, stop. Nothing was marked and the band
      // never got through a bar, so there is nothing to write down.
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      await controller.play();
      await pumpEventQueue();
      await controller.stop();
      expect(library.runsFor(_ref), isEmpty);
    });

    test('a run with the microphone off still counts as playing it', () async {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      await controller.play();
      await pumpEventQueue();
      // The band got a chorus in; nobody was marking it.
      player.at = const PlaybackPosition(tuneBeat: 15, chorus: 0);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await controller.stop();

      final runs = library.runsFor(_ref);
      expect(runs, hasLength(1));
      expect(runs.single.asked, 0, reason: 'played, not marked');
      expect(runs.single.isGraded, isFalse);
      expect(runs.single.tempo, 120);
    });

    test('without a library there is nowhere to keep it', () async {
      final player = _FakePlayer();
      final mic = FakeListener();
      final controller = PracticeController(
        tune: _tune(),
        player: player,
        settings: AppSettings.inMemory(),
        listener: mic,
      );
      addTearDown(controller.dispose);
      await _cleanRun(controller, mic);
      expect(controller.runs, isEmpty);
      expect(controller.nextTempo, isNull);
    });
  });

  group('opening where you left off', () {
    test('a tune never played opens at the tempo it is written at', () {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      expect(controller.tempo, 120, reason: 'the written tempo');
    });

    test('a tune played before opens at the tempo you stopped at', () async {
      final library = LibraryStore.inMemory();
      final first = _build(library);
      first.controller.setTempo(152);
      await _cleanRun(first.controller, first.mic);

      // Leaving the screen and coming back is a new controller.
      final again = _build(library);
      expect(again.controller.tempo, 152);
    });
  });

  group('what to play next', () {
    test('two clean runs at a tempo earn the next four', () async {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      controller.setTempo(140);
      await _cleanRun(controller, mic);
      expect(controller.nextTempo, isNull, reason: 'one is not enough');
      await _cleanRun(controller, mic);
      expect(controller.nextTempo, 144);
    });

    test('a scruffy run does not earn it', () async {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      await _cleanRun(controller, mic);
      await _scruffyRun(controller, mic);
      expect(controller.nextTempo, isNull);
    });

    test('it never suggests past the fastest the app will go', () async {
      final library = LibraryStore.inMemory();
      final (:controller, :mic, :player) = _build(library);
      controller.setTempo(PracticeController.maxTempo);
      await _cleanRun(controller, mic);
      await _cleanRun(controller, mic);
      expect(controller.nextTempo, isNull);
    });
  });

  group('the sheet', () {
    Future<void> open(WidgetTester tester, LibraryStore library) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: _tune(),
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
            library: library,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tune-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practice Record'));
      await tester.pumpAndSettle();
    }

    testWidgets('says so plainly when there is nothing in it yet', (
      tester,
    ) async {
      await open(tester, LibraryStore.inMemory());
      expect(find.byKey(const ValueKey('record-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('record-best')), findsNothing);
    });

    testWidgets('shows the runs, the best clean tempo and the next step', (
      tester,
    ) async {
      final library = LibraryStore.inMemory(
        runs: {
          _ref: [
            (at: DateTime.now(), tempo: 120, asked: 12, hits: 12),
            (at: DateTime.now(), tempo: 120, asked: 12, hits: 11),
            (at: DateTime.now(), tempo: 160, asked: 12, hits: 4),
          ],
        },
      );
      await open(tester, library);
      expect(find.byKey(const ValueKey('record-last')), findsOneWidget);
      expect(find.textContaining('120 BPM'), findsWidgets);
      // 160 was a mess, so the best clean tempo is 120, not the fastest.
      expect(find.text('120 BPM'), findsWidgets);
      expect(find.byKey(const ValueKey('record-move-up')), findsOneWidget);
      expect(find.textContaining('Time to try 124'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('taking the step up sets the tempo and closes', (tester) async {
      final library = LibraryStore.inMemory(
        runs: {
          _ref: [
            (at: DateTime.now(), tempo: 120, asked: 12, hits: 12),
            (at: DateTime.now(), tempo: 120, asked: 12, hits: 12),
          ],
        },
      );
      await open(tester, library);
      await tester.tap(find.byKey(const ValueKey('record-take-it-up')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record-move-up')), findsNothing);
      expect(find.text('124 BPM'), findsOneWidget, reason: 'the transport');
    });

    testWidgets('forgetting it asks first, then forgets', (tester) async {
      final library = LibraryStore.inMemory(
        runs: {
          _ref: [(at: DateTime.now(), tempo: 120, asked: 12, hits: 12)],
        },
      );
      await open(tester, library);
      await tester.tap(find.byKey(const ValueKey('record-clear')));
      await tester.pumpAndSettle();
      expect(find.text('Forget This Record?'), findsOneWidget);
      await tester.tap(find.text('Keep It'));
      await tester.pumpAndSettle();
      expect(library.runsFor(_ref), hasLength(1), reason: 'still there');

      await tester.tap(find.byKey(const ValueKey('record-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record-clear-confirm')));
      await tester.pumpAndSettle();
      expect(library.runsFor(_ref), isEmpty);
    });
  });
}
