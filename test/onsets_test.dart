// Finding the hits in a recording.
//
// The recordings here are made rather than recorded, so the answer is
// known to the sample. That matters more than usual: every millisecond
// this gets wrong is a millisecond that later reads as a drummer who
// cannot keep time, so what is really being tested is the size of the
// tool's own error.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/onsets.dart';
import 'package:play_along/audio/wav_file.dart';

/// Hits at exactly [at] seconds, in a recording [seconds] long.
///
/// Five milliseconds of decaying noise, which is a rimshot in spirit and
/// has the one property that matters: it starts abruptly.
WavAudio hitsAt(
  List<double> at, {
  double seconds = 10,
  int rate = 44100,
  int channels = 1,
  double level = 0.7,
}) {
  final samples = Float32List((seconds * rate).round() * channels);
  final noise = math.Random(1);
  final length = (0.005 * rate).round();
  for (final when in at) {
    final start = (when * rate).round();
    for (var i = 0; i < length; i++) {
      final frame = start + i;
      if (frame < 0 || frame >= samples.length ~/ channels) continue;
      final value =
          (noise.nextDouble() * 2 - 1) * math.exp(-i / (length / 3)) * level;
      for (var channel = 0; channel < channels; channel++) {
        samples[frame * channels + channel] += value;
      }
    }
  }
  return WavAudio(sampleRate: rate, channels: channels, samples: samples);
}

/// How far each of [wanted] was reported from where it really was, in ms.
List<double> errorsFinding(List<double> wanted, WavAudio audio) {
  final found = findOnsets(audio);
  return [
    for (final when in wanted)
      if (found.isEmpty)
        double.nan
      else
        found
                .map((one) => one - when)
                .reduce((a, b) => a.abs() < b.abs() ? a : b) *
            1000,
  ];
}

void main() {
  final everyHalfSecond = [for (var i = 1; i <= 16; i++) i * 0.5];

  group('how accurate it is, which is the whole question', () {
    test('a hit is placed within a millisecond of where it really is', () {
      final errors = errorsFinding(everyHalfSecond, hitsAt(everyHalfSecond));
      for (final error in errors) {
        expect(error.abs(), lessThan(1), reason: 'errors were $errors');
      }
    });

    test('and it is not wrong in the same direction every time', () {
      // A steady bias would be harmless, because it comes out as the
      // recording sitting late as a whole. A bias is still worth not
      // having, and this says there is not one.
      final errors = errorsFinding(everyHalfSecond, hitsAt(everyHalfSecond));
      final mean = errors.reduce((a, b) => a + b) / errors.length;
      expect(mean.abs(), lessThan(0.5));
    });

    test('the error does not wander with where a hit falls', () {
      // The coarse pass works in steps of six milliseconds, so before the
      // attack was looked for in the original samples this wandered by
      // that much depending on the phase of the hit against the steps.
      // Nudging every hit by a third of a step used to change the answer.
      final shifted = [for (final when in everyHalfSecond) when + 0.002];
      final errors = errorsFinding(shifted, hitsAt(shifted));
      final mean = errors.reduce((a, b) => a + b) / errors.length;
      final spread = errors
          .map((error) => (error - mean).abs())
          .reduce(math.max);
      expect(spread, lessThan(1));
    });
  });

  group('what it finds', () {
    test('every hit, and no more than every hit', () {
      expect(findOnsets(hitsAt(everyHalfSecond)), hasLength(16));
    });

    test('hits close together are still two hits', () {
      final pair = [1.0, 1.12];
      expect(findOnsets(hitsAt(pair, seconds: 3)), hasLength(2));
    });

    test('a quiet passage is not missed for being quiet', () {
      // The threshold follows the music. A fixed one would find the loud
      // half and read the soft half as a drummer who stopped.
      final loud = [1.0, 1.5, 2.0, 2.5];
      final soft = [5.0, 5.5, 6.0, 6.5];
      final samples = hitsAt(loud, seconds: 8).samples;
      final quiet = hitsAt(soft, seconds: 8, level: 0.05).samples;
      for (var i = 0; i < samples.length; i++) {
        samples[i] += quiet[i];
      }
      final found = findOnsets(
        WavAudio(sampleRate: 44100, channels: 1, samples: samples),
      );
      expect(found, hasLength(8));
    });

    test('stereo is summed rather than counted twice', () {
      expect(findOnsets(hitsAt(everyHalfSecond, channels: 2)), hasLength(16));
    });

    test('silence has nothing in it', () {
      expect(findOnsets(hitsAt(const [])), isEmpty);
    });

    test('a recording too short to look at gives nothing', () {
      expect(findOnsets(hitsAt(const [], seconds: 0.005)), isEmpty);
    });
  });
}
