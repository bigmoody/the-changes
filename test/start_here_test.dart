// Taking it from the bridge: the band comes in part-way through the form
// the first time, then comes round to the top and plays it whole.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

/// A band that makes no sound but remembers what it was asked for.
class _FakePlayer extends FakePlayer {
  int? askedPickUp;
  var starts = 0;

  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {
    askedPickUp = pickUpBeats;
    starts++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> restoreAudioSession() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// Sixteen bars, four to a line, so "the second half" is bar 9.
Tune _tune() => Tune.fromChart(
  title: 'Sixteen',
  key: 'C',
  defaultTempo: 120,
  chart:
      '| C6 | A7 | Dm7 | G7 | C6 | A7 | Dm7 | G7 |'
      '| F6 | Fm6 | C6 | A7 | Dm7 | G7 | C6 | C6 |',
);

({PracticeController controller, _FakePlayer player}) _build() {
  final player = _FakePlayer();
  final controller = PracticeController(
    tune: _tune(),
    player: player,
    settings: AppSettings.inMemory(),
  );
  addTearDown(controller.dispose);
  return (controller: controller, player: player);
}

void main() {
  group('choosing where to come in', () {
    test('it starts at the top until you say otherwise', () {
      final (:controller, :player) = _build();
      expect(controller.startBar, isNull);
      expect(controller.pickUpBeats, 0);
    });

    test('taking it from bar 9 is 32 beats into the form', () {
      final (:controller, :player) = _build();
      controller.startFromBar(8);
      expect(controller.startBar, 8);
      expect(controller.pickUpBeats, 32, reason: '8 bars of 4');
    });

    test('asking again for the same bar puts it back to the top', () {
      final (:controller, :player) = _build();
      controller.startFromBar(8);
      controller.startFromBar(8);
      expect(controller.startBar, isNull);
    });

    test('choosing the bar it already starts on is not a pick-up', () {
      // Bar 1 of the whole tune is the top: it would be a pick-up of
      // nothing, and a marker on it would say something untrue.
      final (:controller, :player) = _build();
      controller.startFromBar(0);
      expect(controller.startBar, isNull);
      expect(controller.pickUpBeats, 0);
    });

    test('a bar outside the loop is not offered', () {
      final (:controller, :player) = _build();
      controller.loopBar(2);
      controller.startFromBar(8);
      expect(controller.startBar, isNull, reason: 'bar 9 is not in the loop');
    });

    test('inside a loop it is measured from the loop, not the tune', () {
      final (:controller, :player) = _build();
      // Bars 5–8, coming in on bar 7.
      controller.loopBar(4);
      controller.extendLoopToBar(7);
      controller.startFromBar(6);
      expect(controller.startBar, 6);
      expect(controller.pickUpBeats, 8, reason: 'two bars into the loop');
    });

    test('a new loop drops a pick-up it no longer covers', () {
      final (:controller, :player) = _build();
      controller.startFromBar(8);
      expect(controller.startBar, 8);
      controller.loopBar(1);
      expect(controller.startBar, isNull);
    });

    test('back to the top clears it', () {
      final (:controller, :player) = _build();
      controller.startFromBar(8);
      controller.startFromTheTop();
      expect(controller.startBar, isNull);
    });
  });

  group('what the band is told', () {
    test('the pick-up goes to the player', () async {
      final (:controller, :player) = _build();
      controller.startFromBar(8);
      await controller.play();
      expect(player.askedPickUp, 32);
    });

    test('from the top it asks for nothing', () async {
      final (:controller, :player) = _build();
      await controller.play();
      expect(player.askedPickUp, 0);
    });

    test('choosing one mid-run starts the band again on it', () async {
      final (:controller, :player) = _build();
      await controller.play();
      expect(player.starts, 1);
      controller.startFromBar(8);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(player.starts, 2);
      expect(player.askedPickUp, 32);
    });
  });

  group('the clock', () {
    // Sixteen bars of four at 120, with a bar of count-in.
    RenderedBacking render({int countInBars = 1}) => renderBacking(
      BackingRequest(
        tune: _tune(),
        loop: LoopRange.wholeTune(_tune()),
        tempo: 120,
        countInBars: countInBars,
      ),
    );

    test('a pick-up puts the first beat where the band comes in', () {
      final backing = render();
      final loop = LoopRange.wholeTune(_tune());
      final countIn = Duration(
        microseconds:
            (backing.countInBeats * backing.samplesPerBeat / 44100 * 1000000)
                .round(),
      );
      final clock = PlaybackClock(
        backing: backing,
        loop: loop,
        pickUpBeats: 32,
      );
      final at = clock.positionAt(countIn + const Duration(milliseconds: 10));
      expect(at.tuneBeat, 32, reason: 'bar 9');
      expect(at.chorus, 0);
    });

    test('the second time round comes back to the top and runs whole', () {
      final backing = render();
      final loop = LoopRange.wholeTune(_tune());
      final clock = PlaybackClock(
        backing: backing,
        loop: loop,
        pickUpBeats: 32,
      );
      final beat = backing.samplesPerBeat / 44100;
      Duration at(double beats) => Duration(
        microseconds: ((backing.countInBeats * beat + beats * beat) * 1000000)
            .round(),
      );
      // The first time through is short: 32 beats of the 64 remain.
      expect(clock.positionAt(at(31)).chorus, 0);
      expect(clock.positionAt(at(32.5)).chorus, 1);
      expect(clock.positionAt(at(32.5)).tuneBeat, 0, reason: 'the top');
      // And the whole form the second time.
      expect(clock.positionAt(at(95)).chorus, 1);
      expect(clock.positionAt(at(96.5)).chorus, 2);
    });

    test('with no pick-up nothing about the clock changes', () {
      final backing = render();
      final loop = LoopRange.wholeTune(_tune());
      final beat = backing.samplesPerBeat / 44100;
      final at = Duration(
        microseconds:
            (((backing.countInBeats + 3) * beat) * 1000000).round() + 1000,
      );
      expect(
        PlaybackClock(backing: backing, loop: loop).positionAt(at).tuneBeat,
        PlaybackClock(
          backing: backing,
          loop: loop,
          pickUpBeats: 0,
        ).positionAt(at).tuneBeat,
      );
    });
  });

  group('cutting the front off the band', () {
    RenderedBacking render() => renderBacking(
      BackingRequest(
        tune: _tune(),
        loop: LoopRange.wholeTune(_tune()),
        tempo: 120,
      ),
    );

    test('exactly the beats before the pick-up come off', () {
      final whole = render();
      final from9 = PracticePlayer.fromPickUp(whole, 32);
      final beat = whole.samplesPerBeatByChorus.first * 2; // s16le
      for (final part in whole.batch.pcm.keys) {
        expect(
          whole.batch.pcm[part]!.length - from9.batch.pcm[part]!.length,
          32 * beat,
          reason: part.label,
        );
      }
      expect(whole.batch.clicks.length - from9.batch.clicks.length, 32 * beat);
    });

    test('the count-in is left alone; you still get counted in', () {
      final whole = render();
      final from9 = PracticePlayer.fromPickUp(whole, 32);
      final countIn = whole.countInBeats * whole.samplesPerBeat * 2;
      expect(countIn, greaterThan(0), reason: 'there is one to keep');
      expect(
        from9.batch.clicks.sublist(0, countIn),
        whole.batch.clicks.sublist(0, countIn),
        reason: 'the clicks are untouched',
      );
    });

    test('what is left starts where the pick-up does', () {
      final whole = render();
      final from9 = PracticePlayer.fromPickUp(whole, 32);
      final countIn = whole.countInBeats * whole.samplesPerBeat * 2;
      final cut = 32 * whole.samplesPerBeatByChorus.first * 2;
      final bass = whole.batch.pcm[Instrument.bass]!;
      expect(
        from9.batch.pcm[Instrument.bass]!.sublist(countIn, countIn + 400),
        bass.sublist(countIn + cut, countIn + cut + 400),
      );
    });

    test('no pick-up, nothing touched', () {
      final whole = render();
      expect(identical(PracticePlayer.fromPickUp(whole, 0), whole), isTrue);
    });

    test('a pick-up past the end is left alone rather than emptied', () {
      // Belt and braces: a silent band would be much worse than a wrong
      // starting bar.
      final whole = render();
      final daft = PracticePlayer.fromPickUp(whole, 100000);
      expect(
        daft.batch.pcm[Instrument.bass]!.length,
        whole.batch.pcm[Instrument.bass]!.length,
      );
    });
  });

  group('on the screen', () {
    Future<void> open(WidgetTester tester) async {
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
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('holding a bar marks it, and says so in the loop bar', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('starts-here')), findsNothing);
      expect(find.byKey(const ValueKey('starts-at')), findsNothing);

      await tester.longPress(find.text('F6'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('starts-here')), findsOneWidget);
      expect(find.text('From 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap still sets a loop, as it always did', (tester) async {
      await open(tester);
      await tester.tap(find.text('F6'));
      await tester.pumpAndSettle();
      expect(find.text('Bar 9'), findsOneWidget, reason: 'the loop');
      expect(find.byKey(const ValueKey('starts-here')), findsNothing);
    });

    testWidgets('the chip puts it back to the top', (tester) async {
      await open(tester);
      await tester.longPress(find.text('F6'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('starts-at-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('starts-at')), findsNothing);
      expect(find.byKey(const ValueKey('starts-here')), findsNothing);
    });
  });
}
