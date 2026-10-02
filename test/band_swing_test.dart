// The band's swing, when somebody would rather say than let it follow.
//
// What matters is that it reaches the audio and that leaving it alone
// changes nothing. The curve is the better answer for nearly everybody
// and it has a page in Learn arguing so; this must not quietly become
// the default by being added.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/swing.dart';
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

void main() {
  group('asking for one', () {
    test('it follows the tempo until somebody says otherwise', () async {
      final settings = AppSettings.inMemory();
      expect(settings.swing, isNull);
      await settings.setSwing(dottedSwing);
      expect(settings.swing, dottedSwing);
      await settings.setSwing(null);
      expect(settings.swing, isNull, reason: 'and back again');
    });
  });

  group('what the band does with it', () {
    test('no swing set is the curve, whatever the tempo', () {
      for (final tempo in [80, 120, 160, 240, 300]) {
        final tune = standards.first;
        final request = BackingRequest(
          tune: tune,
          loop: LoopRange(startBeat: 0, lengthBeats: 4 * tune.beatsPerBar),
          tempo: tempo,
        );
        expect(swingForPass(request, 0), swingAt(tempo), reason: '$tempo');
      }
    });

    test('a swing set is that swing, whatever the tempo', () {
      for (final tempo in [80, 120, 160, 240, 300]) {
        final tune = standards.first;
        final request = BackingRequest(
          tune: tune,
          loop: LoopRange(startBeat: 0, lengthBeats: 4 * tune.beatsPerBar),
          tempo: tempo,
          swing: dottedSwing,
        );
        expect(swingForPass(request, 0), dottedSwing, reason: '$tempo');
      }
    });
  });

  group('in the rendered band', () {
    late SampleBank bank;

    setUpAll(() async {
      bank = await SampleBank.load(
        (path) async => File('assets/sounds/$path').readAsBytes(),
      );
    });

    BackingRequest request({double? swing}) {
      final tune = standards.firstWhere((t) => t.title == 'A Foggy Day');
      return BackingRequest(
        tune: tune,
        loop: LoopRange(startBeat: 0, lengthBeats: 8 * tune.beatsPerBar),
        tempo: 160,
        countInBars: 0,
        seed: 7,
        samples: bank,
        swing: swing,
      );
    }

    test('leaving it alone renders the same band, byte for byte', () {
      // The promise to everybody who never opens this.
      expect(
        digest(renderBacking(request()).stems[Instrument.drums]!),
        digest(renderBacking(request(swing: null)).stems[Instrument.drums]!),
      );
    });

    test('and asking for it changes what the drums play', () {
      // The ride is where the "and" lives, so this is where it shows.
      expect(
        digest(
          renderBacking(request(swing: straight)).stems[Instrument.drums]!,
        ),
        isNot(digest(renderBacking(request()).stems[Instrument.drums]!)),
      );
    });

    test('straight and hard are not the same band either', () {
      expect(
        digest(
          renderBacking(request(swing: straight)).stems[Instrument.drums]!,
        ),
        isNot(
          digest(
            renderBacking(request(swing: widestSwing)).stems[Instrument.drums]!,
          ),
        ),
      );
    });

    test('the swing the curve would have given is the band it gives', () {
      // Setting the slider to exactly what the tempo would have produced
      // has to be the same performance, or the two paths disagree about
      // what following the tempo means.
      expect(
        digest(
          renderBacking(request(swing: swingAt(160))).stems[Instrument.drums]!,
        ),
        digest(renderBacking(request()).stems[Instrument.drums]!),
      );
    });
  });
}
