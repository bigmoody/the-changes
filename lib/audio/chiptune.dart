// A chiptune band, for when you want one.
//
// What makes this sound is hardware and not anybody's music. A console of
// that era had a handful of channels and each one could make exactly one
// kind of noise: two pulse waves whose duty cycle you could pick, a
// triangle for the bass, and a noise generator that everybody used for
// drums because there was nothing else to use. Give a band those voices
// and it sounds like that, whatever it plays. Nothing here is copied from
// anything: there are no tunes in this file, only waveforms.
//
// Two eras, because they are two different machines:
//
//  • 8-Bit. Pulse waves, a triangle bass, noise for the kit, flat
//    envelopes and no room at all. Everything is a hard edge, which is
//    what a square wave is.
//  • 16-Bit. The next machine played short samples rather than generating
//    waves, so it is warmer and rounder: softer attacks, a little more in
//    the harmonics, some decay on the notes, and a small room, because
//    they put reverb on everything the moment they could.
//
// Pulses are built from their harmonics rather than drawn as edges, and
// stop at the Nyquist frequency. A square wave drawn as a square aliases
// horribly at this sample rate: every harmonic above half the rate folds
// back down as a wrong note. The hardware had no such problem because it
// was running at a rate where the fold-back landed above hearing, and the
// grit people remember is the fold-back of a 1.79 MHz chip, not of a
// 44.1 kHz one.

import 'dart:math' as math;
import 'dart:typed_data';

/// Which machine.
enum ChipEra {
  eightBit('8-Bit'),
  sixteenBit('16-Bit');

  const ChipEra(this.label);

  final String label;

  /// How much of the harmonics survive: the later machine's samples were
  /// filtered on the way in and on the way out.
  double get rolloff => this == eightBit ? 1 : 0.72;

  /// How long the front of a note takes. A pulse channel switching on is
  /// instant; a sample being triggered is not quite.
  double get attack => this == eightBit ? 0.001 : 0.006;

  /// How fast a held note dies away. Nearly not at all on the earlier
  /// machine, which is why its chords sound like an organ.
  double get decay => this == eightBit ? 2.5 : 0.9;
}

/// The harmonic amplitudes of a pulse wave of [duty], from the first up.
///
/// A pulse of duty d has the nth harmonic at sin(nπd)/n, which is what
/// makes the duty cycle the tone control it is: at a half it is a square
/// and every even harmonic cancels, at a quarter the odd ones thin out
/// and the even ones come in, and at an eighth it is all harmonics and
/// sounds like a reed.
List<double> pulseHarmonics(double duty, {int upTo = 32}) => [
  for (var n = 1; n <= upTo; n++)
    math.sin(n * math.pi * duty) / n * (2 / math.pi),
];

/// The harmonic amplitudes of a triangle wave, which is the bass channel.
///
/// Odd harmonics only, falling away as the square of the number, so it is
/// nearly a sine with a corner on it: quiet, round, and the reason a bass
/// line on these machines sits under everything without fighting it.
List<double> triangleHarmonics({int upTo = 15}) => [
  for (var n = 1; n <= upTo; n++)
    if (n.isEven) 0.0 else (8 / (math.pi * math.pi)) / (n * n) * _sign(n),
];

double _sign(int n) => ((n - 1) ~/ 2).isEven ? 1 : -1;

/// Adds up [harmonics] of [hertz] for [seconds], with a flat-ish envelope.
Float32List _wave(
  double hertz,
  double seconds,
  int sampleRate, {
  required List<double> harmonics,
  required ChipEra era,
  double amplitude = 1,
}) {
  final count = (seconds * sampleRate).round();
  final out = Float32List(count);
  final nyquist = sampleRate / 2;
  // The release is a few milliseconds: long enough not to click, short
  // enough that a note still ends when it ends.
  final release = math.min(count, (0.008 * sampleRate).round());
  final attack = math.max(1, (era.attack * sampleRate).round());
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    var envelope = math.min(1.0, i / attack) * math.exp(-t / era.decay);
    if (i > count - release) envelope *= (count - i) / release;
    var sample = 0.0;
    for (var n = 0; n < harmonics.length; n++) {
      if (harmonics[n] == 0) continue;
      final f = hertz * (n + 1);
      if (f >= nyquist) break;
      // The later machine's filter: the higher the harmonic the less of
      // it survives.
      final kept = era == ChipEra.eightBit
          ? 1.0
          : math.pow(era.rolloff, n).toDouble();
      sample += harmonics[n] * kept * math.cos(2 * math.pi * f * t);
    }
    out[i] = amplitude * envelope * sample;
  }
  return out;
}

