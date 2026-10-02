// The metronome: the clicks that loop in time (including the ones it
// takes away) and the screen that sets them.

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
          metronomeLoop(tempo: tempo, beatsPerBar: beats),
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
      final samples = decodeWav(metronomeLoop(tempo: 120, beatsPerBar: 4));
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
          metronomeLoop(tempo: 120, beatsPerBar: 2, subdivision: subdivision),
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

  group('2 and 4', () {
    test('the click falls on the backbeat and nowhere else', () {
      final clicks = onsets(
        decodeWav(
          metronomeLoop(tempo: 120, beatsPerBar: 4, clickOn: ClickOn.backbeat),
        ),
        tempo: 120,
      );
      expect(clicks, hasLength(2));
      expect(clicks[0], closeTo(1, 0.02), reason: 'beat 2');
      expect(clicks[1], closeTo(3, 0.02), reason: 'beat 4');
    });

    test('the bar is still a bar long, so it loops in time', () {
      final samples = decodeWav(
        metronomeLoop(tempo: 120, beatsPerBar: 4, clickOn: ClickOn.backbeat),
      );
      expect(samples.length, (60 / 120 * 44100).round() * 4);
    });

    test('nothing is accented, because the accent was on 1', () {
      final samples = decodeWav(
        metronomeLoop(tempo: 120, beatsPerBar: 4, clickOn: ClickOn.backbeat),
      );
      final perBeat = samples.length ~/ 4;
      int loudestIn(int beat) => samples
          .sublist(beat * perBeat, (beat + 1) * perBeat)
          .map((s) => s.abs())
          .reduce((a, b) => a > b ? a : b);
      expect(loudestIn(0), lessThan(loudestIn(1)), reason: 'silent on 1');
      // The two that do sound are the same weight as each other.
      expect(loudestIn(1), closeTo(loudestIn(3), loudestIn(1) * 0.05));
    });

    test('it splits the backbeat, not the bar', () {
      // Eighths on 2 and 4: 2, 2-and, 4, 4-and; and nothing on 1 or 3.
      final clicks = onsets(
        decodeWav(
          metronomeLoop(
            tempo: 120,
            beatsPerBar: 4,
            clickOn: ClickOn.backbeat,
            subdivision: Subdivision.eighths,
          ),
        ),
        tempo: 120,
      );
      expect(clicks, hasLength(4));
      expect([for (final at in clicks) at.round()], [1, 2, 3, 4]);
      expect(clicks[1], closeTo(1.5, 0.02));
    });

    test('there is no 4 in a bar of three', () {
      expect(ClickOn.backbeat.suits(4), isTrue);
      expect(ClickOn.backbeat.suits(3), isFalse);
      expect(ClickOn.backbeat.suits(5), isFalse);
      expect(ClickOn.everyBeat.suits(3), isTrue);
    });
  });

  group('the click that goes away', () {
    test('the loop is as long as the pattern', () {
      final beat = (60 / 120 * 44100).round();
      for (final dropout in Dropout.values) {
        expect(
          decodeWav(metronomeLoop(tempo: 120, beatsPerBar: 4, dropout: dropout))
              .length,
          beat * 4 * dropout.bars,
          reason: dropout.label,
        );
      }
    });

    test('it clicks through the bars it is on and none of the ones off', () {
      final clicks = onsets(
        decodeWav(
          metronomeLoop(tempo: 120, beatsPerBar: 4, dropout: Dropout.twoInFour),
        ),
        tempo: 120,
      );
      // Two bars of four, then two bars of nothing.
      expect(clicks, hasLength(8));
      expect(clicks.last, lessThan(8));
    });

    test('the click comes back exactly where it would have been', () {
      // The whole point: the gap is marked by where the click returns, so
      // it has to land on the bar line to the sample.
      final loop = metronomeLoop(
        tempo: 132,
        beatsPerBar: 4,
        dropout: Dropout.everyOther,
      );
      final samples = decodeWav(loop);
      final clicks = onsets(samples, tempo: 132);
      expect(clicks, hasLength(4), reason: 'one bar on, one off');
      expect(clicks.first, closeTo(0, 0.01));
      // And the loop's own end is a bar line too: it repeats seamlessly.
      expect(samples.length, (60 / 132 * 44100).round() * 8);
    });

    test('off leaves the click alone', () {
      expect(Dropout.none.bars, 1);
      expect(Dropout.none.sounds(0), isTrue);
      expect(Dropout.none.sounds(7), isTrue);
    });

    test('the pattern repeats, so bar 5 of 4-on-4-off is silent', () {
      expect(Dropout.fourInEight.sounds(0), isTrue);
      expect(Dropout.fourInEight.sounds(3), isTrue);
      expect(Dropout.fourInEight.sounds(4), isFalse);
      expect(Dropout.fourInEight.sounds(7), isFalse);
      expect(Dropout.fourInEight.sounds(8), isTrue, reason: 'round again');
    });

    test('the ladder gets harder: fewer clicks, longer gaps', () {
      // The chips are offered in this order, so it has to be an order.
      final ladder = [
        Dropout.oneInFour,
        Dropout.everyOther,
        Dropout.twoInFour,
        Dropout.fourInEight,
      ];
      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i].off,
          greaterThanOrEqualTo(ladder[i - 1].off),
          reason: '${ladder[i].label} after ${ladder[i - 1].label}',
        );
      }
      expect(Dropout.values.first, Dropout.none, reason: 'off comes first');
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
    // The Learn list is lazy and keeps growing: scroll to the card
    // rather than assuming it is on screen.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('learn-metronome')),
      120,
      // The page's own list, not the search box's text field,
      // which is a scrollable too.
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
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

  testWidgets('the backbeat and the dropout are set, kept, and start', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    final player = PracticePlayer();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: MetronomeScreen(player: player, settings: settings),
      ),
    );

    Future<void> pick(String key) async {
      final chip = find.byKey(ValueKey('metronome-$key'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    // Nothing is on to begin with, and the exercises say nothing.
    expect(find.textContaining('downbeat is yours'), findsNothing);
    expect(find.textContaining('comes back exactly'), findsNothing);

    await pick('backbeat');
    await pick('twoInFour');
    expect(settings.metronomeClickOn, ClickOn.backbeat);
    expect(settings.metronomeDropout, Dropout.twoInFour);
    // Each one says what it is for, once it is on.
    expect(find.textContaining('downbeat is yours'), findsOneWidget);
    expect(find.textContaining('comes back exactly'), findsOneWidget);

    // Start is reachable without scrolling, however long the settings get.
    await tester.tap(find.byKey(const ValueKey('metronome-play')));
    await tester.pumpAndSettle();
    expect(find.text('Stop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the backbeat is not offered, or kept, in odd time', (
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
        home: MetronomeScreen(player: PracticePlayer(), settings: settings),
      ),
    );
    final backbeat = find.byKey(const ValueKey('metronome-backbeat'));
    await tester.ensureVisible(backbeat);
    await tester.pumpAndSettle();
    await tester.tap(backbeat);
    await tester.pumpAndSettle();
    expect(settings.metronomeClickOn, ClickOn.backbeat);

    // A waltz has no 4 to click on. The chip stays, so you can see the
    // exercise exists, but it greys out and the setting goes back.
    await tester.tap(find.byKey(const ValueKey('metronome-beats-3')));
    await tester.pumpAndSettle();
    expect(backbeat, findsOneWidget);
    final chip = tester.widget<ChoiceChip>(backbeat);
    expect(chip.onSelected, isNull, reason: 'greyed out, not taken away');
    expect(chip.selected, isFalse);
    expect(settings.metronomeClickOn, ClickOn.everyBeat);
    expect(find.textContaining('downbeat is yours'), findsNothing);
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
