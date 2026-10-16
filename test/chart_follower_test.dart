// Following a chart by ear, tested on the app's own band.
//
// The band is rendered with its real samples, mixed down to one track the
// way a microphone would hear it, and fed to the follower a few
// milliseconds at a time. Where the band actually was at every moment is
// known exactly, so how often the follower agrees is a number.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/chart_follower.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// The whole band on one track, from the top of the tune, and how long a
/// beat is in it.
({Float32List audio, int samplesPerBeat, int countInBeats}) _band(
  SampleBank bank,
  Tune tune,
  int tempo, {
  int seed = 1,
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
  for (final stem in backing.stems.values) {
    final wav = readWav(stem);
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
void _feed(ChartFollower follower, Float32List audio, {int from = 0}) {
  const piece = 2048;
  for (var at = from; at < audio.length; at += piece) {
    follower.hear(
      Float32List.sublistView(audio, at, math.min(at + piece, audio.length)),
    );
  }
}

/// How many of the beats heard after [settle] seconds put the follower on
/// the bar the band was actually playing.
///
/// The track starts with the count-in's bar of silence (the clicks are
/// not in it), so the tune's first beat is that many beats in.
double _onTheBar(
  ChartFollower follower,
  ({Float32List audio, int samplesPerBeat, int countInBeats}) band, {
  double settle = 0,
}) {
  var right = 0;
  var counted = 0;
  final total = follower.tune.totalBeats;
  final beatsPerBar = follower.tune.beatsPerBar;
  for (final heard in follower.heardBeats) {
    if (heard.at < settle) continue;
    final actual =
        ((heard.at * 44100 / band.samplesPerBeat).round() - band.countInBeats) %
        total;
    counted++;
    if (actual ~/ beatsPerBar == heard.bar) right++;
  }
  return counted == 0 ? 0 : right / counted;
}

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  for (final (title, tempo) in [
    ('Autumn Leaves', 140),
    ('Blue Bossa', 150),
    ('Cherokee', 200),
  ]) {
    test('follows $title from the top, at the tempo it was told', () {
      final tune = _standard(title);
      final band = _band(bank, tune, tempo);
      final follower = ChartFollower(tune: tune, tempo: tempo.toDouble());
      _feed(follower, band.audio);
      final share = _onTheBar(follower, band, settle: 4);
      // ignore: avoid_print
      print(
        '$title: ${(share * 100).toStringAsFixed(1)}% on the bar, '
        'tempo heard ${follower.position?.tempo.toStringAsFixed(1)}',
      );
      expect(share, greaterThan(0.9));
    });
  }

  test('finds the tempo when the band is not at the one it was told', () {
    // The record is faster than the chart says, which records usually
    // are: the follower is told 160 and the band plays 176.
    final tune = _standard('Autumn Leaves');
    final band = _band(bank, tune, 176);
    final follower = ChartFollower(tune: tune, tempo: 160);
    _feed(follower, band.audio);
    final share = _onTheBar(follower, band, settle: 8);
    // ignore: avoid_print
    print(
      'Told 160, played 176: ${(share * 100).toStringAsFixed(1)}%, '
      'tempo heard ${follower.position?.tempo.toStringAsFixed(1)}',
    );
    expect(follower.position!.tempo, closeTo(176, 3));
    expect(share, greaterThan(0.85));
  });

  test('finds its place when it starts in the middle', () {
    // Nobody told it where: it comes in at bar 9 of Blue Bossa knowing
    // nothing, and has only the chords to go on.
    final tune = _standard('Blue Bossa');
    final band = _band(bank, tune, 150);
    final follower = ChartFollower(tune: tune, tempo: 150, fromTheTop: false);
    final from =
        (band.countInBeats + 8 * tune.beatsPerBar) * band.samplesPerBeat;
    _feed(follower, Float32List.sublistView(band.audio, from));
    // The beats it reports are timed from where it started listening.
    final offset = from / 44100;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      // Two times round the eight bars it can tell apart before it is
      // held to it.
      if (heard.at < 16 * 60 / 150 * 4 / 4 * 2) continue;
      final actual =
          (((heard.at + offset) * 44100 / band.samplesPerBeat).round() -
              band.countInBeats) %
          tune.totalBeats;
      counted++;
      if (actual ~/ 4 == heard.bar) right++;
    }
    final share = right / counted;
    // ignore: avoid_print
    print('From the middle: ${(share * 100).toStringAsFixed(1)}%');
    expect(share, greaterThan(0.85));
  });

  for (final (loudness, needs) in [(0.1, 0.85), (0.2, 0.0)]) {
    test('keeps its place with a noisy room over the band ($loudness)', () {
      final tune = _standard('Autumn Leaves');
      final band = _band(bank, tune, 140);
      final random = math.Random(7);
      var peak = 0.0;
      for (final sample in band.audio) {
        peak = math.max(peak, sample.abs());
      }
      final noisy = Float32List(band.audio.length);
      for (var i = 0; i < noisy.length; i++) {
        // Hiss at a tenth of the band's peak is a loud room: a fan, a
        // crowd talking. A fifth is as loud as the band itself, and is
        // only here to say how it does, not to hold it to anything.
        noisy[i] =
            band.audio[i] + (random.nextDouble() * 2 - 1) * peak * loudness;
      }
      final follower = ChartFollower(tune: tune, tempo: 140);
      _feed(follower, noisy);
      final share = _onTheBar(follower, band, settle: 4);
      // ignore: avoid_print
      print('Noise at $loudness: ${(share * 100).toStringAsFixed(1)}%');
      expect(share, greaterThan(needs));
    });
  }

  // Harder for the count: a slow ballad on brushes has soft attacks and
  // few of them, and a waltz counts three. Each played twice, by two
  // different performances, so nothing here is tuned to one take.
  for (final (name, tune, tempo, needs) in [
    (
      'a brushed ballad',
      _standard('Stella by Starlight').withStyle(BandStyle.of(Feel.ballad)),
      66,
      0.85,
    ),
    (
      'a jazz waltz',
      _standard('Days of Wine and Roses')
          .inMeter(const Meter(3, 4))
          .withStyle(BandStyle.of(Feel.jazzWaltz)),
      150,
      0.85,
    ),
  ]) {
    for (final seed in [2, 3]) {
      test('follows $name (performance $seed)', () {
        final band = _band(bank, tune, tempo, seed: seed);
        final follower = ChartFollower(tune: tune, tempo: tempo.toDouble());
        _feed(follower, band.audio);
        final share = _onTheBar(follower, band, settle: 6);
        // ignore: avoid_print
        print(
          '$name, performance $seed: '
          '${(share * 100).toStringAsFixed(1)}%, tempo heard '
          '${follower.position?.tempo.toStringAsFixed(1)}',
        );
        expect(share, greaterThan(needs));
      });
    }
  }
}
