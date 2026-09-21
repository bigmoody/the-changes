// The click under a snippet: where it falls, and that it is a click
// rather than a note.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/fft.dart';
import 'package:play_along/audio/sample_bank.dart';

Future<SampleBank> loadBank() =>
    SampleBank.load((path) async => File('assets/sounds/$path').readAsBytes());

/// A rim click at [at] seconds, as the exercises ask for one.
SnippetDrum click(double at, {bool accent = false}) => (
  at: at,
  drum: Drum.crossStick,
  velocity: accent ? 0.5 : 0.34,
  hard: accent,
);

/// The loudest sample in a window around [at] seconds.
int peakNear(List<int> samples, double at, {double window = 0.05}) {
  final from = math.max(0, ((at - window / 2) * 44100).round());
  final to = math.min(samples.length, ((at + window) * 44100).round());
  var peak = 0;
  for (var i = from; i < to; i++) {
    peak = math.max(peak, samples[i].abs());
  }
  return peak;
}

void main() {
  test('a snippet with no clicks has none', () async {
    final bank = await loadBank();
    final quiet = decodeWav(
      renderSnippet(bank, [
        (pitch: 60, start: 0, length: 0.4, velocity: 0.7, bass: false),
      ]),
    );
    final clicked = decodeWav(
      renderSnippet(
        bank,
        [(pitch: 60, start: 0, length: 0.4, velocity: 0.7, bass: false)],
        drums: [click(0.6)],
      ),
    );
    // Nothing at 0.6 s without a click there, something with one.
    expect(peakNear(quiet, 0.6), lessThan(peakNear(clicked, 0.6) ~/ 4));
  });

  test('clicks land where they are asked for', () async {
    final bank = await loadBank();
    final samples = decodeWav(
      renderSnippet(
        bank,
        const [],
        drums: [click(0, accent: true), click(0.5), click(1.0)],
      ),
    );
    for (final at in [0.0, 0.5, 1.0]) {
      expect(peakNear(samples, at), greaterThan(2000), reason: 'at $at');
    }
    // And not in the gaps between them.
    expect(peakNear(samples, 0.3, window: 0.1), lessThan(2000));
  });

  test('the downbeat click is the loudest', () async {
    final bank = await loadBank();
    final samples = decodeWav(
      renderSnippet(
        bank,
        const [],
        drums: [click(0, accent: true), click(0.5)],
      ),
    );
    expect(peakNear(samples, 0.0), greaterThan(peakNear(samples, 0.5)));
  });

  test('it is a click, not a note: no pitch to hear', () async {
    // A rim click has its energy spread across the spectrum; a metronome
    // tone piles it into one bin. Anything with a single strong partial
    // would be one more note under an exercise about placement.
    final bank = await loadBank();
    final rim = decodeWav(
      renderSnippet(bank, const [], drums: [click(0, accent: true)]),
    );
    final tone = decodeWav(metronomeLoop(tempo: 120, beatsPerBar: 1));
    final inClick = loudestShare(rim);
    final inTone = loudestShare(tone);
    expect(inTone, greaterThan(0.2), reason: 'the tone really is one pitch');
    expect(
      inClick,
      lessThan(inTone / 3),
      reason: 'click $inClick against tone $inTone',
    );
  });
}

/// How much of a sound's energy sits in its single loudest frequency.
///
/// Near one for a pure tone and small for anything broadband, which is
/// the plainest way to ask whether a sound has a pitch. Counting zero
/// crossings does not work here: the tone decays inside the window, and
/// the silence after it drags the count down to the click's.
double loudestShare(List<int> samples) {
  const size = 2048;
  final window = Float32List(size);
  for (var i = 0; i < size && i < samples.length; i++) {
    window[i] = samples[i] / 32768;
  }
  final spectrum = magnitudeSpectrum(window, size: size);
  var total = 0.0;
  var loudest = 0.0;
  for (final magnitude in spectrum) {
    final energy = magnitude * magnitude;
    total += energy;
    loudest = math.max(loudest, energy);
  }
  return total == 0 ? 0 : loudest / total;
}
