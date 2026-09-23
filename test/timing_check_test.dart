// Did they play to the click?
//
// Every drummer here is invented, so what they did wrong is known
// exactly. The three faults are put in one at a time and then all three
// at once, because the whole point of this check is that it takes them
// apart: a take trimmed two frames late must not read the same as a
// rhythm section that cannot hold time.

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/timing_check.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/recorded_take.dart';

/// Four bars, four times round: sixty-four beats, thirty-two seconds.
RecordedTake take({double bpm = 120, double start = 0}) => RecordedTake(
  name: 'Invented',
  files: const {TakeStem.drums: 'drums.wav'},
  bpm: bpm,
  key: 5,
  bars: 4,
  choruses: 4,
  startSeconds: start,
);

const _beats = 64;

/// A drummer who hits beat [beat] at whatever [when] says.
///
/// [on] says which beats are struck at all, so a two feel can be tried.
WavAudio played(
  double Function(int beat) when, {
  bool Function(int beat)? on,
  double seconds = 34,
}) {
  const rate = 44100;
  final samples = Float32List((seconds * rate).round());
  final noise = math.Random(7);
  final length = (0.005 * rate).round();
  for (var beat = 0; beat < _beats; beat++) {
    if (on != null && !on(beat)) continue;
    final start = (when(beat) * rate).round();
    for (var i = 0; i < length; i++) {
      final frame = start + i;
      if (frame < 0 || frame >= samples.length) continue;
      samples[frame] +=
          (noise.nextDouble() * 2 - 1) * math.exp(-i / (length / 3)) * 0.7;
    }
  }
  return WavAudio(sampleRate: rate, channels: 1, samples: samples);
}

/// Dead on the click at [bpm].
double Function(int) exactly(double bpm, {double from = 0}) =>
    (beat) => from + beat * 60 / bpm;

