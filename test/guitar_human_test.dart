// Whether the guitarist sounds like a person.
//
// The rhythms are written with fixed velocities on exact beats, so before
// this the guitar struck the same beat of every bar at the same strength
// at the same instant, all chorus. That is audible as a machine, and it is
// measurable: the strokes land off the grid by different amounts and are
// struck with different force. These tests measure both, so the
// humanising cannot be lost in a refactor without something going red.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

/// Where each stroke begins, and how hard it was struck: a jump in level
/// after a quiet patch, and the loudest sample in the moment that follows.
List<({int at, double peak})> _strokes(List<double> samples) {
  const gap = 2000; // strokes are never this close together
  final out = <({int at, double peak})>[];
  var last = -gap;
  for (var i = 1; i < samples.length; i++) {
    if (samples[i].abs() > 0.04 && i - last >= gap) {
      var peak = 0.0;
      for (var j = i; j < math.min(i + 1500, samples.length); j++) {
        if (samples[j].abs() > peak) peak = samples[j].abs();
      }
      out.add((at: i, peak: peak));
      last = i;
    }
  }
  return out;
}

double _spread(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.fold(0.0, (sum, v) => sum + (v - mean) * (v - mean)) /
      values.length;
  return math.sqrt(variance) / mean;
}

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  /// A calypso tune, because its rhythm is written with six fixed
  /// velocities on exact beats: the worst case for sounding mechanical.
  List<double> guitarOf(int seed) {
    final tune = practiceProgressions.first.withStyle(
      const BandStyle(
        drums: Feel.calypso,
        bass: BassStyle.calypso,
        piano: PianoStyle.calypso,
      ),
    );
    final rendered = renderBacking(
      BackingRequest(
        tune: tune,
        loop: LoopRange.bars(tune, 0, 7),
        tempo: 130,
        seed: seed,
        samples: bank,
        countInBars: 0,
        comping: Comping.guitar,
      ),
    );
    return [
      for (final s in decodeWav(rendered.stems[Instrument.chords]!)) s / 32768,
    ];
  }

  test('the strokes are not all struck equally hard', () {
    final strokes = _strokes(guitarOf(11));
    expect(strokes.length, greaterThan(20), reason: 'nothing to measure');
    final spread = _spread([for (final s in strokes) s.peak]);
    expect(
      spread,
      greaterThan(0.12),
      reason: 'every stroke came out the same strength: $spread',
    );
  });

  test('the strokes do not all land in the same place in the bar', () {
    final strokes = _strokes(guitarOf(11));
    final beat = 44100 * 60 / 130;
    final sixteenth = beat / 4;
    // How far each stroke sits from the nearest sixteenth.
    final offsets = [
      for (final s in strokes) s.at - (s.at / sixteenth).round() * sixteenth,
    ];
    // Written on the grid, every one of these would be the same number:
    // the same lag through the attack of the same recording. What is
    // measured is that they differ, not where they are, because where the
    // ear hears a stroke start is not the sample a threshold crosses.
    final mean = offsets.reduce((a, b) => a + b) / offsets.length;
    final wander = math.sqrt(
      offsets.fold(0.0, (sum, o) => sum + (o - mean) * (o - mean)) /
          offsets.length,
    );
    expect(
      wander,
      greaterThan(44100 * 0.003),
      reason: 'every stroke sat at the same point in the bar',
    );
  });

  test('two performances of the same bars are not the same performance', () {
    final a = _strokes(guitarOf(3));
    final b = _strokes(guitarOf(9));
    final shared = math.min(a.length, b.length);
    expect(shared, greaterThan(10));
    var same = 0;
    for (var i = 0; i < shared; i++) {
      if ((a[i].peak - b[i].peak).abs() < 0.001) same++;
    }
    expect(same, lessThan(shared ~/ 2), reason: 'the band played it twice');
  });
}
