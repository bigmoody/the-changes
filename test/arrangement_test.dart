// Arrangements: a performance rather than a loop — a set number of
// choruses, the head in and out, trading with the drummer, and parts laying
// out so you cover them.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';

/// Eight bars of blues, enough for two rounds of fours.
Tune _tune() => Tune.fromChart(
  title: 'Eight',
  key: 'F',
  defaultTempo: 120,
  chart: '| F7 | Bb7 | F7 | F7 | Bb7 | Bb7 | F7 | F7 |',
);

/// How loud a stretch of a rendered part is, in bars from the start of the
/// playing (the count-in is skipped).
double _levelOfBars(
  RenderedBacking backing,
  Instrument part,
  int fromBar,
  int toBar, {
  int beatsPerBar = 4,
}) {
  final pcm = Int16List.sublistView(backing.batch.pcm[part]!);
  final perBar = backing.samplesPerBeat * beatsPerBar;
  final from = backing.countInBeats * backing.samplesPerBeat + fromBar * perBar;
  final to = math.min(
    pcm.length,
    backing.countInBeats * backing.samplesPerBeat + toBar * perBar,
  );
  var sum = 0.0;
  for (var i = from; i < to; i++) {
    sum += pcm[i] * pcm[i].toDouble();
  }
  return to > from ? math.sqrt(sum / (to - from)) : 0;
}

RenderedBacking _render(Arrangement arrangement, {Tune? tune, int seed = 3}) {
  final subject = tune ?? _tune();
  return renderBacking(
    BackingRequest(
      tune: subject,
      loop: LoopRange.wholeTune(subject),
      tempo: 180,
      countInBars: 1,
      seed: seed,
      arrangement: arrangement,
    ),
  );
}

