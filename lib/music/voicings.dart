// How a chord gets arranged under the hands.
//
// A chord symbol names a set of notes and says nothing about where to
// put them, and where you put them is most of what a chord sounds like.
// The same Cmaj7 can be four notes crammed inside an octave, three notes
// with the root left to the bass, or a spread across a tenth, and those
// are three different sounds rather than three spellings of one.
//
// The names below are the ones players use. They are not a theory: each
// is a rule for moving or dropping one voice, and knowing which one you
// are playing is worth more than being able to name it afterwards.
//
// The rootless forms in here are the ones the app's own pianist plays,
// so the screen that teaches them and the band that uses them cannot
// come to disagree.

import 'chord.dart';

/// The lowest and highest note the comping uses (C3 to E5): the middle of
/// the piano, above the bass. The bottom of a voicing normally sits around
/// [compHome] (B♭3, just below middle C), which is where left-hand rootless
/// voicings live.
const compLowest = 48;
const compHighest = 76;
const compHome = 58;

/// The two standard rootless jazz voicings of [chord], low to high.
///
/// The bass has the root, so the piano plays the notes that give the chord
/// its character: the 3rd and 7th (which say major/minor/dominant), plus the
/// 5th, 6th, 9th or 13th for colour. The two shapes are the usual "A" form
/// (3rd on the bottom) and "B" form (7th on the bottom); alternating between
/// them is how pianists move smoothly from chord to chord.
///
/// The voicings are jazzier than the symbols on the page, as a real player's
/// would be: a plain C becomes a C6/9, a plain Cm becomes a Cm6/9, and a
/// dominant heading for a minor chord ([resolvingTo]) picks up the ♭9 and
/// ♭13 that the ear expects there.
List<List<int>> voicingsFor(Chord chord, {Chord? resolvingTo}) {
  final intervals = chord.quality.intervals;
  bool has(int semitones) => intervals.contains(semitones);

  final third = has(3) ? 3 : (has(4) ? 4 : 5); // minor, major or suspended
  final fifth = has(6) ? 6 : (has(8) ? 8 : 7); // flat, sharp or perfect
  // A plain major or minor triad is played as a 6th chord: nobody comps a
  // bare triad on a standard. Anything odder (sus, diminished, augmented) is
  // left alone, and doubles its root rather than having a 7th invented.
  final isPlainTriad = fifth == 7 && (third == 3 || third == 4);
  final seventh = has(11)
      ? 11
      : has(10)
      ? 10
      : has(9) || isPlainTriad
      ? 9 // a 6th chord: the 6th does the 7th's job
      : 12;
  final isDominant = third == 4 && seventh == 10;

  // A V7 on its way to a minor chord a fifth below takes the tensions that
  // belong there: E7 → Am is voiced as E7♭9♭13.
  final plainDominant = isDominant && !has(13) && !has(15) && !has(20);
  final altered =
      plainDominant &&
      resolvingTo != null &&
      resolvingTo.quality.intervals.contains(3) &&
      (chord.root + 5) % 12 == resolvingTo.root;

  final ninth = has(13) || altered
      ? 13
      : has(15)
      ? 15
      : 14; // flat, sharp or natural 9th
  final thirteenth = has(20) || altered ? 20 : 21; // flat or natural 13th

  // Dominants sound better with the 13th (or the ♯11, if the chord has one)
  // than the plain 5th.
  final colour = has(18) ? 18 : (isDominant ? thirteenth : fifth);
  final degrees = has(6) && has(10)
      ? [third, fifth, seventh, 17] // half-diminished: ♭3 ♭5 ♭7 11
      : [third, colour, seventh, ninth];

  // A form: 3rd at the bottom. B form: 7th at the bottom.
  return [
    _stack(chord.root, [degrees[0], degrees[1], degrees[2], degrees[3]]),
    _stack(chord.root, [degrees[2], degrees[3], degrees[0], degrees[1]]),
  ];
}

/// Stacks [degrees] (semitones above [root]) upwards into a close voicing
/// sitting in the comping range.
List<int> _stack(int root, List<int> degrees) {
  final notes = <int>[];
  var previous = compLowest - 1;
  for (final degree in degrees) {
    final pitchClass = (root + degree) % 12;
    var note = previous + (pitchClass - previous) % 12;
    if (note <= previous) note += 12;
    notes.add(note);
    previous = note;
  }
  // Move the whole shape into the middle of the range.
  while (notes.last > compHighest) {
    for (var i = 0; i < notes.length; i++) {
      notes[i] -= 12;
    }
  }
  return notes;
}

// ── The named arrangements ──────────────────────────────────────────────

/// One note of a voicing: where it sounds, what it is called, which
/// degree of the chord it is, and whether this arrangement moved it.
typedef VoicedNote = ({int pitch, String note, String degree, bool moved});

