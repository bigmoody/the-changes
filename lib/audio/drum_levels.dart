// How loud each drum is, one at a time.
//
// The mixer already turns the whole kit up and down, which is the wrong
// size of knob for the problem this exists for. A ride cymbal and a kick
// drum are not the same thing to listen to: the cymbals carry most of the
// energy above 5 kHz, and for a lot of people, autistic players above
// all, that is where listening stops being pleasant and starts being
// painful. Turning the kit down to fix the ride takes the kick and the
// snare with it, and then there is no time left to play against.
//
// So each drum has its own level. The ride and the hats come first in the
// list because they are the reason for it.
//
// This is not a mixer fader. The drums are rendered into one stem before a
// note sounds, so a level here changes what gets rendered rather than what
// is playing, and the band starts again to pick it up. That is the same
// deal as changing the feel or the tempo, and it is why these live in
// Settings with the rest of the band's sound rather than in the mixer,
// where every other control is live.

import 'drum_patterns.dart';

/// How loud each drum is, where 1 is as the kit was recorded.
///
/// Empty is the usual case: nobody is given a level they did not ask for,
/// and an empty map renders exactly what the band always rendered.
class DrumLevels {
  const DrumLevels([this.byDrum = const {}]);

  /// Only the drums somebody has actually moved. The rest are 1.
  final Map<Drum, double> byDrum;

  bool get isEmpty => byDrum.isEmpty;
  bool get isNotEmpty => byDrum.isNotEmpty;

  /// How many have been moved off where they were.
  int get moved => byDrum.length;

  /// The level for [drum], 1 if it has not been touched.
  ///
  /// Multiplying by exactly 1 leaves a sample bit for bit, which is what
  /// keeps the band sounding the same for everybody who never opens this.
  double of(Drum drum) => byDrum[drum] ?? 1;

  /// The same again with [drum] at [level], or back to where it was when
  /// that is 1.
  DrumLevels set(Drum drum, double level) {
    final out = {...byDrum};
    if (level == 1) {
      out.remove(drum);
    } else {
      out[drum] = level.clamp(0, 1.5);
    }
    return DrumLevels(out);
  }

  /// Everything back to the kit as recorded.
  DrumLevels get cleared => const DrumLevels();

  Map<String, double> toJson() => {
    for (final entry in byDrum.entries) entry.key.name: entry.value,
  };

  static DrumLevels fromJson(Map<String, Object?> json) => DrumLevels({
    for (final entry in json.entries)
      if (Drum.values.where((drum) => drum.name == entry.key).firstOrNull
          case final drum?)
        if (entry.value case final num level)
          drum: level.toDouble().clamp(0, 1.5),
  });
}

/// The drums in the order they are worth being offered in.
///
/// Not the order they are declared in, which follows the kit, but the
/// order somebody comes to this screen for: the cymbals and the hats,
/// which are what hurts, then everything else.
const drumsByEar = <Drum>[
  Drum.ride,
  Drum.hiHatClosed,
  Drum.hiHatOpen,
  Drum.hiHatPedal,
  Drum.snare,
  Drum.swirl,
  Drum.crossStick,
  Drum.kick,
  Drum.tomHigh,
  Drum.tomLow,
  Drum.cowbell,
];
