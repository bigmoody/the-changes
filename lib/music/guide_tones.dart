// Guide-tone lines: the two notes that make the changes audible.
//
// A chord's 3rd says whether it is major or minor, and its 7th says what kind
// of 7th chord it is. Those two notes are the guide tones. The root and the
// 5th can be left to the bass player, but take the 3rd and the 7th away and
// the chord stops saying anything at all.
//
// Take one chord's guide tones, then the next chord's, and they join up into
// two lines that barely move. In a ii–V–I in C the 7th of Dm7 (C) slides a
// semitone down to the 3rd of G7 (B), while the 3rd of Dm7 (F) waits its turn
// and then falls a semitone to the 3rd of CΔ7 (E). Learners practise exactly
// that: holding two quiet lines while the chords change underneath them. What
// is worth showing on the page is therefore not the notes on their own but how
// little each one has to move, and which ones are simply held.
//
// Because the two lines are what matters, each chord's pair has to be put the
// right way round: 3rd on top or 7th on top, whichever keeps the lines still.
// Get that wrong and a ii–V–I comes out as two zig-zags instead of two falling
// lines, which teaches a learner the opposite of the lesson.
//
// [guideTonesThrough] takes chords in playing order: `tune.slots` mapped to
// their chords, or `loopRange.slotsIn(tune)` for the stretch being looped.

import 'chord.dart';

/// One chord's two guide tones, and how each got there from the chord before.
class GuideTones {
  const GuideTones({
    required this.chord,
    required this.upper,
    required this.lower,
    required this.upperDegree,
    required this.lowerDegree,
    required this.upperMove,
    required this.lowerMove,
  });

  final Chord chord;

  /// The spelled note name of the upper line. It is spelled the way this chord
  /// spells it, so the ♭3 of B♭m7 reads D♭ and never C♯.
  final String upper;
  final String lower;

  /// Which degree of the chord [upper] is, written as [ChordQuality.formula]
  /// writes it: usually "3" or "b7", but "6", "4", "#5" and "1" stand in when
  /// the chord hasn't got a 3rd or a 7th. See [guideTonesThrough].
  final String upperDegree;
  final String lowerDegree;

  /// Semitones from the previous chord's upper note: negative for down,
  /// positive for up, counted the shortest way round the octave, because a
  /// line that looks like 11 semitones up is really a semitone down. The first
  /// chord has nothing to move from, so both its moves are 0.
  final int upperMove;
  final int lowerMove;

  /// A held note is the easiest thing a learner can play, and worth pointing
  /// out: the chord changed while the line stood still.
  bool get upperHeld => upperMove == 0;
  bool get lowerHeld => lowerMove == 0;
  bool get bothHeld => upperHeld && lowerHeld;

  /// How far the pair moved in total. Small is the whole point, so this is the
  /// number to sort or grade by.
  int get totalMove => upperMove.abs() + lowerMove.abs();

  /// Reads like "G7 F held / B ↓1", which is what a failing test (or a
  /// debug print) needs to show.
  @override
  String toString() =>
      '${chord.display} $upper ${_moveLabel(upperMove)} / '
      '$lower ${_moveLabel(lowerMove)}';
}

String _moveLabel(int move) => switch (move) {
  0 => 'held',
  < 0 => '↓${-move}',
  _ => '↑$move',
};

