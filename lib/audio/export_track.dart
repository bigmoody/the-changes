// Writing the band out as an audio file.
//
// The band is generated a batch at a time so it can be streamed without ever
// repeating; an export is the same thing run to the end rather than as far
// as the next minute, with the instruments summed into one track instead of
// kept apart for the mixer.
//
// A take can be laid over the top, which gives you what you played with the
// band around it as a single file: the thing you'd send someone.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/loop_range.dart';
import '../music/tune.dart';
import 'backing_synth.dart';
import 'sample_bank.dart';

/// The most an export may run to, so a mistyped chorus count can't fill the
/// phone: about twenty minutes.
const _longest = 20 * 60;

/// How many beats of the band fit into [time], allowing for a tempo ramp
/// making the later ones shorter.
int beatsIn(BackingRequest request, Duration time) {
  var left = time.inMicroseconds * request.sampleRate / 1000000;
  // The intro is played once, before any of these.
  left -= _introSamples(request);
  final perChorus = request.loop.lengthBeats;
  var beats = 0;
  var chorus = 0;
  while (left > 0 && chorus < 500) {
    final perBeat = samplesPerBeatFor(request, chorus);
    for (var i = 0; i < perChorus && left > 0; i++) {
      left -= perBeat;
      beats++;
    }
    chorus++;
  }
  return beats;
}

/// Where the band should stop once somebody has played [beats] of it: the
/// end of the section they finished in, so the band lands on a rehearsal
/// letter rather than being cut off mid-phrase. A chart with no sections
/// finishes the chorus.
int finishSectionAfter(Tune tune, LoopRange loop, int beats) {
  final perChorus = loop.lengthBeats;
  if (beats <= 0) return perChorus;
  final chorus = beats ~/ perChorus;
  final within = beats % perChorus;
  if (within == 0) return beats;

  // The section starts inside the loop, counted from where the loop does.
  var finish = perChorus;
  for (final bar in tune.sections.keys) {
    final at = bar * tune.beatsPerBar - loop.startBeat;
    // At the letter counts as having finished the section, not as needing
    // another one.
    if (at >= within && at < finish) finish = at;
  }
  return chorus * perChorus + finish;
}

/// The sample [beat] falls on, counting the count-in if there is one.
int samplesAtBeat(BackingRequest request, int beat, {bool withCountIn = true}) {
  final perChorus = request.loop.lengthBeats;
  var samples =
      (withCountIn
          ? request.countInBars *
                request.tune.beatsPerBar *
                samplesPerBeatFor(request, 0)
          : 0) +
      _introSamples(request);
  var left = beat;
  var chorus = 0;
  while (left > 0) {
    final perBeat = samplesPerBeatFor(request, chorus);
    final take = math.min(left, perChorus);
    samples += take * perBeat;
    left -= take;
    chorus++;
  }
  return samples;
}

