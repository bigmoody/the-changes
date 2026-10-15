// Exercises generated from a tune's own changes.
//
// Everything else in Learn that works on chord tones works on a cell: a
// ii–V–I, a turnaround, four bars of cycle. That is where you find out
// what the notes are, and it is not where the difficulty is. The
// difficulty turns up when the cell is bar seven of something, arrived at
// from wherever bar six left you, at a tempo.
//
// So these are generated over whatever chart is in front of you, built-in
// or written or imported. Nothing here knows the name of a tune: it reads
// chords and bar lengths and nothing else, which is what makes a tune
// somebody typed in this morning work exactly as well as A Foggy Day.
//
// Five of them, in the order they are worth learning:
//
//  1. Arpeggios. What the notes are, in order, nothing else going on.
//  2. Guide tones. The two notes that say what the chord is, held while
//     the chord changes underneath them.
//  3. Three to seven. The same two notes as a movement: a 7th falling to
//     the next chord's 3rd is most of what makes a line sound like the
//     changes rather than like a scale.
//  4. Bebop scales. Eight notes to the bar so the chord tones keep
//     landing on the beat, bar after bar.
//  5. Enclosures. Arriving at the note you meant by going round it.
//
// The line is voiced as a line: each chord starts from the note nearest
// where the last one finished, so what comes out is playable rather than
// a row of shapes in the same octave.

import 'dart:math' as math;

import 'bebop_scales.dart';
import 'chord.dart';
import 'enclosures.dart';
import 'guide_tones.dart';
import 'tune.dart';
import 'voicings.dart' show degreeIn;

/// One note of a generated exercise.
///
/// [beat] counts from the start of the chorus, so the whole exercise is one
/// list and the screen can cut it into bars however it likes.
typedef ExerciseNote = ({
  int pitch,
  String name,
  String degree,
  double beat,
  double length,
  Chord chord,

  /// The note the exercise is *for*: a guide tone, a resolution, the
  /// target of an enclosure. Drawn in the accent colour.
  bool target,

  /// First note on this chord, so a chord symbol goes over it.
  bool startsChord,
});

/// The range a generated line is written in: G3 to A5, which is a line
/// anybody can play and anybody can read, on either clef.
const exerciseLowest = 55;
const exerciseHighest = 81;
const exerciseHome = 67;

/// The exercises, easiest first.
enum ChartExercise {
  arpeggio(
    'Arpeggios',
    'The chord tones in order, one to a beat. Every note is in the '
        'chord, so the only thing to get right is which notes those are '
        'and where your hand goes next.',
  ),
  guideTones(
    'Guide Tones',
    'The 3rd and the 7th, one held note a chord. They are the two notes '
        'that say what a chord is, and holding one while the chord changes '
        'under it is the first time the changes sound like changes.',
  ),
  threeToSeven(
    '3 to 7',
    'The same two notes as a movement rather than a pair: the 3rd, then '
        'the 7th, then the next chord\'s 3rd. In a ii–V that last step is '
        'a semitone, and hearing it is most of hearing the change.',
  ),
  bebop(
    'Bebop Scales',
    'Eight notes to the bar instead of seven, so the chord tones keep '
        'landing on the beats for as long as you keep going. The extra '
        'note is the whole trick.',
  ),
  enclosure(
    'Enclosures',
    'Arriving at the 3rd of each chord by going round it first. The note '
        'you meant all along turns up sounding inevitable.',
  );

  const ChartExercise(this.label, this.about);

  final String label;
  final String about;

  /// How far through the five this is, for the level the screen shows.
  int get level => index + 1;
}

/// Every chord of [tune] in playing order, with the beats it lasts.
List<ChordSlot> slotsOf(Tune tune) => [for (final bar in tune.bars) ...bar];

/// The exercise for [which] over [tune]'s changes.
///
/// [from] is where the line starts, which the screen moves when somebody
/// wants it in another octave.
List<ExerciseNote> exerciseOver(
  Tune tune,
  ChartExercise which, {
  int from = exerciseHome,
}) {
  final slots = slotsOf(tune);
  if (slots.isEmpty) return const [];
  return switch (which) {
    ChartExercise.arpeggio => _arpeggios(slots, from),
    ChartExercise.guideTones => _guideTones(slots, from),
    ChartExercise.threeToSeven => _threeToSeven(slots, from),
    ChartExercise.bebop => _bebop(slots, from),
    ChartExercise.enclosure => _enclosures(slots, from),
  };
}