/// The two guide-tone lines through [chords], in playing order: one
/// [GuideTones] per chord, carrying its two notes and how far each line had to
/// move to reach them. An empty list in gives an empty list out.
///
/// Each chord contributes its 3rd and its 7th, taken from its own formula so
/// they come out spelled as the chord spells them. Not every chord has both,
/// and a line cannot stop halfway through a tune, so two stand-ins are used
/// (see [thirdDegreeOf] and [seventhDegreeOf] for exactly which).
///
/// The two notes are then put round the way that keeps the lines still: of the
/// two possible assignments (3rd on top or 7th on top), the one whose total
/// movement from the previous chord is smaller wins. That single decision is
/// what turns a ii–V–I into two smooth falling lines. When the two are equally
/// small the lines are left as they were, so they don't swap roles for
/// nothing, and the very first chord, having nothing to move from, starts with
/// the 3rd on top, which is how these lines are conventionally written.
List<GuideTones> guideTonesThrough(List<Chord> chords) {
  final lines = <GuideTones>[];

  // The previous chord's two notes, as pitch classes, because movement is
  // heard as an interval and not as a spelling: G♯ to A♭ is no move at all.
  int? previousUpper;
  int? previousLower;
  var upperHasThird = true;

  for (final chord in chords) {
    final thirdDegree = thirdDegreeOf(chord);
    final seventhDegree = seventhDegreeOf(chord);
    final thirdPitch = chord.pitchClassFor(thirdDegree);
    final seventhPitch = chord.pitchClassFor(seventhDegree);

    var thirdOnTop = true;
    var upperMove = 0;
    var lowerMove = 0;
    if (previousUpper != null && previousLower != null) {
      final thirdOnTopUpper = _move(previousUpper, thirdPitch);
      final thirdOnTopLower = _move(previousLower, seventhPitch);
      final seventhOnTopUpper = _move(previousUpper, seventhPitch);
      final seventhOnTopLower = _move(previousLower, thirdPitch);
      final thirdOnTopCost = thirdOnTopUpper.abs() + thirdOnTopLower.abs();
      final seventhOnTopCost =
          seventhOnTopUpper.abs() + seventhOnTopLower.abs();
      thirdOnTop = thirdOnTopCost == seventhOnTopCost
          ? upperHasThird
          : thirdOnTopCost < seventhOnTopCost;
      upperMove = thirdOnTop ? thirdOnTopUpper : seventhOnTopUpper;
      lowerMove = thirdOnTop ? thirdOnTopLower : seventhOnTopLower;
    }

    final upperDegree = thirdOnTop ? thirdDegree : seventhDegree;
    final lowerDegree = thirdOnTop ? seventhDegree : thirdDegree;
    lines.add(
      GuideTones(
        chord: chord,
        upper: chord.noteFor(upperDegree),
        lower: chord.noteFor(lowerDegree),
        upperDegree: upperDegree,
        lowerDegree: lowerDegree,
        upperMove: upperMove,
        lowerMove: lowerMove,
      ),
    );

    previousUpper = thirdOnTop ? thirdPitch : seventhPitch;
    previousLower = thirdOnTop ? seventhPitch : thirdPitch;
    upperHasThird = thirdOnTop;
  }

  return lines;
}

/// Semitones from pitch class [from] to pitch class [to], the shortest way
/// round: -6 (down a tritone) to +5. Guide tones are sung, not leapt, so an
/// upward move of 11 semitones is really a downward semitone and is recorded
/// as -1. A tritone is reported as a fall, since it has to be one or the other.
int _move(int from, int to) => (to - from + 6) % 12 - 6;

int _number(String degree) => int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));

/// The degree of [chord] numbered [number] ("b3" for 3 of a minor chord), or
/// null if the chord hasn't got one.
String? _degreeNumbered(Chord chord, int number) {
  for (final degree in chord.quality.formula) {
    if (_number(degree) == number) return degree;
  }
  return null;
}

/// The degree the upper guide tone is built on: the 3rd, or for a sus chord
/// (which has deliberately replaced its 3rd with the 4th), the 4th, since that
/// suspended note is the one the ear is waiting on and the one that resolves.
/// The root is a last resort for a chord with neither, so that nothing throws.
String thirdDegreeOf(Chord chord) =>
    _degreeNumbered(chord, 3) ?? _degreeNumbered(chord, 4) ?? '1';

/// The degree the other guide tone is built on: the 7th, or the 6th when there
/// isn't one, because a 6th chord uses its 6th exactly where a 7th chord uses
/// its 7th (C6 and CΔ7 are the same chord wearing different hats).
///
/// A plain triad has neither, and the line still has to land on a note the
/// chord contains, so:
///  • An altered 5th is taken next, because on an augmented or diminished
///    triad the ♯5 or ♭5 is the note carrying the quality: the guide tone in
///    all but name. Without it C+ would be indistinguishable from C.
///  • Otherwise the root, not the plain 5th. A plain 5th adds nothing the 3rd
///    hasn't already said, and it sits a tritone or a 4th away from where the
///    7ths on either side of it live, which makes the line leap. The root sits
///    right beside them, and it is where the classic descending lines actually
///    start: Cm, CmΔ7, Cm7, Cm6 is the line C–B–B♭–A.
String seventhDegreeOf(Chord chord) {
  final fifth = _degreeNumbered(chord, 5);
  return _degreeNumbered(chord, 7) ??
      _degreeNumbered(chord, 6) ??
      (fifth != null && fifth != '5' ? fifth : '1');
}
