// Drawing a recording down to a row of levels.
//
// The claim the picture makes is that a loud moment in the file is a
// tall column in the same place. Everything here is that claim: the
// attacks land where they happened, a quiet recording is still drawn
// full height, and nothing that cannot be read takes the screen down
// with it.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/waveform.dart';
import 'package:play_along/audio/wav_file.dart';

/// A mono recording of [seconds], silent but for a burst at each of
/// [spikes], given as a fraction of the way through.
WavAudio made({
  double seconds = 4,
  int rate = 1000,
  List<double> spikes = const [],
  double loudness = 1,
}) {
  final frames = (seconds * rate).round();
  final samples = Float32List(frames);
  for (final at in spikes) {
    final from = (frames * at).round();
    for (var i = from; i < from + rate ~/ 50 && i < frames; i++) {
      samples[i] = loudness;
    }
  }
  return WavAudio(sampleRate: rate, channels: 1, samples: samples);
}

/// Which column is tallest.
int loudestOf(List<double> peaks) {
  var best = 0;
  for (var i = 1; i < peaks.length; i++) {
    if (peaks[i] > peaks[best]) best = i;
  }
  return best;
}

void main() {
  group('where the notes are', () {
    test('a column for every slice, however long the recording', () {
      expect(peaksOf(made(seconds: 1)).length, waveformColumns);
      expect(peaksOf(made(seconds: 30)).length, waveformColumns);
      expect(peaksOf(made(), columns: 40).length, 40);
    });

    test('a note draws where it was played, not somewhere else', () {
      // The whole of the picture's usefulness. A spike a quarter of the
      // way through has to be a quarter of the way along.
      for (final at in [0.0, 0.25, 0.5, 0.75]) {
        final peaks = peaksOf(made(spikes: [at]), columns: 100);
        final drawn = loudestOf(peaks) / 100;
        expect(
          (drawn - at).abs(),
          lessThan(0.03),
          reason: 'a note at $at drew at $drawn',
        );
      }
    });

    test('two notes draw as two', () {
      final peaks = peaksOf(made(spikes: [0.2, 0.8]), columns: 100);
      expect(peaks[20], greaterThan(0.5));
      expect(peaks[80], greaterThan(0.5));
      // And the gap between them is a gap.
      expect(peaks.sublist(30, 70).reduce(max), lessThan(0.01));
    });

    test('a quiet recording is still drawn full height', () {
      // Played gently into the microphone it is still a phrase, and one
      // drawn as a flat line in the middle of the bar tells nobody
      // anything.
      final quiet = peaksOf(made(spikes: [0.5], loudness: 0.02));
      final loud = peaksOf(made(spikes: [0.5], loudness: 0.9));
      expect(quiet.reduce(max), closeTo(1, 0.0001));
      expect(loudestOf(quiet), loudestOf(loud));
    });

    test('everything it gives back is between nought and one', () {
      final peaks = peaksOf(made(spikes: [0.1, 0.4, 0.9], loudness: 0.6));
      for (final peak in peaks) {
        expect(peak, inInclusiveRange(0, 1));
      }
    });

    test('silence is a row of nothing rather than a crash', () {
      final peaks = peaksOf(made());
      expect(peaks.length, waveformColumns);
      expect(peaks.every((peak) => peak == 0), isTrue);
    });

    test('a recording with no frames draws nothing', () {
      final empty = WavAudio(
        sampleRate: 44100,
        channels: 1,
        samples: Float32List(0),
      );
      expect(peaksOf(empty), isEmpty);
    });

    test('a note on one side of a stereo file is not silence', () {
      // Looking at only the first channel would lose a phrase recorded
      // on the other one entirely.
      final samples = Float32List(2000);
      for (var i = 1000; i < 1040; i += 2) {
        samples[i + 1] = 0.9;
      }
      final peaks = peaksOf(
        WavAudio(sampleRate: 1000, channels: 2, samples: samples),
        columns: 50,
      );
      expect(peaks.reduce(max), greaterThan(0.5));
    });
  });

  group('reading the file', () {
    test('something that is not a WAV draws nothing, and does not throw', () {
      // The dragging is the feature and the picture is the help: a file
      // that will not decode should lose the drawing and nothing else.
      expect(peaksOfWav(Uint8List.fromList([1, 2, 3])), isEmpty);
      expect(peaksOfWav(Uint8List(0)), isEmpty);
    });
  });
}
