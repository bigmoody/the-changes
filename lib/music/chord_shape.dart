// What a chord is, as a rhythm section hears it.
//
// A chart writes C6 and another writes CΔ7; a bass player walks the same
// notes under both and a comper voices whichever they feel like. The same
// goes for Dm7 and Dm9, for G7 and G13 and G7♭9. The extensions are the
// comper's business and the difference between the charts is somebody's
// pen, not the harmony.
//
// So this is the coarse reading: major, minor, dominant, half-diminished,
// diminished, suspended. It is what you need to answer two questions that
// come up all over the app. What is this chord doing in the tune, where
// a 13th and a 7th are both dominants and behave alike. And whether a
// recording of real players will fit a chart they did not play, where the
// answer has to be yes for C6 against CΔ7 and firmly no for Cm7 against
// C7.
//
// Deliberately not finer than that. A reading that told C6 and CΔ7 apart
// would make the second question answer no almost everywhere, and a
// reading that let Cm7 pass for C7 would put the wrong 3rd under
// somebody's solo.

import 'chord.dart';

/// How a chord behaves, which is as much as most of the app needs.
enum ChordShape {
  major('Major'),
  minor('Minor'),
  dominant('Dominant'),
  halfDiminished('Half-diminished'),
  diminished('Diminished'),
  suspended('Suspended');

  const ChordShape(this.label);

  final String label;
}

/// What [chord] is, read off its formula rather than its symbol, so every
/// way of writing the same thing lands in the same place.
ChordShape shapeOf(Chord chord) {
  final formula = chord.quality.formula;
  final minorThird = formula.contains('b3');
  final majorThird = formula.contains('3');
  final flatFive = formula.contains('b5');
  final flatSeven = formula.contains('b7');

  // A sus has had its 3rd taken out and replaced, which is the whole of
  // what makes it one. Asked first, because a 7sus has a ♭7 as well and
  // would otherwise read as an ordinary dominant.
  if (formula.contains('4') && !majorThird && !minorThird) {
    return ChordShape.suspended;
  }
  // A diminished 7th's giveaway is the double-flatted 7th, which is the
  // note nothing else has.
  if (formula.contains('bb7')) return ChordShape.diminished;
  if (minorThird && flatFive) {
    // The ♭7 is the whole difference between the two: with it the chord
    // is a ii waiting for its V, without it it is a passing chord.
    return flatSeven ? ChordShape.halfDiminished : ChordShape.diminished;
  }
  if (minorThird) return ChordShape.minor;
  if (flatSeven) return ChordShape.dominant;
  return ChordShape.major;
}

/// Whether [chord] is a dominant 7th of any colour.
///
/// A 7sus counts: it is the same bass going to the same place with the
/// 3rd held back, and everything in the app that cares about dominants
/// cares about where they are going.
bool isDominant(Chord chord) {
  final shape = shapeOf(chord);
  return shape == ChordShape.dominant ||
      (shape == ChordShape.suspended && chord.quality.formula.contains('b7'));
}
