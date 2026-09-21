// Swing: whether the curve it teaches is the one it draws, and whether
// the screen shows the lesson without being asked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/swing_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

void main() {
  group('how far the swing opens', () {
    test('it flattens as the tempo climbs, every step of the way', () {
      // The whole claim of the screen. If this were not monotonic the
      // slider would wander about as you tapped through the tempos and
      // teach nothing.
      for (var i = 1; i < swingTempos.length; i++) {
        expect(
          swingAt(swingTempos[i].tempo),
          lessThan(swingAt(swingTempos[i - 1].tempo)),
          reason: '${swingTempos[i].name} against ${swingTempos[i - 1].name}',
        );
      }
    });

    test('a medium-up tempo lands on the triplet everybody is taught', () {
      // 2 : 1 is not wrong, it is a snapshot of one tempo, and this is
      // roughly the tempo. If the model did not pass through it the
      // screen would be arguing with the whole world for no reason.
      expect(swingAt(200), closeTo(tripletSwing, 0.01));
    });

    test('it opens wider than a triplet at a ballad and stops somewhere', () {
      expect(swingAt(80), greaterThan(dottedSwing));
      expect(swingAt(80), widestSwing, reason: 'and no wider');
      // However slow it gets, it never runs away.
      expect(swingAt(40), widestSwing);
    });

    test('it is straight by the time it is burning, and stays there', () {
      expect(swingAt(300), straight);
      expect(swingAt(400), straight, reason: 'never the wrong side of even');
    });

    test('it is the short note holding still that does it', () {
      // The reason the screen gives for the curve, checked against the
      // curve: wherever the swing has not hit a limit, the short note
      // really is about a tenth of a second.
      for (final tempo in [160, 180, 200, 220, 240]) {
        final beat = 60 / tempo;
        expect(
          (1 - swingAt(tempo)) * beat,
          closeTo(shortEighth, 0.001),
          reason: 'at $tempo',
        );
      }
    });

    test('the "and" is never early, and never on the beat', () {
      for (var tempo = 40; tempo <= 400; tempo += 5) {
        expect(swingAt(tempo), inInclusiveRange(straight, widestSwing));
      }
    });
  });

  group('where the notes actually land', () {
    test('the downbeats are the beat, whatever the swing', () {
      // Only the "and" moves. If swinging harder pushed the beat around
      // too it would be a tempo change wearing a disguise.
      for (final at in [straight, tripletSwing, widestSwing]) {
        final eighths = swungEighths(tempo: 120, at: at);
        for (final (i, pair) in eighths.indexed) {
          expect(pair.downbeat, closeTo(i * 0.5, 1e-9), reason: '$at');
        }
      }
    });

    test('straight puts the "and" exactly halfway, and swing puts it late', () {
      final even = swungEighths(tempo: 120, at: straight).first;
      expect(even.and - even.downbeat, closeTo(0.25, 1e-9));
      final swung = swungEighths(tempo: 120, at: tripletSwing).first;
      expect(swung.and, greaterThan(even.and));
    });

    test('the short note comes out at a tenth of a second, as promised', () {
      // The screen makes a claim in words; this is the same claim in
      // seconds, measured off what will actually be played.
      for (final tempo in [160, 200, 240]) {
        final eighths = swungEighths(tempo: tempo, at: swingAt(tempo));
        final next = eighths[1].downbeat;
        expect(
          next - eighths.first.and,
          closeTo(shortEighth, 0.001),
          reason: 'at $tempo',
        );
      }
    });

    test('two bars of four, and it starts at the top', () {
      final eighths = swungEighths(tempo: 120, at: tripletSwing);
      expect(eighths, hasLength(8));
      expect(eighths.first.downbeat, 0);
    });
  });

  group('the ride', () {
    List<SnippetDrum> rideOnly(List<SnippetDrum> hits) => [
      for (final hit in hits)
        if (hit.drum == Drum.ride) hit,
    ];

    test('a ding on every beat, and nothing pitched anywhere', () {
      final hits = ridePattern(tempo: 120, at: tripletSwing, bars: 2);
      final onTheBeat = [
        for (final hit in rideOnly(hits))
          if ((hit.at * 2 - (hit.at * 2).roundToDouble()).abs() < 1e-9) hit.at,
      ];
      expect(onTheBeat, [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]);
      // Cymbals and a foot. A pitch anywhere in here would be a note to
      // listen to instead of a rhythm.
      expect({for (final hit in hits) hit.drum}, {Drum.ride, Drum.hiHatPedal});
    });

    test('the "and" comes after 2 and 4, and only there', () {
      final hits = ridePattern(tempo: 120, at: tripletSwing, bars: 2);
      final swung = [
        for (final hit in rideOnly(hits))
          if ((hit.at * 2 - (hit.at * 2).roundToDouble()).abs() > 1e-9) hit.at,
      ];
      // Two bars, so two backbeats each: after 2 and after 4.
      expect(swung, hasLength(4));
      for (final at in swung) {
        final beat = at / 0.5;
        expect(beat.floor().isOdd, isTrue, reason: '$at is after 2 or 4');
        expect(beat - beat.floorToDouble(), closeTo(tripletSwing, 1e-9));
      }
    });

    test('swinging harder moves the "and" and nothing else', () {
      // The whole demonstration. If the beats moved too it would be a
      // tempo change, and if the "and" did not move there would be
      // nothing to hear.
      List<double> atSwing(double at) => [
        for (final hit in ridePattern(tempo: 120, at: at, bars: 2)) hit.at,
      ];
      final even = atSwing(straight);
      final hard = atSwing(widestSwing);
      expect(even, isNot(hard));
      // The strokes on the beat are in the same places either way.
      bool onBeat(double at) =>
          (at * 2 - (at * 2).roundToDouble()).abs() < 1e-9;
      expect(
        even.where(onBeat).toList(),
        hard.where(onBeat).toList(),
        reason: 'the beat does not move',
      );
      // And the swung ones are later when it swings harder.
      final laterEven = even.where((at) => !onBeat(at)).toList();
      final laterHard = hard.where((at) => !onBeat(at)).toList();
      expect(laterEven, hasLength(laterHard.length));
      for (var i = 0; i < laterEven.length; i++) {
        expect(laterHard[i], greaterThan(laterEven[i]));
      }
    });

    test('the foot keeps 2 and 4, so there is a beat to be late to', () {
      final feet = [
        for (final hit in ridePattern(tempo: 120, at: tripletSwing, bars: 2))
          if (hit.drum == Drum.hiHatPedal) hit.at,
      ];
      expect(feet, [0.5, 1.5, 2.5, 3.5]);
    });

    test('a fast tempo gets more bars, so it is not over in a blink', () {
      final slow = ridePattern(tempo: 80, at: swingAt(80));
      final fast = ridePattern(tempo: 300, at: swingAt(300));
      expect(fast.length, greaterThan(slow.length));
      // And neither drags on: a few seconds either way.
      for (final hits in [slow, fast]) {
        expect(hits.last.at, inInclusiveRange(1.5, 8));
      }
    });
  });

  group('saying it in words', () {
    test('the ratio reads the way a drummer says it', () {
      expect(ratioText(straight), '1 : 1');
      expect(ratioText(tripletSwing), '2 : 1');
      expect(ratioText(dottedSwing), '3 : 1');
      // And in between it is not a round number, so it does not pretend.
      expect(ratioText(0.6), '1.5 : 1');
    });

    test('the names run from straight to hard without a gap', () {
      expect(swingName(straight), 'Straight');
      expect(swingName(tripletSwing), 'Triplet');
      expect(swingName(dottedSwing), 'Dotted');
      expect(swingName(widestSwing), 'Hard');
      for (var at = straight; at <= widestSwing; at += 0.005) {
        expect(swingName(at), isNotEmpty, reason: '$at');
      }
    });

    test('every tempo is named and says what happens to the eighths', () {
      for (final tempo in swingTempos) {
        expect(tempo.name, isNotEmpty);
        expect(tempo.tempo, inInclusiveRange(40, 400));
        expect(tempo.about.length, greaterThan(40), reason: tempo.name);
      }
    });

    test('the fastest one says the swing is not in the clock', () {
      // The point the screen is really for: at the top the ratio is even
      // and it still swings, which is the accent doing it.
      expect(swingTempos.last.about, contains('accent'));
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: SwingScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String ratioOn(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('swing-ratio'))).data!;

    /// Picks a tempo, dragging the strip along if that one is off the
    /// side: five tempos with their numbers never all fit at once.
    Future<void> pickTempo(WidgetTester tester, String name) async {
      final chip = find.byKey(ValueKey('pick-$name'));
      await tester.dragUntilVisible(
        chip,
        find.byKey(const ValueKey('pick-Medium')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('the beat and the ratio are there on opening, not below it', (
      tester,
    ) async {
      // The picture of the beat is the feature. Explanation has pushed
      // the point of a screen off the bottom of the phone before now.
      await open(tester);
      expect(find.byKey(const ValueKey('swing-ratio')), findsOneWidget);
      expect(find.byKey(const ValueKey('swing-slider')), findsOneWidget);
      final bar = find.byKey(const ValueKey('swing-ratio'));
      expect(tester.getRect(bar).bottom, lessThan(852));
      expect(find.text('long'), findsOneWidget);
      expect(find.text('short'), findsOneWidget);
    });

    testWidgets('tapping through the tempos flattens it on its own', (
      tester,
    ) async {
      // This is the lesson, and it has to happen without the user
      // touching the slider at all.
      await open(tester);
      await pickTempo(tester, 'Ballad');
      final slow = ratioOn(tester);

      await pickTempo(tester, 'Burning');
      expect(ratioOn(tester), isNot(slow));
      expect(ratioOn(tester), '1 : 1', reason: 'straight, at the top');
      expect(find.byKey(const ValueKey('swing-name')), findsOneWidget);
      expect(find.text('Straight'), findsOneWidget);
    });

    testWidgets('taking hold of the slider stops it following', (tester) async {
      await open(tester);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('follow-the-tempo')),
            )
            .value,
        isTrue,
        reason: 'following to begin with, because that is the lesson',
      );
      await tester.drag(
        find.byKey(const ValueKey('swing-slider')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('follow-the-tempo')),
            )
            .value,
        isFalse,
      );
      // And now the tempo leaves it alone.
      final chosen = ratioOn(tester);
      await pickTempo(tester, 'Ballad');
      expect(ratioOn(tester), chosen);
    });

    testWidgets('switching following back on catches it up', (tester) async {
      await open(tester);
      await tester.drag(
        find.byKey(const ValueKey('swing-slider')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      final moved = ratioOn(tester);
      await tester.tap(find.byKey(const ValueKey('follow-the-tempo')));
      await tester.pumpAndSettle();
      expect(ratioOn(tester), isNot(moved));
      expect(ratioOn(tester), ratioText(swingAt(swingTempos[1].tempo)));
    });

    testWidgets(
      'hearing it is pinned, and says nothing when there is no band',
      (tester) async {
        await open(tester);
        final button = find.byKey(const ValueKey('play-swing'));
        expect(button, findsOneWidget);
        expect(tester.getRect(button).bottom, lessThan(852));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('choosing a tempo says what happens at it', (tester) async {
      await open(tester);
      await pickTempo(tester, 'Burning');
      expect(find.textContaining('still swings'), findsOneWidget);
    });

    testWidgets('it opens from Learn', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LearnPage(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('learn-swing'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(SwingScreen), findsOneWidget);
    });
  });
}
