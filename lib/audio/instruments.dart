// The band's instrument sounds, synthesised in code (no sample files, so
// nothing to license or download).
//
//  • Upright bass: Karplus–Strong string synthesis. A burst of noise is fed
//    round a short delay line whose length sets the pitch; averaging each
//    trip makes the high frequencies die away first, like a real plucked
//    string.
//  • Electric piano: FM synthesis, the technique behind the classic DX7
//    "E. Piano". A sine wave's pitch is wobbled by another sine; the wobble
//    fades quickly, so each note starts bright and bell-like and mellows.
//  • Cymbals: six detuned square waves, high-pass filtered, the metallic
//    tone used in classic drum machines, plus filtered noise for sizzle.
//  • Room reverb: a small Schroeder/Freeverb-style reverb (comb and all-pass
//    filters) so the band sounds like it's in a room, not a box.

import 'dart:math' as math;
import 'dart:typed_data';

import 'drum_patterns.dart' show Drum;

double midiToFrequency(int note) =>
    440 * math.pow(2, (note - 69) / 12).toDouble();

// ── Bass ─────────────────────────────────────────────────────────────────

/// A plucked upright-bass note lasting [seconds] (then quickly muted).
Float32List pluckedBass(
  double frequency,
  double seconds,
  int sampleRate,
  math.Random random, {
  double velocity = 1,
}) {
  final period = math.max(2, (sampleRate / frequency).round());
  final release = (0.07 * sampleRate).round();
  final held = (seconds * sampleRate).round();
  final out = Float32List(held + release);

  // Excite the string with softened noise: a finger pluck, not a pick.
  final delay = Float64List(period);
  var smoothed = 0.0;
  for (var i = 0; i < period; i++) {
    smoothed += 0.35 * ((random.nextDouble() * 2 - 1) - smoothed);
    delay[i] = smoothed;
  }
  var mean = 0.0;
  for (final v in delay) {
    mean += v;
  }
  mean /= period;
  for (var i = 0; i < period; i++) {
    delay[i] -= mean;
  }

  // Per-sample loss: rings for ~2.5 s, then damped fast when released.
  final ringing = math.exp(math.log(0.001) / (2.5 * sampleRate));
  final muted = math.exp(math.log(0.001) / (0.06 * sampleRate));

  var index = 0;
  var tone = 0.0; // one-pole low-pass for a warm, woody tone
  final twoPiF = 2 * math.pi * frequency / sampleRate;
  for (var n = 0; n < out.length; n++) {
    final next = (index + 1) % period;
    final loss = n < held ? ringing : muted;
    final value = delay[index];
    delay[index] = loss * 0.5 * (value + delay[next]);
    index = next;

    tone += 0.28 * (value - tone);
    // A little pure fundamental adds body the string model lacks.
    final body =
        math.sin(twoPiF * n) * math.exp(-n / (0.9 * sampleRate)) * 0.35;
    final gate = n < held ? 1.0 : 1 - (n - held) / release;
    out[n] = velocity * (tone * 2.2 + body * gate);
  }
  _fadeIn(out, (0.003 * sampleRate).round());
  return out;
}

// ── Electric piano ───────────────────────────────────────────────────────

/// A Rhodes-style electric piano note.
Float32List electricPiano(
  double frequency,
  double seconds,
  int sampleRate, {
  double velocity = 1,
}) {
  final held = (seconds * sampleRate).round();
  final release = (0.12 * sampleRate).round();
  final out = Float32List(held + release);
  final w = 2 * math.pi * frequency / sampleRate;
  // Low notes sustain longer than high ones, as on the real instrument.
  final sustain = 2.2 * math.pow(261.6 / frequency, 0.4);

  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final amplitude =
        (0.55 * math.exp(-t / 0.3) + 0.45 * math.exp(-t / sustain)) *
        (n < held ? 1.0 : 1 - (n - held) / release);
    // Brightness (FM index) falls quickly after the hammer strike.
    final index = velocity * (1.6 * math.exp(-t / 0.18) + 0.25);
    final body = math.sin(w * n + index * math.sin(w * n));
    // The metallic "tine" click at the very start.
    final tine =
        0.18 * velocity * math.exp(-t / 0.025) * math.sin(w * 13.9 * n);
    out[n] = (velocity * 0.8 + 0.2) * amplitude * (body + tine);
  }
  _fadeIn(out, (0.002 * sampleRate).round());
  return out;
}