void main() {
  group('the plan for each chorus', () {
    test('head in and out: the first and last, solos in between', () {
      const a = Arrangement(choruses: 4, headInAndOut: true);
      expect(
        [for (var c = 0; c < 4; c++) a.isHead(c)],
        [true, false, false, true],
      );
    });

    test('without a count there is no last chorus to come back to', () {
      const a = Arrangement(headInAndOut: true);
      expect(a.isHead(0), isTrue);
      expect([for (var c = 1; c < 20; c++) a.isHead(c)], everyElement(isFalse));
    });

    test('the head is played straight through by everyone', () {
      const a = Arrangement(
        choruses: 3,
        headInAndOut: true,
        trading: Trading.fours,
        layOut: {LayOut.chords},
      );
      expect(a.planFor(0).trading, Trading.off);
      expect(a.planFor(0).layOut, isEmpty);
      expect(a.planFor(1).trading, Trading.fours);
      expect(a.planFor(1).layOut, {LayOut.chords});
      // Nobody lays out on the melody.
      for (var bar = 0; bar < 8; bar++) {
        expect(a.plays(LayOut.chords, 0, bar), isTrue);
      }
    });

    test('trading fours: you take four, the drummer takes four', () {
      const a = Arrangement(trading: Trading.fours);
      expect(
        [for (var bar = 0; bar < 12; bar++) a.drummerHas(0, bar)],
        [
          false, false, false, false, //
          true, true, true, true, //
          false, false, false, false,
        ],
      );
      expect(a.plays(LayOut.bass, 0, 5), isFalse);
      expect(a.plays(LayOut.bass, 0, 1), isTrue);
    });

    test('trading twos and eights swap at their own length', () {
      expect(const Arrangement(trading: Trading.twos).drummerHas(0, 2), isTrue);
      expect(
        const Arrangement(trading: Trading.eights).drummerHas(0, 2),
        isFalse,
      );
      expect(
        const Arrangement(trading: Trading.eights).drummerHas(0, 9),
        isTrue,
      );
    });

    test('the plain loop asks nothing of the band', () {
      expect(Arrangement.keepGoing.isPlain, isTrue);
      expect(
        const Arrangement(choruses: 4).isPlain,
        isTrue,
        reason: 'just a count',
      );
      expect(const Arrangement(trading: Trading.twos).isPlain, isFalse);
    });

    test('it says what it is', () {
      expect(Arrangement.keepGoing.describe(), 'Keep going');
      expect(
        const Arrangement(
          choruses: 4,
          headInAndOut: true,
          trading: Trading.fours,
        ).describe(),
        '4 choruses, head in and out, trading fours',
      );
    });
  });

  group('how much is written', () {
    test('an arrangement that ends stops asking for more', () {
      final tune = _tune();
      final request = BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: 180,
        arrangement: const Arrangement(choruses: 5),
      );
      final perBatch = chorusesPerBatch(request);
      expect(perBatch, greaterThan(1));
      var total = 0;
      for (var batch = 0; batch < 10; batch++) {
        total += chorusesIn(request, batch);
      }
      expect(total, 5, reason: 'five choruses, no more');
      // Once they have been played there is nothing left to write.
      expect(chorusesIn(request, (5 / perBatch).ceil()), 0);
    });

    test('keeping going never runs out', () {
      final tune = _tune();
      final request = BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: 180,
      );
      for (var batch = 0; batch < 50; batch++) {
        expect(chorusesIn(request, batch), chorusesPerBatch(request));
      }
    });

    test('three choruses are three choruses long', () {
      final backing = _render(const Arrangement(choruses: 3));
      final beats =
          Int16List.sublistView(backing.batch.pcm[Instrument.bass]!).length /
          backing.samplesPerBeat;
      // Eight bars of four, three times, after a bar of count-in.
      expect(beats, closeTo(4 + 3 * 32, 1));
    });
  });

  group('what the band actually plays', () {
    test('the chords lay out on the solos and come back for the head', () {
      final backing = _render(
        const Arrangement(
          choruses: 3,
          headInAndOut: true,
          layOut: {LayOut.chords},
        ),
      );
      final head = _levelOfBars(backing, Instrument.chords, 0, 8);
      final solo = _levelOfBars(backing, Instrument.chords, 8, 16);
      final outHead = _levelOfBars(backing, Instrument.chords, 16, 24);
      expect(head, greaterThan(100));
      expect(outHead, greaterThan(100));
      // Only what is left ringing from the head.
      expect(solo, lessThan(head / 10));
      // The bass carries on regardless.
      expect(_levelOfBars(backing, Instrument.bass, 8, 16), greaterThan(100));
    });

    test('trading fours: the band drops out for the drummer', () {
      final backing = _render(const Arrangement(trading: Trading.fours));
      final yours = _levelOfBars(backing, Instrument.bass, 0, 4);
      final theirs = _levelOfBars(backing, Instrument.bass, 4, 8);
      expect(yours, greaterThan(100));
      expect(theirs, lessThan(yours / 10));
      // The drums keep going through both.
      expect(_levelOfBars(backing, Instrument.drums, 4, 8), greaterThan(100));
    });

    test('a tune with no arrangement is untouched', () {
      final plain = _render(Arrangement.keepGoing);
      final counted = _render(const Arrangement(choruses: 8));
      // A count of choruses changes how much is written, not the playing.
      final a = Int16List.sublistView(plain.batch.pcm[Instrument.bass]!);
      final b = Int16List.sublistView(counted.batch.pcm[Instrument.bass]!);
      final shared = math.min(a.length, b.length);
      expect(shared, greaterThan(0));
      for (var i = 0; i < shared; i += 97) {
        expect(b[i], a[i]);
      }
    });
  });

  group('the drummer takes four', () {
    test('the foot keeps time right through the solo', () {
      for (var bar = 0; bar < 4; bar++) {
        final hits = drumSoloBar(
          feel: Feel.swing,
          bar: bar,
          of: 4,
          beatsPerBar: 4,
          random: math.Random(bar),
        );
        expect(
          hits.where((h) => h.drum == Drum.hiHatPedal).map((h) => h.beat),
          [1.0, 3.0],
        );
        expect(hits, isNotEmpty);
        for (final hit in hits) {
          expect(hit.beat, lessThan(4));
          expect(hit.beat, greaterThanOrEqualTo(0));
        }
      }
    });

    test('snare and toms, not the ride pattern', () {
      final hits = [
        for (var seed = 0; seed < 20; seed++)
          ...drumSoloBar(
            feel: Feel.swing,
            bar: 0,
            of: 4,
            beatsPerBar: 4,
            random: math.Random(seed),
          ),
      ];
      final drums = hits.map((h) => h.drum).toSet();
      expect(drums, contains(Drum.snare));
      expect(drums, isNot(contains(Drum.ride)));
    });

    test('the last bar drives back in', () {
      final last = drumSoloBar(
        feel: Feel.swing,
        bar: 3,
        of: 4,
        beatsPerBar: 4,
        random: math.Random(7),
      );
      final closing = last.where((h) => h.beat >= 2 && h.drum != Drum.kick);
      // Every eighth of the last two beats is struck.
      expect(closing.length, greaterThanOrEqualTo(4));
    });

    test('a waltz solo stays inside three beats', () {
      for (var seed = 0; seed < 10; seed++) {
        final hits = drumSoloBar(
          feel: Feel.swing,
          bar: seed % 4,
          of: 4,
          beatsPerBar: 3,
          random: math.Random(seed),
        );
        expect([for (final h in hits) h.beat], everyElement(lessThan(3)));
      }
    });
  });

  _rampTests();

  group('counting the choruses while it plays', () {
    test('the clock counts each time round the form', () {
      final tune = _tune();
      final loop = LoopRange.wholeTune(tune);
      final backing = renderBacking(
        BackingRequest(tune: tune, loop: loop, tempo: 120, countInBars: 1),
      );
      final clock = PlaybackClock(backing: backing, loop: loop);
      // 120 BPM: a beat is half a second, the count-in 2 s, a chorus 16 s.
      Duration at(double seconds) =>
          Duration(microseconds: (seconds * 1e6).round());
      expect(clock.positionAt(at(0.5)).chorus, isNull, reason: 'counting in');
      // Read as the screen reads it, over and over as it plays.
      // Every 10 ms, so a whole chorus is never skipped over.
      final seen = [
        for (var tick = 0; tick < 6000; tick++)
          clock.positionAt(at(tick / 100)).chorus,
      ];
      int? atSecond(double seconds) => seen[(seconds * 100).round()];
      // A chorus is 32 beats: 16 s. The count-in is the first 2 s.
      expect(atSecond(2.4), 0);
      expect(atSecond(17.9), 0);
      expect(atSecond(18.1), 1);
      expect(atSecond(34.1), 2);
      expect(atSecond(50.1), 3);
    });
  });
}

