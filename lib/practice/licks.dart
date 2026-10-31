// Licks in context: the stock phrases of jazz vocabulary, each written
// over the changes it belongs to and played there with a band.
//
// A lick learned on its own is a shape under the fingers. The same lick
// heard over its ii–V, landing on the third of the I as the band arrives
// there, is a sentence, and that is the only form of it that ever turns
// up in a solo. So each one here is a few bars of changes, in today's key,
// with the lick written over them, and the band playing the changes round
// while the lick is played to them: first by the band, then by you.
//
// The notes are written as degrees of whichever chord is sounding (the 3rd
// of G7, the ♭9 of G7), because that is how a lick is understood and how
// it moves to another key: spelled by the chord, so a ♭9 is an A♭ and not
// a G♯.

import 'dart:math' as math;

import '../audio/backing_synth.dart' show SnippetNote, SnippetDrum;
import '../music/chord.dart';
import '../audio/piano_comping.dart';
import '../music/swing.dart';

/// One chord of a lick's changes: on [degree] of the key (a degree of the
/// major scale, "2", "b3", "5"), of [quality], for [beats].
typedef LickChord = ({String degree, String quality, int beats});

/// One note of a lick: [degree] of the chord sounding at [at] (in beats
/// from the start), [octave]s up from where that chord's root sits, held
/// for [length] beats. Beats count straight; the "and"s are swung when it
/// is played.
typedef LickNote = ({double at, double length, String degree, int octave});

class Lick {
  const Lick({
    required this.name,
    required this.about,
    required this.changes,
    required this.notes,
  });

  final String name;

  /// What it is and what to listen for.
  final String about;
  final List<LickChord> changes;
  final List<LickNote> notes;

  int get beats => changes.fold(0, (sum, c) => sum + c.beats);
}

/// A lick's changes in [key], each with the beat it starts on.
List<({Chord chord, double at, int beats})> changesIn(Lick lick, String key) {
  final home = Chord.parse(key);
  var at = 0.0;
  return [
    for (final change in lick.changes)
      () {
        final chord = Chord.parse(
          '${home.noteFor(change.degree)}${change.quality}',
        );
        final out = (chord: chord, at: at, beats: change.beats);
        at += change.beats;
        return out;
      }(),
  ];
}

/// One note of a lick as written in a key.
typedef LickEvent = ({double at, double length, int pitch, String name});

/// [lick] in [key], its roots placed from the first pitch of the key at or
/// above [floor]: each chord's root in the octave above the key's.
List<LickEvent> lickIn(Lick lick, String key, {required int floor}) {
  final changes = changesIn(lick, key);
  final tonic = floor + (Chord.parse(key).root - floor) % 12;
  return [
    for (final note in lick.notes)
      () {
        final sounding = changes.lastWhere((c) => c.at <= note.at + 1e-9);
        final chord = sounding.chord;
        final root = tonic + (chord.root - tonic) % 12;
        return (
          at: note.at,
          length: note.length,
          // A 9th is written where a 2nd would be: the line moves by
          // step, and [LickNote.octave] says when it leaps.
          pitch: root + degreeToSemitones(note.degree) % 12 + 12 * note.octave,
          name: chord.noteFor(note.degree),
        );
      }(),
  ];
}

/// Where a beat lands once swung: the "and" late by as much as a player
/// swings at [tempo].
double _swung(double beat, int tempo) {
  final whole = beat.floorToDouble();
  final part = beat - whole;
  if ((part - 0.5).abs() > 1e-6) return beat;
  return whole + swingAt(tempo);
}

/// When each note of [lick] starts, in swung beats from the top.
List<double> lickStarts(Lick lick, int tempo) => [
  for (final note in lick.notes) _swung(note.at, tempo),
];