// ── Drums ────────────────────────────────────────────────────────────────

/// Pre-rendered drum hits, reused for every beat (like a sampler).
class DrumKit {
  DrumKit(int sampleRate, math.Random random)
    : ride = [
        for (var i = 0; i < 3; i++)
          _cymbal(sampleRate, random, seconds: 1.3, decay: 0.5, tuning: 1.9),
      ],
      hiHatPedal = _cymbal(
        sampleRate,
        random,
        seconds: 0.09,
        decay: 0.022,
        tuning: 2.6,
        noise: 0.6,
      ),
      closedHat = _cymbal(
        sampleRate,
        random,
        seconds: 0.12,
        decay: 0.035,
        tuning: 2.8,
        noise: 0.5,
      ),
      kick = _kick(sampleRate),
      crossStick = _crossStick(sampleRate, random);

  /// A few slightly different ride hits, so repeated beats aren't identical.
  final List<Float32List> ride;
  final Float32List hiHatPedal;
  final Float32List closedHat;
  final Float32List kick;
  final Float32List crossStick;
}

Float32List _cymbal(
  int sampleRate,
  math.Random random, {
  required double seconds,
  required double decay,
  required double tuning,
  double noise = 0.35,
}) {
  // The classic drum-machine "metal" frequencies, detuned a touch each time.
  const base = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0];
  final frequencies = [
    for (final f in base) f * tuning * (0.99 + random.nextDouble() * 0.02),
  ];
  final phases = [for (final _ in base) random.nextDouble()];
  final out = Float32List((seconds * sampleRate).round());
  final hp1 = _HighPass(7000, sampleRate);
  final hp2 = _HighPass(7000, sampleRate);
  final noiseFilter = _HighPass(9000, sampleRate);

  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    var metal = 0.0;
    for (var i = 0; i < frequencies.length; i++) {
      metal += ((phases[i] + frequencies[i] * t) % 1.0) < 0.5 ? 1.0 : -1.0;
    }
    final sizzle = noiseFilter.process(random.nextDouble() * 2 - 1);
    final envelope = math.exp(-t / decay) * math.min(1.0, t / 0.0008);
    out[n] = envelope * (hp2.process(hp1.process(metal / 6)) + noise * sizzle);
  }
  return out;
}

Float32List _kick(int sampleRate) {
  final out = Float32List((0.35 * sampleRate).round());
  var phase = 0.0;
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final frequency = 52 + 90 * math.exp(-t / 0.018); // pitch drops: "thump"
    phase += 2 * math.pi * frequency / sampleRate;
    out[n] = math.sin(phase) * math.exp(-t / 0.13);
  }
  _fadeIn(out, (0.001 * sampleRate).round());
  return out;
}

Float32List _crossStick(int sampleRate, math.Random random) {
  final out = Float32List((0.08 * sampleRate).round());
  final filter = _HighPass(2500, sampleRate);
  for (var n = 0; n < out.length; n++) {
    final t = n / sampleRate;
    final wood =
        0.6 * math.sin(2 * math.pi * 1650 * t) +
        0.4 * math.sin(2 * math.pi * 930 * t);
    out[n] =
        wood * math.exp(-t / 0.018) +
        0.7 *
            filter.process(random.nextDouble() * 2 - 1) *
            math.exp(-t / 0.006);
  }
  return out;
}

// ── Room reverb ──────────────────────────────────────────────────────────

/// Adds a small-room reverb to [buffer] in place.
///
/// The loop (everything from [loopStart]) is treated as circular: the reverb
/// is first "warmed up" on the end of the loop, so the tail of the last beat
/// carries seamlessly into the first when playback jumps back.
void addRoomReverb(
  Float32List buffer,
  int loopStart,
  int sampleRate, {
  required double wet,
}) {
  if (wet <= 0 || buffer.isEmpty) return;
  final dry = Float32List.fromList(buffer);

  _Reverb countInRoom() => _Reverb(sampleRate);
  if (loopStart > 0) {
    final room = countInRoom();
    for (var n = 0; n < loopStart; n++) {
      buffer[n] = dry[n] + wet * room.process(dry[n]);
    }
  }

  final loopLength = buffer.length - loopStart;
  if (loopLength <= 0) return;
  final room = _Reverb(sampleRate);
  final warmUp = math.min(loopLength, (2.5 * sampleRate).round());
  for (var n = buffer.length - warmUp; n < buffer.length; n++) {
    room.process(dry[n]);
  }
  for (var n = loopStart; n < buffer.length; n++) {
    buffer[n] = dry[n] + wet * room.process(dry[n]);
  }
}