void _rampTests() {
  group('the tempo ramp', () {
    test('climbs a step a chorus and holds at the top', () {
      const ramp = TempoRamp(step: 5, climb: 20);
      expect(
        [for (var c = 0; c < 7; c++) ramp.tempoAt(c, 120)],
        [120, 125, 130, 135, 140, 140, 140],
      );
      expect(ramp.chorusesToTop(120), 4);
      expect(ramp.describe(), '+5 a chorus, up to 20 faster');
    });

    test('with no limit it climbs until it runs out of tempo', () {
      const ramp = TempoRamp(step: 10);
      expect(ramp.tempoAt(100, 120), 320, reason: 'the fastest the app goes');
      expect(ramp.chorusesToTop(120), 20);
    });

    test('off leaves the tempo alone', () {
      expect(TempoRamp.off.tempoAt(9, 120), 120);
      expect(TempoRamp.off.chorusesToTop(120), 0);
      expect(Arrangement.keepGoing.isPlain, isTrue);
      expect(
        const Arrangement(ramp: TempoRamp(step: 5)).isPlain,
        isFalse,
        reason: 'the choruses are no longer alike',
      );
    });

    test('a beat gets shorter every chorus, then settles', () {
      final tune = _tune();
      final request = BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: 120,
        arrangement: const Arrangement(ramp: TempoRamp(step: 20, climb: 40)),
      );
      expect(
        [for (var c = 0; c < 4; c++) tempoForChorus(request, c)],
        [120, 140, 160, 160],
      );
      // 44100 samples a second: a beat at 120 is half a second.
      expect(samplesPerBeatFor(request, 0), 22050);
      expect(samplesPerBeatFor(request, 2), (60 / 160 * 44100).round());
      // The clock only needs the passes where it is still changing.
      expect(samplesPerBeatByChorus(request).length, 3);
    });

    test('the band really does get faster: each chorus is shorter', () {
      final tune = _tune();
      final backing = renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 120,
          countInBars: 1,
          seed: 5,
          arrangement: const Arrangement(
            choruses: 3,
            ramp: TempoRamp(step: 30, climb: 60),
          ),
        ),
      );
      final beats = backing.samplesPerBeatByChorus;
      expect(beats.length, 3);
      expect(beats[1], lessThan(beats[0]));
      expect(beats[2], lessThan(beats[1]));
      // Count-in at the starting tempo, then three passes, each shorter.
      final total = Int16List.sublistView(backing.batch.pcm[Instrument.bass]!)
          .length;
      final expected = 4 * beats[0] + 32 * (beats[0] + beats[1] + beats[2]);
      expect(total, expected);
    });

    test('the clock follows the band up the ramp', () {
      final tune = _tune();
      final loop = LoopRange.wholeTune(tune);
      final request = BackingRequest(
        tune: tune,
        loop: loop,
        tempo: 120,
        countInBars: 1,
        arrangement: const Arrangement(ramp: TempoRamp(step: 60, climb: 60)),
      );
      final backing = renderBacking(request);
      final clock = PlaybackClock(backing: backing, loop: loop);
      Duration at(double seconds) =>
          Duration(microseconds: (seconds * 1e6).round());
      // A bar of count-in at 120 is 2 s; the first chorus (32 beats at 120)
      // lasts 16 s; the second, at 180, lasts 32 * 60/180 ≈ 10.67 s.
      expect(clock.positionAt(at(1.0)).countInBeat, 3);
      expect(clock.positionAt(at(2.4)).chorus, 0);
      expect(clock.positionAt(at(17.9)).chorus, 0);
      expect(clock.positionAt(at(18.1)).chorus, 1);
      expect(clock.positionAt(at(28.5)).chorus, 1);
      expect(clock.positionAt(at(29.0)).chorus, 2, reason: 'faster now');
      // And the beat inside the chorus is read at the chorus's own tempo.
      expect(clock.positionAt(at(18.1 + 3 * 60 / 180)).tuneBeat, 3);
    });

    test('a ramp needs no chorus count to work', () {
      final tune = _tune();
      final request = BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: 200,
        arrangement: const Arrangement(ramp: TempoRamp(step: 5, climb: 20)),
      );
      // It keeps going; the tempo simply stops climbing.
      expect(chorusesIn(request, 99), chorusesPerBatch(request));
      expect(tempoForChorus(request, 500), 220);
    });
  });
}