// ── Naming ──────────────────────────────────────────────────────────────

const _sharps = [
  'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B', //
];
const _flats = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
];

/// The spelled notes of [chord]'s scale, by pitch class.
Map<int, String> _scaleSpelling(Chord chord) => {
  for (final note in scaleFor(chord))
    if (parseNoteName(note) case final spelling?) pitchClassOf(spelling): note,
};

/// What to call [pitch] over [chord]: the scale's own spelling where it has
/// one, and otherwise a sharp on the way up and a flat on the way down,
/// because that is what the movement is.
String _nameOf(int pitch, Map<int, String> scale, {required bool rising}) =>
    scale[pitch % 12] ?? (rising ? _sharps : _flats)[pitch % 12];

/// [pitchClass] in the octave nearest [near], kept inside the range.
///
/// The range is enforced by [_inRange] and not by a correction of its own.
/// It used to nudge by one octave either way, which is enough when [near]
/// is already in the range and not enough when it is not: a line that had
/// drifted above the top came back to a note still above the top.
int _near(int pitchClass, int near) {
  var pitch = near + ((pitchClass - near) % 12);
  if (pitch - near > 6) pitch -= 12;
  return _inRange(pitch);
}

/// Where to start a shape [spans] semitones tall so the whole of it fits,
/// as near [near] as that allows.
///
/// The shape has to be placed, not its notes. Clamping each note on its
/// own put the top of an arpeggio an octave below the note before it: a
/// C–E♭–G–B♭ whose B♭ was one semitone over the top came out as a shape
/// that climbed and then fell off, and the line stopped being a line.
int _roomFor(int pitchClass, int near, int spans) {
  var root = _near(pitchClass, near);
  while (root + spans > exerciseHighest && root - 12 >= exerciseLowest) {
    root -= 12;
  }
  return root;
}

/// [pitch] moved by octaves until it is inside the range.
int _inRange(int pitch) {
  var moved = pitch;
  while (moved < exerciseLowest) {
    moved += 12;
  }
  while (moved > exerciseHighest) {
    moved -= 12;
  }
  return moved;
}

// ── 1. Arpeggios ────────────────────────────────────────────────────────

List<ExerciseNote> _arpeggios(List<ChordSlot> slots, int from) {
  final notes = <ExerciseNote>[];
  var previous = from;
  var rising = true;
  for (final slot in slots) {
    final chord = slot.chord;
    final scale = _scaleSpelling(chord);
    // Root, 3rd, 5th, 7th: the chord as the chord, in order.
    final tones = chord.quality.intervals.take(4).toList();
    final root = _roomFor(chord.root, previous, tones.last);
    var played = [for (final tone in tones) root + tone];
    // Up through one chord and down through the next, which is how it is
    // practised and what keeps a whole chorus inside one register.
    if (!rising) played = played.reversed.toList();
    final each = slot.beats / played.length;
    for (final (i, pitch) in played.indexed) {
      notes.add((
        pitch: pitch,
        name: _nameOf(pitch, scale, rising: rising),
        degree: degreeIn(chord, pitch),
        beat: slot.startBeat + i * each,
        length: each,
        chord: chord,
        target: false,
        startsChord: i == 0,
      ));
    }
    previous = played.last;
    rising = !rising;
  }
  return notes;
}

// ── 2. Guide tones ──────────────────────────────────────────────────────

List<ExerciseNote> _guideTones(List<ChordSlot> slots, int from) {
  final through = guideTonesThrough([for (final slot in slots) slot.chord]);
  final notes = <ExerciseNote>[];
  var previous = from;
  for (final (i, slot) in slots.indexed) {
    final tones = through[i];
    final chord = slot.chord;
    // The upper line, which is the one to hold first. Voiced nearest the
    // last note, which is the point: the line barely moves.
    final pitch = _near(chord.pitchClassFor(tones.upperDegree), previous);
    notes.add((
      pitch: pitch,
      name: tones.upper,
      degree: tones.upperDegree,
      beat: slot.startBeat.toDouble(),
      // Held for the whole chord: the chord changes, the note does not.
      length: slot.beats.toDouble(),
      chord: chord,
      target: true,
      startsChord: true,
    ));
    previous = pitch;
  }
  return notes;
}

// ── 3. Three to seven ───────────────────────────────────────────────────

