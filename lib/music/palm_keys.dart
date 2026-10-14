// Getting up to the palm keys and back down again.
//
// The top of a saxophone is played with the side of the left palm rather
// than the fingers, and the join is where it falls apart. Below written
// C♯ the fingers are doing ordinary work; above it the hand has to roll
// off them onto three keys it cannot feel for, hold the note steady while
// it does, and roll back. Most players can hit a high F on its own and
// cannot get to one in the middle of a line.
//
// So the exercises here are not palm key exercises. They are ordinary
// scales and arpeggios that happen to run out of the top of the normal
// range, which is the only way the join gets practised in the place it
// actually breaks: on the way past, at tempo, with somewhere to be.
//
// Written pitches throughout. The palm keys are the same written notes on
// every saxophone, alto to baritone, so one set of exercises serves them
// all; what changes is what comes out, and the app already knows that
// from the instrument setting.

import 'chord.dart';
import 'key_order.dart';
import 'scales.dart';

/// The lowest written note the palm keys make: D above the staff.
///
/// Everything below this is fingered. The exercises are built to cross
/// this line rather than to sit above it.
const firstPalmNote = 86;

/// The highest written note these exercises go to: F.
///
/// Not the F♯ above it. That is a side key worked by the right hand, a
/// different problem with a different solution, and putting it in here
/// would mean an exercise that practises two things and teaches neither.
const topPalmNote = 89;

/// Where the exercises start from, as written pitches: the tonic in the
/// octave below the staff's top, so there is an octave and a half of
/// ordinary playing before the hand has to move.
const _lowestStart = 60;
const _highestStart = 71;

/// The bottom of the horn, written: low B♭.
///
/// Where a run through changes starts from, rather than the middle of
/// the staff. Three chords need most of the instrument to climb through
/// before they reach the palm keys, and started halfway up, a ii–V–I in
/// B used all of it on the ii and the V and stopped before the chord it
/// is named after.
const lowestWritten = 58;

/// One note of an exercise: what to play, what it is called, and what it
/// is doing.
///
/// The degree is the point of the page as much as the join is. A player
/// who gets to a high F by feel and does not know it is the 3rd has
/// learned a stretch rather than a note, and the next tune in a different
/// key starts the learning again.
typedef ExerciseNote = ({int pitch, String name, String degree});

/// A scale or an arpeggio, up into the palm keys and back down.
typedef Exercise = ({List<ExerciseNote> notes, Set<int> palm});

/// What the exercises are built out of.
enum PalmShape {
  major('Major Scale'),
  dominant('Dominant Scale'),
  minor('Minor Scale'),
  triad('Triad'),
  seventh('Seventh Arpeggio'),

  /// The 3rd and 7th of each chord of a ii–V–I: the two notes that say
  /// what the chord is and the two that move when it changes.
  guideTones('Guide Tones'),

  /// Every chord tone of a ii–V–I, climbing through the three chords.
  twoFiveOne('ii–V–I');

  const PalmShape(this.label);

  final String label;

  /// Whether it is built from a chord rather than a scale, which decides
  /// where its notes come from.
  bool get isChord => this == triad || this == seventh;

  /// Whether it runs through changes rather than sitting on one chord.
  ///
  /// The join is harder here than anywhere, which is the reason for it:
  /// the hand has to move while the harmony is moving too, and a note
  /// missed over a V is a note missed in front of everybody.
  bool get isProgression => this == guideTones || this == twoFiveOne;

  /// Which degrees of each chord are played, by number.
  ///
  /// The number, not the spelling: a dominant's seventh is its ♭7 and a
  /// minor chord's third is its ♭3, and asking either of them for a plain
  /// "7" gets a note that is not in the chord.
  List<String> get degrees =>
      this == guideTones ? const ['3', '7'] : const ['1', '3', '5', '7'];
}

/// The exercise in [key] for [shape]: up to the highest note the palm
/// keys reach in that key, and back down to where it started.
///
/// Comes back empty for nothing playable, which cannot happen for the
/// twelve keys but is better than a crash if it ever does.
Exercise palmExercise(String key, PalmShape shape) {
  if (shape.isProgression) return _throughTheChanges(key, shape);
  final steps = _stepsOf(key, shape);
  if (steps.isEmpty) return (notes: const [], palm: const {});

  final start = _startFor(key);
  final up = <ExerciseNote>[];
  Exercise finish() => _upAndDown(_reaching(up, key));
  // Every degree in order, octave after octave, until the next one would
  // be above the top. The last note is therefore always the highest the
  // shape reaches inside the palm keys.
  for (var octave = 0; octave < 4; octave++) {
    for (final (semitones, name, degree) in steps) {
      final pitch = start + semitones + octave * 12;
      if (pitch > topPalmNote) return finish();
      if (pitch >= start) up.add((pitch: pitch, name: name, degree: degree));
    }
  }
  return finish();
}