/// The band under [lick] in [key], [times] round, from [from] seconds:
/// the piano comping on 1 and the "and" of 2 (the Charleston), the bass
/// walking, and the lick itself on the passes [lickOn] says.
({List<SnippetNote> notes, List<SnippetDrum> drums}) lickBand(
  Lick lick,
  String key, {
  required int tempo,
  required int times,
  required int floor,
  required bool Function(int pass) lickOn,
  double from = 0,
  int down = 0,
  int lickDown = 0,
  required List<SnippetDrum> Function(int bars) ride,
}) {
  final beat = 60 / tempo;
  final changes = changesIn(lick, key);
  final events = lickIn(lick, key, floor: floor);
  final starts = lickStarts(lick, tempo);
  final comper = Comper(math.Random(7));
  final notes = <SnippetNote>[];
  final passBeats = lick.beats;

  for (var pass = 0; pass < times; pass++) {
    final top = from + pass * passBeats * beat;
    for (final (i, change) in changes.indexed) {
      final next = changes[(i + 1) % changes.length].chord;
      final voicing = comper.voice(change.chord, next);
      // A chord a bar long is comped on 1 and the "and" of 2; a shorter
      // one once, on its first beat.
      final hits = change.beats >= 4 ? [0.0, 1 + swingAt(tempo)] : [0.0];
      for (final hit in hits) {
        for (final pitch in voicing) {
          notes.add((
            pitch: pitch - down,
            start: top + (change.at + hit) * beat,
            length: beat * 0.45,
            velocity: 0.42,
            bass: false,
          ));
        }
      }
      // A walking line, a note a beat: root, third, fifth, then a half
      // step into the next root.
      final root = 28 + (change.chord.root - 28) % 12;
      final third = change.chord.quality.intervals.contains(3) ? 3 : 4;
      final nextRoot = 28 + (next.root - 28) % 12;
      final line = [
        root,
        root + third,
        root + 7,
        nextRoot + (nextRoot > root ? -1 : 1),
      ];
      for (var b = 0; b < change.beats; b++) {
        notes.add((
          pitch: change.beats == 2 && b == 1
              ? nextRoot + (nextRoot > root ? -1 : 1)
              : line[b % 4],
          start: top + (change.at + b) * beat,
          length: beat * 0.9,
          velocity: 0.75,
          bass: true,
        ));
      }
    }
    if (!lickOn(pass)) continue;
    for (final (i, event) in events.indexed) {
      notes.add((
        pitch: event.pitch - lickDown,
        start: top + starts[i] * beat,
        // Short enough that every note is heard starting, the way the
        // articulation lines are played.
        length: event.length * beat * (event.length <= 0.5 ? 0.6 : 0.85),
        velocity: 0.85,
        bass: false,
      ));
    }
  }
  final bars = (passBeats * times / 4).ceil();
  return (
    notes: notes,
    drums: [
      for (final hit in ride(bars))
        (
          at: from + hit.at,
          drum: hit.drum,
          velocity: hit.velocity,
          hard: hit.hard,
        ),
    ],
  );
}

// ── The licks ────────────────────────────────────────────────────────────

LickNote _n(double at, String degree, {double length = 0.5, int octave = 0}) =>
    (at: at, length: length, degree: degree, octave: octave);

const _twoFiveOne = <LickChord>[
  (degree: '2', quality: 'm7', beats: 4),
  (degree: '5', quality: '7', beats: 4),
  (degree: '1', quality: '^7', beats: 8),
];

const _minorTwoFiveOne = <LickChord>[
  (degree: '2', quality: 'ø7', beats: 4),
  (degree: '5', quality: '7b9', beats: 4),
  (degree: '1', quality: 'm6', beats: 8),
];

