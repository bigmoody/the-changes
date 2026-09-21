// How quietly you can play and still be heard.
//
// The first version of Check My Playing turned people away at the door: a
// loudness gate meant for a tuner held right against a guitar. These pin
// what the measurements showed: that YIN doesn't care how loud a note is,
// only how cleanly it repeats, so the limit is the room's noise and not the
// level.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/pitch_detector.dart';
import 'package:play_along/audio/tuner_listener.dart';
import 'package:play_along/music/tuning.dart';

const _rate = 44100;

/// A note with a few harmonics, at [level], over [noise] of hiss.
Float32List _play(
  double hz,
  int samples, {
  required double level,
  double noise = 0,
  int seed = 1,
}) {
  final random = math.Random(seed);
  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    final t = i / _rate;
    var value = 0.0;
    for (var harmonic = 1; harmonic <= 8; harmonic++) {
      value += math.sin(2 * math.pi * hz * harmonic * t) / harmonic;
    }
    out[i] = value * level * 0.5 + (random.nextDouble() * 2 - 1) * noise;
  }
  return out;
}

double _rms(Float32List buffer) {
  var sum = 0.0;
  for (final sample in buffer) {
    sum += sample * sample;
  }
  return math.sqrt(sum / buffer.length);
}

/// The detector as Check My Playing sets it up.
PitchDetector _checking() {
  final listener = TunerListener.forChecking();
  return PitchDetector(
    sampleRate: _rate,
    lowestHz: listener.lowestHz,
    silence: listener.silence,
  );
}

void main() {
  test('quiet playing is still named, right down to a whisper', () {
    final detector = _checking();
    final size = detector.windowSize;
    for (final level in [0.2, 0.05, 0.01, 0.002, 0.001]) {
      final buffer = _play(midiToHz(65), size, level: level);
      final heard = detector.detect(buffer);
      expect(
        heard,
        isNotNull,
        reason: 'level $level (rms ${_rms(buffer).toStringAsFixed(5)})',
      );
      expect(hzToMidi(heard!.hz), closeTo(65, 0.3), reason: 'level $level');
      expect(
        heard.clarity,
        greaterThan(TunerListener.forChecking().minClarity),
      );
    }
  });

  test('the loudness gate is a guard against nothing, not a doorman', () {
    final listener = TunerListener.forChecking();
    // A note this quiet measures about 0.0004 RMS and must still get in.
    expect(listener.silence, lessThan(0.001));
    final detector = _checking();
    final buffer = _play(midiToHz(65), detector.windowSize, level: 0.001);
    expect(_rms(buffer), lessThan(0.001), reason: 'genuinely quiet');
    expect(detector.detect(buffer), isNotNull);
  });

  test('hiss on its own is never mistaken for a note', () {
    final detector = _checking();
    final size = detector.windowSize;
    var named = 0;
    for (var seed = 0; seed < 200; seed++) {
      for (final noise in [0.0005, 0.005, 0.03]) {
        final buffer = _play(0, size, level: 0, noise: noise, seed: seed);
        if (detector.detect(buffer) != null) named++;
      }
    }
    expect(named, 0, reason: 'a quiet gate is safe because noise has no pitch');
  });

  test('what limits it is the room, not the level', () {
    final detector = _checking();
    final size = detector.windowSize;
    // Well above the hiss: heard. Down among it: nothing at all, which is
    // reported as nothing rather than guessed at.
    final clear = _play(midiToHz(65), size, level: 0.02, noise: 0.002);
    expect(detector.detect(clear), isNotNull);
    final buried = _play(midiToHz(65), size, level: 0.002, noise: 0.002);
    expect(detector.detect(buried), isNull, reason: 'lost in the room');
  });

  test('below the floor it hears nothing, rather than an octave up', () {
    final listener = TunerListener.forChecking();
    expect(listener.lowestHz, greaterThanOrEqualTo(100));
    final detector = _checking();
    // Most of a walking bass line (E1 up to G2) is simply not heard, so
    // through a speaker it can't be credited to you. It isn't folded up an
    // octave into the same note name either, which would be worse than
    // useless.
    for (final midi in [28, 33, 38, 43]) {
      final bass = _play(midiToHz(midi), detector.windowSize, level: 0.2);
      expect(
        detector.detect(bass),
        isNull,
        reason: 'midi $midi is the bass player\'s',
      );
    }
    // The top of their range does overlap yours, though, which is why
    // headphones are the real answer, not this.
    final high = _play(midiToHz(52), detector.windowSize, level: 0.2);
    expect(detector.detect(high), isNotNull);
  });
}
