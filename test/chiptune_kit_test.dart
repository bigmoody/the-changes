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

  test('every drum is a handful of frames, stepping, then stopped', () {
    // The console sets its four-bit volume once a frame, sixty times a
    // second, from a short list counting down. So a drum's length is a
    // whole number of frames, it holds one level for each of them, and
    // it ends on the nought at the bottom of the list, not on a tail.
    const perFrame = 44100 ~/ 60;
    for (final drum in Drum.values) {
      final sound = kit.of(drum);
      if (sound == null) continue;
      expect(sound.length % perFrame, 0, reason: '${drum.name}: whole frames');
      expect(
        sound.length ~/ perFrame,
        lessThanOrEqualTo(12),
        reason: '${drum.name}: a fifth of a second at the very most',
      );
    }
    // The closed hat is five frames and the snare ten: a twelfth of a
    // second and a sixth, which is the scale these sounds live at.
    expect(kit.hiHatClosed.length ~/ perFrame, 5);
    expect(kit.snare.length ~/ perFrame, 10);
    expect(kit.kick.length ~/ perFrame, 6);
  });

  test('and inside a frame the level does not move: it steps', () {
    // The noise is plus or minus the frame's volume and nothing else, so
    // within one frame every sample is the same size. A real drum's
    // decay glides; this one stairs down.
    const perFrame = 44100 ~/ 60;
    final snare = kit.snare;
    for (var frame = 0; frame < 9; frame++) {
      final sizes = {
        for (var i = frame * perFrame; i < (frame + 1) * perFrame; i++)
          snare[i].abs().toStringAsFixed(6),
      };
      expect(sizes, hasLength(1), reason: 'frame $frame');
    }
    // And the last frame is the nought: silence, not a fade.
    for (var i = 9 * perFrame; i < 10 * perFrame; i++) {
      expect(snare[i], 0);
    }
  });

  test('the noise is the console\'s own, not a random number source', () {
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
