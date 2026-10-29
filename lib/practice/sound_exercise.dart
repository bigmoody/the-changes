// Sound: long tones, vibrato, a ballad's notes held with the band under
// them, and the edges of the horn.
//
// These used to be a sentence in the routine and a link to the tuner,
// which is a needle and nothing to play. Sound is practised by holding
// notes against something: a drone to sit in tune with, a click to put
// the vibrato against, the chords of a ballad changing under a note. So
// each step here is a row of held notes, written out, with the band
// holding what goes under them and the note you should be on lit.

import '../audio/backing_synth.dart' show SnippetDrum, SnippetNote;
import '../audio/drum_patterns.dart';
import '../music/chart_exercises.dart';
import '../music/guide_tones.dart' show seventhDegreeOf, thirdDegreeOf;
import '../music/scale_run.dart';
import '../music/scales.dart';
import '../music/tune.dart';

/// What one step of a sound exercise plays.
enum SoundWay {
  /// The scale of the day from the middle of the horn outwards, a note
  /// above, a note below, one held note at a time over a drone.
  fan,

  /// The same notes, each grown from nothing to full and back.
  swells,

  /// One note, four bars: no vibrato, then two, three and four pulses a
  /// beat, against a click that plays the pulses.
  vibrato,

  /// The 3rds and 7ths of a ballad's first eight bars, a held note a
  /// chord, the band playing the changes under them.
  balladGuides,

  /// The ballad itself, with the band: not held notes, so the screen
  /// opens the tune instead.
  theMelody,

  /// Down to the bottom of the horn, chromatically, as quiet as it goes.
  bottom,

  /// Up to the top and past it, chromatically, with a full sound.
  top,
}

class SoundStep {
  const SoundStep({required this.title, required this.how, required this.way});

  final String title;

  /// What to listen for while playing it.
  final String how;
  final SoundWay way;
}

/// A block's sound work: its steps, in order.
class SoundExercise {
  const SoundExercise(this.steps);

  final List<SoundStep> steps;
}

/// One held note, as written for the player, with what the band holds
/// under it.
typedef HeldNote = ({
  int pitch,
  String name,

  /// How long it is held, and how long after it to breathe, in beats.
  int beats,
  int rest,

  /// Vibrato pulses a beat, played as a click; 0 for none.
  int pulses,

  /// Said over the note: a dynamic, or how many pulses.
  String? label,

  /// What the band holds under it, as written pitches, lowest first. The
  /// lowest is played on the bass.
  List<int> under,

  /// The chord, when there is one, for the symbol over the note.
  String? chord,
});

/// The ballads The Ballad Sound is played on, one a day in turn.
const soundBallads = [
  'Body and Soul',
  'My Funny Valentine',
  'In a Sentimental Mood',
  'Misty',
];

/// The ballad for [day].
String balladFor(int day) => soundBallads[day % soundBallads.length];

/// Where a horn's held notes centre: the G on the second line, which is
/// the middle of the written range of every horn.
const _middle = 67;

/// [pitchClass] in the octave from [low] up.
int _from(int pitchClass, int low) => low + (pitchClass - low) % 12;

/// The tonic drone under [keyName]: the key note low on the bass and its
/// fifth above, written.
List<int> _drone(String keyName) {
  final ionian = modes.firstWhere((m) => m.name == 'Ionian');
  final run = scaleRun(ionian, keyName, straightRun, octaves: 1, floor: 36);
  final root = run.pitches.first;
  return [root, root + 19];
}

/// The scale of the day, fanned out from the middle: the note nearest the
/// middle, then one above, one below, two above, and so on.
List<({int pitch, String name})> _fanned(String keyName, int count) {
  final ionian = modes.firstWhere((m) => m.name == 'Ionian');
  final run = scaleRun(ionian, keyName, straightRun, octaves: 2, floor: 55);
  final up = [
    for (var i = 0; i <= run.turn; i++)
      (pitch: run.pitches[i], name: run.names[i]),
  ];
  var middle = 0;
  for (final (i, note) in up.indexed) {
    if ((note.pitch - _middle).abs() < (up[middle].pitch - _middle).abs()) {
      middle = i;
    }
  }
  final out = [up[middle]];
  for (var step = 1; out.length < count; step++) {
    if (middle + step < up.length) out.add(up[middle + step]);
    if (out.length < count && middle - step >= 0) out.add(up[middle - step]);
    if (middle + step >= up.length && middle - step < 0) break;
  }
  return out;
}

