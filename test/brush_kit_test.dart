// The brush kit: a second set of recordings, chosen in the mixer.
//
// Brushes are not sticks played quietly. The snare answers with a wash
// where a stick answers with a crack, and no amount of turning the kit
// down gets you there, so this is a whole other library rather than a
// gain. What the tests here are for is the two things that are easy to
// get wrong when a second kit is bolted on: that the band actually plays
// it when it is chosen, and that choosing it changes the tone without
// changing the arrangement.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_levels.dart';
import 'package:play_along/audio/drum_patterns.dart' show Drum;
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart' show DrumSound;
import 'package:play_along/music/tune_library.dart';

/// How far down a drum is still ringing [seconds] after the hit, in dB
/// against the take's own peak, taken over the take that rings longest.
///
/// Against its own peak because [DrumSamples.levelling] brings every
/// layer up to the same peak: what you hear as resonance is the ratio of
/// the ring to the stroke, not the ring's level in the file.
double ringAt(DrumSamples drum, double seconds) {
  var worst = -200.0;
  for (final takes in drum.layers) {
    for (final take in takes) {
      final samples = take.samples;
      final peak = samples.fold<int>(0, (p, s) => math.max(p, s.abs()));
      final at = (seconds * 44100).round();
      if (peak == 0 || at + 441 >= samples.length) continue;
      var window = 0;
      for (var i = at; i < at + 441; i++) {
        window = math.max(window, samples[i].abs());
      }
      if (window == 0) continue;
      worst = math.max(worst, 20 * math.log(window / peak) / math.ln10);
    }
  }
  return worst;
}

/// The magnitudes of a real signal's spectrum, by a radix-2 FFT.
///
/// [input]'s length must be a power of two. Only the lower half is
/// returned, the upper half being its mirror image.
List<double> spectrumOf(List<double> input) {
  final n = input.length;
  final re = List<double>.of(input);
  final im = List<double>.filled(n, 0);
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i], ti = im[i];
      re[i] = re[j];
      im[i] = im[j];
      re[j] = tr;
      im[j] = ti;
    }
  }
  for (var span = 2; span <= n; span <<= 1) {
    final half = span ~/ 2;
    for (var i = 0; i < n; i += span) {
      for (var k = 0; k < half; k++) {
        final angle = -2 * math.pi * k / span;
        final wr = math.cos(angle), wi = math.sin(angle);
        final ur = re[i + k], ui = im[i + k];
        final xr = re[i + k + half], xi = im[i + k + half];
        final vr = xr * wr - xi * wi, vi = xr * wi + xi * wr;
        re[i + k] = ur + vr;
        im[i + k] = ui + vi;
        re[i + k + half] = ur - vr;
        im[i + k + half] = ui - vi;
      }
    }
  }
  return [
    for (var i = 0; i < n ~/ 2; i++) math.sqrt(re[i] * re[i] + im[i] * im[i]),
  ];
}

/// How loudly [drum] is still sounding the band around [hz], [seconds]
/// after the stroke, in dB against the stroke's own peak. The take that
/// sings loudest is the one reported.
///
/// Against its own peak because [DrumSamples.levelling] brings every
/// layer up to the same peak: what the ear hears as a drum ringing on is
/// the ring measured against the stroke that started it.
double modeRingOf(DrumSamples drum, double hz, double seconds) {
  const n = 8192;
  const rate = 44100;
  var worst = -200.0;
  for (final takes in drum.layers) {
    for (final take in takes) {
      final samples = take.samples;
      var peak = 0, peakAt = 0;
      for (var i = 0; i < samples.length; i++) {
        if (samples[i].abs() > peak) {
          peak = samples[i].abs();
          peakAt = i;
        }
      }
      if (peak == 0) continue;
      final from = peakAt + (seconds * rate).round();
      final frame = List<double>.filled(n, 0);
      for (var i = 0; i < n && from + i < samples.length; i++) {
        frame[i] =
            samples[from + i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / n));
      }
      final spectrum = spectrumOf(frame);
      // A sixth of an octave around the mode, which is the mode and not
      // its neighbours.
      final lo = (hz / math.pow(2, 1 / 12) * n / rate).floor();
      final hi = (hz * math.pow(2, 1 / 12) * n / rate).ceil();
      var energy = 0.0;
      for (var k = math.max(1, lo); k <= math.min(n ~/ 2 - 1, hi); k++) {
        energy += spectrum[k] * spectrum[k];
      }
      if (energy <= 0) continue;
      // Against the peak through the same window, so the window's own
      // gain cancels.
      final ring =
          20 * math.log(math.sqrt(energy) / (peak * n / 4)) / math.ln10;
      worst = math.max(worst, ring);
    }
  }
  return worst;
}

