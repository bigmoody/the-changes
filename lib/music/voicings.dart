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

/// The quartal voicings of [chord], low to high, or null for a chord they
/// do not suit.
///
/// Stacked fourths rather than a rootless shell: on a modal tune the
/// rootless voicings are not wrong, they are just not the sound. Sixteen
/// bars of one chord is not held up by saying which chord it is, which is
/// what a 3rd and a 7th are for. It is held up by the colour of the
/// stack, and that is why the record everybody knows this tune from is
/// built on fourths.
///
/// The first form is the "So What" chord itself, as Bill Evans plays it in
/// the answering figure to the head: on D minor, E A D G B, three perfect
/// fourths with a major third on top, which over a bass playing the root
/// is the 9th, 5th, octave, 11th and 13th. In the comping range it lands
/// where he plays it, E3 up to B4. The second is the same stack from the
/// root, so the two can be alternated the way the A and B rootless forms
/// are.
///
/// Only for minor sevenths, which is what a dorian vamp is made of. A
/// fourth stack over a dominant or a major seventh is a different idea
/// and not this one, so those keep the voicings they had.
List<List<int>>? quartalVoicingsFor(Chord chord) {
  final intervals = chord.quality.intervals;
  final isMinorSeventh =
      intervals.contains(3) &&
      intervals.contains(10) &&
      !intervals.contains(6); // a half-diminished is not a dorian chord
  if (!isMinorSeventh) return null;
  // In four keys of the twelve the first form comes out with its bottom
  // note a semitone or two under [compLowest]. That is [_stack] keeping
  // the top note inside the range and letting the bottom give, and it is
  // the right way round: the alternative is the whole shape an octave up,
  // where comping turns shrill. The range was drawn for the four-note
  // rootless voicings, and a five-note stack of fourths is 19 semitones
  // wide where those are 10 or 11, so it does not always have an octave
  // to sit in. Two semitones below C3 is still well clear of the bass.
  return [
    // 9th, 5th, octave, 11th, 13th.
    _stack(chord.root, const [2, 7, 12, 17, 21]),
    // Root, 11th, ♭7th, ♭3rd, 5th: the same shape, started on the root.
    _stack(chord.root, const [0, 5, 10, 15, 19]),
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
    whyCalled:
        'Close because the notes are as close together as they will go. '
        'Stack the chord in thirds from the root and there is no room '
        'left between any two of them.',
    about:
        'All four notes inside an octave, stacked in thirds: the chord as '
        'a textbook writes it. Useful as the thing everything else is a '
        'change from, and muddy anywhere below middle C, which is why '
        'nobody actually plays it there.',
  ),
  drop2(
    'Drop 2',
    whyCalled:
        'The number counts down from the top, which is the only '
        'confusing part of it and the part nobody says out loud. Write '
        'the chord out with the highest note first. Take the second one '
        'down. Drop it an octave. Second from the top, dropped: drop 2.',
    about:
        'Take the second voice down from the top and drop it an octave. '
        'That is the whole technique. It spreads the chord across a '
        'tenth, which opens it up and puts it on four adjacent guitar '
        'strings under one hand, and it is what a saxophone section is '
        'usually playing.',
  ),
  drop3(
    'Drop 3',
    whyCalled:
        'The same counting, one further down: third voice from the top, '
        'dropped an octave. Not the third note up from the bottom, which '
        'is what everybody assumes the first time and which would give '
        'you a different chord.',
    about:
        'The same move on the third voice down instead, which leaves a '
        'bigger hole under the top note. On a guitar it skips a string, '
        'so it suits a chord with the root in the bass.',
  ),
  shell(
    'Shell',
    whyCalled:
        'A shell is what is left when the inside has been taken out. The '
        'root, the 3rd and the 7th are the frame the chord hangs on, and '
        'the 5th and everything above it has been scooped out from '
        'between them.',
    about:
        'Root, 3rd and 7th, and nothing else. The 3rd and the 7th are '
        'what say major, minor or dominant, so three notes carry the '
        'chord and the missing 5th is never missed. The first voicing '
        'worth learning and the last one you stop using.',
  ),
  rootSeventh(
    'Root & 7th',
    whyCalled:
        'A shell with one note taken out of it. Three notes are already '
        'the frame of the chord; two are the frame of the frame, and the '
        'root with the 7th is one of the two ways to do it.',
    about:
        'The left hand a bebop pianist actually plays. Two notes are '
        'enough because the bass has the root anyway and the one note on '
        'top is doing all the work of saying what the chord is.',
  ),
  rootThird(
    'Root & 3rd',
    whyCalled:
        'The other of the two. Same idea, the 3rd on top instead of the '
        '7th, and which one you pick is decided by where the last chord '
        'left your hand rather than by the chord itself.',
    about:
        'Swap between this and the 7th as the chords go past and the top '
        'note barely moves: a ii with its 7th on top, a V with its 3rd, '
        'and the two notes are a semitone apart. That is the whole trick '
        'and it is why a good left hand sounds joined up rather than '
        'jumping about.',
  ),
  rootlessA(
    'Rootless A',
    whyCalled:
        'Rootless because the root is not in it. The bass is already '
        'playing that note, so a pianist who plays it too is doubling '
        'somebody for no reason. A and B are not shapes with meanings, '
        'they are just the two of them, and what tells them apart is '
        'which note is sitting at the bottom.',
    about:
        'The bass has the root, so the piano leaves it out and plays the '
        'notes that matter, with the 3rd at the bottom. Colour on top: a '
        '6th, 9th or 13th where a textbook would put the 5th.',
  ),
  rootlessB(
    'Rootless B',
    whyCalled:
        'The B form, which is the A form with its bottom two notes moved '
        'up an octave. Two shapes, alternated, so the hand stays where it '
        'is while the chords go past underneath it.',
    about:
        'The same notes with the 7th at the bottom instead. A pianist '
        'alternates between the two forms so the hand barely moves from '
        'chord to chord, which is what makes comping sound joined up.',
  );

  const Voicing(this.label, {required this.about, required this.whyCalled});

  final String label;

  /// What it is and where you would use it.
  final String about;

  /// Where the name comes from.
  ///
  /// Worth its own field rather than a sentence buried in [about],
  /// because the names are the part that puts people off: "drop 2"
  /// sounds like jargon until somebody tells you it means the second
  /// voice from the top, dropped, and then it is just a description.
  final String whyCalled;

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
      rootSeventh => _twoNoteShell(chord, seventh: true),
      rootThird => _twoNoteShell(chord, seventh: false),
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

/// The root and one other: the 7th, or the 3rd.
///
/// Two notes, which is what a bebop left hand plays. Whichever of the
/// two is on top carries the chord on its own, so the choice is made by
/// where the hand already is rather than by the chord.
List<VoicedNote> _twoNoteShell(Chord chord, {required bool seventh}) {
  final all = _close(chord);
  return [all[0], seventh ? all[3] : all[1]];
}

/// A run of chords with the two-note shells alternated, so the top note
/// moves as little as it can.
///
/// The point of having two forms. Take the 7th on one chord and the 3rd
/// on the next and the upper voice steps rather than leaps, which is
/// what makes a left hand sound joined up. Where it starts is a choice;
/// after that it alternates.
List<List<VoicedNote>> alternatingShells(
  List<Chord> chords, {
  bool from7th = true,
}) {
  final out = <List<VoicedNote>>[];
  int? previousTop;
  for (final (i, chord) in chords.indexed) {
    final shell = (i.isEven ? from7th : !from7th)
        ? Voicing.rootSeventh.on(chord)
        : Voicing.rootThird.on(chord);
    // Each chord is placed on its own, so left alone the hand would
    // jump an octave between two notes that are a semitone apart. Move
    // the whole shape to wherever its top note is nearest the last one,
    // which is what a hand does without being told.
    var shift = 0;
    if (previousTop != null) {
      final top = shell.last.pitch;
      for (final octave in [-24, -12, 0, 12, 24]) {
        if ((top + octave - previousTop).abs() <
            (top + shift - previousTop).abs()) {
          shift = octave;
        }
      }
    }
    final moved = [
      for (final note in shell)
        (
          pitch: note.pitch + shift,
          note: note.note,
          degree: note.degree,
          moved: note.moved,
        ),
    ];
    previousTop = moved.last.pitch;
    out.add(moved);
  }
  return out;
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
