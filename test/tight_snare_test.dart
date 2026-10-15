// The funk snare: the same drum, the other microphone.
//
// The kit's snare is an overhead's snare, which is the drum in its room,
// and on a jazz backbeat that is what you want. Funk wants the drum and
// not the room, so funk reaches for the close microphone instead. The
// level is the same either way and only the tone changes, so the
// pattern's velocity still means what it meant.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

int peakOf(DrumSamples drum) => drum.layers
    .expand((takes) => takes)
    .expand((take) => take.samples)
    .fold(0, (peak, s) => math.max(peak, s.abs()));

/// How long a recording takes to fall 40 dB, in seconds.
double decayOf(DrumSamples drum) {
  final take = drum.layers.last.last.samples;
  final peak = take.fold(0, (p, s) => math.max(p, s.abs()));
  for (var i = 0; i + 441 < take.length; i++) {
    var window = 0;
    for (var j = i; j < i + 441; j++) {
      window = math.max(window, take[j].abs());
    }
    if (window < peak * 0.01) return i / SampleBank.sampleRate;
  }
  return take.length / SampleBank.sampleRate;
}

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  group('the recording', () {
    test('it is the same shape as the snare it stands in for', () {
      // Two layers of three, quiet ones for a ghost and loud for the
      // backbeat, so nothing about how it is played has to change.
      expect(bank.snareTight.length, bank.snare.length);
      for (var layer = 0; layer < bank.snareTight.length; layer++) {
        expect(
          bank.snareTight.layers[layer].length,
          bank.snare.layers[layer].length,
        );
      }
    });

    test('and the same level, so a velocity means what it meant', () {
      expect(peakOf(bank.snareTight) / peakOf(bank.snare), closeTo(1, 0.001));
    });

    test('but it is tighter, which is the whole point', () {
      expect(decayOf(bank.snareTight), lessThan(decayOf(bank.snare) * 0.8));
    });

    test('and it is a different recording, not the same one trimmed', () {
      expect(
        bank.snareTight.layers.last.last.samples,
        isNot(bank.snare.layers.last.last.samples),
      );
    });
  });

  group('who gets it', () {
    /// The same bank with the close snare replaced by the overhead one, so
    /// a render that reaches for it comes out differently and a render
    /// that does not comes out the same.
    SampleBank withoutIt() => SampleBank(
      bass: bank.bass,
      piano: bank.piano,
      guitar: bank.guitar,
      ride: bank.ride,
      hiHatPedal: bank.hiHatPedal,
      hiHatClosed: bank.hiHatClosed,
      hiHatOpen: bank.hiHatOpen,
      kick: bank.kick,
      snare: bank.snare,
      snareTight: bank.snare,
      crossStick: bank.crossStick,
      cowbell: bank.cowbell,
      tomHigh: bank.tomHigh,
      tomLow: bank.tomLow,
      brushes: bank.brushes,
    );

    Uint8List drumsOf(String title, SampleBank samples) {
      final tune = standards.firstWhere((t) => t.title == title);
      return renderBacking(
        BackingRequest(
          tune: tune,
          loop: LoopRange.wholeTune(tune),
          tempo: 110,
          samples: samples,
          seed: 7,
        ),
      ).stems[Instrument.drums]!;
    }

    test('a funk tune plays it', () {
      final funk = standards.firstWhere((t) => t.style.drums == Feel.funk);
      expect(
        drumsOf(funk.title, bank),
        isNot(drumsOf(funk.title, withoutIt())),
      );
    });

    test('and a swing tune does not', () {
      // Its backbeat is the drum in its room, which is the kit's own.
      expect(drumsOf('A Foggy Day', bank), drumsOf('A Foggy Day', withoutIt()));
    });

    test('nor does a bossa', () {
      expect(drumsOf('Blue Bossa', bank), drumsOf('Blue Bossa', withoutIt()));
    });
  });
}
