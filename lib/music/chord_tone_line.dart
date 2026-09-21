// Chord tones through a whole form, one note at a time.
//
// A piano player meets a chord and puts a shape on it. A horn player meets
// the same chord holding one note, somewhere in the middle of the horn,
// with the chord before it still in the air. The question is never what
// the notes of the chord are. It is which of them is nearest, and which
// way to go from there.
//
// That question only turns up over a form. A ii-V-I on its own is three
// chords and no problem. Twelve bars of blues is eleven changes coming at
// you with nowhere to stop and work anything out, and a rhythm tune
// changes chord every two beats for thirty-two bars. So what is built here
// is a whole chorus: one chord tone on every beat, for as long as each
// chord lasts, from the first bar to the last.
//
// The exercises differ only in how each chord's run is started, and that
// is the whole lesson. Start every chord on its root and the line leaps
// about, because the roots do. Start on whichever chord tone is nearest
// the note you just played and the line walks, because two chords a fourth
// apart have more in common than not. Nothing here has to claim that: both
// lines get measured, and the numbers say it.
//
// Everything is worked out at concert pitch, in a concert range, so that
// every player practises the same notes and the measurements of a line
// are the same whoever is reading it. [writtenFor] then moves the writing
// into the key the player reads. That way round rather than the other:
// working it out in the written key would hand a tenor and an alto
// different exercises over the same twelve bars, and the numbers under
// them would disagree.

import 'chord.dart';
import 'guide_tones.dart' show seventhDegreeOf, thirdDegreeOf;
import 'tune.dart';

/// How each chord's run of notes is started.
enum ToneExercise {
  fromTheRoot(
    'From the Root',
    'Every chord from its root, up through the arpeggio. This is what '
        'everybody does first, and it is worth playing once so you can hear '
        'what is wrong with it: the line jumps to wherever the next root is '
        'instead of going anywhere.',
  ),
  nearest(
    'Nearest Note',
    'When the chord changes, take whichever of its notes is nearest the '
        'one you just played and keep going the same way. Nothing else '
        'changes. The line stops leaping about and starts sounding like a '
        'line, and you are still playing nothing but chord tones.',
  ),
  upAndDown(
    'Up and Down',
    'The same nearest note, but turning round at every chord. It keeps you '
        'in one part of the horn instead of climbing out of it, and the '
        'turns are where the line stops sounding like an exercise.',
  ),
  landOnTheThird(
    'Land on the 3rd',
    'One note per chord: its 3rd, and nothing else. The 3rd is the note '
        'that says major or minor, so this is the smallest thing you can '
        'play that still spells the changes out loud.',
  ),
  landOnTheSeventh(
    'Land on the 7th',
    'The same again on the 7th. Over a run of dominants each 7th is a '
        'semitone above the next chord\'s 3rd, so once you can do both you '
        'have the two lines that bebop is mostly made of.',
  );

  const ToneExercise(this.label, this.about);

  final String label;
  final String about;

  /// Whether this plays one note per chord rather than one per beat.
  bool get lands => this == landOnTheThird || this == landOnTheSeventh;

  /// Whether it works out where to start from the note before it.
  bool get connects => this != fromTheRoot;
}

/// One note of the exercise.
typedef ToneNote = ({
  Chord chord,

  /// Concert pitch, as MIDI: middle C is 60.
  int pitch,

  /// Spelled as the chord spells it, so the ♭3 of B♭m7 reads D♭.
  String name,

  /// Which degree of the chord it is, as [ChordQuality.formula] writes it.
  String degree,

  /// 0-based, counted from the start of the form.
  int bar,

  /// 0-based, within the bar.
  int beat,

  /// How long it is held, in beats. One, except in the landing exercises,
  /// where the note lasts as long as its chord.
  int beats,

  /// Whether this is the first note on its chord, which is where the
  /// interesting thing happens.
  bool opens,

  /// Semitones from the note before it, signed. Zero on the first note of
  /// the line, which has nothing to have come from.
  int step,
});

/// The degrees of [chord] an arpeggio is made of, lowest first: its root,
/// 3rd, 5th and 7th as the chord's own formula spells them.
///
/// Read off the formula rather than assumed, so a sus chord gives the 4th
/// it has deliberately put in place of its 3rd, and a 6th chord gives its
/// 6th. Anything past the 7th is an extension, which is a different
/// lesson, and a chord with no 5th in it (an altered dominant) simply has
/// three notes here instead of four.
List<String> arpeggioDegrees(Chord chord) {
  final degrees = [
    for (final degree in chord.quality.formula)
      if (_number(degree) <= 7) degree,
  ];
  degrees.sort((a, b) => degreeToSemitones(a).compareTo(degreeToSemitones(b)));
  return degrees;
}

int _number(String degree) => int.parse(degree.replaceAll(RegExp(r'[b#]'), ''));

