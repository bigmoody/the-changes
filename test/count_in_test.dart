// The count-in: one click a beat, whatever the bar is.
//
// It went wrong once, which is why this exists. A compound bar is
// counted in two, and two clicks tells you nothing about the bar that
// is coming, so the eighths were counted underneath it. What that
// actually did was click three times a beat, which at any tempo a tune
// is played at is a blur rather than a count, and the count-in stopped
// being something you could come in on.

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

List<double> countInFor(Meter meter, {int tempo = 120}) {
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
        countInBars: 1,
      ),
    ).countIn,
  );
}

void main() {
  test('a bar of clicks is a bar of beats, in any meter', () {
    for (final meter in Meter.choices) {
      final clicks = countInFor(meter);
      expect(
        clicks,
        hasLength(meter.pulses),
        reason: 'a bar of $meter is ${meter.pulses} beats',
      );
      // Half a second a beat at 120, and every click on one.
      for (final (i, at) in clicks.indexed) {
        expect(at, closeTo(i * 0.5, 0.01), reason: 'beat $i of $meter');
      }
    }
  });

  test('and it follows the tempo', () {
    final quick = countInFor(Meter.four, tempo: 240);
    expect(quick, hasLength(4));
    expect(quick.last, closeTo(3 * 0.25, 0.01));
  });
}
