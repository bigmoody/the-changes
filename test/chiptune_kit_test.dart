// The chiptune kit: an eight-bit console's drums, made the way that
// console made them.
//
// Nothing here is sampled, because those machines had nothing to
// sample: noise for the hats and the snare, a fast fall in pitch for
// the kick and the toms, a square blip for anything short.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/instruments.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/audio/wav_file.dart';

double loudest(Float32List sound) {
  var peak = 0.0;
  for (final value in sound) {
    if (value.abs() > peak) peak = value.abs();
  }
  return peak;
}

/// Where the sound has fallen to a tenth of its peak: a drum's length.
double lengthOf(Float32List sound, int sampleRate) {
  final peak = loudest(sound);
  for (var i = sound.length - 1; i >= 0; i--) {
    if (sound[i].abs() > peak / 10) return i / sampleRate;
  }
  return 0;
}

void main() {
  final kit = ChiptuneKit(44100);

  test('every drum but the brush swirl has a sound', () {
    for (final drum in Drum.values) {
      final sound = kit.of(drum);
      if (drum == Drum.swirl) {
        expect(sound, isNull, reason: 'a console cannot drag a brush');
        continue;
      }
      expect(sound, isNotNull, reason: drum.name);
      expect(loudest(sound!), greaterThan(0.05), reason: drum.name);
    }
  });

  test('the kick falls in pitch rather than being struck', () {
    // What makes a chip kick a kick: a note dropped fast enough stops
    // being a note. So the first half of it crosses zero far more often
    // than the second.
    final kick = kit.kick;
    int crossings(int from, int to) {
      var count = 0;
      for (var i = from + 1; i < to; i++) {
        if ((kick[i] < 0) != (kick[i - 1] < 0)) count++;
      }
      return count;
    }

    final half = (0.03 * 44100).round();
    expect(crossings(0, half), greaterThan(crossings(half, half * 2)));
  });

  test('nothing rings: a console has no room and no cymbal', () {
    // Which is the whole character of the kit. The closed hat is a
    // tick, the open one is longer, the ride longer again, and the
    // longest thing in the kit is still under a quarter of a second.
    final closed = lengthOf(kit.hiHatClosed, 44100);
    final open = lengthOf(kit.hiHatOpen, 44100);
    final ride = lengthOf(kit.ride, 44100);
    expect(closed, lessThan(0.03));
    expect(open, greaterThan(closed * 3));
    expect(ride, greaterThan(open));
    for (final drum in Drum.values) {
      final sound = kit.of(drum);
      if (sound == null) continue;
      expect(
        sound.length / 44100,
        lessThan(0.25),
        reason: '${drum.name} is still going',
      );
      // And it ends on silence rather than on a step, which is a click.
      expect(sound.last.abs(), lessThan(0.001), reason: drum.name);
    }
  });

  test('the noise is the console\'s own, not a random number source', () {
    // A linear feedback shift register in the short mode repeats every
    // ninety-three steps, which is what gives a chip snare its pitch. A
    // random source would never repeat.
    final snare = kit.snare;
    expect(loudest(snare), greaterThan(0.1));
    // Two kits built the same way are identical, sample for sample: it
    // is a sequence, not a dice roll.
    final twin = ChiptuneKit(44100).snare;
    expect(snare.length, twin.length);
    for (var i = 0; i < snare.length; i += 97) {
      expect(snare[i], twin[i], reason: 'sample $i');
    }
  });

  test('the band plays it, and it is not the band\'s own kit', () async {
    final bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
    final tune = standards.firstWhere((t) => t.title == 'Blue Bossa');
    Uint8List drumsWith(DrumSound sound) => renderBacking(
      BackingRequest(
        tune: tune,
        loop: LoopRange.bars(tune, 0, 3),
        tempo: 140,
        countInBars: 0,
        seed: 4,
        samples: bank,
        drumSound: sound,
      ),
    ).stems[Instrument.drums]!;

    final chip = drumsWith(DrumSound.chiptune);
    expect(rms(chip), greaterThan(200), reason: 'the kit is audible');
    expect(
      chip,
      isNot(drumsWith(DrumSound.kit)),
      reason: 'and it is not the recorded kit',
    );
  });
}

/// How loud a rendered stem is overall.
double rms(Uint8List wav) {
  final audio = readWav(wav);
  var sum = 0.0;
  for (final sample in audio.samples) {
    sum += sample * sample;
  }
  return math.sqrt(sum / audio.samples.length) * 32768;
}
