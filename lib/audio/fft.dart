// A fast Fourier transform, and the magnitude spectrum of a windowed
// signal.
//
// The tuner finds one note by looking for the sound repeating (see
// pitch_detector.dart). A chord doesn't repeat simply — six strings ringing
// together have no single period — so naming one means looking at the
// frequencies themselves instead.

import 'dart:math' as math;
import 'dart:typed_data';

/// An in-place complex FFT, decimation in time. [real] and [imaginary] must
/// be the same length, and that length a power of two.
void fft(Float64List real, Float64List imaginary) {
  final n = real.length;
  assert(imaginary.length == n);
  assert(n & (n - 1) == 0, 'the length must be a power of two');
  if (n <= 1) return;

  // Put the samples in bit-reversed order, which is where the butterflies
  // below expect to find them.
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tempReal = real[i];
      real[i] = real[j];
      real[j] = tempReal;
      final tempImaginary = imaginary[i];
      imaginary[i] = imaginary[j];
      imaginary[j] = tempImaginary;
    }
  }

  for (var length = 2; length <= n; length <<= 1) {
    final angle = -2 * math.pi / length;
    final stepReal = math.cos(angle);
    final stepImaginary = math.sin(angle);
    for (var start = 0; start < n; start += length) {
      var turnReal = 1.0;
      var turnImaginary = 0.0;
      for (var k = 0; k < length ~/ 2; k++) {
        final a = start + k;
        final b = a + length ~/ 2;
        final oddReal = real[b] * turnReal - imaginary[b] * turnImaginary;
        final oddImaginary = real[b] * turnImaginary + imaginary[b] * turnReal;
        real[b] = real[a] - oddReal;
        imaginary[b] = imaginary[a] - oddImaginary;
        real[a] += oddReal;
        imaginary[a] += oddImaginary;
        final nextReal = turnReal * stepReal - turnImaginary * stepImaginary;
        turnImaginary = turnReal * stepImaginary + turnImaginary * stepReal;
        turnReal = nextReal;
      }
    }
  }
}

/// The magnitude spectrum of [samples], over [size] points (a power of
/// two). Bin `i` holds the energy at `i * sampleRate / size` hertz, so only
/// the first half is meaningful.
///
/// A Hann window is applied first: cutting a sound off mid-cycle smears
/// every note across the whole spectrum, which would bury the quieter
/// strings of a chord under the loud ones.
Float64List magnitudeSpectrum(Float32List samples, {required int size}) {
  final real = Float64List(size);
  final imaginary = Float64List(size);
  final count = math.min(samples.length, size);
  for (var i = 0; i < count; i++) {
    final window = 0.5 - 0.5 * math.cos(2 * math.pi * i / (count - 1));
    real[i] = samples[i] * window;
  }
  fft(real, imaginary);
  final magnitude = Float64List(size ~/ 2);
  for (var i = 0; i < magnitude.length; i++) {
    magnitude[i] = math.sqrt(real[i] * real[i] + imaginary[i] * imaginary[i]);
  }
  return magnitude;
}