/// The climb through changes, carried into the palm keys where the next
/// chord tone would have been past the top of them.
///
/// The same problem the scales have and the same answer: a line that
/// stops a semitone below the join is not what this page says it is. It
/// takes the lowest note in the palm range belonging to any of the three
/// chords, so the hand still arrives somewhere the ear accepts.
List<ExerciseNote> _reachingWith(
  List<ExerciseNote> up,
  List<Chord> chords,
  PalmShape shape,
) {
  if (up.isEmpty || up.last.pitch >= firstPalmNote) return up;
  // What the exercise is made of first, and anything in the chords after
  // that. Guide tones in G are C, G, F♯ and B, and not one of them is a
  // D, E♭, E or F: there is no 3rd or 7th up there to land on, and a
  // line that stops below the join is not what this page is about. So it
  // reaches with a chord tone and the degree under it says which.
  for (final degrees in [
    shape.degrees,
    const ['1', '3', '5', '7'],
  ]) {
    for (var pitch = firstPalmNote; pitch <= topPalmNote; pitch++) {
      for (final chord in chords) {
        for (final wanted in degrees) {
          final degree = _asSpelled(chord, wanted);
          if (degree != null && chord.pitchClassFor(degree) == pitch % 12) {
            return [
              ...up,
              (
                pitch: pitch,
                name: chord.noteFor(degree),
                degree: prettyDegree(degree),
              ),
            ];
          }
        }
      }
    }
  }
  return up;
}

/// The climb, carried up to a palm note where it stopped short of one.
///
/// Only one of the sixty exercises needs it: a G♭ triad is G♭ B♭ D♭ and
/// not one of those is a D, E♭, E or F, so it tops out a semitone below
/// the join however far it climbs. An exercise that never reaches the
/// palm keys is not what this page says it is, so it carries on to the
/// lowest note of the key that does. From the D♭ that is a whole tone,
/// which is the join itself and no bad way to meet it.
List<ExerciseNote> _reaching(List<ExerciseNote> up, String key) {
  if (up.isEmpty || up.last.pitch >= firstPalmNote) return up;
  final scale = modes.firstWhere((m) => m.name == 'Ionian');
  final names = scale.notesFrom(key);
  final semitones = scale.semitones;
  final tonic = Chord.parse(key).root % 12;
  for (var pitch = firstPalmNote; pitch <= topPalmNote; pitch++) {
    for (var i = 0; i < semitones.length && i < names.length; i++) {
      if ((tonic + semitones[i]) % 12 == pitch % 12) {
        return [
          ...up,
          (
            pitch: pitch,
            name: names[i],
            degree: prettyDegree(scale.degrees[i]),
          ),
        ];
      }
    }
  }
  return up;
}

/// The way up, then the way back without repeating the top note.
///
/// Both ways on purpose: coming down off the palm keys is the harder of
/// the two and the half everybody leaves out, because an exercise that
/// ends on the high note ends on the bit that went well.
Exercise _upAndDown(List<ExerciseNote> up) {
  if (up.isEmpty) return (notes: const [], palm: const {});
  final notes = [...up, ...up.reversed.skip(1)];
  return (
    notes: notes,
    palm: {
      for (final (index, note) in notes.indexed)
        if (note.pitch >= firstPalmNote) index,
    },
  );
}

/// The tonic to begin on: the one between middle C and the B above it,
/// which leaves room to climb.
///
/// From the key itself rather than from the first interval of the shape,
/// which is always nought and so started every one of the twelve on a C.
int _startFor(String key) {
  final tonic = Chord.parse(key).root % 12;
  for (var pitch = _lowestStart; pitch <= _highestStart; pitch++) {
    if (pitch % 12 == tonic) return pitch;
  }
  return _lowestStart;
}

/// The tonic at the bottom of the horn: the lowest one a saxophone can
/// play, which is where a run through changes begins.
int _lowTonic(String key) {
  final tonic = Chord.parse(key).root % 12;
  for (var pitch = lowestWritten; pitch < lowestWritten + 12; pitch++) {
    if (pitch % 12 == tonic) return pitch;
  }
  return lowestWritten;
}

