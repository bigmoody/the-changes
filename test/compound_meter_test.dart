// Six eight, twelve eight, seven four, and counting a standard in
// something other than what it was written in.
//
// A bar of 6/8 holds six eighth notes and nobody counts six: it is felt
// in two, and a tempo on a 6/8 chart means those two. So a meter
// carries what is written and the band counts the pulse, and the only
// thing that really changes underneath is the subdivision: a compound
// beat divides in three before anybody leans it, which is where swing
// puts its "and" anyway.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/midi_file.dart';
import 'package:play_along/music/midi_write.dart';
import 'package:play_along/music/musicxml_export.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/theme.dart';
import 'package:flutter/material.dart';
import 'package:play_along/settings/app_settings.dart';

UserProgression progression({required Meter meter, List<String>? bars}) =>
    UserProgression(
      id: 'x',
      title: 'Test',
      key: 'C',
      tempo: 100,
      bars: bars ?? const ['CΔ7', 'Am7', 'Dm7', 'G7'],
      style: BandStyle.of(Feel.swing),
      meter: meter,
    );

void main() {
  group('what is written and what is counted', () {
    test('a compound bar is felt in two, or in four', () {
      expect(const Meter(6, 8).pulses, 2);
      expect(const Meter(6, 8).compound, isTrue);
      expect(const Meter(12, 8).pulses, 4);
      expect(const Meter(12, 8).label, '12/8');
      // Simple time counts what it says.
      expect(const Meter(7, 4).pulses, 7);
      expect(const Meter(7, 4).compound, isFalse);
      expect(Meter.four.pulses, 4);
    });

    test('and a chart in six eight has two chords in a bar at most', () {
      expect(
        UserProgression.problemWith('CΔ7 Am7', meter: const Meter(6, 8)),
        isNull,
      );
      expect(
        UserProgression.problemWith('CΔ7 Am7 Dm7', meter: const Meter(6, 8)),
        'At most 2 chords in a bar of 6/8',
      );
    });

    test('the bars last the pulses, not the written notes', () {
      final tune = progression(meter: const Meter(6, 8)).toTune();
      expect(tune.beatsPerBar, 2);
      expect(tune.totalBeats, 8, reason: 'four bars of two');
      final seven = progression(meter: const Meter(7, 4)).toTune();
      expect(seven.beatsPerBar, 7);
      expect(seven.bars.first.single.beats, 7);
    });

    test('a meter is saved and read back, and old charts are in four', () {
      final six = progression(meter: const Meter(6, 8));
      final again = UserProgression.fromJson(six.toJson());
      expect(again.meter, const Meter(6, 8));
      expect(again.beatsPerBar, 2);
      // What a version that only knew the beats would have read: the
      // pulse count, which is what it would have played.
      expect(six.toJson()['beats'], 2);
      expect(
        UserProgression.fromJson({...six.toJson()}..remove('meter')).meter,
        const Meter(2, 4),
      );
    });
  });

  group('the band in compound time', () {
    test('its off-beats sit on the triplet, whatever the tempo', () {
      for (final tempo in [60, 120, 240]) {
        final six = BackingRequest(
          tune: progression(meter: const Meter(6, 8)).toTune(),
          loop: LoopRange(startBeat: 0, lengthBeats: 8),
          tempo: tempo,
        );
        expect(swingForPass(six, 0), tripletSwing, reason: '$tempo');
      }
      // Simple time still follows the curve it always did.
      final four = BackingRequest(
        tune: progression(meter: Meter.four).toTune(),
        loop: LoopRange(startBeat: 0, lengthBeats: 16),
        tempo: 240,
      );
      expect(swingForPass(four, 0), swingAt(240));
    });

    test('a swing somebody has set by hand is still theirs', () {
      final request = BackingRequest(
        tune: progression(meter: const Meter(12, 8)).toTune(),
        loop: LoopRange(startBeat: 0, lengthBeats: 16),
        tempo: 100,
        swing: straight,
      );
      expect(swingForPass(request, 0), straight);
    });
  });

  group('sending a compound chart out', () {
    test('MusicXML says six eight, and the bars last a bar', () {
      final xml = musicXmlFor(progression(meter: const Meter(6, 8)));
      expect(xml, contains('<beats>6</beats>'));
      expect(xml, contains('<beat-type>8</beat-type>'));
      final measures = xml.split('<measure ').skip(1);
      for (final measure in measures) {
        final durations = [
          for (final match in RegExp(
            r'<duration>(\d+)</duration>',
          ).allMatches(measure))
            int.parse(match[1]!),
        ];
        expect(
          durations.fold(0, (a, b) => a + b),
          6,
          reason: 'two dotted quarters is six divisions of a quarter',
        );
      }
    });

    test('and the MIDI counts in dotted quarters at the right speed', () {
      final tune = progression(meter: const Meter(6, 8)).toTune();
      final bytes = midiFor(tune, tempo: 100);
      // Read out of the conductor track by hand: the app's own reader
      // keeps the notes and throws the rest away.
      final signature = meta(bytes, 0x58)!;
      expect(signature[0], 6, reason: 'six eighths written in the bar');
      expect(signature[1], 3, reason: 'the denominator, as a power of two');
      expect(signature[2], 36, reason: 'a click every dotted quarter');
      final tempo = meta(bytes, 0x51)!;
      final microseconds = (tempo[0] << 16) + (tempo[1] << 8) + tempo[2];
      // A hundred dotted quarters a minute is a hundred and fifty
      // quarters, which is what a DAW has to be told.
      expect((60000000 / microseconds).round(), 150);
      // And a note of one beat lasts a dotted quarter.
      final file = readMidiFile(bytes);
      expect(file.ticksPerBeat, 480, reason: 'ticks are per quarter note');
    });

    test('a chart in seven goes out in seven', () {
      final xml = musicXmlFor(progression(meter: const Meter(7, 4)));
      expect(xml, contains('<beats>7</beats>'));
      expect(xml, contains('<beat-type>4</beat-type>'));
    });
  });

  group('counting a standard another way', () {
    test('the chart keeps its chords and the beats are shared again', () {
      final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
      final waltz = tune.inMeter(const Meter(3, 4));
      expect(waltz.barCount, tune.barCount, reason: 'the form is the form');
      expect(
        [for (final bar in waltz.bars) bar.map((s) => s.chord.display).join()],
        [for (final bar in tune.bars) bar.map((s) => s.chord.display).join()],
        reason: 'and every bar keeps its chords',
      );
      expect(waltz.totalBeats, tune.barCount * 3);
      expect(waltz.meter.label, '3/4');
      expect(tune.meter, Meter.four, reason: 'the tune itself is untouched');
    });

    test('a bar with more chords than beats plays the ones that fit', () {
      final tune = Tune.fromChart(
        title: 'Four in a bar',
        key: 'C',
        defaultTempo: 120,
        chart: '| CΔ7 Am7 Dm7 G7 | CΔ7 |',
      );
      expect(tune.bars.first, hasLength(4));
      final waltz = tune.inMeter(const Meter(3, 4));
      expect(waltz.bars.first, hasLength(3));
      for (final slot in waltz.slots) {
        expect(slot.beats, greaterThan(0));
      }
    });

    test('the practice screen remembers it, and says it is not the tune', () {
      final library = LibraryStore.inMemory();
      final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
      final controller = PracticeController(
        tune: tune,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        library: library,
        ref: TuneRef.of(tune),
      );
      addTearDown(controller.dispose);

      expect(controller.meterIsChosen, isFalse);
      expect(controller.meter, Meter.four);

      controller.setMeter(const Meter(3, 4));
      expect(controller.meterIsChosen, isTrue);
      expect(controller.tune.beatsPerBar, 3);
      expect(controller.chart.beatsPerBar, 3);
      expect(controller.originalTune.meter, Meter.four);
      expect(library.meterFor(TuneRef.of(tune)), const Meter(3, 4));

      // It survives a key change, which rebuilds both the chart and the
      // band from the tune underneath.
      controller.transpose(2);
      expect(controller.tune.beatsPerBar, 3);
      expect(controller.chart.beatsPerBar, 3);

      controller.setMeter(null);
      expect(controller.meterIsChosen, isFalse);
      expect(controller.tune.beatsPerBar, 4);
      expect(library.meterFor(TuneRef.of(tune)), isNull);
    });

    testWidgets('the chart itself says when it is not as written', (
      tester,
    ) async {
      // Saying it in the sheet where it was chosen is not enough: the
      // chart is what somebody reads on a stand, and a standard counted
      // another way has to say so there.
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
      final library = LibraryStore.inMemory();
      Future<void> open() async {
        // A new key each time: the screen keeps its controller for as
        // long as its state lives, and this is a player opening the
        // tune again rather than the same screen rebuilding.
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(library.meterFor(TuneRef.of(tune))?.label ?? 'as'),
            theme: appTheme(Brightness.light),
            home: PracticeScreen(
              tune: tune,
              player: PracticePlayer(),
              settings: AppSettings.inMemory(),
              library: library,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.byKey(const ValueKey('chart-meter')), findsNothing);

      library.setMeter(TuneRef.of(tune), const Meter(3, 4));
      await open();
      expect(find.byKey(const ValueKey('chart-meter')), findsOneWidget);
      expect(find.text('3/4'), findsOneWidget);
    });

    test('and the library keeps it across a restart', () async {
      final tune = standards.first;
      final library = LibraryStore.inMemory();
      library.setMeter(TuneRef.of(tune), const Meter(6, 8));
      final back = LibraryStore.inMemory()..replaceWith(library.toJson());
      await Future<void>.delayed(Duration.zero);
      expect(back.meterFor(TuneRef.of(tune)), const Meter(6, 8));
    });

    test('a tune counted another way renders without complaint', () {
      final tune = standards
          .firstWhere((t) => t.title == 'Autumn Leaves')
          .inMeter(const Meter(6, 8));
      final rendered = renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.bars(tune, 0, 3),
          tempo: 90,
          countInBars: 0,
          seed: 5,
        ),
      );
      expect(rendered.stems, isNotEmpty);
      expect(math.max(tune.totalBeats, 0), tune.barCount * 2);
    });
  });
}

/// A meta event's bytes, the first of its kind in the file.
List<int>? meta(List<int> bytes, int kind) {
  for (var i = 0; i < bytes.length - 2; i++) {
    if (bytes[i] == 0xFF && bytes[i + 1] == kind) {
      final length = bytes[i + 2];
      return bytes.sublist(i + 3, i + 3 + length);
    }
  }
  return null;
}
