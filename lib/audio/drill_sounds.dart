// What the chord-tone drills play when you ask to hear a question.
//
// Before you answer, you hear just the chord, so the sound can guide you
// without giving the answer away. Afterwards:
//  • Spell it plays the chord, then its notes one by one, low to high.
//  • Aim for plays the chord with the target note on top of it, so you hear
//    the colour that note gives the chord, which is the point of aiming for it.
//
// Everything sounds at concert pitch: a trumpet player's written D7 comes out
// as a concert C7, the same as the band would play under them.

import 'dart:math' as math;

import '../music/chord.dart';
import '../music/chord_drill.dart';
import '../music/fretboard_arpeggio.dart';
import 'backing_synth.dart';
import 'piano_comping.dart';

/// The notes for hearing [question]. [concertShift] is how far concert pitch
/// is from what's written (−2 for a B♭ instrument).
List<SnippetNote> drillSnippet(
  DrillQuestion question, {
  required int concertShift,
  required bool withAnswer,
}) {
  final chord = question.chord;
  final root = (chord.root + concertShift) % 12;
  final intervals = chord.quality.intervals;

  SnippetNote note(
    int pitch,
    double start,
    double length, {
    bool bass = false,
  }) => (pitch: pitch, start: start, length: length, velocity: 0.8, bass: bass);

  // The chord in close position, G3 to F♯4, over the root in the bass.
  final voicing = [
    for (final interval in intervals) 55 + ((root + interval - 55) % 12),
  ]..sort();
  final chordLength = withAnswer && question.mode == DrillMode.aim ? 2.4 : 1.4;
  final notes = <SnippetNote>[
    note(36 + root, 0, chordLength, bass: true),
    for (final pitch in voicing) note(pitch, 0, chordLength),
  ];
  if (!withAnswer) return notes;

  if (question.mode == DrillMode.spell) {
    // Up through the chord from the root, a note every 0.3 s.
    var pitch = 48 + root;
    var start = 1.5;
    for (final degree in question.degrees) {
      final target = (root + degreeToSemitones(degree)) % 12;
      if (degree != question.degrees.first) {
        pitch += (target - pitch) % 12 == 0 ? 12 : (target - pitch) % 12;
      }
      notes.add(note(pitch, start, 0.5));
      start += 0.3;
    }
  } else {
    // The target note(s) above the chord, arriving a moment after it.
    var top = voicing.last;
    for (final degree in question.degrees) {
      final target = (root + degreeToSemitones(degree)) % 12;
      final pitch = top + 1 + ((target - top - 1) % 12);
      notes.add(note(pitch, 0.6, 1.8));
      top = pitch;
    }
  }
  return notes;
}

/// [chord] (at concert pitch) as an arpeggio: up from the root through
/// every note of the chord to the octave, back down, then all together over
/// the root in the bass, what the Chord tones page plays.
List<SnippetNote> chordArpeggioSnippet(Chord chord) {
  // The root between C3 and B3, so the chord sits around middle C.
  final root = 48 + chord.root % 12;
  final up = <int>{
    for (final degree in chord.quality.formula)
      root + degreeToSemitones(degree),
  }.toList()..sort();
  final top = up.last > root + 12 ? up.last : root + 12;
  final line = [...up, if (!up.contains(top)) top];
  final down = line.reversed.skip(1).toList();

  const step = 0.24;
  final notes = <SnippetNote>[];
  var start = 0.0;
  for (final pitch in [...line, ...down]) {
    notes.add((
      pitch: pitch,
      start: start,
      length: step * 1.6,
      velocity: 0.75,
      bass: false,
    ));
    start += step;
  }
  // Then the whole chord, ringing.
  start += 0.1;
  notes.add((
    pitch: root - 12,
    start: start,
    length: 1.6,
    velocity: 0.8,
    bass: true,
  ));
  for (final pitch in up) {
    notes.add((
      pitch: pitch,
      start: start,
      length: 1.6,
      velocity: 0.7,
      bass: false,
    ));
  }
  return notes;
}