List<ExerciseNote> _threeToSeven(List<ChordSlot> slots, int from) {
  final notes = <ExerciseNote>[];
  var previous = from;
  for (final slot in slots) {
    final chord = slot.chord;
    final scale = _scaleSpelling(chord);
    // By degree and not by which line is on top. guideTonesThrough hands
    // back an upper and a lower, which are whichever of the two is higher,
    // so asking it for the 3rd gets the 7th half the time: on Cm7 it came
    // out as ♭7 then ♭3, which is the exercise backwards.
    final thirdDegree = thirdDegreeOf(chord);
    final seventhDegree = seventhDegreeOf(chord);
    // The 3rd first, then the 7th, so the 7th is left sounding into the
    // next chord's 3rd. That hand-over is the exercise.
    final third = _near(chord.pitchClassFor(thirdDegree), previous);
    final seventh = _near(chord.pitchClassFor(seventhDegree), third);
    final half = slot.beats / 2;
    for (final (j, (pitch, degree)) in [
      (third, thirdDegree),
      (seventh, seventhDegree),
    ].indexed) {
      notes.add((
        pitch: pitch,
        name: _nameOf(pitch, scale, rising: true),
        degree: degree,
        beat: slot.startBeat + j * half,
        length: half,
        chord: chord,
        target: true,
        startsChord: j == 0,
      ));
    }
    previous = seventh;
  }
  return notes;
}

// ── 4. Bebop scales ─────────────────────────────────────────────────────

/// [chord]'s scale with a passing note put in, as semitones from the root.
///
/// Eight notes, so a bar of quavers is exactly one octave and the chord
/// tones land on the beats. Which gap the note goes in is worked out from
/// the chord rather than looked up, so a chord the three named bebop
/// scales do not cover gets the same treatment: a half-diminished runs
/// locrian with a natural 7th on top and its ♭5 still lands on a beat.
///
/// Null when the chord has no seven-note scale to build on.
List<int>? bebopDegreesOf(Chord chord) {
  final spelling = _scaleSpelling(chord);
  if (spelling.length < 7) return null;
  final scale = [
    for (final pitchClass in spelling.keys) (pitchClass - chord.root) % 12,
  ]..sort();
  if (scale.length < 7) return null;

  /// The scale with [note] put in, in its place.
  List<int> with_(int note) => [...scale, note]..sort();

  // Where the chord's own four notes sit in the scale. They want to be at
  // 0, 2, 4 and 6, because those are the notes that fall on the beats when
  // eight of them are played to the bar.
  final tones = chord.quality.intervals.take(4).map((i) => i % 12).toList();
  final at = [for (final tone in tones) scale.indexOf(tone)];
  if (at.contains(-1)) return null;

  // The first one in the wrong place decides where the note goes: one
  // note earlier in the scale shifts it and everything after it by one.
  for (var k = 1; k < at.length; k++) {
    if (at[k] == 2 * k) continue;
    // One note can only shift it by one, so it has to be one short.
    if (at[k] != 2 * k - 1) return null;
    final below = scale[at[k] - 1];
    if (scale[at[k]] - below < 2) return null;
    return with_(below + 1);
  }

  // All four already on the beats, so the eighth note goes above the 7th
  // and the scale comes round to the root in a bar.
  if (12 - scale.last >= 2) return with_(scale.last + 1);

  // No room up there, which means the 7th is a major 7th: a semitone
  // under the root. There is no eight-note scale that keeps a major 7th
  // on a beat, so the note goes between the 5th and the 6th instead and
  // the 6th lands on the beat in its place. That is the major bebop
  // scale, and it is why a major tune so often wants a 6 where you
  // expected a Δ7.
  final fifth = scale.indexWhere((semitones) => semitones >= 7);
  if (fifth < 0 || fifth + 1 >= scale.length) return null;
  if (scale[fifth + 1] - scale[fifth] < 2) return null;
  return with_(scale[fifth] + 1);
}

/// The notes of [chord] that a bebop scale over it lands on the beat.
///
/// Its own four, except over a major 7th, where there is no eight-note
/// scale that keeps the 7th on a beat and the 6th stands in for it.
Set<int> bebopBeatTonesOf(Chord chord) {
  final degrees = bebopDegreesOf(chord);
  if (degrees == null) return const {};
  return {for (var i = 0; i < degrees.length; i += 2) degrees[i]};
}

/// Which of the named scales [degrees] is, where it is one of them.
String? bebopNameOf(Chord chord, List<int> degrees) {
  for (final scale in bebopScales) {
    final theirs = semitonesOf(scale.degrees).toList()..sort();
    if (theirs.length == degrees.length) {
      var same = true;
      for (var i = 0; i < theirs.length; i++) {
        if (theirs[i] != degrees[i]) same = false;
      }
      if (same) return scale.name;
    }
  }
  return null;
}

