// The band's own audio, rendered and roughed up, for testing the ear:
// the whole band or some of it, under a soloist, in a room, with noise.
// Shared by the tests of the follower and of finding the tempo.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/chart_follower.dart';

/// A band's track, how long a beat is in it, and how many beats of
/// count-in silence come first.
typedef BandTrack = ({Float32List audio, int samplesPerBeat, int countInBeats});

Tune standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// The whole band on one track, from the top of the tune, and how long a
/// beat is in it.
BandTrack renderBand(
  SampleBank bank,
  Tune tune,
  int tempo, {
  int seed = 1,
  Set<Instrument>? only,
}) {
  final backing = renderBacking(
    BackingRequest(
      tune: tune,
      loop: LoopRange.wholeTune(tune),
      tempo: tempo,
      samples: bank,
      seed: seed,
    ),
  );
  Float32List? mix;
  for (final MapEntry(key: who, value: stem) in backing.stems.entries) {
    final wav = readWav(stem);
    if (only != null && !only.contains(who)) {
      mix ??= Float32List(wav.frames);
      continue;
    }
    final frames = wav.frames;
    mix ??= Float32List(frames);
    for (var i = 0; i < math.min(frames, mix.length); i++) {
      var sum = 0.0;
      for (var c = 0; c < wav.channels; c++) {
        sum += wav.samples[i * wav.channels + c];
      }
      mix[i] += sum / wav.channels;
    }
  }
  // The stems wrap the end of the performance's ringing tail round to
  // their start, for looping, which leaves the end of the tune sounding
  // in the count-in's bar. A band starting from the top has silence
  // before it, so that is what goes there.
  mix!.fillRange(0, backing.countInBeats * backing.samplesPerBeat, 0);
  return (
    audio: mix,
    samplesPerBeat: backing.samplesPerBeat,
    countInBeats: backing.countInBeats,
  );
}

/// Feeds [audio] to [follower] in small pieces, as a microphone would.
/// Feeds [audio] to [hear] in small pieces, as a microphone would.
void feed(void Function(Float32List) hear, Float32List audio) {
  const piece = 2048;
  for (var at = 0; at < audio.length; at += piece) {
    hear(
      Float32List.sublistView(audio, at, math.min(at + piece, audio.length)),
    );
  }
}

/// How many of the beats heard after [settle] seconds put the follower on
/// the bar the band was actually playing.
///
/// The track starts with the count-in's bar of silence (the clicks are
/// not in it), so the tune's first beat is that many beats in.
double onTheBar(
  Tune tune,
  List<FollowedPosition> beats,
  BandTrack band, {
  double settle = 0,
}) {
  var right = 0;
  var counted = 0;
  final total = tune.totalBeats;
  final beatsPerBar = tune.beatsPerBar;
  for (final heard in beats) {
    if (heard.at < settle) continue;
    final actual =
        ((heard.at * 44100 / band.samplesPerBeat).round() - band.countInBeats) %
        total;
    counted++;
    if (actual ~/ beatsPerBar == heard.bar) right++;
  }
  return counted == 0 ? 0 : right / counted;
}

/// How many times the follower moved more than two beats from where
/// counting on from its last beat would have put it: a leap to some other
/// place in the tune, which is what it must not do once it knows where
/// it is.
int leaps(Tune tune, List<FollowedPosition> beats, {double after = 0}) {
  final total = tune.totalBeats;
  var leaps = 0;
  int? last;
  for (final heard in beats) {
    if (heard.at < after) continue;
    if (last != null) {
      var off = (heard.beat - (last + 1)) % total;
      if (off > total ~/ 2) off -= total;
      if (off.abs() > 2) leaps++;
    }
    last = heard.beat;
  }
  return leaps;
}

/// A soloist over the band: swung eighths of any note at all, chromatic
/// and outside the chords as often as in, as loud as the band. Harder
/// than a real soloist, who plays the changes most of the time.
Float32List withASoloist(Float32List band, int samplesPerBeat, int from) {
  final out = Float32List.fromList(band);
  final random = math.Random(11);
  var peak = 0.0;
  for (final sample in band) {
    peak = math.max(peak, sample.abs());
  }
  var at = from;
  var long = true;
  while (at < out.length) {
    final length = (samplesPerBeat * (long ? 2 / 3 : 1 / 3)).round();
    long = !long;
    if (random.nextDouble() < 0.85) {
      final pitch = 60 + random.nextInt(24);
      final hz = 440 * math.pow(2, (pitch - 69) / 12);
      for (var i = 0; i < length && at + i < out.length; i++) {
        final t = i / 44100;
        final envelope = math.min(1, i / 400) * math.exp(-t * 3);
        var tone = 0.0;
        for (var h = 1; h <= 6; h++) {
          tone += math.sin(2 * math.pi * hz * h * t) / h;
        }
        out[at + i] += tone * envelope * peak * 0.35;
      }
    }
    at += length;
  }
  return out;
}

/// A room round it: a plain reverb of the old kind, four echoes feeding
/// back and two smearing, a second and more of tail.
Float32List inARoom(Float32List dry) {
  final wet = Float32List(dry.length);
  for (final (delay, feedback) in [
    (1557, 0.84),
    (1617, 0.83),
    (1491, 0.85),
    (1422, 0.84),
  ]) {
    final line = Float32List(delay);
    var at = 0;
    for (var i = 0; i < dry.length; i++) {
      final out = line[at];
      line[at] = dry[i] + out * feedback;
      wet[i] += out * 0.25;
      at = (at + 1) % delay;
    }
  }
  for (final delay in [225, 556]) {
    final line = Float32List(delay);
    var at = 0;
    for (var i = 0; i < wet.length; i++) {
      final buffered = line[at];
      final input = wet[i];
      final out = -input + buffered;
      line[at] = input + buffered * 0.5;
      wet[i] = out;
      at = (at + 1) % delay;
    }
  }
  return Float32List.fromList([
    for (var i = 0; i < dry.length; i++) dry[i] * 0.7 + wet[i] * 0.5,
  ]);
}

/// The samples of a WAV as one channel.
Float32List readWavSamples(List<int> bytes) {
  final wav = readWav(Uint8List.fromList(bytes));
  final mono = Float32List(wav.frames);
  for (var i = 0; i < wav.frames; i++) {
    var sum = 0.0;
    for (var c = 0; c < wav.channels; c++) {
      sum += wav.samples[i * wav.channels + c];
    }
    mono[i] = sum / wav.channels;
  }
  return mono;
}
