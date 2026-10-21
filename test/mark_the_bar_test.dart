// How much the bar being played is allowed to shout.
//
// Nothing on the chart is animated. The thing that moves is the mark
// itself, travelling bar to bar for as long as the tune runs, and the
// whole of this setting is how loud that is allowed to be.
//
// The chord being played sits on a pencil-red pill whenever the bar is
// marked at all, so its lettering is written to read on the pill. With
// nothing marking the bar there is no pill, and the lettering has to be
// the ordinary ink: a colour picked to read on the pill is the wrong
// colour on plain paper.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/chord_chart.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

/// A band that makes no sound and is told where it has got to.
class _FakePlayer extends FakePlayer {
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

Tune _tune() => Tune.fromChart(
  title: 'ii V I',
  key: 'C',
  defaultTempo: 120,
  chart: '| Dm7 | G7 | C\u03947 | A7 |',
);

/// The chart with the band on the first bar, and what it drew.
///
/// Every box on it rather than the one being played: which Material is
/// which is an accident of the widget tree, but how many of them are
/// tinted or ruled in the accent is the behaviour itself, and counting
/// says it without guessing.
Future<({int tinted, int ruled, int pills, Color ink})> playing(
  WidgetTester tester,
  MarkTheBar mark, {
  Color? chordColour,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final settings = AppSettings.inMemory();
  await settings.setMarkTheBar(mark);
  if (chordColour != null) await settings.setChordColour(2, chordColour);
  final player = _FakePlayer();
  final controller = PracticeController(
    tune: _tune(),
    player: player,
    settings: settings,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      // The chart does not listen to the controller itself; the practice
      // screen rebuilds it. Same arrangement here, or nothing would ever
      // redraw when the band moved.
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ChordChart(controller: controller),
        ),
      ),
    ),
  );
  await controller.play();
  player.at = const PlaybackPosition(tuneBeat: 0, chorus: 0);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump();

  final scheme = appTheme(Brightness.light).colorScheme;
  final boxes = tester
      .widgetList<Material>(
        find.descendant(
          of: find.byType(ChordChart),
          matching: find.byType(Material),
        ),
      )
      .where((box) => box.shape is RoundedRectangleBorder)
      .toList();
  final letters = tester.widget<Text>(
    find
        .byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Dm'))
        .first,
  );
  await controller.stop();
  return (
    tinted: boxes.where((b) => b.color == scheme.tertiaryContainer).length,
    ruled: boxes
        .where(
          (b) =>
              (b.shape! as RoundedRectangleBorder).side.color ==
              scheme.tertiary,
        )
        .length,
    pills: find.byKey(const ValueKey('chord-playing')).evaluate().length,
    ink: letters.style!.color!,
  );
}

void main() {
  group('what each choice means', () {
    test('filled is the one that fills', () {
      expect(MarkTheBar.filled.fills, isTrue);
      expect(MarkTheBar.filled.marks, isTrue);
    });

    test('outlined marks without filling', () {
      expect(MarkTheBar.outlined.fills, isFalse);
      expect(MarkTheBar.outlined.marks, isTrue);
    });

    test('nothing is nothing', () {
      expect(MarkTheBar.off.fills, isFalse);
      expect(MarkTheBar.off.marks, isFalse);
    });

    test('it is filled until somebody turns it down', () async {
      final settings = AppSettings.inMemory();
      expect(settings.markTheBar, MarkTheBar.filled);
      await settings.setMarkTheBar(MarkTheBar.off);
      expect(settings.markTheBar, MarkTheBar.off);
    });

    test('every choice has a Title Case name', () {
      for (final mark in MarkTheBar.values) {
        expect(mark.label, isNotEmpty);
        expect(mark.label[0], mark.label[0].toUpperCase());
      }
    });
  });

  group('on the chart', () {
    testWidgets('filled tints the one bar and rules it in the accent', (
      tester,
    ) async {
      final drawn = await playing(tester, MarkTheBar.filled);
      expect(drawn.tinted, 1, reason: 'the bar being played, and only it');
      expect(drawn.ruled, 1);
    });

    testWidgets('outlined keeps the rule and drops the tint', (tester) async {
      final drawn = await playing(tester, MarkTheBar.outlined);
      expect(drawn.tinted, 0, reason: 'nothing is filled any more');
      expect(drawn.ruled, 1, reason: 'but you can still find your place');
    });

    testWidgets('nothing marks nothing', (tester) async {
      final drawn = await playing(tester, MarkTheBar.off);
      expect(drawn.tinted, 0);
      expect(drawn.ruled, 0);
    });

    testWidgets('the chord being played is on a pill, written to read on it', (
      tester,
    ) async {
      final scheme = appTheme(Brightness.light).colorScheme;
      // Compared as the packed value they are drawn with: two Colours can
      // hold the same colour and still not be equal, because one was
      // worked out in floats and the other written down as an int.
      for (final mark in [MarkTheBar.filled, MarkTheBar.outlined]) {
        final drawn = await playing(tester, mark);
        expect(drawn.pills, 1, reason: mark.label);
        expect(
          drawn.ink.toARGB32(),
          scheme.onTertiary.toARGB32(),
          reason: mark.label,
        );
      }
      // Nothing marking the bar: no pill, and the ordinary ink.
      final off = await playing(tester, MarkTheBar.off);
      expect(off.pills, 0);
      expect(off.ink.toARGB32(), scheme.onSurface.toARGB32());
    });

    testWidgets('somebody\'s own chord colour survives every choice', (
      tester,
    ) async {
      // D is the root of the bar the band is on. Their colour is theirs
      // whatever the bar is or is not marked with: on the pill, lightened
      // or darkened only as far as reading it needs, the hue left alone.
      const theirs = Color(0xFF1A3FA0);
      for (final mark in MarkTheBar.values) {
        final drawn = await playing(tester, mark, chordColour: theirs);
        expect(
          HSLColor.fromColor(drawn.ink).hue,
          closeTo(HSLColor.fromColor(theirs).hue, 1),
          reason: mark.label,
        );
      }
      final off = await playing(tester, MarkTheBar.off, chordColour: theirs);
      expect(off.ink.toARGB32(), theirs.toARGB32());
    });
  });
}
