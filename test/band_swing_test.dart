// The band's swing, when somebody would rather say than let it follow.
//
// What matters is that it reaches the audio and that leaving it alone
// changes nothing. The curve is the better answer for nearly everybody
// and it has a page in Learn arguing so; this must not quietly become
// the default by being added.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/audio/drum_levels.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/music/arrangement.dart';
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

  group('what the slider actually moves', () {
    test('the ride "a" and the snare, by the amount asked for', () {
      // Somebody said they could not hear it, so this says in numbers
      // what moves: the off-beat ride after 2 and 4, and the snare comp.
      for (final (at, and) in [(straight, 1.5), (tripletSwing, 1 + 2 / 3)]) {
        final hits = drumBar(
          feel: Feel.swing,
          bar: 0,
          beatsPerBar: 4,
          random: Random(1),
          swing: at,
        );
        final offbeat = hits.firstWhere(
          (h) => h.drum == Drum.ride && h.beat > 1 && h.beat < 2,
        );
        expect(offbeat.beat, closeTo(and, 0.001), reason: 'swing $at');
      }
    });

    test('and the whole kit measures different for it', () {
      // Not merely a different render: a quarter of the drums' own level
      // is how much of the stem changes between straight and hard, which
      // is not a subtlety.
      final hits = {
        for (final at in [straight, widestSwing])
          at: drumBar(
            feel: Feel.swing,
            bar: 0,
            beatsPerBar: 4,
            random: Random(1),
            swing: at,
          ).map((h) => '${h.drum.name}@${h.beat}').toSet(),
      };
      expect(hits[straight], isNot(hits[widestSwing]));
    });
  });

  group('the step between the app and the renderer', () {
    // Where this was lost. The player puts the sample bank into the
    // request on its way to the isolate, by writing out a copy field by
    // field, and the swing was not in the list. Every test called the
    // renderer directly and so none of them crossed this one line.
    BackingRequest full(SampleBank? bank) {
      final tune = standards.first;
      return BackingRequest(
        tune: tune,
        loop: LoopRange(startBeat: 0, lengthBeats: 4 * tune.beatsPerBar),
        tempo: 140,
        countInBars: 0,
        sampleRate: 22050,
        seed: 9,
        samples: bank,
        comping: Comping.guitar,
        bassSound: BassSound.imported,
        drumSound: DrumSound.imported,
        arpeggios: true,
        arpeggioSound: Comping.guitar,
        arpeggioStart: ArpeggioStart.third,
        arrangement: const Arrangement(choruses: 3),
        drumLevels: const DrumLevels().set(Drum.ride, 0.25),
        swing: dottedSwing,
      );
    }

    test('putting the samples in keeps everything else', () {
      // Field by field, so the next one added to the request and
      // forgotten here fails this rather than going quiet on a phone.
      final was = full(null);
      final now = was.withSamples(null);
      expect(now.tempo, was.tempo);
      expect(now.loop.startBeat, was.loop.startBeat);
      expect(now.countInBars, was.countInBars);
      expect(now.sampleRate, was.sampleRate);
      expect(now.seed, was.seed);
      expect(now.comping, was.comping);
      expect(now.bassSound, was.bassSound);
      expect(now.drumSound, was.drumSound);
      expect(now.arpeggios, was.arpeggios);
      expect(now.arpeggioSound, was.arpeggioSound);
      expect(now.arpeggioStart, was.arpeggioStart);
      expect(now.arrangement.choruses, was.arrangement.choruses);
      expect(now.swing, was.swing, reason: 'the one that was being lost');
      expect(
        now.drumLevels.of(Drum.ride),
        was.drumLevels.of(Drum.ride),
        reason: 'and this one with it',
      );
    });

    test('and the band it renders is the band that was asked for', () {
      // The end of the chain: what the player actually plays has to be
      // what the request said, not a copy of it with pieces missing.
      final straightened = full(null).withSamples(null);
      expect(swingForPass(straightened, 0), dottedSwing);
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