void main() {
  group('a drummer who played it perfectly', () {
    late TimingCheck check;
    setUp(() {
      check = checkTiming(played(exactly(120)), take: take());
    });

    test('is told so', () {
      expect(check.verdict, TimingVerdict.locked);
      expect(check.scatterMs, lessThan(2));
    });

    test('and nothing is suggested to them', () {
      expect(check.worthNudging, isFalse);
      expect(check.worthRetempoing, isFalse);
      expect(check.offsetMs.abs(), lessThan(2));
      expect(check.impliedBpm, closeTo(120, 0.05));
    });

    test('every beat was found but the one at the very start', () {
      // A rise is measured against what came before it, and before the
      // first sample there is nothing. The template puts bar 1 beat 1 at
      // sample zero, so that beat is routinely missing and sixty-three
      // others are not, which is plenty to fit a line to.
      expect(check.beatsExpected, 64);
      expect(check.beatsMatched, 63);
      expect(check.coverage, closeTo(0.98, 0.01));
    });
  });

  group('one fault at a time', () {
    test('a file trimmed late is an offset, not bad playing', () {
      // Twenty milliseconds of silence left on the front. Nobody played
      // badly; the file is wrong.
      final check = checkTiming(played(exactly(120, from: 0.02)), take: take());
      expect(check.offsetMs, closeTo(20, 2));
      expect(check.scatterMs, lessThan(2), reason: 'they played perfectly');
      expect(check.verdict, TimingVerdict.locked);
      expect(check.worthNudging, isTrue);
      expect(check.worthRetempoing, isFalse);
    });

    test('a file trimmed early is the same the other way', () {
      final check = checkTiming(
        played(exactly(120, from: 0.1)),
        take: take(start: 0.14),
      );
      expect(check.offsetMs, closeTo(-40, 3));
      expect(check.verdict, TimingVerdict.locked);
    });

    test('a wrong tempo is drift, and the real one is reported', () {
      // Recorded at 124 and labelled 120.
      final check = checkTiming(played(exactly(124)), take: take(bpm: 120));
      expect(check.impliedBpm, closeTo(124, 0.1));
      expect(check.tempoErrorPercent, closeTo(3.33, 0.2));
      expect(check.scatterMs, lessThan(2), reason: 'steady, just not 120');
      expect(check.verdict, TimingVerdict.locked);
      expect(check.worthRetempoing, isTrue);
    });

    test('a tempo far too small to see in the length is still caught', () {
      // A fifth of a per cent. Over six choruses of a blues that is more
      // than a beat by the end, and the length check would not blink.
      final check = checkTiming(played(exactly(120.25)), take: take(bpm: 120));
      expect(check.impliedBpm, closeTo(120.25, 0.1));
      expect(check.worthRetempoing, isTrue);
      expect(check.verdict, TimingVerdict.locked, reason: 'steady playing');
    });

    test('loose playing is scatter, and nothing is offered to fix it', () {
      final wobble = math.Random(3);
      final check = checkTiming(
        played((beat) => beat * 0.5 + (wobble.nextDouble() - 0.5) * 0.05),
        take: take(),
      );
      // Spread evenly across fifty milliseconds averages twelve or so.
      expect(check.scatterMs, closeTo(12.5, 4));
      expect(check.verdict, TimingVerdict.tight);
      expect(check.worthNudging, isFalse);
      expect(check.worthRetempoing, isFalse);
    });

    test('a band not playing to a click at all is called that', () {
      final wobble = math.Random(4);
      final check = checkTiming(
        played((beat) => beat * 0.5 + (wobble.nextDouble() - 0.5) * 0.18),
        take: take(),
      );
      expect(check.scatterMs, greaterThan(35));
      expect(check.verdict, TimingVerdict.adrift);
    });
  });

  group('drummers who play more than the beats', () {
    test('eighth notes are not read as half the tempo', () {
      // The period search looks for what makes everything line up, and a
      // ride playing eighths lines up at half a beat as well as at one.
      // Only the stated tempo keeps it honest, which is why the search
      // never wanders more than a few per cent from it.
      const rate = 44100;
      final samples = Float32List(34 * rate);
      final noise = math.Random(9);
      final length = (0.005 * rate).round();
      for (var half = 0; half < _beats * 2; half++) {
        final start = (half * 0.25 * rate).round();
        for (var i = 0; i < length; i++) {
          if (start + i >= samples.length) continue;
          samples[start + i] +=
              (noise.nextDouble() * 2 - 1) * math.exp(-i / (length / 3)) * 0.7;
        }
      }
      final check = checkTiming(
        WavAudio(sampleRate: rate, channels: 1, samples: samples),
        take: take(),
      );
      expect(check.impliedBpm, closeTo(120, 0.5));
      expect(check.verdict, TimingVerdict.locked);
    });

    test('and a fill does not count against them', () {
      // Sixteenths through one bar, on the beat everywhere else.
      final extra = [for (var i = 0; i < 16; i++) 8 + i * 0.125];
      const rate = 44100;
      final samples = Float32List(34 * rate);
      final noise = math.Random(13);
      final length = (0.005 * rate).round();
      for (final when in [
        for (var beat = 0; beat < _beats; beat++) beat * 0.5,
        ...extra,
      ]) {
        final start = (when * rate).round();
        for (var i = 0; i < length; i++) {
          if (start + i >= samples.length) continue;
          samples[start + i] +=
              (noise.nextDouble() * 2 - 1) * math.exp(-i / (length / 3)) * 0.7;
        }
      }
      final check = checkTiming(
        WavAudio(sampleRate: rate, channels: 1, samples: samples),
        take: take(),
      );
      expect(check.verdict, TimingVerdict.locked);
      expect(check.scatterMs, lessThan(3));
    });
  });

  group('all three at once, which is the real case', () {
    late TimingCheck check;
    setUp(() {
      // Trimmed 30 ms late, recorded at 121 rather than 120, and played
      // with a few milliseconds of ordinary human scatter.
      final wobble = math.Random(11);
      check = checkTiming(
        played(
          (beat) =>
              0.03 + beat * 60 / 121 + (wobble.nextDouble() - 0.5) * 0.012,
        ),
        take: take(bpm: 120),
      );
    });

    test('the trim is found without the tempo hiding it', () {
      expect(check.offsetMs, closeTo(30, 4));
    });

    test('the tempo is found without the trim hiding it', () {
      expect(check.impliedBpm, closeTo(121, 0.15));
    });

    test('and what is left is just the playing', () {
      expect(check.scatterMs, closeTo(3, 1.5));
      expect(check.verdict, TimingVerdict.locked);
    });
  });

  group('drummers who do not hit every beat', () {
    test('a two feel is measured from what it does play', () {
      final check = checkTiming(
        played(exactly(120), on: (beat) => beat.isEven),
        take: take(),
      );
      expect(check.beatsMatched, 31, reason: 'the one at sample zero aside');
      expect(check.coverage, closeTo(0.48, 0.02));
      expect(check.verdict, TimingVerdict.locked);
    });

    test('playing tastefully is not called a fault', () {
      // Beats 2 and 4 only: a quarter of them, which is below the bar,
      // so it says so rather than guessing.
      final check = checkTiming(
        played(exactly(120), on: (beat) => beat % 4 == 1 || beat % 4 == 3),
        take: take(),
      );
      expect(check.beatsMatched, 32, reason: 'two of every four');
      expect(check.verdict, TimingVerdict.locked);
    });
  });

  group('when nothing can be said', () {
    test('silence says so rather than guessing', () {
      final check = checkTiming(played((_) => -1), take: take());
      expect(check.verdict, TimingVerdict.cannotTell);
      expect(check.enoughToTell, isFalse);
    });

    test('too few hits to fit a line to says so too', () {
      final check = checkTiming(
        played(exactly(120), on: (beat) => beat < 4),
        take: take(),
      );
      expect(check.verdict, TimingVerdict.cannotTell);
    });

    test('a take with no tempo is not measured', () {
      final check = checkTiming(played(exactly(120)), take: take(bpm: 0));
      expect(check.verdict, TimingVerdict.cannotTell);
      expect(check.beatsExpected, 0);
    });
  });

  group('saying where the worst of it is', () {
    test('the bar, counted the way a person counts bars', () {
      // One beat badly out, in bar 5 of a four bar form.
      final check = checkTiming(
        played((beat) => beat * 0.5 + (beat == 17 ? 0.09 : 0)),
        take: take(),
      );
      expect(check.worstBeat, 17);
      expect(check.worstBar, 5, reason: 'beat 17 is in the fifth bar');
      expect(check.worstMs, closeTo(90, 8));
    });
  });

  group('running it off the thread that draws the screen', () {
    test('everything it needs and gives back can cross an isolate', () async {
      // The app measures in its own isolate, because a take is a hundred
      // megabytes of samples and walking all of them where the screen is
      // drawn would stop the screen. That only works if the recording
      // going in and the answer coming back can both be sent, and
      // nothing in a widget test can tell us whether they can: everything
      // there is inside a zone, and a closure that captures one cannot be
      // sent whatever it holds.
      final audio = played(exactly(120));
      final it = take();
      final check = await Isolate.run(() => checkTiming(audio, take: it));
      expect(check.verdict, TimingVerdict.locked);
      expect(check.beatsMatched, 63);
    });
  });

  group('which stem to measure', () {
    test('the kit, whenever there is one', () {
      expect(stemToTime(TakeStem.values), TakeStem.drums);
      expect(
        stemToTime([TakeStem.bass, TakeStem.comp]),
        TakeStem.comp,
        reason: 'a comp has clearer beginnings than a walking bass',
      );
      expect(stemToTime([TakeStem.bass]), TakeStem.bass);
      expect(stemToTime(const []), isNull);
    });
  });
}
