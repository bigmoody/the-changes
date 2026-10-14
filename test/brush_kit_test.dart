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
import 'package:play_along/audio/drum_patterns.dart' show Drum;
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart' show DrumSound;
import 'package:play_along/music/tune_library.dart';

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
        snare: bank.snare,
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