/// The vocabulary, plainest first.
/// Eight bars of running eighths for the Playing Fast page: the bebop
/// scale down a ii–V, up the I and round through its own V of ii, then
/// the ii–V again and home. Not in [licks]: it is a line to hear at two
/// tempos, longer than a lick, so there is time to feel the half note
/// at 260 before it is over.
final fastLine = Lick(
  name: 'Eight Bars in F',
  about:
      'Running eighths through two ii–Vs in F, with a turnaround between '
      'them, landing on the 3rd.',
  changes: const [
    (degree: '2', quality: 'm7', beats: 4),
    (degree: '5', quality: '7', beats: 4),
    (degree: '1', quality: '^7', beats: 4),
    (degree: '6', quality: '7', beats: 4),
    (degree: '2', quality: 'm7', beats: 4),
    (degree: '5', quality: '7', beats: 4),
    (degree: '1', quality: '^7', beats: 8),
  ],
  notes: [
    _n(0, '1'),
    _n(0.5, '9'),
    _n(1, 'b3'),
    _n(1.5, '11'),
    _n(2, '5'),
    _n(2.5, 'b7'),
    _n(3, '13'),
    _n(3.5, '5'),
    _n(4, '1'),
    _n(4.5, '7', octave: -1),
    _n(5, 'b7', octave: -1),
    _n(5.5, '13', octave: -1),
    _n(6, '5', octave: -1),
    _n(6.5, '11', octave: -1),
    _n(7, '3', octave: -1),
    _n(7.5, '9', octave: -1),
    _n(8, '5', octave: -1),
    _n(8.5, '1'),
    _n(9, '3'),
    _n(9.5, '5'),
    _n(10, '7'),
    _n(10.5, '13'),
    _n(11, '5'),
    _n(11.5, '3'),
    _n(12, '5', octave: -1),
    _n(12.5, '3', octave: -1),
    _n(13, '11', octave: -1),
    _n(13.5, '5', octave: -1),
    _n(14, 'b7', octave: -1),
    _n(14.5, 'b9'),
    _n(15, '1'),
    _n(15.5, 'b7', octave: -1),
    _n(16, 'b3'),
    _n(16.5, '5'),
    _n(17, 'b7'),
    _n(17.5, '9', octave: 1),
    _n(18, '1', octave: 1),
    _n(18.5, 'b7'),
    _n(19, '5'),
    _n(19.5, 'b3'),
    _n(20, '13', octave: -1),
    _n(20.5, '1'),
    _n(21, '3'),
    _n(21.5, '5'),
    _n(22, 'b7'),
    _n(22.5, '13'),
    _n(23, '5'),
    _n(23.5, '3'),
    _n(24, '1', octave: 1),
    _n(24.5, '7'),
    _n(25, '13'),
    _n(25.5, '5'),
    _n(26, '3'),
    _n(26.5, '1'),
    _n(27, '7', octave: -1),
    _n(27.5, '9'),
    _n(28, '3', length: 4),
  ],
);