List<ExerciseNote> _bebop(List<ChordSlot> slots, int from) {
  final notes = <ExerciseNote>[];
  var previous = from;
  var rising = true;
  for (final slot in slots) {
    final chord = slot.chord;
    final scale = _scaleSpelling(chord);
    final degrees = bebopDegreesOf(chord);
    if (degrees == null) {
      // Nothing to run: hold the root rather than inventing a scale.
      final pitch = _near(chord.root, previous);
      notes.add((
        pitch: pitch,
        name: _nameOf(pitch, scale, rising: rising),
        degree: '1',
        beat: slot.startBeat.toDouble(),
        length: slot.beats.toDouble(),
        chord: chord,
        target: false,
        startsChord: true,
      ));
      previous = pitch;
      continue;
    }
    // Quavers, eight to a four-beat bar, and the direction turns each
    // chord so a chorus does not climb off the top of the instrument.
    //
    // Coming down it starts on the octave root rather than running the
    // ascending notes backwards. Backwards is wrong and wrong in exactly
    // the way the whole exercise is about: reversing the eight puts the
    // chord tones on the second, fourth, sixth and eighth notes, which is
    // off the beat. From the root down they land on the first, third,
    // fifth and seventh again, because the added note is still sitting
    // between the 7th and the root.
    final root = _roomFor(
      chord.root,
      rising ? previous - 4 : previous + 4,
      rising ? degrees.last : 12,
    );
    final run = rising
        ? [for (final semitones in degrees) root + semitones]
        : [
            root + 12,
            for (final semitones in degrees.reversed.take(degrees.length - 1))
              root + semitones,
          ];
    final each = slot.beats / run.length;
    final tones = chord.quality.intervals.map((i) => i % 12).toSet();
    for (final (i, pitch) in run.indexed) {
      final held = pitch;
      notes.add((
        pitch: held,
        name: _nameOf(held, scale, rising: rising),
        degree: degreeIn(chord, held),
        beat: slot.startBeat + i * each,
        length: each,
        chord: chord,
        // The chord tones, which are the notes that should be landing on
        // the beats: marked so you can see whether they are.
        target: tones.contains((held - chord.root) % 12),
        startsChord: i == 0,
      ));
    }
    // Where the line actually finished, which is the note that was
    // written: tracking the raw run let it wander out of the range and
    // then there was nothing to bring it back from.
    previous = notes.last.pitch;
    rising = !rising;
  }
  return notes;
}

// ── 5. Enclosures ───────────────────────────────────────────────────────

List<ExerciseNote> _enclosures(List<ChordSlot> slots, int from) {
  final notes = <ExerciseNote>[];
  var previous = from;
  for (final (i, slot) in slots.indexed) {
    final chord = slot.chord;
    final scale = _scaleSpelling(chord);
    final spelled = scaleFor(chord);
    // A different one each chord, in the order they are worth knowing,
    // and the same one every time you come back to this bar.
    final shape = enclosures[i % enclosures.length];
    final third = degreeIn(chord, chord.root + chord.quality.intervals[1]);
    final target = _near(
      (chord.root + chord.quality.intervals[1]) % 12,
      previous,
    );
    final line = enclosureOn(
      shape,
      target: target,
      targetName: _nameOf(target, scale, rising: true),
      scale: spelled,
    );
    // The target lands on the chord: everything before it leads in, so it
    // sits in the beats before the change.
    final each = math.min(0.5, slot.beats / line.length);
    final start = slot.startBeat - (line.length - 1) * each;
    for (final (j, note) in line.indexed) {
      final pitch = _inRange(note.pitch);
      notes.add((
        pitch: pitch,
        name: note.name,
        degree: note.isTarget ? third : '',
        beat: start + j * each,
        length: each,
        chord: chord,
        target: note.isTarget,
        startsChord: note.isTarget,
      ));
    }
    previous = target;
  }
  // The first chord's run-in starts before the tune does. Those notes are
  // dropped rather than the whole line being shifted over to make room
  // for them: shifting it put every target a beat after the chord it was
  // arriving at, which is the one thing this exercise must not do. So the
  // first chord gets a shorter way in, and every other target lands on
  // its own change.
  return [
    for (final note in notes)
      if (note.beat >= 0) note,
  ];
}
