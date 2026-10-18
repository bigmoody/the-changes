// The funk kit's close microphones: the same drums, heard from a
// different place.
//
// The kit is an overhead's kit, which is the drums in their room, and on
// a jazz backbeat that is what you want. Funk wants the drums and not
// the room.
//
// The snare and the kick are the two, and they needed it for opposite
// reasons. The snare's level was right and only its tail was wrong, so
// the close one is normalised to the same peak and only the tone changes.
// The kick's level was the problem: the overheads' kick peaks at 0.077
// against the snare's 1.0, which is what a kick sounds like from across
// a room and is 22 dB under the floor a funk groove needs, and no
// velocity reaches up from there.

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

  group('the kick, which had the same problem worse', () {
    test('the close kick is far louder than the overheads\' one', () {
      // The point of it. The overheads' kick peaks at 0.077 against the
      // snare's 1.0, because that is a kick heard across a room, and no
      // velocity reaches the floor of a funk groove from there.
      expect(peakOf(bank.kickClose) / peakOf(bank.kick), greaterThan(5));
    });

    test('and shorter, because a funk kick is a punch', () {
      expect(decayOf(bank.kickClose), lessThan(decayOf(bank.kick)));
    });

    test('it sits with the funk snare rather than under it', () {
      // Within a decibel, where it was 17.6 under.
      final kick = peakOf(bank.kickClose) * 0.85; // the funk pattern's
      final snare = peakOf(bank.snareTight) * 0.5; // velocities
      expect(20 * math.log(kick / snare) / math.ln10, closeTo(0, 2));
    });

    test('the same two layers and four takes as the kick it replaces', () {
      expect(bank.kickClose.length, bank.kick.length);
      for (var layer = 0; layer < bank.kickClose.length; layer++) {
        expect(
          bank.kickClose.layers[layer].length,
          bank.kick.layers[layer].length,
        );
      }
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
      kickClose: bank.kick,
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

    test('a funk tune plays them', () {
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
