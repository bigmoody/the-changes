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
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/music/tune.dart';

int digest(Uint8List bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash = (hash ^ byte) * 0x100000001b3;
    hash &= 0xFFFFFFFFFFFFFFFF;
  }
  return hash;
}

void main() {
  group('kept with the tune', () {
    test('a style follows the tempo until somebody says otherwise', () {
      const plain = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      expect(plain.swing, isNull);
      expect(plain.withSwing(dottedSwing).swing, dottedSwing);
      expect(plain.withSwing(dottedSwing).withSwing(null).swing, isNull);
    });

    test('and changing the feel does not throw it away', () {
      // The mixer builds a style by hand when a part is changed, and a
      // swing dropped there would vanish the moment somebody touched the
      // drums.
      const style = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      final swung = style.withSwing(dottedSwing);
      expect(swung.withFigure(CompFigure.charleston).swing, dottedSwing);
    });

    test('a feel chip stays chosen when a swing is set', () {
      // The mixer marks a chip by comparing the style against the plain
      // one for that feel. A swing set on top made none of them match,
      // so every chip went unselected the moment the slider moved.
      const style = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      expect(
        style.withSwing(dottedSwing).withFigure(null).withSwing(null),
        BandStyle.of(Feel.swing),
      );
    });

    test('two styles differing only in swing are different styles', () {
      // Or the controller would decide nothing had changed and not
      // rebuild the band.
      const style = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      expect(style.withSwing(dottedSwing), isNot(style));
      expect(style.withSwing(dottedSwing), style.withSwing(dottedSwing));
    });

    test('it is written down with the tune and read back', () {
      final library = LibraryStore.inMemory();
      const style = BandStyle(
        drums: Feel.swing,
        bass: BassStyle.walking,
        piano: PianoStyle.swing,
      );
      final ref = TuneRef.standard('Oleo');
      library.setStyle(ref, style.withSwing(dottedSwing));
      final read = LibraryStore.readStyles(library.toJson());
      expect(read[ref]?.swing, dottedSwing);
    });

    test('a style saved before swing existed still reads back', () {
      // Three parts and no fourth, which is every style anybody has
      // saved until now.
      final read = LibraryStore.readStyles({
        'styles': {
          's:Oleo': ['swing', 'walking', 'swing'],
        },
      });
      expect(read[TuneRef.standard('Oleo')]?.drums, Feel.swing);
      expect(read[TuneRef.standard('Oleo')]?.swing, isNull);
    });

    test('and one saved with a figure and no swing is not confused', () {
      // The swing is tagged rather than positional for exactly this: a
      // bare fourth value could be either of them.
      final read = LibraryStore.readStyles({
        'styles': {
          's:Oleo': ['swing', 'walking', 'swing', 'charleston'],
        },
      });
      expect(read[TuneRef.standard('Oleo')]?.figure, CompFigure.charleston);
      expect(read[TuneRef.standard('Oleo')]?.swing, isNull);
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
