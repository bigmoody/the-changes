import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guide_tones.dart';
import 'package:play_along/music/tune_library.dart';

/// The guide-tone lines through a progression written the way a player would
/// say it: `through('Dm7 G7 CΔ7')`.
List<GuideTones> through(String progression) => guideTonesThrough([
  for (final symbol in progression.split(' ')) Chord.parse(symbol),
]);

List<String> upperLine(List<GuideTones> lines) => [
  for (final g in lines) g.upper,
];
List<String> lowerLine(List<GuideTones> lines) => [
  for (final g in lines) g.lower,
];
List<int> moves(List<GuideTones> lines) => [
  for (final g in lines) ...[g.upperMove, g.lowerMove],
];

/// Semitones between two pitch classes, the shortest way round. Written out
/// again here rather than shared with the code under test, so the tests
/// measure movement independently of the thing measuring it.
int shortestMove(int from, int to) => (to - from + 6) % 12 - 6;

void main() {
  test('a ii–V–I in C gives the two falling lines players know by ear', () {
    final lines = through('Dm7 G7 CΔ7');

    // The 7th of Dm7 (C) falls a semitone to the 3rd of G7 (B) and stays
    // there; the 3rd of Dm7 (F) is held, then falls to the 3rd of CΔ7 (E).
    expect(upperLine(lines), ['F', 'F', 'E']);
    expect(lowerLine(lines), ['C', 'B', 'B']);

    expect(lines[1].upperHeld, isTrue, reason: 'F is common to Dm7 and G7');
    expect(lines[1].lowerMove, -1, reason: 'C falls to B');
    expect(lines[2].upperMove, -1, reason: 'F falls to E');
    expect(lines[2].lowerHeld, isTrue, reason: 'B is common to G7 and CΔ7');

    // The point of the whole exercise: nothing moves more than a semitone.
    expect(moves(lines).every((m) => m.abs() <= 1), isTrue, reason: '$lines');
  });

  test('a minor ii–V–i walks one line down C, B, A', () {
    final lines = through('Dø7 G7♭9 Cm6');

    expect(upperLine(lines), ['F', 'F', 'E♭']);
    expect(lowerLine(lines), ['C', 'B', 'A']);
    expect(moves(lines).every((m) => m.abs() <= 2), isTrue, reason: '$lines');

    // Cm6 has no 7th, so its 6th carries the line, which is why the chord is
    // written that way in the first place.
    expect(lines.last.lowerDegree, '6');
  });

  test('a cycle of dominants steps down a semitone and never leaps', () {
    final lines = through('E7 A7 D7 G7');

    expect(upperLine(lines), ['G♯', 'G', 'F♯', 'F']);
    expect(lowerLine(lines), ['D', 'C♯', 'C', 'B']);
    for (final g in lines.skip(1)) {
      expect(g.upperMove, -1, reason: '$g');
      expect(g.lowerMove, -1, reason: '$g');
    }
  });

  test('the first chord starts with its 3rd on top and moves nowhere', () {
    final first = through('Dm7 G7 CΔ7').first;
    expect(first.upperDegree, 'b3');
    expect(first.lowerDegree, 'b7');
    expect(first.bothHeld, isTrue);
    expect(first.totalMove, 0);
  });

  test('a 6th chord lends its 6th to the line in place of a 7th', () {
    final lines = through('Dm7 G7 C6');

    expect(lines.last.upper, 'E');
    expect(lines.last.lower, 'A');
    expect(lines.last.upperDegree, '3');
    expect(lines.last.lowerDegree, '6');
    expect(upperLine(lines), ['F', 'F', 'E']);
    expect(lowerLine(lines), ['C', 'B', 'A']);
  });

  test('a sus chord lends its 4th in place of a 3rd, and resolves', () {
    final lines = through('G7sus4 G7 CΔ7');

    expect(lines.first.upperDegree, '4', reason: 'the suspended note');
    // The 4th resolving to the 3rd is the whole reason a sus chord exists,
    // and it should show up as a one-semitone fall in the line.
    expect(upperLine(lines), ['C', 'B', 'B']);
    expect(lowerLine(lines), ['F', 'F', 'E']);
    expect(lines[1].upperMove, -1);
  });

  test('a plain triad has no 7th, so the line rests on its root', () {
    final c = through('C').single;
    expect(c.upper, 'E');
    expect(c.lower, 'C');
    expect(c.lowerDegree, '1');

    // The descending cliché every learner meets: the root walks down while
    // the 3rd is held. It only comes out right if the triad's line starts on
    // the root rather than on the 5th.
    final lines = through('Cm CmΔ7 Cm7 Cm6');
    expect(upperLine(lines), ['E♭', 'E♭', 'E♭', 'E♭']);
    expect(lowerLine(lines), ['C', 'B', 'B♭', 'A']);
    expect(lines.every((g) => g.upperHeld), isTrue, reason: '$lines');
  });

  test('an altered 5th carries the line, since it carries the chord', () {
    // Take the ♯5 away from C+ and nothing is left to tell it from C, so the
    // altered 5th stands in for the missing 7th.
    final augmented = through('C+').single;
    expect(augmented.upper, 'E');
    expect(augmented.lower, 'G♯');

    final diminished = through('C°').single;
    expect(diminished.upper, 'E♭');
    expect(diminished.lower, 'G♭');

    // A sus triad has neither a 3rd nor a 7th and still comes out with two
    // notes rather than an exception.
    final sus = through('Csus4').single;
    expect(sus.upper, 'F');
    expect(sus.lower, 'C');
  });

  test('a progression with nothing in it gives no lines', () {
    expect(guideTonesThrough([]), isEmpty);
  });

  test('every standard in the library comes out as two singable lines', () {
    final library = [...standards, ...practiceProgressions];
    expect(library, isNotEmpty);

    for (final tune in library) {
      final chords = [for (final slot in tune.slots) slot.chord];
      final lines = guideTonesThrough(chords);
      expect(lines, hasLength(chords.length), reason: tune.title);

      for (var i = 0; i < lines.length; i++) {
        final g = lines[i];
        final where = '${tune.title}: ${i == 0 ? '' : '${lines[i - 1]} → '}$g';
        expect(g.upper, isNotEmpty, reason: where);
        expect(g.lower, isNotEmpty, reason: where);
        // Guide tones are sung, not leapt: if the two notes have been put the
        // right way round, neither line ever travels further than a tritone.
        expect(g.upperMove.abs(), lessThanOrEqualTo(6), reason: where);
        expect(g.lowerMove.abs(), lessThanOrEqualTo(6), reason: where);

        // And the way round they were put is the quieter of the two: swapping
        // the lines over would move the pair further, or exactly as far.
        if (i == 0) continue;
        final previous = lines[i - 1];
        int pitch(GuideTones g, String degree) => g.chord.pitchClassFor(degree);
        final fromUpper = pitch(previous, previous.upperDegree);
        final fromLower = pitch(previous, previous.lowerDegree);
        final toUpper = pitch(g, g.upperDegree);
        final toLower = pitch(g, g.lowerDegree);
        expect(g.upperMove, shortestMove(fromUpper, toUpper), reason: where);
        expect(g.lowerMove, shortestMove(fromLower, toLower), reason: where);
        final swapped =
            shortestMove(fromUpper, toLower).abs() +
            shortestMove(fromLower, toUpper).abs();
        expect(g.totalMove, lessThanOrEqualTo(swapped), reason: where);
      }
    }
  });
}