/// The degree a landing exercise aims at on [chord]: its 3rd, or its 7th.
///
/// Which note stands in when a chord hasn't got one is decided in
/// [thirdDegreeOf] and [seventhDegreeOf], where the guide-tone lines decide
/// it, because it is the same question and two answers to it would show up
/// as two screens disagreeing about B♭6.
String landingDegree(Chord chord, ToneExercise exercise) =>
    exercise == ToneExercise.landOnTheThird
    ? thirdDegreeOf(chord)
    : seventhDegreeOf(chord);

/// [line] as the player reads it, moved by [move].
///
/// Only the writing changes: the notes are the same sounds in the same
/// order, so a transposing instrument's part sits higher or lower on the
/// stave than a concert one, exactly as a real part does. Each note is
/// respelled by its own degree of the moved chord, so the ♭3 of the
/// transposed chord is spelled as that chord spells it.
List<ToneNote> writtenFor(List<ToneNote> line, Transposition move) => [
  for (final note in line)
    (
      chord: note.chord.transposed(move),
      pitch: note.pitch + move.semitones,
      name: note.chord.transposed(move).noteFor(note.degree),
      degree: note.degree,
      bar: note.bar,
      beat: note.beat,
      beats: note.beats,
      opens: note.opens,
      step: note.step,
    ),
];

/// A chord tone and the pitch it sits at.
typedef _Rung = ({int pitch, String degree});

/// Every chord tone of [chord] between [low] and [high], in order: the
/// arpeggio as a ladder to climb, rather than one octave of it.
///
/// Built by walking the pitches rather than by stacking intervals, because
/// what a run needs is to carry on past the 7th into the next octave
/// without any special case for the joint.
List<_Rung> _ladder(Chord chord, int low, int high) {
  final byOffset = {
    for (final degree in arpeggioDegrees(chord))
      degreeToSemitones(degree) % 12: degree,
  };
  return [
    for (var pitch = low; pitch <= high; pitch++)
      if (byOffset[(pitch - chord.root) % 12] case final degree?)
        (pitch: pitch, degree: degree),
  ];
}

/// Where on [ladder] to start, given the note just played and the way the
/// line is travelling: the first rung at or above [from] going up, or the
/// last at or below it going down.
///
/// At or above rather than strictly above, so that when the new chord
/// contains the note you are already on, you stay on it. That is the best
/// thing that can happen at a chord change and it would be a shame to step
/// off it for the sake of movement.
int _startFrom(List<_Rung> ladder, int from, int direction) {
  if (direction > 0) {
    for (var i = 0; i < ladder.length; i++) {
      if (ladder[i].pitch >= from) return i;
    }
    return ladder.length - 1;
  }
  for (var i = ladder.length - 1; i >= 0; i--) {
    if (ladder[i].pitch <= from) return i;
  }
  return 0;
}

