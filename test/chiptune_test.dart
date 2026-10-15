// The chiptune band.
//
// What is checked here is that the waveforms are the waveforms: a pulse
// of a given duty has particular harmonics and a triangle has others, and
// those are facts rather than taste. The one that matters most is the
// aliasing: a square wave drawn as a square folds every harmonic above
// half the sample rate back down as a wrong note, and the whole reason
// these are built from their harmonics is to stop that happening.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/chiptune.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

/// How much of [wave] sits at [hertz], by correlating against it.
double energyAt(Float32List wave, double hertz, int sampleRate) {
  var real = 0.0, imaginary = 0.0;
  for (var i = 0; i < wave.length; i++) {
    final angle = 2 * math.pi * hertz * i / sampleRate;
    real += wave[i] * math.cos(angle);
    imaginary += wave[i] * math.sin(angle);
  }
  return math.sqrt(real * real + imaginary * imaginary) / wave.length;
}

void main() {
  const rate = 44100;

  group('a pulse wave is a pulse wave', () {
    test('a square has odd harmonics and no even ones', () {
      // Duty one half: every even harmonic cancels. That is what makes a
      // square a square.
      final harmonics = pulseHarmonics(0.5);
      expect(harmonics[0].abs(), greaterThan(0.6));
      expect(harmonics[1].abs(), lessThan(1e-9), reason: '2nd');
      expect(harmonics[3].abs(), lessThan(1e-9), reason: '4th');
      // And the odd ones fall away as one over the number. By size: the
      // signs alternate, because these are the coefficients of a pulse
      // centred on zero rather than one that crosses there, and the two
      // are the same wave a fraction of a cycle apart.
      expect((harmonics[2] / harmonics[0]).abs(), closeTo(1 / 3, 0.001));
      expect((harmonics[4] / harmonics[0]).abs(), closeTo(1 / 5, 0.001));
    });

    test('and a quarter-duty pulse has its even ones back', () {
      // Which is the other pulse channel, and why two channels playing
      // the same notes did not sound like one doubled part.
      final harmonics = pulseHarmonics(0.25);
      expect(harmonics[1].abs(), greaterThan(0.1));
      // The 4th disappears instead: sin(4 × π/4) is zero.
      expect(harmonics[3].abs(), lessThan(1e-9));
    });

    test('a triangle is odd harmonics falling away as the square', () {
      final harmonics = triangleHarmonics();
      expect(harmonics[1].abs(), lessThan(1e-9), reason: '2nd');
      expect((harmonics[2] / harmonics[0]).abs(), closeTo(1 / 9, 0.001));
      expect((harmonics[4] / harmonics[0]).abs(), closeTo(1 / 25, 0.001));
    });
  });

  group('nothing aliases', () {
    test('a high note has nothing folded back under it', () {
      // The test the whole approach exists for. A naive square at 1800 Hz
      // puts harmonics at 5400, 9000, … 23400, and that last one folds
      // back to 20700, which is not a harmonic of anything. Built from
      // the harmonics it simply stops at the Nyquist frequency.
      const hertz = 1800.0;
      final wave = chipTone(hertz, 0.3, rate);
      final loudest = energyAt(wave, hertz, rate);
      // Half a semitone off the fundamental: nothing should be there, and
      // a folded harmonic would land somewhere like it.
      for (final wrong in [hertz * 1.03, hertz * 0.97, 20700.0, 19000.0]) {
        expect(
          energyAt(wave, wrong, rate),
          lessThan(loudest * 0.05),
          reason: 'something is sitting at $wrong',
        );
      }
    });

    test('and the harmonics that are there are the right ones', () {
      const hertz = 220.0;
      final wave = chipTone(hertz, 0.4, rate, duty: 0.5);
      final first = energyAt(wave, hertz, rate);
      expect(energyAt(wave, hertz * 3, rate) / first, closeTo(1 / 3, 0.08));
      expect(
        energyAt(wave, hertz * 2, rate) / first,
        lessThan(0.05),
        reason: 'a square has no 2nd harmonic',
      );
    });
  });

  group('the two eras', () {
    test('the later one is rounder than the earlier one', () {
      // Its samples were filtered going in and coming out, so there is
      // less of the top of the wave left.
      const hertz = 220.0;
      double brightness(ChipEra era) {
        final wave = chipTone(hertz, 0.3, rate, duty: 0.5, era: era);
        final first = energyAt(wave, hertz, rate);
        return energyAt(wave, hertz * 7, rate) / first;
      }

      expect(
        brightness(ChipEra.sixteenBit),
        lessThan(brightness(ChipEra.eightBit)),
      );
    });

    test('and it takes longer to start and dies away faster', () {
      expect(ChipEra.sixteenBit.attack, greaterThan(ChipEra.eightBit.attack));
      expect(ChipEra.sixteenBit.decay, lessThan(ChipEra.eightBit.decay));
    });
  });

  group('the band plays it', () {
    test('every voice renders every part, and none of them silent', () async {
      // The chip voices go through the synthesised paths, which only the
      // missing-sample-bank case used to reach, so this is the check that
      // they are reached at all and that nothing comes out empty.
      final bank = await SampleBank.load(
        (path) async => File('assets/sounds/$path').readAsBytes(),
      );
      final tune = standards.firstWhere((t) => t.title == 'A Foggy Day');
      for (final voice in BandVoice.values) {
        final backing = renderBacking(
          BackingRequest(
            tune: tune,
            loop: LoopRange.wholeTune(tune),
            tempo: 160,
            samples: bank,
            seed: 7,
            voice: voice,
          ),
        );
        for (final stem in backing.stems.entries) {
          final pcm = decodeWav(stem.value);
          final peak = pcm.fold(0, (p, s) => math.max(p, s.abs()));
          expect(
            peak,
            greaterThan(2000),
            reason: '${voice.label}: ${stem.key.label} came out at $peak',
          );
        }
      }
    });

    test('and a console does not sound like the band', () async {
      final bank = await SampleBank.load(
        (path) async => File('assets/sounds/$path').readAsBytes(),
      );
      final tune = standards.firstWhere((t) => t.title == 'A Foggy Day');
      Uint8List chords(BandVoice voice) => renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 160,
          samples: bank,
          seed: 7,
          voice: voice,
        ),
      ).stems[Instrument.chords]!;
      expect(chords(BandVoice.band), isNot(chords(BandVoice.eightBit)));
      expect(chords(BandVoice.eightBit), isNot(chords(BandVoice.sixteenBit)));
    });
  });

  group('the kit', () {
    test('every drum makes a sound', () {
      final kit = ChipKit(rate, math.Random(7), ChipEra.eightBit);
      for (final (name, drum) in [
        ('kick', kit.kick),
        ('snare', kit.snare),
        ('hat', kit.closedHat),
        ('pedal', kit.hiHatPedal),
        ('cross stick', kit.crossStick),
        ...kit.ride.indexed.map((e) => ('ride ${e.$1}', e.$2)),
      ]) {
        expect(drum, isNotEmpty, reason: name);
        expect(
          drum.fold<double>(0, (peak, s) => math.max(peak, s.abs())),
          greaterThan(0.01),
          reason: name,
        );
      }
    });

    test(
      'the hat is shorter than the snare, which is shorter than the ride',
      () {
        // One noise channel at three settings, which is all the hardware
        // had and all it needed.
        final kit = ChipKit(rate, math.Random(7), ChipEra.eightBit);
        expect(kit.closedHat.length, lessThan(kit.snare.length));
        expect(kit.snare.length, lessThan(kit.ride.first.length));
      },
    );

    test('the kick falls rather than thumping', () {
      // There was no kick to sample, so it is a pulse dropped through its
      // own register: the second half of it is lower than the first.
      final kick = chipKick(rate);
      double zeroCrossings(Iterable<double> half) {
        var crossings = 0;
        var last = 0.0;
        for (final sample in half) {
          if (last <= 0 && sample > 0) crossings++;
          last = sample;
        }
        return crossings.toDouble();
      }

      final half = kick.length ~/ 2;
      expect(
        zeroCrossings(kick.take(half)),
        greaterThan(zeroCrossings(kick.skip(half))),
      );
    });

    test('a ride hit is not the same hit three times', () {
      final kit = ChipKit(rate, math.Random(7), ChipEra.eightBit);
      expect(kit.ride[0], isNot(kit.ride[1]));
      expect(kit.ride[1], isNot(kit.ride[2]));
    });
  });
}
