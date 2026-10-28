// Writing the band out as an audio file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/export_track.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';

Tune _eight() => Tune.fromChart(
  title: 'Eight',
  key: 'F',
  defaultTempo: 120,
  chart: '| F7 | Bb7 | F7 | F7 | Bb7 | Bb7 | F7 | F7 |',
);

BackingRequest _request({
  int? choruses = 2,
  int tempo = 160,
  int countInBars = 1,
  Arrangement? arrangement,
}) {
  final tune = _eight();
  return BackingRequest(
    tune: tune,
    loop: LoopRange.wholeTune(tune),
    tempo: tempo,
    countInBars: countInBars,
    seed: 4,
    arrangement: arrangement ?? Arrangement(choruses: choruses),
  );
}

/// The export summed to one channel.
///
/// It is written in stereo, with each part where the player puts it, and
/// everything here is about where a sound is in time and how loud it is
/// rather than which side of the room it came from. Summed rather than
/// one channel taken, so a part panned away from centre is not quietly
/// left out of the measurement.
Int16List _mono(Uint8List wav) {
  final frames = decodeWav(wav);
  return Int16List.fromList([
    for (var i = 0; i + 1 < frames.length; i += 2)
      ((frames[i] + frames[i + 1]) / 2).round(),
  ]);
}

double _rms(Int16List samples, int from, int to) {
  var sum = 0.0;
  final end = math.min(to, samples.length);
  for (var i = from; i < end; i++) {
    sum += samples[i] * samples[i].toDouble();
  }
  return end > from ? math.sqrt(sum / (end - from)) : 0;
}