/// A chord note: a pulse wave, which is the voice of the thing.
///
/// [duty] is which of the two pulse channels it is standing in for. A
/// quarter for the comping, because a square and a quarter-pulse playing
/// the same notes is how those machines got two parts out of two
/// channels that sounded alike.
Float32List chipTone(
  double hertz,
  double seconds,
  int sampleRate, {
  double duty = 0.25,
  ChipEra era = ChipEra.eightBit,
}) => _wave(
  hertz,
  seconds,
  sampleRate,
  harmonics: pulseHarmonics(duty),
  era: era,
  amplitude: 0.22,
);

/// A bass note: the triangle channel.
Float32List chipBass(
  double hertz,
  double seconds,
  int sampleRate, {
  ChipEra era = ChipEra.eightBit,
}) => _wave(
  hertz,
  seconds,
  sampleRate,
  harmonics: triangleHarmonics(),
  era: era,
  amplitude: 0.5,
);

/// Noise, as the noise channel made it: a shift register clocked at a
/// chosen rate, which is white noise held in steps rather than a fresh
/// number every sample.
///
/// [step] is how many samples each value lasts. That is the whole of the
/// noise channel's "pitch", and it is why its hi-hat and its snare are
/// the same sound at two settings.
Float32List _noise(
  int sampleRate,
  math.Random random, {
  required double seconds,
  required double decay,
  required int step,
  double amplitude = 1,
}) {
  final count = (seconds * sampleRate).round();
  final out = Float32List(count);
  var held = random.nextDouble() * 2 - 1;
  for (var i = 0; i < count; i++) {
    if (i % step == 0) held = random.nextDouble() * 2 - 1;
    out[i] = amplitude * held * math.exp(-(i / sampleRate) / decay);
  }
  return out;
}

/// A kick: a pulse dropped fast through its own register.
///
/// There was no kick drum to sample, so this is what everybody did
/// instead, and it is why the kick on those records is a falling sound
/// rather than a thump.
Float32List chipKick(int sampleRate, {ChipEra era = ChipEra.eightBit}) {
  final seconds = era == ChipEra.eightBit ? 0.1 : 0.14;
  final count = (seconds * sampleRate).round();
  final out = Float32List(count);
  var phase = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    // 150 Hz down to 40 over the length of it.
    final hertz = 150 * math.exp(-t / 0.03) + 40;
    phase += 2 * math.pi * hertz / sampleRate;
    final envelope = math.exp(-t / (seconds / 3));
    // Squared off on the earlier machine, rounder on the later one.
    final wave = era == ChipEra.eightBit
        ? (math.sin(phase) > 0 ? 1.0 : -1.0)
        : math.sin(phase);
    out[i] = 0.9 * envelope * wave;
  }
  return out;
}

/// The percussion, all of it out of the noise channel bar the kick.
class ChipKit {
  ChipKit(int sampleRate, math.Random random, ChipEra era)
    : ride = [
        for (var i = 0; i < 3; i++)
          _noise(
            sampleRate,
            random,
            seconds: era == ChipEra.eightBit ? 0.28 : 0.5,
            decay: era == ChipEra.eightBit ? 0.07 : 0.13,
            step: 2,
            amplitude: 0.5,
          ),
      ],
      // Shorter and faster-clocked: the same sound at another setting,
      // which is all the hardware could do and all it needed to.
      closedHat = _noise(
        sampleRate,
        random,
        seconds: 0.05,
        decay: 0.012,
        step: 1,
        amplitude: 0.45,
      ),
      hiHatPedal = _noise(
        sampleRate,
        random,
        seconds: 0.04,
        decay: 0.009,
        step: 1,
        amplitude: 0.35,
      ),
      snare = _noise(
        sampleRate,
        random,
        seconds: era == ChipEra.eightBit ? 0.12 : 0.18,
        decay: era == ChipEra.eightBit ? 0.035 : 0.055,
        step: 3,
        amplitude: 0.8,
      ),
      crossStick = _noise(
        sampleRate,
        random,
        seconds: 0.03,
        decay: 0.006,
        step: 4,
        amplitude: 0.5,
      ),
      kick = chipKick(sampleRate, era: era);

  final List<Float32List> ride;
  final Float32List closedHat;
  final Float32List hiHatPedal;
  final Float32List snare;
  final Float32List crossStick;
  final Float32List kick;
}