/// Renders [request] right through to the end of its arrangement and
/// returns it as a WAV.
///
/// The arrangement must say how many choruses; an export of something that
/// keeps going for ever is not a file.
///
/// With [take] (raw 16-bit samples from a recording), your playing is
/// mixed in [takeLeadIn] seconds from its own start, which is where the
/// band came in when it was recorded.
Uint8List exportTrack(
  BackingRequest request, {
  bool withCountIn = true,
  Int16List? take,
  double takeLeadIn = 0,
  double takeLevel = 1,
  int? endBeat,
}) {
  final choruses = request.arrangement.choruses;
  if (choruses == null || choruses < 1) {
    throw ArgumentError('An export needs a number of choruses');
  }
  final rate = request.sampleRate;
  final perBeat = samplesPerBeatFor(request, 0);
  final countIn = withCountIn ? request.countInBars : 0;

  // Two tracks, because the band is in stereo. The parts are placed the
  // way the player places them, with the same law the engine uses:
  // SoLoud's own pan is cos and sin of the angle, so a centred part is
  // 0.707 in each channel and the two agree note for note. An export that
  // was a mono sum of a stereo band would not be the thing anybody heard.
  final left = <double>[];
  final right = <double>[];
  void put(int at, double value, {double pan = 0}) {
    while (left.length <= at) {
      left.add(0);
      right.add(0);
    }
    final gains = panGains(pan);
    left[at] += value * gains.left;
    right[at] += value * gains.right;
  }

  final first = renderBacking(
    BackingRequest(
      tune: request.tune,
      loop: request.loop,
      tempo: request.tempo,
      countInBars: countIn,
      sampleRate: rate,
      seed: request.seed,
      samples: request.samples,
      comping: request.comping,
      bassSound: request.bassSound,
      drumSound: request.drumSound,
      arpeggios: request.arpeggios,
      arpeggioSound: request.arpeggioSound,
      arpeggioStart: request.arpeggioStart,
      arrangement: request.arrangement,
    ),
  );

  var at = 0;
  void addBatch(BackingBatch batch) {
    var longest = 0;
    for (final entry in batch.pcm.entries) {
      final samples = Int16List.sublistView(entry.value);
      longest = math.max(longest, samples.length);
      for (var i = 0; i < samples.length; i++) {
        put(at + i, samples[i] / 32768, pan: entry.key.pan);
      }
    }
    if (withCountIn) {
      final clicks = Int16List.sublistView(batch.clicks);
      for (var i = 0; i < clicks.length; i++) {
        put(at + i, clicks[i] / 32768);
      }
    }
    at += longest;
  }

  addBatch(first.batch);
  var state = first.batch.state;
  var tails = first.batch.tails;
  for (var index = 1; chorusesIn(request, index) > 0; index++) {
    if (at > _longest * rate) break;
    final batch = renderBatch(
      request,
      batch: index,
      gain: first.gain,
      state: state,
      carryIn: tails,
    );
    addBatch(batch);
    state = batch.state;
    tails = batch.tails;
  }

  // Let the last chord ring rather than stopping on it.
  for (final entry in tails.entries) {
    final tail = entry.value;
    for (var i = 0; i < tail.length; i++) {
      put(at + i, tail[i] * first.gain, pan: entry.key.pan);
    }
  }

  if (take != null) {
    // The recording starts before the band does; the band's first beat is
    // [takeLeadIn] into it, and lands here after the count-in.
    final from = (takeLeadIn * rate).round();
    final start = countIn * request.tune.beatsPerBar * perBeat;
    for (var i = from; i < take.length; i++) {
      put(start + i - from, take[i] / 32768 * takeLevel);
    }
  }

  // Stop where asked, letting what's ringing fade rather than cutting it
  // off with a click.
  if (endBeat != null) {
    final end = samplesAtBeat(request, endBeat, withCountIn: withCountIn);
    final fade = (0.4 * rate).round();
    for (final channel in [left, right]) {
      if (end + fade < channel.length) {
        channel.removeRange(end + fade, channel.length);
      }
      for (var i = 0; i < fade && end + i < channel.length; i++) {
        channel[end + i] *= 1 - i / fade;
      }
    }
  }

  // Nothing is allowed to clip: if the sum went over, the whole thing comes
  // down together rather than the peaks being squared off.
  // Across both channels together, so the balance between them is not
  // changed by one of them being the louder.
  var peak = 0.0;
  for (final channel in [left, right]) {
    for (final sample in channel) {
      peak = math.max(peak, sample.abs());
    }
  }
  final scale = peak > 0.99 ? 0.99 / peak : 1.0;

  // Interleaved, a frame at a time.
  final frames = Int16List(left.length * 2);
  for (var i = 0; i < left.length; i++) {
    frames[i * 2] = (left[i] * scale * 32767).round().clamp(-32768, 32767);
    frames[i * 2 + 1] = (right[i] * scale * 32767).round().clamp(-32768, 32767);
  }
  return wavOf(frames, rate, channels: 2);
}

/// How long [request]'s arrangement would run for, near enough to warn
/// somebody before they wait for it.
Duration exportLength(BackingRequest request) {
  final choruses = request.arrangement.choruses ?? 0;
  var samples =
      request.countInBars *
          request.tune.beatsPerBar *
          samplesPerBeatFor(request, 0) +
      _introSamples(request);
  for (var chorus = 0; chorus < choruses; chorus++) {
    samples += request.loop.lengthBeats * samplesPerBeatFor(request, chorus);
  }
  return Duration(milliseconds: samples * 1000 ~/ request.sampleRate);
}

/// How long the intro lasts, played once before the loop, where there is
/// one (see BackingRequest.intro).
int _introSamples(BackingRequest request) =>
    (request.intro?.lengthBeats ?? 0) * samplesPerBeatFor(request, 0);
