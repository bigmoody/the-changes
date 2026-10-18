// The arpeggios are a part of their own.
//
// They are what you play along to rather than what the band comps
// with, so hearing them on something other than the chords is most of
// the use of having them: a horn over a piano, a vibraphone over a
// guitar, whatever somebody imported for them.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/soundfont_store.dart';

SampledInstrument instrument(String name) => SampledInstrument(
  name: name,
  notes: {
    60: [SampledNote(Int16List(32))],
  },
  takesAre: Takes.roundRobin,
);

SampleBank bankWith({SampledInstrument? chords, SampledInstrument? arpeggio}) {
  final plain = SampledInstrument(
    name: 'ours',
    notes: {
      60: [SampledNote(Int16List(16))],
    },
    takesAre: Takes.roundRobin,
  );
  // One silent hit: a kit with no layers at all cannot work out how to
  // level itself.
  final empty = DrumSamples.plain([
    [Int16List(1)],
  ]);
  return SampleBank(
    bass: plain,
    piano: plain,
    guitar: plain,
    ride: empty,
    hiHatPedal: empty,
    hiHatClosed: empty,
    hiHatOpen: empty,
    kick: empty,
    kickClose: empty,
    snare: empty,
    snareTight: empty,
    crossStick: empty,
    cowbell: empty,
    tomHigh: empty,
    tomLow: empty,
  ).withImported(chords: chords, arpeggio: arpeggio);
}

void main() {
  test('the arpeggios play their own font when there is one', () {
    final bank = bankWith(
      chords: instrument('piano font'),
      arpeggio: instrument('horn font'),
    );
    expect(bank.playingArpeggio(Comping.imported).name, 'horn font');
    expect(bank.playing(Comping.imported).name, 'piano font');
  });

  test('and the chords\' font when there is not, as they always did', () {
    // Before the arpeggios had a font of their own, choosing the
    // imported sound for them meant the one the chords were using.
    // Anybody set up that way keeps hearing it.
    final bank = bankWith(chords: instrument('piano font'));
    expect(bank.playingArpeggio(Comping.imported).name, 'piano font');
  });

  test('and the band\'s own piano when neither is imported', () {
    expect(bankWith().playingArpeggio(Comping.imported).name, 'ours');
    expect(bankWith().playingArpeggio(Comping.piano).name, 'ours');
  });

  test('the store keeps it apart from the chords', () {
    final store = SoundFontStore.inMemory(
      chords: instrument('piano font'),
      arpeggio: instrument('horn font'),
    );
    expect(store.chords?.name, 'piano font');
    expect(store.arpeggio?.name, 'horn font');
    expect(store.has(SoundFontRole.arpeggio), isTrue);
    expect(
      SoundFontRole.arpeggio.fileName,
      isNot(SoundFontRole.chords.fileName),
    );
  });
}