const _flatNames = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
];

/// Chromatic, from [from] to [to] either way, named in flats, which is how
/// a horn player reads the bottom and the top of the horn.
List<({int pitch, String name})> _chromatic(int from, int to) => [
  for (var p = from; from <= to ? p <= to : p >= to; p += from <= to ? 1 : -1)
    (pitch: p, name: _flatNames[p % 12]),
];

/// The held notes for [way], written for the player.
///
/// [keyName] is today's key, as the player reads it. [ballad] is the
/// ballad's chart already moved into the player's written key, for
/// [SoundWay.balladGuides].
List<HeldNote> heldNotes(SoundWay way, String keyName, {Tune? ballad}) {
  final drone = _drone(keyName);
  HeldNote held(
    ({int pitch, String name}) note, {
    int beats = 6,
    int rest = 2,
    int pulses = 0,
    String? label,
    List<int>? under,
  }) => (
    pitch: note.pitch,
    name: note.name,
    beats: beats,
    rest: rest,
    pulses: pulses,
    label: label,
    under: under ?? drone,
    chord: null,
  );

  switch (way) {
    case SoundWay.fan:
      return [for (final note in _fanned(keyName, 7)) held(note)];
    case SoundWay.swells:
      return [
        for (final note in _fanned(keyName, 5))
          held(note, beats: 8, label: 'p < f > p'),
      ];
    case SoundWay.vibrato:
      final note = _fanned(keyName, 1).single;
      return [
        for (final (pulses, label) in [
          (0, 'None'),
          (2, 'Two a Beat'),
          (3, 'Three a Beat'),
          (4, 'Four a Beat'),
        ])
          held(note, beats: 4, rest: 0, pulses: pulses, label: label),
      ];
    case SoundWay.balladGuides:
      if (ballad == null) return const [];
      return [
        for (final note in exerciseOver(
          ballad,
          ChartExercise.guideTones,
          from: _middle,
        ))
          if (note.beat < 32)
            (
              pitch: note.pitch,
              name: note.name,
              beats: note.length.round(),
              rest: 0,
              pulses: 0,
              label: null,
              // Root on the bass, then the 3rd and 7th in the middle of
              // the piano, so the chord is there without crowding the
              // note being held over it.
              under: [
                _from(note.chord.bass, 36),
                _from(note.chord.pitchClassFor(thirdDegreeOf(note.chord)), 52),
                _from(
                  note.chord.pitchClassFor(seventhDegreeOf(note.chord)),
                  52,
                ),
              ],
              chord: note.chord.display,
            ),
      ];
    case SoundWay.theMelody:
      return const [];
    case SoundWay.bottom:
      // Written E down to the low B♭ of a saxophone.
      return [
        for (final note in _chromatic(64, 58))
          held(note, label: 'pp', under: [drone.first]),
      ];
    case SoundWay.top:
      // Written C above the stave up through the palm keys and into the
      // altissimo, as far as it will go today.
      return [
        for (final note in _chromatic(84, 93))
          held(note, label: 'f', under: [drone.first]),
      ];
  }
}

/// Long tones, the horn's warm-up. Vibrato joins them from stage 3.
SoundExercise longTones(int stage) => SoundExercise([
  const SoundStep(
    title: 'From the Middle Outwards',
    how:
        'Each note held six beats over the drone, then two to breathe. '
        'The same sound on every note, and each one sitting still against '
        'the drone: if it beats against it, you are out of tune.',
    way: SoundWay.fan,
  ),
  const SoundStep(
    title: 'Swells',
    how:
        'Start each note from nothing, grow it to full over four beats and '
        'take it back to nothing over four. The pitch must not move as it '
        'grows: listen to the drone, not to yourself.',
    way: SoundWay.swells,
  ),
  if (stage >= 3)
    const SoundStep(
      title: 'Measured Vibrato',
      how:
          'One note, four bars. No vibrato, then two, three and four '
          'pulses a beat with the click. Even pulses, from the jaw or the '
          'air, never wider than the note.',
      way: SoundWay.vibrato,
    ),
]);