class _Reverb {
  _Reverb(int sampleRate)
    : _combs = [
        for (final d in const [1116, 1188, 1277, 1356])
          _Comb((d * sampleRate / 44100).round()),
      ],
      _allPasses = [
        for (final d in const [556, 441])
          _AllPass((d * sampleRate / 44100).round()),
      ];

  final List<_Comb> _combs;
  final List<_AllPass> _allPasses;

  double process(double input) {
    var out = 0.0;
    for (final comb in _combs) {
      out += comb.process(input * 0.25);
    }
    for (final allPass in _allPasses) {
      out = allPass.process(out);
    }
    return out;
  }
}

class _Comb {
  _Comb(int length) : _buffer = Float64List(length);
  final Float64List _buffer;
  int _index = 0;
  double _store = 0;

  double process(double input) {
    final out = _buffer[_index];
    _store = out * 0.7 + _store * 0.3; // damping: highs decay faster
    _buffer[_index] = input + _store * 0.8; // feedback: room size
    _index = (_index + 1) % _buffer.length;
    return out;
  }
}

class _AllPass {
  _AllPass(int length) : _buffer = Float64List(length);
  final Float64List _buffer;
  int _index = 0;

  double process(double input) {
    final delayed = _buffer[_index];
    _buffer[_index] = input + delayed * 0.5;
    _index = (_index + 1) % _buffer.length;
    return delayed - input;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

class _HighPass {
  _HighPass(double cutoff, int sampleRate)
    : _a = 1 / (1 + 2 * math.pi * cutoff / sampleRate);
  final double _a;
  double _lastIn = 0;
  double _lastOut = 0;

  double process(double input) {
    _lastOut = _a * (_lastOut + input - _lastIn);
    _lastIn = input;
    return _lastOut;
  }
}

void _fadeIn(Float32List samples, int count) {
  for (var i = 0; i < count && i < samples.length; i++) {
    samples[i] *= i / count;
  }
}

/// Takes the last [count] samples down to nothing.
///
/// An exponential decay never actually reaches zero, so a sound cut at
/// the end of its buffer ends on a step, which is a click. This ends it
/// on silence instead.
void _fadeOut(Float32List samples, int count) {
  final from = math.max(0, samples.length - count);
  for (var i = from; i < samples.length; i++) {
    samples[i] *= (samples.length - i) / (samples.length - from);
  }
}

/// Lifts everything above [hertz] by [gain] (1.0 ≈ +6 dB), leaving the low
/// end alone: a presence boost.
///
/// It works by subtracting a one-pole low-passed copy to get the high end,
/// then adding that back in. Small speakers and earbuds can't reproduce a
/// bass's fundamental at all, so this is what makes the notes audible there.
void addPresence(
  Float32List buffer,
  int sampleRate, {
  required double hertz,
  required double gain,
}) {
  final a = 1 - math.exp(-2 * math.pi * hertz / sampleRate);
  var low = 0.0;
  for (var i = 0; i < buffer.length; i++) {
    low += a * (buffer[i] - low);
    buffer[i] += gain * (buffer[i] - low);
  }
}

/// Takes out what's below [hertz]: rumble a small speaker can't play, which
/// would otherwise use up the headroom.
void cutLows(Float32List buffer, int sampleRate, {required double hertz}) {
  final a = 1 - math.exp(-2 * math.pi * hertz / sampleRate);
  var low = 0.0;
  for (var i = 0; i < buffer.length; i++) {
    low += a * (buffer[i] - low);
    buffer[i] -= low;
  }
}

/// Rounds off the peaks, like a bass amp pushed a little: [drive] is how
/// hard (1 barely touches it; 3 is a warm, even growl). Quiet detail comes
/// up, the attack no longer spikes, and the rounding adds overtones for a
/// presence boost to bring out. The result peaks at 1.
void saturate(Float32List buffer, {required double drive}) {
  final peak = buffer.fold(0.0, (a, b) => math.max(a, b.abs()));
  if (peak == 0) return;
  double tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  final top = tanh(drive);
  for (var i = 0; i < buffer.length; i++) {
    buffer[i] = tanh(drive * buffer[i] / peak) / top;
  }
}

// ── A chiptune kit ───────────────────────────────────────────────────────
//
// The drums of an eight-bit console, made the way that console made them,
// because it had no drum samples to play. Super Mario Bros. played its
// drums on the noise channel, and that is what this kit is.
//
// What makes it sound like a console and not like a drum is two things,
// and an earlier version of this kit got both of them wrong by building
// chip drums out of a real drum's habits:
//
//  • The volume is four bits, nought to fifteen, and it is set once a
//    frame, sixty times a second. A drum is a short list of those
//    numbers counting down, a handful of frames long. That is the whole
//    envelope: it steps, it does not glide, and it stops dead when the
//    list runs out. A smooth exponential tail is a real drum's, and it
//    is what made this one ring.
//  • There are no cymbals. A console has a noise generator and nothing
//    else that hisses, so the ride is a hi-hat like the others, and the
//    kit is never put in a room.
//
// The volume lists and pitches below are a real game's noise
// instruments, written out in tracker form: see tool/groove_sources.txt.

/// Frames a second: the rate the console's music driver sets volumes at.
const _frames = 60;

/// The noise generator's period at each of its sixteen pitches, in
/// cycles of the console's clock, highest pitch first.
const _noisePeriods = [
  4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, //
  4068,
];

/// The console's clock, NTSC, in hertz.
const _cpuHz = 1789773;

/// The noise generator: a fifteen-bit linear feedback shift register, as
/// the console has, rather than a random number source.
class _Noise {
  int _register = 1;

  /// The next bit: on or off, nothing between, as the console's is.
  bool next() {
    final feedback = (_register & 1) ^ ((_register >> 1) & 1);
    _register = (_register >> 1) | (feedback << 14);
    return (_register & 1) == 1;
  }
}

/// A noise drum: [volumes] set one a frame, the generator at [pitch].
///
/// [pitch] is the tracker's, nought to fifteen with fifteen highest; the
/// generator steps at the clock divided by that pitch's period, and the
/// output holds each bit until the next step, as the hardware does.
Float32List _noiseDrum(
  int sampleRate, {
  required List<int> volumes,
  required int pitch,
  double gain = 1,
}) {
  final perFrame = sampleRate ~/ _frames;
  final out = Float32List(perFrame * volumes.length);
  final stepsPerSample = _cpuHz / _noisePeriods[15 - pitch] / sampleRate;
  final noise = _Noise();
  var bit = noise.next();
  var due = 0.0;
  for (var i = 0; i < out.length; i++) {
    due += stepsPerSample;
    while (due >= 1) {
      bit = noise.next();
      due -= 1;
    }
    final volume = volumes[i ~/ perFrame] / 15;
    out[i] = (bit ? 1.0 : -1.0) * volume * gain;
  }
  return out;
}

/// A triangle note held for [frameCount] frames, falling from [from] to
/// [to] hertz a frame at a time: the console's tom.
///
/// The triangle has no volume of its own, only on and off, so a tom made
/// from it is a length and a pitch and nothing else. Sixteen steps to
/// the wave, as the chip's counter gives it.
Float32List _triangleDrop(
  int sampleRate, {
  required double from,
  required double to,
  required int frameCount,
  double gain = 1,
}) {
  final perFrame = sampleRate ~/ _frames;
  final out = Float32List(perFrame * frameCount);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    final frame = i ~/ perFrame;
    final hertz = from + (to - from) * frame / math.max(frameCount - 1, 1);
    phase = (phase + hertz / sampleRate) % 1;
    final triangle = 1 - 4 * (phase - 0.5).abs();
    out[i] = (triangle * 8).round() / 8 * gain;
  }
  // The one smoothing the hardware has: it does not jump from a peak to
  // silence, because the wave is wherever it is when the note stops. A
  // millisecond each end does the same job here.
  _fadeIn(out, (0.001 * sampleRate).round());
  _fadeOut(out, (0.001 * sampleRate).round());
  return out;
}

/// A square blip on one of the pulse channels: [volumes] a frame at a
/// time, at [hertz], with the wave high for [duty] of each cycle.
Float32List _pulseBlip(
  int sampleRate, {
  required List<int> volumes,
  required double hertz,
  double duty = 0.125,
  double gain = 1,
}) {
  final perFrame = sampleRate ~/ _frames;
  final out = Float32List(perFrame * volumes.length);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    phase = (phase + hertz / sampleRate) % 1;
    final volume = volumes[i ~/ perFrame] / 15;
    out[i] = (phase < duty ? 1.0 : -1.0) * volume * gain;
  }
  return out;
}