/// A mode (its [semitones] above [root], at concert pitch) as the Scales &
/// modes page plays it: just the scale, up an octave and back down, the
/// last note left to ring.
/// A few chords in time, each voiced with a root under it: what the ear
/// training plays.
///
/// Voiced by the band's own comper, so what is heard is what the band
/// would play rather than a stack of thirds nobody uses. It hands each
/// chord the next one, which is what makes the top voice move by step
/// instead of jumping: a ii-V-I has to sound like a ii-V-I and not like
/// three chords that happen to be next to each other.
///
/// The last chord rings on, because a progression that stops dead sounds
/// like a mistake and the ear spends its time on that instead of on the
/// harmony.
List<SnippetNote> progressionSnippet(
  List<Chord> chords, {
  int tempo = 100,
  double beatsEach = 2,
  int seed = 1,
}) {
  if (chords.isEmpty || tempo <= 0) return const [];
  final comper = Comper(math.Random(seed));
  final step = beatsEach * 60 / tempo;
  final notes = <SnippetNote>[];
  for (final (i, chord) in chords.indexed) {
    final last = i == chords.length - 1;
    final voicing = comper.voice(chord, last ? null : chords[i + 1]);
    final length = last ? step + 1.4 : step * 0.98;
    for (final pitch in voicing) {
      notes.add((
        pitch: pitch,
        start: i * step,
        length: length,
        velocity: 0.7,
        bass: false,
      ));
    }
    // The root underneath, so the movement is audible in the bass as
    // well as in the voicing. Half of hearing a tritone sub is hearing
    // the bass slide down by one.
    notes.add((
      pitch: 36 + chord.root % 12,
      start: i * step,
      length: length,
      velocity: 0.8,
      bass: true,
    ));
  }
  return notes;
}

/// A run of [pitches], evenly spaced, as a snippet.
///
/// For a scale played in a shape rather than straight up, where the line
/// is worked out elsewhere and this only has to sound it. The last note
/// is held, because a pattern that stops dead sounds like a mistake
/// rather than an ending.
List<SnippetNote> runSnippet(
  List<int> pitches, {
  double step = 0.2,
  bool bass = false,
}) => [
  for (final (i, pitch) in pitches.indexed)
    (
      pitch: pitch,
      start: i * step,
      // A walking line is four even notes, not three and a held one, so
      // the last note rings only when it is not the bass: a bass player
      // stops when the next chord comes.
      length: i == pitches.length - 1 && !bass ? 1.2 : step * 1.5,
      velocity: 0.75,
      bass: bass,
    ),
];

List<SnippetNote> modeSnippet(List<int> semitones, int root) {
  // The root between C4 and B4, so the line sits around middle C.
  final tonic = 60 + root % 12;
  final up = [for (final s in semitones) tonic + s, tonic + 12];
  final line = [...up, ...up.reversed.skip(1)];

  const step = 0.22;
  return [
    for (var i = 0; i < line.length; i++)
      (
        pitch: line[i],
        start: i * step,
        length: i == line.length - 1 ? 1.2 : step * 1.5,
        velocity: 0.75,
        bass: false,
      ),
  ];
}

/// An arpeggio [shape] on the guitar or bass, note by note in the order it's
/// played (up across the strings and back down), the last note left to
/// ring. For [renderSnippet], with `guitar: true` for a guitar shape and
/// `brightBass: true` for a bass one.
List<SnippetNote> fretArpeggioSnippet(FretArpeggio shape) {
  final up = [for (final note in shape.notes) note.pitch];
  final line = [...up, ...up.reversed.skip(1)];
  // The bass unhurried, so each low note has time to speak.
  final step = shape.isBass ? 0.34 : 0.2;
  return [
    for (var i = 0; i < line.length; i++)
      (
        pitch: line[i],
        start: i * step,
        length: i == line.length - 1 ? 1.4 : step * 1.6,
        velocity: 0.8,
        bass: shape.isBass,
      ),
  ];
}
