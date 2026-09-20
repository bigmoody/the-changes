// The metronome: a bar of clicks that loops in time, and the screen that
// sets it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/metronome_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// Where the clicks start, in beats, from the sound itself.
List<double> onsets(List<int> samples, {required int tempo}) {
  final samplesPerBeat = 60 / tempo * 44100;
  final found = <double>[];
  // Starts "quiet" so a click at the very start counts.
  var quiet = 1000;
  for (var i = 0; i < samples.length; i++) {
    if (samples[i].abs() > 2000) {
      if (quiet > 200) found.add(i / samplesPerBeat);
      quiet = 0;
    } else {
      quiet++;
    }
  }
  return found;
}

void main() {
  group('the bar of clicks', () {
    test('one click a beat, and exactly a bar long', () {
      for (final (tempo, beats) in [(120, 4), (90, 3), (200, 5)]) {
        final samples = decodeWav(
          metronomeBar(tempo: tempo, beatsPerBar: beats),
        );
        expect(
          samples.length,
          (60 / tempo * 44100).round() * beats,
          reason: '$beats beats at $tempo',
        );
        final beatsIn = onsets(samples, tempo: tempo);
        expect(beatsIn, hasLength(beats));
        for (var beat = 0; beat < beats; beat++) {
          expect(beatsIn[beat], closeTo(beat, 0.02));
        }
      }
    });

    test('the first beat of the bar is the loudest', () {
      final samples = decodeWav(metronomeBar(tempo: 120, beatsPerBar: 4));
      final perBeat = samples.length ~/ 4;
      final loudest = [
        for (var beat = 0; beat < 4; beat++)
          samples
              .sublist(beat * perBeat, (beat + 1) * perBeat)
              .map((s) => s.abs())
              .reduce((a, b) => a > b ? a : b),
      ];
      expect(loudest.first, greaterThan(loudest[1]));
      expect(loudest.first, greaterThan(loudest[3]));
    });

    test('the beat divides into eighths, triplets or swing', () {
      List<double> clicksIn(Subdivision subdivision) => onsets(
        decodeWav(
          metronomeBar(tempo: 120, beatsPerBar: 2, subdivision: subdivision),
        ),
        tempo: 120,
      );
      expect(clicksIn(Subdivision.quarters), hasLength(2));
      expect(clicksIn(Subdivision.eighths), hasLength(4));
      expect(clicksIn(Subdivision.triplets), hasLength(6));
      // Swing: the off-beat sits two thirds of the way through the beat.
      final swing = clicksIn(Subdivision.swing);
      expect(swing, hasLength(4));
      expect(swing[1], closeTo(2 / 3, 0.02));
    });
  });

  testWidgets('the metronome opens from Learn and keeps its settings', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: LearnPage(player: PracticePlayer(), settings: settings),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('learn-metronome')));
    await tester.pumpAndSettle();
    expect(find.byType(MetronomeScreen), findsOneWidget);
    expect(find.text('120'), findsOneWidget);

    // A waltz at 90, clicking on the triplets.
    await tester.tap(find.byKey(const ValueKey('metronome-beats-3')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30; i++) {
      await tester.tap(find.byKey(const ValueKey('metronome-slower')));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('metronome-triplets')));
    await tester.pumpAndSettle();
    expect(find.text('90'), findsOneWidget);
    expect(settings.metronomeBeats, 3);
    expect(settings.metronomeTempo, 90);
    expect(settings.metronomeSubdivision, Subdivision.triplets);

    // It starts and stops.
    await tester.tap(find.byKey(const ValueKey('metronome-play')));
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('metronome-play')));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the tempo makes the click again once, not per pixel', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final player = PracticePlayer();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: MetronomeScreen(player: player, settings: AppSettings.inMemory()),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('metronome-play')));
    await tester.pumpAndSettle();
    expect(player.loopsStarted, 1);

    // Twenty changes in a row, as a drag would make.
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byKey(const ValueKey('metronome-faster')));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(player.loopsStarted, 1, reason: 'still the first click');
    await tester.pumpAndSettle();
    expect(player.loopsStarted, 2, reason: 'made again once, at the end');
    expect(find.text('140'), findsOneWidget);
  });
}
