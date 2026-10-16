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
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/comping.dart';
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

    test('six eight can be counted in six as well as in two', () {
      // Felt in two at most tempos, counted in six at slow ones, and
      // which one a player wants is theirs to say. Both are offered.
      const inTwo = Meter(6, 8);
      const inSix = Meter(6, 8, countedIn: 6);
      expect(inTwo.pulses, 2);
      expect(inSix.pulses, 6);
      expect(inSix.compound, isFalse, reason: 'an eighth does not divide in 3');
      expect(inTwo == inSix, isFalse);
      expect(Meter.choices, contains(inSix));
      // The chart says the same thing at the front either way; only the
      // chip that says how you are counting it tells them apart.
      expect(inTwo.written, '6/8');
      expect(inSix.written, '6/8');
      expect(inSix.label, '6/8 (in 6)');
      expect(Meter.parse(inSix.label), inSix);
      expect(Meter.parse(inTwo.label), inTwo);
      // And a bar of it holds six chords at the most, not two.
      expect(
        UserProgression.problemWith('C F G C Am Dm', meter: inSix),
        isNull,
      );
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

  group('the bell', () {
    List<double> bellIn(int beatsPerBar, int bar) => [
      for (final hit in drumBar(
        feel: Feel.afroSix,
        bar: bar,
        beatsPerBar: beatsPerBar,
        random: math.Random(3),
        swing: tripletSwing,
      ))
        if (hit.drum == Drum.cowbell) hit.beat,
    ];

    test('the standard bell, laid over whatever bar it meets', () {
      // Seven strokes across twelve eighths: the first, third, fifth,
      // sixth, eighth, tenth and twelfth. In 12/8 that is one bar of
      // four pulses; in 6/8 it takes two bars of two.
      const cycle = [0.0, 2 / 3, 4 / 3, 5 / 3, 7 / 3, 3.0, 11 / 3];
      final twelve = bellIn(4, 0);
      expect(twelve, hasLength(7));
      for (final (i, at) in twelve.indexed) {
        expect(at, closeTo(cycle[i], 1e-9));
      }
      // And in six eight the same cycle, half of it a bar.
      expect(bellIn(2, 0), hasLength(4));
      expect(bellIn(2, 1), hasLength(3));
      expect(bellIn(2, 1).first, closeTo(1 / 3, 1e-9));
      expect(bellIn(2, 2), bellIn(2, 0), reason: 'and round again');
    });

    test('the bombo is on the second beat, and no cymbal is touched', () {
      final bar = drumBar(
        feel: Feel.afroSix,
        bar: 0,
        beatsPerBar: 4,
        random: math.Random(3),
        swing: tripletSwing,
      );
      expect(bar.where((hit) => hit.drum == Drum.kick).map((hit) => hit.beat), [
        1.0,
      ]);
      expect(
        bar.where(
          (hit) => hit.drum == Drum.ride || hit.drum == Drum.hiHatClosed,
        ),
        isEmpty,
      );
      expect(Feel.afroSix.hasDrums, isTrue);
      expect(Genre.ofFeel(Feel.afroSix), Genre.latin);
    });
  });

  group('a groove that does not fit the bar', () {
    test('a bar-length figure is not cut to a bar of another length', () {
      // What made a calypso counted in six eight sound wrong: half a
      // 3-3-2 with its off-beats dragged onto triplets.
      for (final feel in [
        Feel.calypso,
        Feel.bossa,
        Feel.samba,
        Feel.funk,
        Feel.secondLine,
      ]) {
        expect(feel.suits(Meter.four), isTrue, reason: feel.name);
        expect(feel.suits(const Meter(6, 8)), isFalse, reason: feel.name);
        expect(feel.suits(const Meter(3, 4)), isFalse, reason: feel.name);
      }
      // The ones written beat by beat fit any bar there is.
      for (final feel in [
        Feel.swing,
        Feel.ballad,
        Feel.jazzWaltz,
        Feel.afroSix,
        Feel.gypsy,
      ]) {
        for (final meter in Meter.choices) {
          expect(feel.suits(meter), isTrue, reason: '${feel.name} in $meter');
        }
      }
    });

    test(
      'so the band hands over to one that does, and the whole band goes',
      () {
        expect(Feel.calypso.standIn(const Meter(6, 8)), Feel.afroSix);
        expect(Feel.calypso.standIn(const Meter(5, 4)), Feel.swing);
        expect(Feel.swing.standIn(const Meter(6, 8)), Feel.swing);
        final calypso = BandStyle.of(Feel.calypso);
        final inSix = calypso.inMeter(const Meter(6, 8));
        expect(inSix.drums, Feel.afroSix);
        expect(
          inSix.bass,
          BandStyle.of(Feel.afroSix).bass,
          reason: 'a calypso bass under a bell is two grooves at once',
        );
        expect(calypso.inMeter(Meter.four), calypso);
      },
    );

    test('and what is playing is said, not swapped quietly', () {
      // The sheet reads it off the same rule the band plays by, so the
      // two cannot come to disagree. This is that rule.
      expect(Feel.calypso.suits(const Meter(6, 8)), isFalse);
      expect(Feel.calypso.standIn(const Meter(6, 8)).label, 'Afro 6/8');
    });
  });

  group('comping in other bars', () {
    test('a chord that fills the bar gets a whole bar figure', () {
      // A waltz used to be comped with one chord at the front of every
      // bar: a three-beat chord was handed the half-bar figures,
      // because the test was four beats rather than the bar.
      for (final beats in [2, 3, 4, 5, 7]) {
        final comper = Comper(math.Random(5));
        final landings = <double>[];
        for (var bar = 0; bar < 12; bar++) {
          landings.addAll(
            comper
                .comp(
                  Chord.parse(bar.isEven ? 'Dm7' : 'G7'),
                  beats,
                  Feel.swing,
                  beatsPerBar: beats,
                  swing: tripletSwing,
                  bar: bar,
                )
                .map((hit) => hit.beat),
          );
        }
        expect(
          landings.where((at) => at > 0).length,
          greaterThan(2),
          reason: 'a bar of $beats is comped, not just struck on one',
        );
        // And nothing hangs off the end of the bar: a figure that does
        // not fit is left out rather than cut short.
        for (final at in landings) {
          expect(at, lessThan(beats), reason: 'inside a bar of $beats');
        }
      }
    });

    test('the figures themselves move with the bar', () {
      // The Charleston is 1 and the "and" of 2 wherever it is played;
      // what moves is the half way point and the last beat.
      expect(CompFigure.charleston.strikes(0.5, beatsPerBar: 3), [
        (0.0, 0.6, 1.0),
        (1.5, 1.4, 0.9),
      ]);
      expect(CompFigure.twice.strikes(0.5, beatsPerBar: 3).last.$1, 1.5);
      expect(CompFigure.twice.strikes(0.5).last.$1, 2.5, reason: 'in four');
      expect(CompFigure.three.strikes(0.5, beatsPerBar: 5).last.$1, 4.0);
      expect(CompFigure.held.strikes(0.5, beatsPerBar: 3).single.$2, 2.2);
      expect(CompFigure.everyBeat.strikes(0.5, beatsPerBar: 7), hasLength(7));
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

    test('and opening it again finds the same tune, not a longer one', () {
      // The loop and the tempo are both counted in beats, and a tune
      // kept in another meter has a different number of them: opening
      // Cherokee in six eight looped "bars 1 to 128" of a 64-bar tune
      // and played it at a quarter note's tempo.
      final tune = standards.firstWhere((t) => t.title == 'Cherokee');
      final library = LibraryStore.inMemory();
      library.setMeter(TuneRef.of(tune), const Meter(6, 8));
      final controller = PracticeController(
        tune: tune,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        library: library,
        ref: TuneRef.of(tune),
      );
      addTearDown(controller.dispose);
      expect(controller.tune.beatsPerBar, 2);
      expect(controller.loop.lengthBeats, controller.tune.totalBeats);
      expect(controller.loop.isWholeTune(controller.tune), isTrue);
      expect(controller.tempo, tune.defaultTempo);
    });

    test('but a tempo you left off at is already in your own beats', () {
      // It was recorded while the tune was being counted this way, so
      // converting it again on the way in made the tune open slower
      // every time it was opened.
      final tune = standards.firstWhere((t) => t.title == 'Cherokee');
      final library = LibraryStore.inMemory();
      final ref = TuneRef.of(tune);
      library.setMeter(ref, const Meter(6, 8));
      library.noteRun(ref, (at: DateTime.now(), tempo: 85, asked: 8, hits: 8));
      PracticeController opened() => PracticeController(
        tune: tune,
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
        library: library,
        ref: ref,
      );
      final first = opened();
      addTearDown(first.dispose);
      expect(first.tempo, 85);
      final again = opened();
      addTearDown(again.dispose);
      expect(again.tempo, 85, reason: 'and again, and again');
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
