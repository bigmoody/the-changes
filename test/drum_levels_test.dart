// Each drum at the level somebody can stand it.
//
// The claim worth testing is about audio, not about a slider: a level has
// to reach the rendered drums and nothing else, and leaving every level
// alone has to render exactly the band that was there before. The second
// of those is the one that protects everybody who never opens this screen,
// so it is tested by hashing the stem rather than by trusting that
// multiplying by one is free.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_levels.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/settings/app_settings.dart';

int digest(Uint8List bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash = (hash ^ byte) * 0x100000001b3;
    hash &= 0xFFFFFFFFFFFFFFFF;
  }
  return hash;
}

/// How much sound there is in a stem overall, as plain mean square.
double energyOf(Uint8List stem) {
  final samples = Int16List.sublistView(stem);
  var total = 0.0;
  for (final sample in samples) {
    final level = sample / 32768;
    total += level * level;
  }
  return total / samples.length;
}

void main() {
  group('keeping the levels', () {
    test('a drum nobody has touched is at one', () {
      const levels = DrumLevels();
      expect(levels.isEmpty, isTrue);
      for (final drum in Drum.values) {
        expect(levels.of(drum), 1, reason: drum.name);
      }
    });

    test('a level is set and read back, one drum at a time', () {
      final levels = const DrumLevels().set(Drum.ride, 0.4);
      expect(levels.of(Drum.ride), 0.4);
      expect(levels.of(Drum.kick), 1, reason: 'the rest are untouched');
      expect(levels.moved, 1);
    });

    test('putting one back to one forgets it rather than storing it', () {
      // Otherwise a map of twelve ones would be saved and reloaded for
      // somebody who had changed their mind, and "moved" would lie.
      var levels = const DrumLevels().set(Drum.ride, 0.4);
      levels = levels.set(Drum.ride, 1);
      expect(levels.isEmpty, isTrue);
      expect(levels.moved, 0);
    });

    test('a level is held between nothing and half as loud again', () {
      expect(const DrumLevels().set(Drum.ride, -3).of(Drum.ride), 0);
      expect(const DrumLevels().set(Drum.ride, 99).of(Drum.ride), 1.5);
    });

    test('they survive being written down and read back', () {
      final levels = const DrumLevels()
          .set(Drum.ride, 0.3)
          .set(Drum.hiHatClosed, 0.55);
      final read = DrumLevels.fromJson(levels.toJson());
      expect(read.of(Drum.ride), 0.3);
      expect(read.of(Drum.hiHatClosed), 0.55);
      expect(read.moved, 2);
    });

    test('rubbish in the saved map is skipped rather than thrown', () {
      final read = DrumLevels.fromJson({
        'ride': 0.3,
        'trombone': 0.5,
        'kick': 'loud',
      });
      expect(read.moved, 1);
      expect(read.of(Drum.ride), 0.3);
    });

    test('every drum is offered, once, cymbals first', () {
      expect(drumsByEar.toSet(), Drum.values.toSet());
      expect(drumsByEar, hasLength(Drum.values.length));
      expect(drumsByEar.first, Drum.ride, reason: 'the reason this exists');
    });

    test('the setting starts empty and clears back to empty', () async {
      final settings = AppSettings.inMemory();
      expect(settings.drumLevels.isEmpty, isTrue);
      await settings.setDrumLevel(Drum.ride, 0.3);
      expect(settings.drumLevels.of(Drum.ride), 0.3);
      await settings.clearDrumLevels();
      expect(settings.drumLevels.isEmpty, isTrue);
    });
  });

  group('in the rendered band', () {
    late SampleBank bank;

    setUpAll(() async {
      bank = await SampleBank.load(
        (path) async => File('assets/sounds/$path').readAsBytes(),
      );
    });

    BackingRequest request({DrumLevels levels = const DrumLevels()}) {
      final tune = standards.firstWhere((t) => t.title == 'A Foggy Day');
      return BackingRequest(
        tune: tune,
        loop: LoopRange(startBeat: 0, lengthBeats: 8 * tune.beatsPerBar),
        tempo: 160,
        countInBars: 0,
        seed: 7,
        samples: bank,
        drumLevels: levels,
      );
    }

    Uint8List drumsOf(BackingRequest r) =>
        renderBacking(r).stems[Instrument.drums]!;

    test('leaving them alone renders the same band, byte for byte', () {
      // The promise to everybody who never opens this screen.
      expect(
        digest(drumsOf(request())),
        digest(drumsOf(request(levels: const DrumLevels()))),
      );
    });

    test('turning the ride down changes the drums', () {
      final quieter = const DrumLevels().set(Drum.ride, 0.25);
      expect(
        digest(drumsOf(request(levels: quieter))),
        isNot(digest(drumsOf(request()))),
      );
    });

    test('and takes the energy out of the drums with it', () {
      // Measured as how much sound there is rather than as the loudest
      // sample: the loudest moment in a swing kit is the kick or the
      // snare, which this does not touch, so a peak would not move.
      final off = const DrumLevels().set(Drum.ride, 0);
      expect(
        energyOf(drumsOf(request(levels: off))),
        lessThan(energyOf(drumsOf(request())) * 0.9),
      );
    });

    test('a drum that is not in the pattern changes nothing', () {
      // Nothing plays the cowbell in a swing feel, so moving it is a
      // no-op rather than something that quietly shifts the mix.
      final cowbell = const DrumLevels().set(Drum.cowbell, 0.1);
      expect(
        digest(drumsOf(request(levels: cowbell))),
        digest(drumsOf(request())),
      );
    });

    test('the other parts are untouched', () {
      // The whole band is scaled by one number taken from its loudest
      // moment. Turning a drum down lowers that, which would raise the
      // gain and hand somebody more piano and bass than they had, which
      // is the opposite of what they asked for. The gain is worked out
      // from the kit as recorded so that cannot happen.
      final off = const DrumLevels().set(Drum.ride, 0);
      final plain = renderBacking(request()).stems;
      final moved = renderBacking(request(levels: off)).stems;
      for (final part in [Instrument.bass, Instrument.chords]) {
        expect(digest(moved[part]!), digest(plain[part]!), reason: part.label);
      }
    });
  });
}