/// A way of arranging a chord under the hands.
enum Voicing {
  close(
    'Close',
    about:
        'All four notes inside an octave, stacked in thirds: the chord as '
        'a textbook writes it. Useful as the thing everything else is a '
        'change from, and muddy anywhere below middle C, which is why '
        'nobody actually plays it there.',
  ),
  drop2(
    'Drop 2',
    about:
        'Take the second voice down from the top and drop it an octave. '
        'That is the whole technique. It spreads the chord across a '
        'tenth, which opens it up and puts it on four adjacent guitar '
        'strings under one hand, and it is what a saxophone section is '
        'usually playing.',
  ),
  drop3(
    'Drop 3',
    about:
        'The same move on the third voice down instead, which leaves a '
        'bigger hole under the top note. On a guitar it skips a string, '
        'so it suits a chord with the root in the bass.',
  ),
  shell(
    'Shell',
    about:
        'Root, 3rd and 7th, and nothing else. The 3rd and the 7th are '
        'what say major, minor or dominant, so three notes carry the '
        'chord and the missing 5th is never missed. The first voicing '
        'worth learning and the last one you stop using.',
  ),
  rootlessA(
    'Rootless A',
    about:
        'The bass has the root, so the piano leaves it out and plays the '
        'notes that matter, with the 3rd at the bottom. Colour on top: a '
        '6th, 9th or 13th where a textbook would put the 5th.',
  ),
  rootlessB(
    'Rootless B',
    about:
        'The same notes with the 7th at the bottom instead. A pianist '
        'alternates between the two forms so the hand barely moves from '
        'chord to chord, which is what makes comping sound joined up.',
  );

  const Voicing(this.label, {required this.about});

  final String label;
  final String about;

  /// Whether this one is made by moving a voice out of [close] rather
  /// than by leaving notes out.
  bool get isADrop => this == drop2 || this == drop3;

  /// [chord] arranged this way, low to high.
  List<VoicedNote> on(Chord chord) {
    final closeNotes = _close(chord);
    return switch (this) {
      close => closeNotes,
      drop2 => _drop(closeNotes, 2),
      drop3 => _drop(closeNotes, 3),
      shell => _shell(chord),
      rootlessA => _rootless(chord, 0),
      rootlessB => _rootless(chord, 1),
    };
  }
}

/// How far apart the lowest and highest notes are, in semitones.
///
/// The number the drops are for: close position is inside an octave and
/// anything dropped is wider, which is the whole of why it sounds open.
int spanOf(List<VoicedNote> voicing) =>
    voicing.isEmpty ? 0 : voicing.last.pitch - voicing.first.pitch;

/// The degree names a chord tone can have, by semitones above the root.
const _degreeNames = {
  0: 'root',
  1: '♭9th',
  2: '9th',
  3: '♭3rd',
  4: '3rd',
  5: '4th',
  6: '♭5th',
  7: '5th',
  8: '♯5th',
  9: '6th',
  10: '♭7th',
  11: '7th',
};

/// What to call the note [pitch] in [chord].
///
/// A 6th sitting on a chord that already has a 7th is called the 13th,
/// which is what a player would say and what the rootless forms are
/// actually using it as.
String degreeIn(Chord chord, int pitch) {
  final above = (pitch - chord.root) % 12;
  final hasSeventh = chord.quality.intervals.any(
    (i) => i % 12 == 10 || i % 12 == 11,
  );
  if (above == 9 && hasSeventh) return '13th';
  return _degreeNames[above] ?? '';
}

VoicedNote _noteOf(Chord chord, int pitch, {bool moved = false}) => (
  pitch: pitch,
  note: chord.noteFor(_degreeFormula(chord, pitch)),
  degree: degreeIn(chord, pitch),
  moved: moved,
);

/// The formula degree ("3", "b7") for a pitch, so the note spells right.
String _degreeFormula(Chord chord, int pitch) =>
    switch ((pitch - chord.root) % 12) {
      0 => '1',
      1 => 'b9',
      2 => '9',
      3 => 'b3',
      4 => '3',
      5 => '4',
      6 => 'b5',
      7 => '5',
      8 => '#5',
      9 => '6',
      10 => 'b7',
      _ => '7',
    };

/// Root, 3rd, 5th and 7th stacked inside an octave from the root.
List<VoicedNote> _close(Chord chord) {
  final intervals = chord.quality.intervals;
  bool has(int s) => intervals.contains(s);
  final third = has(3) ? 3 : (has(4) ? 4 : 5);
  final fifth = has(6) ? 6 : (has(8) ? 8 : 7);
  final seventh = has(11) ? 11 : (has(10) ? 10 : 9);
  final root = compHome + (chord.root - compHome) % 12;
  return [
    for (final degree in [0, third, fifth, seventh])
      _noteOf(chord, root + degree),
  ];
}

/// [voicing] with the [from]th voice down from the top dropped an octave.
List<VoicedNote> _drop(List<VoicedNote> voicing, int from) {
  final moving = voicing.length - from;
  if (moving < 0) return voicing;
  final dropped = <VoicedNote>[
    for (final (i, note) in voicing.indexed)
      if (i == moving)
        (
          pitch: note.pitch - 12,
          note: note.note,
          degree: note.degree,
          moved: true,
        )
      else
        note,
  ]..sort((a, b) => a.pitch.compareTo(b.pitch));
  return dropped;
}

/// Root, 3rd and 7th: the three notes that say what the chord is.
List<VoicedNote> _shell(Chord chord) {
  final all = _close(chord);
  return [all[0], all[1], all[3]];
}

/// One of the band's own rootless forms, as pitches off [voicingsFor].
List<VoicedNote> _rootless(Chord chord, int form) {
  final forms = voicingsFor(chord);
  final notes = forms[form % forms.length];
  return [for (final pitch in notes) _noteOf(chord, pitch)];
}
