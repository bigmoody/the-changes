// How many times round a tune goes before the band ends it: set on the
// loop bar, kept from tune to tune, and only for the whole tune.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

/// A band that makes no sound but remembers what it was asked to play.
class _FakePlayer extends FakePlayer {
  BackingRequest? asked;

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {
    asked = request;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> restoreAudioSession() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Tune _tune() => Tune.fromChart(
  title: 'Eight',
  key: 'C',
  defaultTempo: 120,
  chart: '| C6 | A7 | Dm7 | G7 | C6 | A7 | Dm7 | G7 |',
);

Future<void> _open(
  WidgetTester tester,
  AppSettings settings, {
  double width = 1024,
}) async {
  tester.view
    ..physicalSize = Size(width, 900) * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: _tune(),
        player: _FakePlayer(),
        settings: settings,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tune stops after three choruses unless told otherwise', (
    tester,
  ) async {
    await _open(tester, AppSettings.inMemory());
    expect(find.text('3 Choruses'), findsOneWidget);
  });

  testWidgets('the count is chosen on the loop bar, and kept', (tester) async {
    final settings = AppSettings.inMemory();
    await _open(tester, settings);
    await tester.tap(find.byKey(const ValueKey('chorus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chorus-count-5')));
    await tester.pumpAndSettle();
    expect(find.text('5 Choruses'), findsOneWidget);
    expect(settings.choruses, 5, reason: 'the next tune starts with it');

    await tester.tap(find.byKey(const ValueKey('chorus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chorus-count-0')));
    await tester.pumpAndSettle();
    expect(find.text('Keep Going'), findsOneWidget);
    expect(settings.choruses, isNull);
  });

  testWidgets('on a phone it is a number, and nothing overflows', (
    tester,
  ) async {
    await _open(tester, AppSettings.inMemory(), width: 393);
    expect(find.byKey(const ValueKey('chorus-count')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chorus-count')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('a new tune opens with the count last chosen', () async {
    final settings = AppSettings.inMemory();
    await settings.setChoruses(6);
    final controller = PracticeController(
      tune: _tune(),
      player: _FakePlayer(),
      settings: settings,
    );
    addTearDown(controller.dispose);
    expect(controller.choruses, 6);
  });

  test('the band is told to stop on the whole tune, not on a loop', () async {
    final player = _FakePlayer();
    final controller = PracticeController(
      tune: _tune(),
      player: player,
      settings: AppSettings.inMemory(),
    );
    addTearDown(controller.dispose);

    await controller.play();
    expect(player.asked!.arrangement.choruses, 3);
    await controller.stop();

    // Two bars looped is a drill: it goes round until it is stopped.
    controller.loopBar(2);
    controller.extendLoopToBar(3);
    expect(controller.choruses, isNull);
    await controller.play();
    expect(player.asked!.arrangement.choruses, isNull);
    await controller.stop();
    // The count is still there for when the whole tune comes back.
    expect(controller.arrangement.choruses, 3);
    controller.loopWholeTune();
    expect(controller.choruses, 3);
  });
}
