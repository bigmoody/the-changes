// Finding the hits in a recording.
//
// The app needs to know when a drummer actually struck something, so it
// can be compared against when the click said to. There is no metadata
// for that: it has to come out of the audio.
//
// The method is spectral flux, which is the standard one and is standard
// because it is hard to beat. A hit is a moment when energy appears
// across many frequencies at once, so the spectrum is taken over and over
// down the recording and, each time, the rises are added up and the falls
// ignored. A ride cymbal struck is a large rise. The same cymbal decaying
// is a fall, and contributes nothing, which is why this finds beginnings
// rather than loud parts.
//
// The threshold moves with the music. A fixed one would find every hit in
// the loud choruses and none in the quiet ones, which would read as a
// drummer who played worse when playing softly.
//
// Everything is done on a mono mixdown at about a quarter of the sample
// rate. Nothing above five kilohertz says anything about when a hit
// began, and the whole thing is four times cheaper that way.

import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';
import 'wav_file.dart';

/// How far apart two hits must be to count as two, in seconds. Below this
/// they are the same stroke: a snare and the room answering it.
const _closest = 0.04;

/// Where the hits are in [audio], in seconds from its start.
///
/// [sensitivity] is how far above the local average a rise must be. Lower
/// finds more, including things that are not hits.
///
/// A hit in the first few milliseconds of the file is not found, because
/// a rise is measured against what came before it and there is nothing
/// before it. That is exactly where the template puts bar 1 beat 1, so
/// the first beat of a take is routinely missing. It does not matter:
/// what uses this has two hundred and eighty-seven others to go on.
List<double> findOnsets(
  WavAudio audio, {
  int window = 512,
  int hop = 64,
  double sensitivity = 1.6,
  int targetRate = 11025,
}) {
  final full = _mono(audio);
  final step = math.max(1, audio.sampleRate ~/ targetRate);
  final samples = _smallerBy(full, step);
  final rate = audio.sampleRate ~/ step;
  if (samples.length < window * 2) return const [];

  // The rise in energy at each step down the recording.
  final frames = (samples.length - window) ~/ hop;
  if (frames < 3) return const [];
  final flux = Float64List(frames);
  Float64List? before;
  for (var frame = 0; frame < frames; frame++) {
    final spectrum = magnitudeSpectrum(
      Float32List.sublistView(samples, frame * hop, frame * hop + window),
      size: window,
    );
    if (before != null) {
      var rise = 0.0;
      for (var bin = 0; bin < spectrum.length; bin++) {
        final change = spectrum[bin] - before[bin];
        if (change > 0) rise += change;
      }
      flux[frame] = rise;
    }
    before = spectrum;
  }

  // What counts as a rise here, rather than anywhere in the recording.
  // A tenth of a second either way, which is long enough to sit out a
  // fill and short enough to follow a change of dynamic.
  final span = math.max(3, (0.1 * rate / hop).round());
  final gap = math.max(1, (_closest * rate / hop).round());
  final onsets = <double>[];
  var last = -gap * 2;
  for (var frame = 1; frame < frames - 1; frame++) {
    final here = flux[frame];
    if (here <= 0) continue;
    // A peak, not a slope.
    if (here < flux[frame - 1] || here < flux[frame + 1]) continue;
    if (frame - last < gap) continue;
    if (here < _around(flux, frame, span) * sensitivity) continue;

    // Where the peak really is, between the two frames either side of it.
    // Without this every hit is rounded to the step, which at these
    // settings is six milliseconds of made-up error on every one.
    final left = flux[frame - 1];
    final right = flux[frame + 1];
    final bend = 2 * here - left - right;
    final nudge = bend == 0 ? 0.0 : (left - right) / (2 * bend);
    final about = _timeOf(frame + nudge.clamp(-0.5, 0.5), hop, window, rate);
    onsets.add(_attackNear(full, audio.sampleRate, about));
    last = frame;
  }
  return onsets;
}

/// When the frame at [frame] was sounding, near enough to go looking.
///
/// The middle of the window rather than its start, because a window is a
/// stretch of time and the rise it reports belongs to the middle of it.
/// This is only ever accurate to about half a step, which at these
/// settings is three milliseconds, and worse than that in a way that
/// depends on where the hit happened to fall between two steps. So it is
/// used to say which hit, and [_attackNear] is used to say when.
double _timeOf(double frame, int hop, int window, int rate) =>
    (frame * hop + window / 2) / rate;

/// How much of the recording either side of a rough onset is searched for
/// the real attack: twenty milliseconds, which is several steps of the
/// coarse pass and far less than the gap between two hits.
const _searchSeconds = 0.02;

/// How finely the attack is found, in samples. At 44.1 kHz this is about
/// a third of a millisecond, which is well under anything a person could
/// play or hear.
const _grain = 16;

/// Where the hit at about [about] really begins, from the full rate audio.
///
/// The coarse pass works on a quarter rate mixdown in steps of six
/// milliseconds, and rounds every hit to that grid in a way that wanders
/// with the phase of the hit against it. Left alone that is six
/// milliseconds of invented error on every stroke, which is a good
/// fraction of what a rhythm section's real scatter is, and it would read
/// as players who could not keep time.
///
/// So the moment itself is taken from the original samples: the loudest
/// rise in energy in the neighbourhood, at the grain above.
double _attackNear(Float32List mono, int rate, double about) {
  final blocks = mono.length ~/ _grain;
  final reach = (_searchSeconds * rate).round() ~/ _grain;
  final middle = (about * rate).round() ~/ _grain;
  final from = math.max(1, middle - reach);
  final to = math.min(blocks, middle + reach + 1);
  if (to - from < 2) return about;

  double energyAt(int block) {
    var total = 0.0;
    for (var i = block * _grain; i < (block + 1) * _grain; i++) {
      total += mono[i] * mono[i];
    }
    return total;
  }

  var best = -1;
  var steepest = 0.0;
  var before = energyAt(from - 1);
  for (var block = from; block < to; block++) {
    final here = energyAt(block);
    if (here - before > steepest) {
      steepest = here - before;
      best = block;
    }
    before = here;
  }
  // The attack starts at the top of the block that rose, not at its end.
  return best < 0 ? about : best * _grain / rate;
}

/// The average of [flux] within [span] frames of [at], which is what the
/// threshold follows.
double _around(Float64List flux, int at, int span) {
  final from = math.max(0, at - span);
  final to = math.min(flux.length, at + span + 1);
  var total = 0.0;
  for (var i = from; i < to; i++) {
    total += flux[i];
  }
  return total / (to - from);
}

/// [audio] summed to mono, at the rate it came in at.
Float32List _mono(WavAudio audio) {
  final channels = math.max(1, audio.channels);
  if (channels == 1) return audio.samples;
  final frames = audio.samples.length ~/ channels;
  final out = Float32List(frames);
  for (var frame = 0; frame < frames; frame++) {
    var total = 0.0;
    for (var channel = 0; channel < channels; channel++) {
      total += audio.samples[frame * channels + channel];
    }
    out[frame] = total / channels;
  }
  return out;
}

/// [mono] with every [step] samples averaged into one.
///
/// Averaging rather than dropping samples: a plain decimation folds the
/// cymbals down on top of the snare, and while that matters little for
/// finding beginnings, it costs nothing to do properly.
Float32List _smallerBy(Float32List mono, int step) {
  if (step <= 1) return mono;
  final out = Float32List(mono.length ~/ step);
  for (var i = 0; i < out.length; i++) {
    var total = 0.0;
    for (var taken = 0; taken < step; taken++) {
      total += mono[i * step + taken];
    }
    out[i] = total / step;
  }
  return out;
}