void main() {
  test('it is written in stereo, with the band spread across it', () {
    // The player puts each part in its own place, so an export that was a
    // mono sum of a stereo band would not be the thing anybody heard.
    final wav = exportTrack(_request());
    // Two channels, and the header saying so.
    final header = ByteData.sublistView(wav);
    expect(header.getUint16(22, Endian.little), 2, reason: 'channels');
    expect(
      header.getUint32(28, Endian.little),
      44100 * 4,
      reason: 'bytes a second',
    );
    expect(header.getUint16(32, Endian.little), 4, reason: 'bytes a frame');

    // And the two channels differ, which is the whole point: the chords
    // sit left of centre and the arpeggios right of it.
    final frames = decodeWav(wav);
    var difference = 0.0;
    for (var i = 0; i + 1 < frames.length; i += 2) {
      difference += (frames[i] - frames[i + 1]).abs();
    }
    expect(difference, greaterThan(0));
  });

  test('the parts are placed where the player places them', () {
    // Bass and drums down the middle, the comping to one side and the
    // arpeggios to the other, so the two keyboard parts can be told
    // apart while both are going.
    expect(Instrument.bass.pan, 0);
    expect(Instrument.drums.pan, 0);
    expect(Instrument.chords.pan, lessThan(0));
    expect(Instrument.arpeggio.pan, greaterThan(0));
    // Modestly: a part at the far side of the image is a part somebody
    // with one earbud in has lost.
    for (final part in Instrument.values) {
      expect(part.pan.abs(), lessThanOrEqualTo(0.5), reason: part.label);
    }
  });

  test('and the law is the engine\'s own', () {
    // Equal power: the two gains square up to one, so a part does not get
    // louder as it crosses the middle, and a centred one is 0.707 either
    // side rather than 1 and 1.
    for (final pan in [-1.0, -0.35, 0.0, 0.2, 0.35, 1.0]) {
      final gains = panGains(pan);
      expect(
        gains.left * gains.left + gains.right * gains.right,
        closeTo(1, 1e-9),
        reason: 'at $pan',
      );
    }
    expect(panGains(0).left, closeTo(0.70710678, 1e-6));
    expect(panGains(0).right, closeTo(0.70710678, 1e-6));
    expect(panGains(-1).left, closeTo(1, 1e-9));
    expect(panGains(-1).right, closeTo(0, 1e-9));
    expect(panGains(1).left, closeTo(0, 1e-9));
    expect(panGains(1).right, closeTo(1, 1e-9));
  });

  test('it comes out as a playable WAV of the right length', () {
    final request = _request(choruses: 2);
    final wav = exportTrack(request);
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');
    expect(String.fromCharCodes(wav.skip(8).take(4)), 'WAVE');

    final samples = _mono(wav);
    final seconds = samples.length / 44100;
    // A bar of count-in and two eight-bar choruses at 160, plus the ring of
    // the last chord.
    final wanted = exportLength(request).inMilliseconds / 1000;
    expect(wanted, closeTo(1.5 + 24, 0.1));
    expect(seconds, greaterThan(wanted));
    expect(
      seconds,
      lessThan(wanted + 4.5),
      reason: 'only the final chord ringing is extra',
    );
  });

  test('the band ends on a final chord rather than stopping dead', () {
    final request = _request(choruses: 2);
    final samples = _mono(exportTrack(request));
    final end = (exportLength(request).inMilliseconds / 1000 * 44100).round();
    double loudness(int from, int to) {
      var sum = 0.0;
      for (var i = from; i < to && i < samples.length; i++) {
        sum += samples[i].abs();
      }
      return sum / (to - from);
    }

    // Half a second into where the form has finished, the band is still
    // sounding: the chord it came down on, not the dregs of the last bar.
    final lastBar = loudness(end - 44100, end);
    final after = loudness(end + 22050, end + 44100);
    expect(after, greaterThan(lastBar / 4), reason: 'a chord to end on');
    // And it dies away rather than being cut off.
    expect(loudness(samples.length - 4410, samples.length), lessThan(after / 4));
  });

  test('the whole band is in it, all the way through', () {
    final samples = _mono(exportTrack(_request(choruses: 3)));
    // Loud from the count-in to the last bar, with nothing dropping out.
    final chunk = samples.length ~/ 8;
    for (var i = 0; i < 7; i++) {
      expect(
        _rms(samples, i * chunk, (i + 1) * chunk),
        greaterThan(200),
        reason: 'eighth ${i + 1}',
      );
    }
  });

  test('nothing clips, however much is stacked up', () {
    final samples = _mono(exportTrack(_request(choruses: 2, tempo: 300)));
    var squared = 0;
    for (final sample in samples) {
      if (sample.abs() >= 32760) squared++;
    }
    expect(squared, 0, reason: 'the whole track comes down instead');
  });

  test('the count-in can be left off', () {
    final withClicks = _mono(exportTrack(_request()));
    final without = _mono(exportTrack(_request(), withCountIn: false));
    expect(without.length, lessThan(withClicks.length));
    // A bar of four at 160 is 1.5 seconds.
    expect((withClicks.length - without.length) / 44100, closeTo(1.5, 0.2));
  });

  test('a take is laid over the band where it belongs', () {
    final request = _request(choruses: 1, countInBars: 1);
    // A recording: half a second of the wait before the band came in, then
    // a steady tone.
    final rate = 44100;
    final lead = 0.5;
    final take = Int16List(rate * 3);
    for (var i = (lead * rate).round(); i < take.length; i++) {
      take[i] = (math.sin(2 * math.pi * 440 * i / rate) * 12000).round();
    }
    final plain = _mono(exportTrack(request));
    final mixed = _mono(exportTrack(request, take: take, takeLeadIn: lead));
    expect(mixed.length, greaterThanOrEqualTo(plain.length));

    // During the count-in the take hasn't started; once the band comes in
    // it has, and the track is louder for it.
    final countIn = (1.5 * rate).round();
    expect(
      _rms(mixed, 0, countIn ~/ 2),
      closeTo(_rms(plain, 0, countIn ~/ 2), 60),
    );
    expect(
      _rms(mixed, countIn + 2000, countIn + 40000),
      greaterThan(_rms(plain, countIn + 2000, countIn + 40000) + 100),
    );
  });

  group('stopping where the recording does', () {
    // Sixteen bars in four sections of four, so there are letters to land
    // on part-way through a chorus.
    Tune sectioned() => Tune.fromChart(
      title: 'Four Fours',
      key: 'C',
      defaultTempo: 120,
      chart:
          '| [A] C | C | F | F | [B] G | G | C | C '
          '| [C] Am | Am | D7 | D7 | [D] G7 | G7 | C | C |',
    );

    BackingRequest request({int choruses = 4, int tempo = 120}) {
      final tune = sectioned();
      return BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: tempo,
        countInBars: 1,
        seed: 2,
        arrangement: Arrangement(choruses: choruses),
      );
    }

    test('how many beats fit in a stretch of time', () {
      // At 120, a beat is half a second.
      expect(beatsIn(request(), const Duration(seconds: 10)), 20);
      expect(beatsIn(request(tempo: 240), const Duration(seconds: 10)), 40);
      // A ramp makes the later beats shorter, so more of them fit.
      final tune = sectioned();
      final ramped = BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: 120,
        arrangement: const Arrangement(
          choruses: 8,
          ramp: TempoRamp(step: 60, climb: 120),
        ),
      );
      expect(
        beatsIn(ramped, const Duration(seconds: 60)),
        greaterThan(beatsIn(request(), const Duration(seconds: 60))),
      );
    });

    test('it runs on to the end of the section you finished in', () {
      final tune = sectioned();
      final loop = LoopRange.wholeTune(tune);
      // Sections start at bars 0, 4, 8 and 12: beats 0, 16, 32 and 48.
      expect(finishSectionAfter(tune, loop, 1), 16, reason: 'into A');
      expect(finishSectionAfter(tune, loop, 15), 16);
      expect(finishSectionAfter(tune, loop, 16), 16, reason: 'already there');
      expect(finishSectionAfter(tune, loop, 17), 32, reason: 'into B');
      expect(finishSectionAfter(tune, loop, 50), 64, reason: 'into D');
      // Second time round: it carries on counting.
      expect(finishSectionAfter(tune, loop, 70), 80);
    });

    test('a chart with no letters finishes the chorus instead', () {
      final plain = _eight();
      final loop = LoopRange.wholeTune(plain);
      expect(plain.sections, isEmpty);
      expect(finishSectionAfter(plain, loop, 5), 32);
      expect(finishSectionAfter(plain, loop, 33), 64);
    });

    test('the file is as long as the section, not the arrangement', () {
      final full = _mono(exportTrack(request(choruses: 4)));
      // Somebody played about ten seconds: twenty beats, which is into the
      // B section, so the band runs to the end of B: 32 beats, 16 seconds.
      final short = _mono(exportTrack(request(choruses: 4), endBeat: 32));
      expect(short.length, lessThan(full.length ~/ 2));
      final seconds = short.length / 44100;
      // Two seconds of count-in, sixteen of band, and the fade.
      expect(seconds, closeTo(2 + 16 + 0.4, 0.3));
    });

    test('it fades rather than stopping with a click', () {
      final samples = _mono(exportTrack(request(choruses: 4), endBeat: 32));
      final last = _rms(samples, samples.length - 2000, samples.length);
      final before = _rms(
        samples,
        samples.length - 30000,
        samples.length - 20000,
      );
      expect(last, lessThan(before / 4), reason: 'it dies away');
    });
  });

  test('an arrangement that never ends is not a file', () {
    expect(() => exportTrack(_request(choruses: null)), throwsArgumentError);
  });

  test('a head-in-and-out arrangement exports as it plays', () {
    final request = _request(
      arrangement: const Arrangement(choruses: 3, headInAndOut: true),
    );
    final samples = _mono(exportTrack(request));
    expect(samples, isNotEmpty);
    expect(
      exportLength(request).inMilliseconds / 1000,
      closeTo(1.5 + 36, 0.1),
      reason: 'three choruses of eight bars at 160',
    );
  });

  test('a tempo ramp makes it shorter than it would have been', () {
    final steady = exportLength(_request(choruses: 4));
    final ramped = exportLength(
      _request(
        arrangement: const Arrangement(
          choruses: 4,
          ramp: TempoRamp(step: 20, climb: 60),
        ),
      ),
    );
    expect(ramped, lessThan(steady));
  });
}
