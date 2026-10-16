// The count-in: a click for each of the bar's written beats.
//
// In a simple meter that is one a beat. In a compound one it is the
// eighths, all six of a bar of six eight, with the pulses louder:
// counting two is not counting a bar of six, and leaves you nothing to
// come in on.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

/// When each click starts, in seconds.
List<double> clicksIn(Uint8List wav) {
  final audio = readWav(wav);
  final rate = audio.sampleRate;
  final out = <double>[];
  var skipUntil = 0;
  for (var i = 0; i < audio.samples.length; i++) {
    if (i < skipUntil) continue;
    if (audio.samples[i].abs() > 0.02) {
      out.add(i / rate);
      // One click is a short tone with a tail; this is past the end of
      // it and well short of the next beat at any tempo played here.
      skipUntil = i + (rate * 0.05).round();
    }
  }
  return out;
}

List<double> countInFor(Meter meter, {int tempo = 120, int bars = 1}) {
  final tune = UserProgression(
    id: 'x',
    title: 'T',
    key: 'C',
    tempo: tempo,
    bars: const ['C', 'F', 'G', 'C'],
    style: BandStyle.of(Feel.swing),
    meter: meter,
  ).toTune();
  return clicksIn(
    renderBacking(
      BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: tempo,
        countInBars: bars,
      ),
    ).countIn,
  );
}

void main() {
  test('a bar of clicks is a bar of written beats, in any meter', () {
    for (final meter in Meter.choices) {
      final clicks = countInFor(meter);
      expect(
        clicks,
        hasLength(meter.beats),
        reason: 'a bar of $meter is ${meter.beats} written beats',
      );
      // Half a second a beat at 120, and in compound time a third of
      // that: the eighths of the bar, three to the pulse.
      final gap = 0.5 / meter.perPulse;
      for (final (i, at) in clicks.indexed) {
        expect(at, closeTo(i * gap, 0.01), reason: 'beat $i of $meter');
      }
    }
  });

  test('two bars is the count-off: the same bar, twice', () {
    // "One, two, one two three four", which in four is eight beats.
    final two = countInFor(Meter.four, bars: 2);
    expect(two, hasLength(8));
    for (final (i, at) in two.indexed) {
      expect(at, closeTo(i * 0.5, 0.01));
    }
    // And in six eight it is both bars' eighths, twelve of them.
    expect(countInFor(const Meter(6, 8), bars: 2), hasLength(12));
    expect(countInFor(Meter.four, bars: 0), isEmpty);
  });

  test('and it follows the tempo', () {
    final quick = countInFor(Meter.four, tempo: 240);
    expect(quick, hasLength(4));
    expect(quick.last, closeTo(3 * 0.25, 0.01));
  });
}
