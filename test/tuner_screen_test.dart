import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/audio/pitch_detector.dart';
import 'package:play_along/audio/sample_bank.dart';

import 'fake_listener.dart';

import 'package:play_along/music/tuning.dart';
import 'package:play_along/screens/tuner_screen.dart';
import 'package:play_along/settings/app_settings.dart';

import 'support/fake_player.dart';

double cents(double hz, double off) => hz * math.pow(2, off / 1200);

void main() {
  Future<(FakeListener, FakePlayer)> open(
    WidgetTester tester, {
    bool allowed = true,
    ChartInstrument instrument = ChartInstrument.concert,
  }) async {
    final listener = FakeListener(allowed: allowed);
    final player = FakePlayer();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: TunerScreen(
          player: player,
          settings: AppSettings.inMemory(instrument),
          listener: listener,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (listener, player);
  }

  String? advice(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('tuner-advice'))).data;

  testWidgets('with no target, names whatever note is played', (tester) async {
    final (listener, player) = await open(tester);
    expect(player.stopped, isTrue, reason: 'the band stops');
    expect(find.text('Play a note'), findsOneWidget);

    listener.hear(midiToHz(69)); // A4
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tuner-note')), findsOneWidget);
    expect(find.text('A'), findsWidgets);
    expect(advice(tester), 'In tune');

    listener.hear(cents(midiToHz(61), -20)); // a flat C♯
    await tester.pumpAndSettle();
    expect(find.text('C♯/D♭'), findsWidgets);
    expect(advice(tester), 'Flat, go up');

    listener.hear(null);
    await tester.pumpAndSettle();
    expect(find.text('Play a note'), findsOneWidget);
  });

  testWidgets('tap a note to hear it, then match it in any octave', (
    tester,
  ) async {
    final (listener, player) = await open(tester);
    await tester.tap(find.byKey(const ValueKey('note-4'))); // E
    await tester.pump();
    expect(player.playedSnippets, hasLength(1));
    expect(find.text('Play or sing E'), findsOneWidget);

    // Sung an octave lower, a touch sharp.
    listener.hear(cents(midiToHz(52), 3));
    await tester.pumpAndSettle();
    expect(find.text('Aiming for E'), findsOneWidget);
    expect(advice(tester), 'Spot on');

    // The wrong note: it says so.
    listener.hear(midiToHz(65)); // F
    await tester.pumpAndSettle();
    expect(find.text("You're on F, aim for E"), findsOneWidget);
    expect(advice(tester), 'Sharp, go down');

    // Back to plain tuning.
    await tester.tap(find.text('Any note'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a note to hear it, then match it'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('all twelve notes play, in the chosen octave', (tester) async {
    final (_, player) = await open(tester);
    for (var note = 0; note < 12; note++) {
      await tester.tap(find.byKey(ValueKey('note-$note')));
      await tester.pump();
    }
    expect(player.playedSnippets, hasLength(12));
    await tester.tap(find.byTooltip('Higher octave'));
    await tester.pump();
    expect(find.text('Octave 5'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('pick B♭ or E♭ on the tuner: notes are as the player reads', (
    tester,
  ) async {
    final (listener, player) = await open(tester);
    // The note is written as a span per spelling now, so that somebody
    // who sees C♯ and D♭ as different colours gets them in different
    // colours. Read it back as the plain text it draws.
    String shown() {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('tuner-note')),
          matching: find.byType(Text),
        ),
      );
      return text.data ?? text.textSpan!.toPlainText();
    }

    // A concert B♭, heard in each key.
    listener.hear(midiToHz(58));
    await tester.pumpAndSettle();
    expect(shown(), 'A♯/B♭', reason: 'concert pitch');

    await tester.tap(find.text('B♭').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Trumpet, tenor'), findsOneWidget);
    expect(shown(), 'C', reason: "a trumpeter's written C");

    await tester.tap(find.text('E♭').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Alto & baritone'), findsOneWidget);
    expect(shown(), 'G', reason: "an alto player's written G");

    // Tapping the E♭ player's written C plays a concert E♭.
    player.playedSnippets.clear();
    await tester.tap(find.byKey(const ValueKey('note-0')));
    await tester.pump();
    final played = decodeWav(player.playedSnippets.single);
    final window = Float32List.fromList([
      for (final s in played.sublist(4000, 4000 + 4096)) s / 32768,
    ]);
    final heard = PitchDetector(sampleRate: 44100).detect(window)!;
    expect(noteNear(hzToMidi(heard.hz)).midi % 12, 3, reason: 'E♭');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the tuner and the charts share the instrument', (tester) async {
    final settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: TunerScreen(
          player: FakePlayer(),
          settings: settings,
          listener: FakeListener(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('F').first);
    await tester.pumpAndSettle();
    expect(settings.instrument, ChartInstrument.f);
  });

  testWidgets('without the microphone, the notes still work', (tester) async {
    final (_, player) = await open(tester, allowed: false);
    expect(find.textContaining('needs the microphone'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-0')));
    await tester.pump();
    expect(player.playedSnippets, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('leaving stops the mic and gives the band its audio back', (
    tester,
  ) async {
    final (listener, player) = await open(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(listener.stopped, isTrue);
    expect(player.restored, isTrue);
  });

  testWidgets('fits on a small phone', (tester) async {
    tester.view
      ..physicalSize = const Size(375, 667) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (listener, _) = await open(tester);
    await tester.tap(find.byKey(const ValueKey('note-6')));
    listener.hear(cents(midiToHz(54), -45));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  group('laid out as a strobe-style tuner', () {
    Color panel(WidgetTester tester) =>
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(const ValueKey('tuner-trace')),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;

    testWidgets('hertz, the note with its octave, and cents across the top', (
      tester,
    ) async {
      final (listener, _) = await open(tester);
      listener.hear(cents(440, -12));
      await tester.pumpAndSettle();
      expect(find.text('HERTZ'), findsOneWidget);
      expect(find.text('CENTS'), findsOneWidget);
      expect(find.text('437.0'), findsOneWidget);
      expect(find.text('−12.0'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tuner-octave'))).data,
        '4',
      );
    });

    testWidgets('the panel goes green in tune, and not out of it', (
      tester,
    ) async {
      final (listener, _) = await open(tester);
      listener.hear(cents(440, -20));
      await tester.pumpAndSettle();
      final out = panel(tester);
      listener.hear(cents(440, 1));
      await tester.pumpAndSettle();
      final inTune = panel(tester);
      expect(inTune, isNot(out));
      expect(inTune.g, greaterThan(inTune.r), reason: 'green');
    });

    testWidgets('the raised keys sit between the naturals', (tester) async {
      await open(tester);
      final c = tester.getCenter(find.byKey(const ValueKey('note-0')));
      final cSharp = tester.getCenter(find.byKey(const ValueKey('note-1')));
      final d = tester.getCenter(find.byKey(const ValueKey('note-2')));
      expect(cSharp.dy, lessThan(c.dy), reason: 'raised');
      expect(cSharp.dx, closeTo((c.dx + d.dx) / 2, 1));
    });

    testWidgets('Default takes the notes back to middle C\'s octave', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Default'), findsOneWidget);
      await tester.tap(find.byTooltip('Lower octave'));
      await tester.pump();
      expect(find.text('Octave 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('octave-default')));
      await tester.pump();
      expect(find.text('Default'), findsOneWidget);
    });
  });
}
