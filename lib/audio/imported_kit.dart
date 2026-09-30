// Turning a General MIDI drum kit into the one the band plays.
//
// The band has ten drums and reaches for them by name. A SoundFont kit is
// one preset with its hits spread over the keyboard by the General MIDI
// percussion map: 36 is the kick, 38 the snare, 42 the closed hi-hat, and
// so on. So this is a translation table, and the honest thing to say about
// it is that the map is a convention rather than anything in the file.
// Almost every kit follows it, because one that did not would play back
// wrong in every other program too.
//
// Where a kit offers two of something the band asks for one of, the
// alternatives are listed in the order we would rather have them: the
// acoustic snare before the electric one, ride 1 before ride 2. And where
// a kit has none of them, that drum stays the band's own. A font missing a
// cowbell should cost you a cowbell, not a calypso.

import 'sample_bank.dart';
import 'drum_patterns.dart' show Drum;

/// Which General MIDI notes to try for each of the band's drums, best
/// first.
const generalMidiDrums = <Drum, List<int>>{
  // 51 Ride Cymbal 1, 59 Ride Cymbal 2, 53 Ride Bell.
  Drum.ride: [51, 59, 53],
  // 44 Pedal Hi-Hat.
  Drum.hiHatPedal: [44, 42],
  // 42 Closed Hi-Hat.
  Drum.hiHatClosed: [42, 44],
  // 46 Open Hi-Hat.
  Drum.hiHatOpen: [46, 42],
  // 36 Bass Drum 1, 35 Acoustic Bass Drum.
  Drum.kick: [36, 35],
  // 38 Acoustic Snare, 40 Electric Snare.
  Drum.snare: [38, 40],
  // 37 Side Stick, which is what a rim click is called in the map.
  Drum.crossStick: [37, 38],
  // 56 Cowbell.
  Drum.cowbell: [56],
  // 50 High Tom, 48 Hi-Mid Tom, 47 Low-Mid Tom.
  Drum.tomHigh: [50, 48, 47],
  // 45 Low Tom, 43 High Floor Tom, 41 Low Floor Tom.
  Drum.tomLow: [45, 43, 41],
};

/// The band's drums, taken from [kit] where it has them.
///
/// Anything the kit does not offer is left out, and the bank keeps playing
/// its own for that one.
Map<Drum, DrumSamples> kitFromGeneralMidi(Map<int, List<SampledNote>> kit) {
  final out = <Drum, DrumSamples>{};
  for (final entry in generalMidiDrums.entries) {
    for (final note in entry.value) {
      final hits = kit[note];
      if (hits == null || hits.isEmpty) continue;
      // One layer per velocity zone the font gave, softest first, one take
      // in each: a SoundFont has no round robins, so a busy ride will play
      // the same recording every time. That is the format's limit and not
      // something to paper over here.
      out[entry.key] = DrumSamples([
        for (final hit in hits) [hit],
      ]);
      break;
    }
  }
  return out;
}