final licks = <Lick>[
  Lick(
    name: 'The Lick',
    about:
        'Up four steps of the minor scale, down a third, then down to the '
        'root: so famous it has become a joke, which is a measure of how '
        'often it was played. Over the ii chord, landing on its root.',
    changes: _twoFiveOne,
    notes: [
      _n(0, '1'),
      _n(0.5, '9'),
      _n(1, 'b3'),
      _n(1.5, '11'),
      _n(2, '9', length: 1),
      _n(3, 'b7', octave: -1),
      _n(3.5, '1', length: 1.5),
    ],
  ),
  Lick(
    name: '1 2 3 5 Down the Changes',
    about:
        'The same four-note cell on every chord: root, 2nd, 3rd, 5th. The '
        'cell is what Coltrane built whole solos from, and it outlines '
        'each chord so plainly that the changes can be heard in the line '
        'alone.',
    changes: const [
      (degree: '2', quality: 'm7', beats: 2),
      (degree: '5', quality: '7', beats: 2),
      (degree: '1', quality: '^7', beats: 4),
    ],
    notes: [
      _n(0, '1'),
      _n(0.5, '9'),
      _n(1, 'b3'),
      _n(1.5, '5'),
      _n(2, '1'),
      _n(2.5, '9'),
      _n(3, '3'),
      _n(3.5, '5'),
      _n(4, '1', octave: 1),
      _n(4.5, '9', octave: 1),
      _n(5, '3', octave: 1),
      _n(5.5, '5', octave: 1),
      _n(6, '3', octave: 1, length: 2),
    ],
  ),
  Lick(
    name: 'Up the ii, 3 to ♭9 on the V',
    about:
        'Up the ii chord, then from the 3rd of the V up its diminished '
        'arpeggio to the ♭9, which falls a half step onto the 5th of the '
        'I. The bebop ii–V–I in one breath.',
    changes: _twoFiveOne,
    notes: [
      _n(0, '1'),
      _n(0.5, 'b3'),
      _n(1, '5'),
      _n(1.5, 'b7'),
      _n(2, '9', octave: 1, length: 1),
      _n(3, 'b7', length: 1),
      _n(4, '3'),
      _n(4.5, '5'),
      _n(5, 'b7'),
      _n(5.5, 'b9', octave: 1),
      _n(6, '1', octave: 1, length: 0.5),
      _n(6.5, 'b9', octave: 1, length: 1.5),
      _n(8, '5', octave: 1, length: 4),
    ],
  ),
  Lick(
    name: 'Enclosure Into the Third',
    about:
        'Down the V7 from its 5th, then the 3rd of the I approached from a '
        'step above and a half step below, so it arrives surrounded: the '
        'sound of almost every bebop resolution.',
    changes: _twoFiveOne,
    notes: [
      _n(4, '5'),
      _n(4.5, '11'),
      _n(5, '3'),
      _n(5.5, '9'),
      _n(6, '1', length: 1),
      _n(7, 'b7', octave: -1),
      _n(7.5, '#5', octave: -1),
      _n(8, '3', length: 4),
    ],
  ),
  Lick(
    name: 'Bebop Scale Down the V',
    about:
        'The dominant bebop scale from the root down: the extra half step '
        'between the root and the ♭7 puts a chord tone on every beat. It '
        'runs out on the 9th and steps down onto the 5th of the I.',
    changes: _twoFiveOne,
    notes: [
      _n(4, '1', octave: 1),
      _n(4.5, '7'),
      _n(5, 'b7'),
      _n(5.5, '13'),
      _n(6, '5'),
      _n(6.5, '11'),
      _n(7, '3'),
      _n(7.5, '9'),
      _n(8, '5', length: 4),
    ],
  ),
  Lick(
    name: 'ø Up, ♭9 Down',
    about:
        'The minor ii–V–i: up the half-diminished chord, then down the V '
        'from its ♭9, through the diminished arpeggio, onto the root of '
        'the minor i.',
    changes: _minorTwoFiveOne,
    notes: [
      _n(0, '1'),
      _n(0.5, 'b3'),
      _n(1, 'b5'),
      _n(1.5, 'b7'),
      _n(2, '1', octave: 1, length: 2),
      _n(4, 'b9', octave: 1),
      _n(4.5, 'b7'),
      _n(5, '5'),
      _n(5.5, '3'),
      _n(6, 'b9', length: 1),
      _n(7, '3', length: 1),
      _n(8, '1', octave: 1, length: 4),
    ],
  ),
  Lick(
    name: 'The Blue Third',
    about:
        'The minor 3rd bent up to the major 3rd, the blues inside a '
        'dominant chord, up to the 6th and back. Then the same blue note '
        'again as the 7th of the IV chord, and home to the 5th.',
    changes: const [
      (degree: '1', quality: '7', beats: 4),
      (degree: '4', quality: '7', beats: 4),
      (degree: '1', quality: '7', beats: 8),
    ],
    notes: [
      _n(0.5, '#9'),
      _n(1, '3'),
      _n(1.5, '5'),
      _n(2, '13'),
      _n(2.5, '5'),
      _n(3, '#9'),
      _n(3.5, '3'),
      _n(4, 'b7', octave: -1, length: 1),
      _n(5, '9', length: 1),
      _n(6, '3', length: 2),
      _n(8, '5', length: 4),
    ],
  ),
];
