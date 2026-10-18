// Fitting somebody else's drum kit to the band's.
//
// The General MIDI percussion map is a convention rather than anything in
// the file, so this is where the guessing lives and where it is worth
// being explicit about what happens when a kit does not have what the band
// is reaching for.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart' show Drum, importableDrums;
import 'package:play_along/audio/imported_kit.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/soundfont.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';

import 'soundfont_test.dart' show buildFont, sample, zone, emptyDrum;

/// A kit whose drums sit on [notes], each a recording of its own length so
/// a test can tell which one it got.
Map<int, List<SampledNote>> kitOn(List<int> notes) {
  final font = SoundFont.read(
    buildFont(
      bank: 128,
      samples: [
        for (final (i, _) in notes.indexed) sample(length: 40 + i * 10),
      ],
      zones: [
        for (final (i, note) in notes.indexed)
          zone(i, keyLow: note, keyHigh: note),
      ],
    ),
  );
  return font.drumKitFor(font.presets.single);
}

void main() {
  test('the usual notes land on the usual drums', () {
    // The swirl is not among them: it is the brush kit's, and General
    // MIDI has no note for a brush circling a drumhead.
    final kit = kitFromGeneralMidi(
      kitOn([36, 38, 42, 44, 46, 51, 37, 56, 50, 45]),
    );
    expect(kit.keys, containsAll(importableDrums));
    expect(kit.containsKey(Drum.swirl), isFalse);
  });

  test('a kit with only the four essentials leaves the rest alone', () {
    // What most kits in a General MIDI font come to. The band keeps its
    // own cowbell and toms rather than going silent.
    final kit = kitFromGeneralMidi(kitOn([36, 38, 42, 51]));
    expect(kit.keys, containsAll([Drum.kick, Drum.snare, Drum.ride]));
    expect(kit.containsKey(Drum.cowbell), isFalse);
    expect(kit.containsKey(Drum.tomHigh), isFalse);
  });

  test('a second choice is taken when the first is missing', () {
    // 40 is the electric snare, 35 the other bass drum, 59 the other ride.
    final kit = kitFromGeneralMidi(kitOn([35, 40, 59]));
    expect(kit.keys, containsAll([Drum.kick, Drum.snare, Drum.ride]));
  });

  test('the closed hi-hat stands in for the pedal one', () {
    // Plenty of kits have 42 and not 44, and a groove with no hi-hat at all
    // where it wanted a pedal chick is worse than one with a closed hat.
    final kit = kitFromGeneralMidi(kitOn([42]));
    expect(kit.containsKey(Drum.hiHatClosed), isTrue);
    expect(kit.containsKey(Drum.hiHatPedal), isTrue);
    expect(kit.containsKey(Drum.hiHatOpen), isTrue);
  });

  test('a kit on the wrong notes gives nothing rather than nonsense', () {
    // Up where the map has no percussion at all.
    expect(kitFromGeneralMidi(kitOn([90, 91, 92])), isEmpty);
  });

  test('a drum is played at its own speed and never transposed', () {
    // The one rule that separates a kit from an instrument: a snare
    // shifted to the key of the tune is not a thing anybody wants.
    final font = SoundFont.read(
      buildFont(
        bank: 128,
        samples: [sample(root: 60, rate: 22050)],
        zones: [zone(0, keyLow: 36, keyHigh: 38)],
      ),
    );
    final kit = font.drumKitFor(font.presets.single);
    // Three notes off one zone, all at the same speed: half ours, because
    // that is the rate it was recorded at, and nothing for the key.
    for (final note in [36, 37, 38]) {
      expect(kit[note]!.single.rate, closeTo(0.5, 0.0001));
    }
  });

  test('asking a pitched preset for a kit is refused', () {
    final font = SoundFont.read(
      buildFont(samples: [sample()], zones: [zone(0)]),
    );
    expect(
      () => font.drumKitFor(font.presets.single),
      throwsA(isA<SoundFontException>()),
    );
  });

  group('the band playing one', () {
    Tune tune() => Tune.fromChart(
      title: 'Test',
      key: 'C',
      chart: 'Cmaj7 | Dm7 | G7 | Cmaj7 |',
      defaultTempo: 120,
    );

    Uint8List drumsWith(DrumSound sound, {Map<Drum, DrumSamples>? imported}) {
      final ours = SoundFont.read(
        buildFont(samples: [sample(length: 400)], zones: [zone(0)]),
      );
      final instrument = ours.instrumentFor(ours.presets.single);
      final t = tune();
      return renderBacking(
        BackingRequest(
          tune: t,
          loop: LoopRange.wholeTune(t),
          tempo: 120,
          countInBars: 0,
          drumSound: sound,
          samples: SampleBank(
            bass: instrument,
            piano: instrument,
            guitar: instrument,
            ride: emptyDrum,
            hiHatPedal: emptyDrum,
            hiHatClosed: emptyDrum,
            hiHatOpen: emptyDrum,
            kick: emptyDrum,
            kickClose: emptyDrum,
            snare: emptyDrum,
            snareTight: emptyDrum,
            crossStick: emptyDrum,
            cowbell: emptyDrum,
            tomHigh: emptyDrum,
            tomLow: emptyDrum,
            importedDrums: imported ?? const {},
          ),
        ),
      ).stems[Instrument.drums]!;
    }

    test('an imported kit is what gets hit', () {
      final kit = kitFromGeneralMidi(kitOn([36, 38, 42, 51]));
      expect(
        drumsWith(DrumSound.imported, imported: kit),
        isNot(drumsWith(DrumSound.kit)),
      );
    });

    test('with no kit imported the band plays its own', () {
      expect(drumsWith(DrumSound.imported), drumsWith(DrumSound.kit));
    });
  });
}