/// The loudest sample in a drum's recordings, which is the level the
/// others are brought up to and so the level the drum plays at.
int peakOf(DrumSamples drum) => drum.layers
    .expand((takes) => takes)
    .expand((take) => take.samples)
    .fold(0, (peak, s) => math.max(peak, s.abs()));

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  group('the kit is all there', () {
    test('every drum the band can hit has a brush recording', () {
      // A missing drum falls back to the stick kit, which would be a
      // single stick-struck cowbell in the middle of a brush groove: the
      // kind of thing that is obvious to hear and invisible in a diff.
      expect(bank.brushes.keys, containsAll(Drum.values));
    });

    test('three velocity layers a drum, so the tone moves with the stroke', () {
      for (final drum in Drum.values) {
        // Two apiece, and for their own reasons: see below.
        if (drum == Drum.crossStick || drum == Drum.swirl) continue;
        expect(bank.brushes[drum]!.length, 3, reason: drum.label);
      }
    });

    test('and the swirl two, which are circle lengths and not weights', () {
      // The band picks the nearer one for the tempo and stretches it the
      // rest of the way onto the beat.
      expect(bank.brushes[Drum.swirl]!.length, 2);
    });

    test('and the cross-stick two, being an edge hit here', () {
      // Brushes have no cross-stick: the clave goes on the edge of the
      // snare, and the top of that range is a different gesture.
      expect(bank.brushes[Drum.crossStick]!.length, 2);
    });

    test('three takes in each layer, so nothing repeats on the beat', () {
      for (final drum in Drum.values) {
        for (final takes in bank.brushes[drum]!.layers) {
          expect(takes.length, 3, reason: drum.label);
        }
      }
    });

    test('and nothing loaded is silent', () {
      for (final drum in Drum.values) {
        expect(peakOf(bank.brushes[drum]!), greaterThan(0), reason: drum.label);
      }
    });
  });

  group('it keeps the stick kit\'s balance', () {
    // The grooves' velocities were written against the stick kit, whose
    // balance is an overhead microphone's: the snare cracks and the kick,
    // heard across the room, is the quietest thing in it. A brush kit
    // normalised on its own terms would put its own balance underneath
    // those velocities, and its kick would swamp its ride.
    test('each drum sits where the stick kit puts it', () {
      final sticks = {
        Drum.ride: bank.ride,
        Drum.hiHatPedal: bank.hiHatPedal,
        Drum.hiHatClosed: bank.hiHatClosed,
        Drum.hiHatOpen: bank.hiHatOpen,
        Drum.kick: bank.kick,
        Drum.snare: bank.snare,
        Drum.crossStick: bank.crossStick,
        Drum.cowbell: bank.cowbell,
        Drum.tomHigh: bank.tomHigh,
        Drum.tomLow: bank.tomLow,
      };
      for (final drum in Drum.values) {
        // The swirl has nothing to match: the stick kit cannot make one.
        if (drum == Drum.swirl) continue;
        final brushed = peakOf(bank.brushes[drum]!);
        final struck = peakOf(sticks[drum]!);
        expect(
          brushed / struck,
          closeTo(1, 0.02),
          reason: '${drum.label}: $brushed against $struck',
        );
      }
    });
  });

  group('how long it rings', () {
    // The snare in this library is undamped, and a brush stroke on an
    // undamped head leaves the wires buzzing well after the stroke. Cut
    // to the stick snare's length the fade started at 0.5s and never
    // reached that ring, so the kit sounded resonant rather than
    // brushed: the softest layer, which is the one a tap lands on, was
    // only 19 dB down at 0.2s where the stick snare is 25. The
    // recordings are cut shorter now, with the fade over the ring.
    //
    // Against the stick snare rather than a number, because "resonant"
    // is a comparison: the kit it is swapped for is what the ear has to
    // go on. Changing the stick kit should bring you back here.
    for (final seconds in [0.1, 0.2, 0.3]) {
      test('at ${(seconds * 1000).round()}ms it is no more resonant than '
          'the stick snare', () {
        final brushed = ringAt(bank.brushes[Drum.snare]!, seconds);
        final struck = ringAt(bank.snare, seconds);
        expect(
          brushed,
          lessThanOrEqualTo(struck),
          reason:
              'brushes ${brushed.toStringAsFixed(1)} dB down, '
              'sticks ${struck.toStringAsFixed(1)} dB down',
        );
      });
    }
  });

  group('it does not sing', () {
    // This drum is tuned high and barely damped, and left alone it sounds
    // a pitch after the stroke rather than just decaying. Measuring one
    // stroke in slices, the mode at 318 Hz stood 22.6 dB above the energy
    // either side of it at the attack, 26.6 dB by 0.08s and still 25.8 dB
    // at 0.15s: as the broadband stroke died away the drum was left
    // ringing, which is what "tinny" and "resonant" were both about.
    //
    // So the recordings are damped, the way a gel pad on the head damps
    // it: see BRUSH_GEL_MODES in tool/process_samples.py. This is the
    // measurement that says the gel is still on. Each mode is checked a
    // tenth of a second after the stroke, by which time an undamped head
    // is all that is left sounding.
    //
    // Was -41.7 dB at 318 Hz before the gel and -62.4 after, so the bar
    // sits between them with room either side. The levels are against the
    // stroke's own peak, so a louder or quieter kit cannot move them.
    const ceiling = -52.0;
    for (final hz in [318.0, 449.0, 566.0]) {
      test('${hz.round()} Hz has stopped ringing a tenth of a second '
          'after the stroke', () {
        final ring = modeRingOf(bank.brushes[Drum.snare]!, hz, 0.1);
        expect(
          ring,
          lessThan(ceiling),
          reason:
              'the brush snare is still sounding ${hz.round()} Hz at '
              '${ring.toStringAsFixed(1)} dB under the stroke',
        );
      });
    }
  });

  group('choosing it', () {
    test('the band reaches for the brush recording', () {
      expect(
        bank.playingDrum(Drum.snare, DrumSound.brushes, bank.snare),
        same(bank.brushes[Drum.snare]),
      );
    });

    test('and for its own when the sticks are chosen', () {
      expect(
        bank.playingDrum(Drum.snare, DrumSound.kit, bank.snare),
        same(bank.snare),
      );
    });

    test('a kit without a drum falls back rather than going quiet', () {
      final gappy = SampleBank(
        bass: bank.bass,
        piano: bank.piano,
        guitar: bank.guitar,
        ride: bank.ride,
        hiHatPedal: bank.hiHatPedal,
        hiHatClosed: bank.hiHatClosed,
        hiHatOpen: bank.hiHatOpen,
        kick: bank.kick,
        kickClose: bank.kick,
        snare: bank.snare,
        snareTight: bank.snare,
        crossStick: bank.crossStick,
        cowbell: bank.cowbell,
        tomHigh: bank.tomHigh,
        tomLow: bank.tomLow,
        brushes: {Drum.snare: bank.brushes[Drum.snare]!},
      );
      expect(
        gappy.playingDrum(Drum.ride, DrumSound.brushes, gappy.ride),
        same(gappy.ride),
      );
    });
  });

  group('how loud it is', () {
    test('the kit sits where the stick kit sits, in the mix', () async {
      // It used to sit over it: 2.1 dB up on a swing tune and 5.1 on a
      // bossa. The recordings were matched to the stick kit's peaks, and
      // peaks are the wrong thing to match, because a brush on a drum is
      // a wash where a stick is a tick and the same peak carries far more
      // energy. Measured against the chords, which do not change.
      for (final title in ['A Foggy Day', 'Blue Bossa']) {
        final tune = standards.firstWhere((t) => t.title == title);
        double drumsAgainstChords(DrumSound sound) {
          final backing = renderBacking(
            BackingRequest(
              tune: tune,
              loop: LoopRange.wholeTune(tune),
              tempo: 140,
              samples: bank,
              seed: 7,
              drumSound: sound,
            ),
          );
          double rms(Instrument part) {
            final pcm = decodeWav(backing.stems[part]!);
            var sum = 0.0;
            for (final sample in pcm) {
              sum += sample * sample.toDouble();
            }
            return math.sqrt(sum / pcm.length);
          }

          return 20 *
              math.log(rms(Instrument.drums) / rms(Instrument.chords)) /
              math.ln10;
        }

        expect(
          drumsAgainstChords(DrumSound.brushes),
          closeTo(drumsAgainstChords(DrumSound.kit), 1.5),
          reason: title,
        );
      }
    });

    test('and the circle is under the kit, not over it', () async {
      // A wash is continuous where a hit is not, so at the velocity a
      // hit wants the circle was carrying more energy than everything
      // else in the groove put together.
      final tune = standards.firstWhere((t) => t.title == 'A Foggy Day');
      double onlyDrum(Drum only) {
        final backing = renderBacking(
          BackingRequest(
            tune: tune,
            loop: LoopRange.wholeTune(tune),
            tempo: 140,
            samples: bank,
            seed: 7,
            drumSound: DrumSound.brushes,
            drumLevels: DrumLevels({
              for (final drum in Drum.values) drum: drum == only ? 1.0 : 0.0,
            }),
          ),
        );
        final pcm = decodeWav(backing.stems[Instrument.drums]!);
        var sum = 0.0;
        for (final sample in pcm) {
          sum += sample * sample.toDouble();
        }
        return math.sqrt(sum / pcm.length);
      }

      expect(onlyDrum(Drum.swirl), lessThan(onlyDrum(Drum.snare)));
    });
  });

  group('what comes out', () {
    Uint8List drumsOf(DrumSound sound) {
      final tune = standards.firstWhere((t) => t.title == 'A Foggy Day');
      return renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 160,
          samples: bank,
          seed: 7,
          drumSound: sound,
        ),
      ).stems.entries.firstWhere((e) => e.key.label == 'Drums').value;
    }

    test('brushes render a different kit from sticks', () {
      expect(drumsOf(DrumSound.brushes), isNot(drumsOf(DrumSound.kit)));
    });

    test('and render something, rather than a silence that differs', () {
      final drums = drumsOf(DrumSound.brushes);
      final pcm = Int16List.view(
        drums.buffer,
        drums.offsetInBytes,
        drums.length ~/ 2,
      );
      expect(pcm.fold(0, (peak, s) => math.max(peak, s.abs())), greaterThan(0));
    });
  });
}