/// The Ballad Sound: vibrato, then a ballad's guide tones held with the
/// band, then the melody.
const balladSound = SoundExercise([
  SoundStep(
    title: 'Measured Vibrato',
    how:
        'One note, four bars: none, then two, three and four pulses a beat '
        'with the click. A ballad uses the slow end, and starts each long '
        'note straight, the vibrato coming in halfway through it.',
    way: SoundWay.vibrato,
  ),
  SoundStep(
    title: 'The Changes Under a Held Note',
    how:
        'The 3rd or 7th of each chord of the first eight bars, held while '
        'the band plays the chord. No gaps between them, the vibrato late '
        'in each note, and every note as full as the last.',
    way: SoundWay.balladGuides,
  ),
  SoundStep(
    title: 'The Melody, Straight',
    how:
        'The melody at 60, with the band, exactly as written: no fills, no '
        'runs. The sound from the last step on every note, vibrato only on '
        'the long ones, and the ends of phrases held for their full '
        'length. Record it, then listen back.',
    way: SoundWay.theMelody,
  ),
]);

/// The edges of the horn: the bottom as soft as it goes, the top as full.
const extremes = SoundExercise([
  SoundStep(
    title: 'The Bottom, Whispered',
    how:
        'Down to the lowest note, chromatically, as quietly as the note '
        'will speak. A low note that only comes out loud is not yet yours. '
        'On a trumpet or trombone, go down to where the horn stops.',
    way: SoundWay.bottom,
  ),
  SoundStep(
    title: 'The Top, Full',
    how:
        'Up from the C above the stave, chromatically, with the same full '
        'sound as the middle. Stop at the first note that thins or goes '
        'sharp, and take it a semitone further next week.',
    way: SoundWay.top,
  ),
]);

/// Beats counted in before the first note.
const soundCountIn = 4;

/// What the band plays for [notes] at [tempo]: a bar counted in, the hi-hat
/// on 2 and 4, what goes under each note held for as long as it is, the
/// note itself on the piano when [guide] is on, and the vibrato's pulses
/// as a click. [down] takes written pitches to concert.
///
/// [starts] is when each note starts, in beats after the count-in.
({
  List<SnippetNote> notes,
  List<SnippetDrum> drums,
  List<int> starts,
  int totalBeats,
})
soundBand(
  List<HeldNote> notes, {
  required int tempo,
  required int down,
  bool guide = true,
}) {
  final starts = <int>[];
  var at = 0;
  for (final note in notes) {
    starts.add(at);
    at += note.beats + note.rest;
  }
  final beat = 60 / tempo;
  final lead = soundCountIn * beat;
  final sound = <SnippetNote>[];
  final drums = <SnippetDrum>[
    for (var b = 0; b < soundCountIn; b++)
      (
        at: b * beat,
        drum: Drum.crossStick,
        velocity: b == 0 ? 0.8 : 0.6,
        hard: b == 0,
      ),
    // The time on 2 and 4, quietly, so a held note still has a pulse to be
    // held against.
    for (var b = 1; b < at; b += 2)
      (at: lead + b * beat, drum: Drum.hiHatPedal, velocity: 0.45, hard: true),
  ];
  for (final (i, note) in notes.indexed) {
    final start = lead + starts[i] * beat;
    final length = note.beats * beat;
    if (guide) {
      sound.add((
        pitch: note.pitch - down,
        start: start,
        length: length * 0.97,
        velocity: 0.42,
        bass: false,
      ));
    }
    // Struck again every two beats: a piano and a bass die away inside
    // three, and a drone that has gone quiet is nothing to tune against.
    for (var k = 0; k < note.beats; k += 2) {
      for (final (j, pitch) in note.under.indexed) {
        sound.add((
          pitch: pitch - down,
          start: start + k * beat,
          length: length - k * beat,
          velocity: (j == 0 ? 0.55 : 0.3) * (k == 0 ? 1 : 0.8),
          bass: j == 0,
        ));
      }
    }
    // The vibrato's pulses, as a click to put them against.
    for (var k = 0; k < note.beats * note.pulses; k++) {
      drums.add((
        at: start + k * beat / note.pulses,
        drum: Drum.crossStick,
        velocity: k % note.pulses == 0 ? 0.45 : 0.3,
        hard: false,
      ));
    }
  }
  return (notes: sound, drums: drums, starts: starts, totalBeats: at);
}