/// [exercise] played through [slots], as a line of notes at concert pitch.
///
/// [low] and [high] are the range to stay inside. The default is the
/// octave and a half in the middle of a treble stave, which is where a
/// horn sounds like itself and where a singer can follow what you are
/// doing. The line turns round rather than climbing out of it.
///
/// Slots come in playing order: `tune.slots`, or the slots of one section.
/// One note per beat of every chord, so a chord lasting two beats gets two
/// notes and the exercise never has to be told what the time signature is.
List<ToneNote> chordToneLine(
  List<ChordSlot> slots, {
  required ToneExercise exercise,
  int low = 55,
  int high = 79,
  int beatsPerBar = 4,
}) {
  final line = <ToneNote>[];
  final centre = (low + high) ~/ 2;
  var direction = 1;
  int? last;

  for (final slot in slots) {
    final chord = slot.chord;
    // An octave of room either side, so a run that overshoots still has
    // rungs under it and the turning round is decided by the range rather
    // than by falling off the end of a list.
    final ladder = _ladder(chord, low - 24, high + 24);
    if (ladder.isEmpty) continue;
    final beatInBar = slot.startBeat % beatsPerBar;

    if (exercise.lands) {
      final degree = landingDegree(chord, exercise);
      final pitchClass = chord.pitchClassFor(degree);
      final pitch = _nearest(last ?? centre, pitchClass, low, high);
      line.add((
        chord: chord,
        pitch: pitch,
        name: chord.noteFor(degree),
        degree: degree,
        bar: slot.barIndex,
        beat: beatInBar,
        beats: slot.beats,
        opens: true,
        step: last == null ? 0 : pitch - last,
      ));
      last = pitch;
      continue;
    }

    if (exercise == ToneExercise.upAndDown && last != null) {
      direction = -direction;
    }

    List<_Rung> run(int at, int way) => [
      for (var i = 0; i < slot.beats; i++)
        if (at + i * way >= 0 && at + i * way < ladder.length)
          ladder[at + i * way],
    ];

    /// How far a run strays outside the range, in semitones. Zero is a run
    /// that fits.
    int outside(List<_Rung> notes) => notes.fold(
      0,
      (sum, rung) =>
          sum +
          (rung.pitch < low
              ? low - rung.pitch
              : rung.pitch > high
              ? rung.pitch - high
              : 0),
    );

    List<_Rung> notes;
    if (exercise.connects) {
      final from = last ?? centre;
      // In the order they are wanted. The first two carry on from the note
      // just played, which is the exercise; the last two give up on that
      // and start at the edge of the range instead, which is what has to
      // happen when the range is too narrow to hold the arpeggio anywhere
      // near where the line already is. Turning round at the edge is the
      // point, so it comes before starting somewhere else entirely.
      final tries = [
        (direction, run(_startFrom(ladder, from, direction), direction)),
        (-direction, run(_startFrom(ladder, from, -direction), -direction)),
        (1, run(_startFrom(ladder, low, 1), 1)),
        (-1, run(_startFrom(ladder, high, -1), -1)),
      ];
      // The first that fits, or failing that the one that strays least,
      // which is what brings a line back. Keeping the first attempt come
      // what may would let it climb further out on every chord and never
      // return, which is what it did before this was here.
      var best = tries.first;
      for (final candidate in tries) {
        if (outside(candidate.$2) == 0) {
          best = candidate;
          break;
        }
        if (outside(candidate.$2) < outside(best.$2)) best = candidate;
      }
      direction = best.$1;
      notes = best.$2;
    } else {
      // From the root, always upwards, from the root in the octave nearest
      // the middle of the range: a player who is not thinking about where
      // the last note left them is not thinking about the range either.
      // The arpeggio is allowed to climb out of the top rather than being
      // tidied into it, because climbing out of the top is one of the
      // things wrong with the exercise and hiding it would be cheating in
      // favour of the answer.
      direction = 1;
      notes = run(_startFrom(ladder, _rootNear(ladder, chord, centre), 1), 1);
    }

    for (final (i, rung) in notes.indexed) {
      line.add((
        chord: chord,
        pitch: rung.pitch,
        name: chord.noteFor(rung.degree),
        degree: rung.degree,
        bar: slot.barIndex,
        beat: beatInBar + i,
        beats: 1,
        opens: i == 0,
        step: last == null ? 0 : rung.pitch - last,
      ));
      last = rung.pitch;
    }
  }

  return line;
}

/// The root of [chord] in the octave nearest [about], as a pitch on
/// [ladder].
int _rootNear(List<_Rung> ladder, Chord chord, int about) {
  final roots = [
    for (final rung in ladder)
      if ((rung.pitch - chord.root) % 12 == 0) rung.pitch,
  ];
  if (roots.isEmpty) return about;
  return roots.reduce((a, b) => (a - about).abs() <= (b - about).abs() ? a : b);
}

/// The pitch of [pitchClass] nearest [about], kept inside [low] to [high].
int _nearest(int about, int pitchClass, int low, int high) {
  var pitch = about + ((pitchClass - about) + 6) % 12 - 6;
  while (pitch < low) {
    pitch += 12;
  }
  while (pitch > high) {
    pitch -= 12;
  }
  return pitch;
}

// ── What the line turns out to be ──────────────────────────────────────
//
// The screen shows these rather than saying the nearest note is smoother,
// so that if it ever stops being true the page stops saying it.

/// The notes where a new chord starts, leaving out the very first, which
/// nobody had to get to from anywhere.
List<ToneNote> changesIn(List<ToneNote> line) => [
  for (final (i, note) in line.indexed)
    if (i > 0 && note.opens) note,
];

/// The biggest distance between two notes next to each other, anywhere.
int biggestJump(List<ToneNote> line) => line
    .skip(1)
    .fold(
      0,
      (worst, note) => note.step.abs() > worst ? note.step.abs() : worst,
    );

/// The biggest distance across a chord change, which is the one that
/// matters: inside a chord you are only running an arpeggio.
int biggestJumpAtChanges(List<ToneNote> line) => changesIn(
  line,
).fold(0, (worst, note) => note.step.abs() > worst ? note.step.abs() : worst);

/// How many changes are crossed by [semitones] or less. A tone or less is
/// a step rather than a jump, and a step is what you can play at speed.
int changesWithin(List<ToneNote> line, int semitones) =>
    changesIn(line).where((note) => note.step.abs() <= semitones).length;

/// The lowest and highest notes the line touches.
(int, int) rangeOf(List<ToneNote> line) {
  if (line.isEmpty) return (0, 0);
  var low = line.first.pitch;
  var high = line.first.pitch;
  for (final note in line) {
    if (note.pitch < low) low = note.pitch;
    if (note.pitch > high) high = note.pitch;
  }
  return (low, high);
}
