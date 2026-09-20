// Which pitches a stave's lines carry.
//
// A clef fixes one note to one line, and every other line and space follows
// from it. Pitch is counted here in diatonic steps from C0 — seven to the
// octave, so the black-and-white difference between E and E♭ doesn't come
// into it. A step of 0 is the bottom line, 1 the first space, 8 the top
// line; below the bottom line the steps go negative.
//
// The app plays in treble and bass. The alto and tenor clefs are here for
// the reading guide, which has to show all four.

/// The seven letters, from C, as the steps count them.
const noteLetters = 'CDEFGAB';

enum Clef {
  treble,
  bass,
  alto,
  tenor;

  /// The note on the bottom line, as a diatonic step from C0: E4 for
  /// treble, G2 for bass, F3 for alto, D3 for tenor.
  int get bottomLine => switch (this) {
    treble => 4 * 7 + 2,
    bass => 2 * 7 + 4,
    alto => 3 * 7 + 3,
    tenor => 3 * 7 + 1,
  };

  /// The step its symbol's origin sits on — the line the clef names, which
  /// is where SMuFL puts the origin of every clef glyph.
  int get originStep => switch (this) {
    treble => 2, // the G line, the one its curl wraps
    bass => 6, // the F line, between its two dots
    alto => 4, // middle C, on the middle line
    tenor => 6, // middle C, moved up to the fourth
  };

  /// Its SMuFL symbol. Alto and tenor are the same C clef, moved.
  String get glyph => switch (this) {
    treble => '\u{E050}',
    bass => '\u{E062}',
    alto || tenor => '\u{E05C}',
  };

  String get label => switch (this) {
    treble => 'Treble',
    bass => 'Bass',
    alto => 'Alto',
    tenor => 'Tenor',
  };

  /// What it's called after the letter it fixes.
  String get otherName => switch (this) {
    treble => 'G clef',
    bass => 'F clef',
    alto || tenor => 'C clef',
  };

  /// How far past the stave the clef itself reaches, in steps, so a figure
  /// leaves room for it whatever the notes do.
  ({int low, int high}) get room => switch (this) {
    treble => (low: -4, high: 12),
    bass => (low: 0, high: 9),
    alto || tenor => (low: -1, high: 9),
  };

  /// The note [step] steps up from the bottom line.
  ({String letter, int octave}) noteAt(int step) {
    final diatonic = bottomLine + step;
    return (letter: noteLetters[diatonic % 7], octave: diatonic ~/ 7);
  }

  /// The step a note sits on, e.g. C4 in treble is −2: middle C, one ledger
  /// line below.
  int stepOf(String letter, int octave) =>
      octave * 7 + noteLetters.indexOf(letter) - bottomLine;

  /// The note this clef is named for, where it fixes it.
  ({String letter, int octave}) get fixes {
    final note = noteAt(originStep);
    return note;
  }
}

/// The sharps in the order they're always written, and the flats in the
/// reverse of it.
const sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
const flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];

/// Where a key signature's accidentals go, as steps from the bottom line.
///
/// The positions are fixed by convention rather than worked out — a
/// signature has to look the same every time or it stops being readable at
/// a glance. Treble is the pattern everyone learns, and bass is the same
/// shape a line lower. The C clefs rearrange theirs, and nothing the app
/// draws needs them, so they aren't claimed here.
List<int> keySignatureSteps(
  Clef clef, {
  required int count,
  required bool sharp,
}) {
  assert(
    clef == Clef.treble || clef == Clef.bass,
    'Only the treble and bass patterns are known here',
  );
  const trebleSharps = [8, 5, 9, 6, 3, 7, 4];
  const trebleFlats = [4, 7, 3, 6, 2, 5, 1];
  final shift = clef == Clef.bass ? -2 : 0;
  return [
    for (final step in (sharp ? trebleSharps : trebleFlats).take(count))
      step + shift,
  ];
}
