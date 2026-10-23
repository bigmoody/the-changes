// Finding the pitch of a guitar string from the microphone.
//
// This is the YIN method (de Cheveigné & Kawahara, 2002): compare the sound
// with itself shifted by every possible period, and take the shortest shift
// at which it lines up almost perfectly. Guitars are hard for simpler
// methods because a string's second harmonic is often louder than the note
// itself, which fools them into reading an octave too high; YIN's "first
// good match" rule avoids that.

import 'dart:math' as math;
import 'dart:typed_data';

class PitchDetector {
  PitchDetector({
    required this.sampleRate,
    this.lowestHz = 60, // below a low E (82 Hz), for strings tuned down
    this.highestHz = 1200,
    this.threshold = 0.15,
    this.silence = 0.008,
    this.periods = 3,
  });

  final int sampleRate;
  final double lowestHz;
  final double highestHz;

  /// How closely the sound must repeat to count as a note (lower is
  /// stricter).
  final double threshold;

  /// Quieter than this (RMS, where full scale is 1) counts as silence.
  final double silence;

  /// How many periods of the lowest note [detect] wants. More is steadier
  /// on a low string a small microphone hardly hears, and slower to follow.
  final int periods;

  /// How many samples [detect] wants: [periods] periods of the lowest
  /// note, one of them the longest shift tried.
  int get windowSize {
    final longest = (sampleRate / lowestHz).ceil();
    return longest * periods;
  }

  /// The pitch in [samples] (−1 … 1), with how clearly it's a single note
  /// (0 … 1), or null for silence and noise.
  ({double hz, double clarity})? detect(Float32List samples) {
    final maxLag = math.min(
      (sampleRate / lowestHz).ceil(),
      samples.length ~/ 2,
    );
    final minLag = math.max(2, (sampleRate / highestHz).floor());
    final width = samples.length - maxLag;
    if (width <= 0 || maxLag <= minLag) return null;

    var energy = 0.0;
    for (var i = 0; i < samples.length; i++) {
      energy += samples[i] * samples[i];
    }
    if (math.sqrt(energy / samples.length) < silence) return null;

    // Step 1–2: how different the sound is from itself shifted by each lag.
    final difference = Float64List(maxLag + 1);
    for (var lag = 1; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var i = 0; i < width; i++) {
        final d = samples[i] - samples[i + lag];
        sum += d * d;
      }
      difference[lag] = sum;
    }

    // Step 3: normalise by the running mean, so short lags aren't favoured.
    final normalised = Float64List(maxLag + 1)..[0] = 1;
    var running = 0.0;
    for (var lag = 1; lag <= maxLag; lag++) {
      running += difference[lag];
      normalised[lag] = running == 0 ? 1 : difference[lag] * lag / running;
    }

    // Step 4: the first lag that dips below the threshold, followed down to
    // the bottom of its dip.
    int? period;
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (normalised[lag] < threshold) {
        while (lag + 1 <= maxLag && normalised[lag + 1] < normalised[lag]) {
          lag++;
        }
        period = lag;
        break;
      }
    }
    if (period == null) return null;

    // Step 5: between samples, where the true bottom of the dip is.
    var exact = period.toDouble();
    if (period > 1 && period < maxLag) {
      final a = normalised[period - 1];
      final b = normalised[period];
      final c = normalised[period + 1];
      final curve = a - 2 * b + c;
      if (curve > 0) exact += (a - c) / (2 * curve);
    }
    return (
      hz: sampleRate / exact,
      clarity: (1 - normalised[period]).clamp(0.0, 1.0),
    );
  }
}