/// The semitones, spelled names and degrees of one octave of [shape] in
/// [key].
List<(int, String, String)> _stepsOf(String key, PalmShape shape) {
  if (shape.isChord) {
    final chord = Chord.parse(
      '$key${shape == PalmShape.triad ? '' : _seventhOf(key)}',
    );
    final names = chord.noteNames;
    final intervals = chord.quality.intervals;
    final degrees = chord.quality.formula;
    return [
      for (var i = 0; i < names.length && i < intervals.length; i++)
        (intervals[i], names[i], prettyDegree(degrees[i])),
    ];
  }
  final mode = modes.firstWhere((m) => m.name == _modeFor(shape));
  final names = mode.notesFrom(key);
  final semitones = mode.semitones;
  final degrees = mode.degrees;
  return [
    for (var i = 0; i < names.length && i < semitones.length; i++)
      (semitones[i], names[i], prettyDegree(degrees[i])),
  ];
}

/// The lowest tone of [chord] above [from] that this exercise plays.
///
/// Which degree that is depends on where the line has got to, which is
/// how a player gets through changes: you take the nearest note that
/// belongs, not the one that happens to be written first.
ExerciseNote? _nextToneAbove(Chord chord, int from, PalmShape shape) {
  ExerciseNote? best;
  for (final wanted in shape.degrees) {
    final degree = _asSpelled(chord, wanted);
    if (degree == null) continue;
    final pitchClass = chord.pitchClassFor(degree);
    var pitch = from + ((pitchClass - from) % 12);
    if (pitch <= from) pitch += 12;
    if (best == null || pitch < best.pitch) {
      best = (
        pitch: pitch,
        name: chord.noteFor(degree),
        degree: prettyDegree(degree),
      );
    }
  }
  return best;
}

/// How [chord] spells the degree numbered [wanted]: the ♭7 of a dominant
/// rather than the 7 that was asked for, and nothing at all where the
/// chord has no such degree.
String? _asSpelled(Chord chord, String wanted) {
  for (final degree in chord.quality.formula) {
    if (degree.replaceAll(RegExp('[b#]'), '') == wanted) return degree;
  }
  return null;
}

/// The chords a progression exercise runs through, in order.
///
/// Public so the page can name them: an exercise whose degrees say "5"
/// over a chord nobody has been told about is a riddle.
List<Chord> twoFiveOneIn(String key) => _twoFiveOne(key);

/// The chords of a ii–V–I in [key], as a player would call them.
List<Chord> _twoFiveOne(String key) {
  final tonic = Chord.parse(key).root;
  String named(int semitones) => nameInKey(tonic + semitones, key: tonic);
  return [
    Chord.parse('${named(2)}m7'),
    Chord.parse('${named(7)}7'),
    Chord.parse('${named(0)}${_seventhOf(key)}'),
  ];
}

/// A line of chord tones climbing through a ii–V–I until it reaches the
/// palm keys, and back down.
///
/// Round again as many times as it takes: three chords of two or four
/// notes do not reach the top of the horn from the bottom of the staff,
/// so the progression repeats an octave higher each time, which is how
/// anybody practises it anyway.
Exercise _throughTheChanges(String key, PalmShape shape) {
  final chords = _twoFiveOne(key);
  final up = <ExerciseNote>[];
  var from = _lowTonic(key);

  for (var round = 0; round < 4; round++) {
    for (final chord in chords) {
      // The next few chord tones above where the line has got to,
      // whichever degrees those turn out to be, rather than starting
      // every chord on its root. Forcing the root meant a jump of a
      // fifth at each change, and three chords of that do not fit
      // between the bottom of the horn and the palm keys: a ii–V–I came
      // out as a ii–V that never reached the I it is named after.
      for (var i = 0; i < shape.degrees.length; i++) {
        final next = _nextToneAbove(chord, from, shape);
        if (next == null) break;
        if (next.pitch > topPalmNote) {
          return _upAndDown(_reachingWith(up, chords, shape));
        }
        up.add(next);
        from = next.pitch;
      }
    }
  }
  return _upAndDown(_reachingWith(up, chords, shape));
}

String _modeFor(PalmShape shape) => switch (shape) {
  PalmShape.dominant => 'Mixolydian',
  PalmShape.minor => 'Dorian',
  // The progressions never ask: they are built from their chords.
  _ => 'Ionian',
};

/// Which seventh the arpeggio is: a major 7th, because these run up to
/// the tonic and a dominant would put a ♭7 where the ear wants the top.
String _seventhOf(String key) => '^7';