/// The kit of an eight-bit console, drum by drum.
///
/// One sound each rather than layers: a console had one noise channel,
/// and what varies between a quiet hit and a loud one there is the
/// volume column, which is what the band's velocity already is.
class ChiptuneKit {
  ChiptuneKit(int sampleRate)
    : kick = _noiseDrum(
        sampleRate,
        volumes: const [10, 7, 4, 3, 2, 0],
        pitch: 9,
        gain: _level,
      ),
      snare = _noiseDrum(
        sampleRate,
        volumes: const [11, 9, 8, 7, 6, 4, 3, 2, 1, 0],
        pitch: 7,
        gain: _level,
      ),
      hiHatClosed = _noiseDrum(
        sampleRate,
        volumes: const [4, 3, 2, 1, 0],
        pitch: 12,
        gain: _level,
      ),
      // The ride is the loose hat: a console has no cymbal to give it.
      ride = _noiseDrum(
        sampleRate,
        volumes: const [7, 5, 4, 2, 2, 1, 0],
        pitch: 12,
        gain: _level,
      ),
      hiHatOpen = _noiseDrum(
        sampleRate,
        volumes: const [6, 5, 4, 4, 4, 4, 4, 4, 3, 2, 1, 0],
        pitch: 12,
        gain: _level,
      ),
      // The foot: the closed hat, a step quieter.
      hiHatPedal = _noiseDrum(
        sampleRate,
        volumes: const [3, 2, 1, 0],
        pitch: 12,
        gain: _level,
      ),
      // A tick at the snare's pitch, as short as the closed hat.
      crossStick = _noiseDrum(
        sampleRate,
        volumes: const [6, 3, 1, 0],
        pitch: 7,
        gain: _level,
      ),
      tomHigh = _triangleDrop(
        sampleRate,
        from: 330,
        to: 165,
        frameCount: 5,
        gain: _level * 0.6,
      ),
      tomLow = _triangleDrop(
        sampleRate,
        from: 220,
        to: 110,
        frameCount: 6,
        gain: _level * 0.6,
      ),
      cowbell = _pulseBlip(
        sampleRate,
        volumes: const [8, 6, 4, 2, 0],
        hertz: 800,
        gain: _level * 0.6,
      );

  /// How loud the kit is against the band. The volumes above are the
  /// console's own, out of fifteen; this is the one number that sits the
  /// whole kit in the mix.
  static const _level = 0.9;

  final Float32List kick;
  final Float32List snare;
  final Float32List hiHatClosed;
  final Float32List ride;
  final Float32List hiHatOpen;
  final Float32List hiHatPedal;
  final Float32List crossStick;
  final Float32List tomHigh;
  final Float32List tomLow;
  final Float32List cowbell;

  /// What this kit plays for [drum], or null where it has nothing: the
  /// swirl, which is a brush dragged across a head and is not a sound a
  /// console can make.
  Float32List? of(Drum drum) => switch (drum) {
    Drum.ride => ride,
    Drum.hiHatClosed => hiHatClosed,
    Drum.hiHatOpen => hiHatOpen,
    Drum.hiHatPedal => hiHatPedal,
    Drum.snare => snare,
    Drum.kick => kick,
    Drum.tomHigh => tomHigh,
    Drum.tomLow => tomLow,
    Drum.crossStick => crossStick,
    Drum.cowbell => cowbell,
    Drum.swirl => null,
  };
}
