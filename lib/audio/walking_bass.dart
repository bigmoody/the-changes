// Generates bass lines that keep changing, like a real jazz bassist.
//
// What varies, and roughly how:
//  • Phrases: every 4–8 bars the bassist picks a new register to sit in
//    (low, middle or high) and, now and then, drops into a "two-feel"
//    (mostly half notes) instead of walking.
//  • Note choice: each chord gets one of about 14 shapes: arpeggios up or
//    down, scale runs, octave leaps, repeated notes, chromatic runs into the
//    next chord from above or below, enclosures (above-then-below), and so on.
//    The same chord won't get the same shape twice in a row.
//  • Landing: usually the root on the first beat of a chord, sometimes the
//    3rd or 5th instead.
//  • Leading in: the last note before a chord change is an approach note: a
//    semitone or step away, or the next chord's 5th.
//  • Rhythm: triplet "skip" notes, quiet ghost notes, and occasionally
//    anticipating the next chord by a swung eighth.
//  • Feel: every note's volume, length and (very slightly) timing varies.

import 'dart:math' as math;

import '../music/chord.dart';

/// One bass note. [beat] counts from the start of the line.
typedef BassNote = ({int pitch, double beat, double length, double velocity});

/// Lowest and highest MIDI notes the line may use (E1 to E3).
const bassLowest = 28;
const bassHighest = 52;

/// Walks [choruses] times through [chords] (each with its length in beats).
/// Every chorus is different, but the same [random] seed gives the same line.
/// [startPitch] continues a line from where an earlier one ended.
List<BassNote> walkingBassLine(
  List<(Chord, int)> chords, {
  required int choruses,
  required math.Random random,
  int beatsPerBar = 4,
  int? startPitch,
}) => _play(
  chords,
  choruses,
  _Bassist(random, startPitch),
  _Style.walking,
  beatsPerBar,
);

/// A two-feel line: half notes, mostly roots and 5ths, the way a bassist
/// plays under a melody or a ballad before settling into a walk.
List<BassNote> twoFeelBassLine(
  List<(Chord, int)> chords, {
  required int choruses,
  required math.Random random,
  int beatsPerBar = 4,
  int? startPitch,
}) => _play(
  chords,
  choruses,
  _Bassist(random, startPitch, alwaysTwoFeel: true),
  _Style.walking,
  beatsPerBar,
);

/// A bossa nova / Latin bass line: root–5th figures with pickups, varied
/// every chorus (octave pops, approach notes, anticipations, changes of
/// register), never the identical loop over and over.
List<BassNote> bossaBassLine(
  List<(Chord, int)> chords, {
  required int choruses,
  required math.Random random,
  int beatsPerBar = 4,
  int? startPitch,
}) => _play(
  chords,
  choruses,
  _Bassist(random, startPitch),
  _Style.bossa,
  beatsPerBar,
);

/// A funk bass line: root-heavy and syncopated, with octave pops.
List<BassNote> funkBassLine(
  List<(Chord, int)> chords, {
  required int choruses,
  required math.Random random,
  int beatsPerBar = 4,
  int? startPitch,
}) => _play(
  chords,
  choruses,
  _Bassist(random, startPitch),
  _Style.funk,
  beatsPerBar,
);

/// A calypso bass line: the 3-3-2 — 1, the "and" of 2 held over 3, then 4 —
/// on roots, 5ths and 3rds, with the odd anticipation of the next chord.
List<BassNote> calypsoBassLine(
  List<(Chord, int)> chords, {
  required int choruses,
  required math.Random random,
  int beatsPerBar = 4,
  int? startPitch,
}) => _play(
  chords,
  choruses,
  _Bassist(random, startPitch),
  _Style.calypso,
  beatsPerBar,
);

enum _Style { walking, bossa, funk, calypso }

List<BassNote> _play(
  List<(Chord, int)> chords,
  int choruses,
  _Bassist bassist,
  _Style style,
  int beatsPerBar,
) {
  final notes = <BassNote>[];
  var start = 0;
  for (var chorus = 0; chorus < choruses; chorus++) {
    for (var i = 0; i < chords.length; i++) {
      final (chord, beats) = chords[i];
      // The last chord leads back to the first, because the section repeats.
      final (next, _) = chords[(i + 1) % chords.length];
      final isVeryLast = chorus == choruses - 1 && i == chords.length - 1;
      final played = style == _Style.walking
          ? bassist.playChord(
              chord,
              next,
              beats,
              chordIndex: i,
              canAnticipate: !isVeryLast,
            )
          : bassist.playGrooveChord(
              chord,
              next,
              beats,
              chordIndex: i,
              canAnticipate: !isVeryLast,
              style: style,
              beatInBar: start % beatsPerBar,
            );
      for (final note in played) {
        notes.add((
          pitch: note.pitch,
          beat: start + note.beat,
          length: note.length,
          velocity: note.velocity,
        ));
      }
      start += beats;
    }
  }
  return notes;
}

enum _Feel { walking, twoFeel }

/// The bassist's memory while playing: where the line is, the current
/// phrase's register and feel, and what was played on each chord last time.
class _Bassist {
  _Bassist(this.random, int? startPitch, {this.alwaysTwoFeel = false})
    : previous = startPitch ?? 38 {
    _newPhrase();
  }

  final math.Random random;

  /// Stay in two-feel rather than drifting in and out of it.
  final bool alwaysTwoFeel;
  int previous; // where the line is now (D2 if starting fresh)
  late int registerCentre;
  late _Feel feel;
  late double phraseDynamics;
  int beatsLeftInPhrase = 0;
  bool skipNextDownbeat = false;
  bool _calypsoAnticipated = false;
  final lastShape = <int, int>{};

  void _newPhrase() {
    registerCentre = 32 + random.nextInt(14); // G♯1 … A2
    feel = alwaysTwoFeel || random.nextDouble() < 0.18
        ? _Feel.twoFeel
        : _Feel.walking;
    phraseDynamics = 0.85 + random.nextDouble() * 0.2;
    beatsLeftInPhrase = (4 + random.nextInt(5)) * 4; // 4–8 bars
  }

  List<BassNote> playChord(
    Chord chord,
    Chord next,
    int beats, {
    required int chordIndex,
    required bool canAnticipate,
  }) {
    if (beatsLeftInPhrase <= 0) _newPhrase();
    beatsLeftInPhrase -= beats;

    // Lean towards the phrase's register, but stay close to where we are.
    final centre = (previous * 2 + registerCentre) ~/ 3;
    final root = _within12(_nearest(chord.bass, centre), previous);
    final tones = _ChordTones(chord);

    // Usually land on the root; sometimes the 3rd or 5th for colour.
    var first = root;
    final landing = random.nextDouble();
    if (beats >= 2 && chord.bass == chord.root) {
      if (landing < 0.07) {
        first = _within12(
          _nearest((chord.root + tones.third) % 12, centre),
          previous,
        );
      } else if (landing < 0.12) {
        first = _within12(
          _nearest((chord.root + tones.fifth) % 12, centre),
          previous,
        );
      }
    }

    final pitches = feel == _Feel.twoFeel && beats >= 2
        ? null
        : _pickShape(first, root, tones, next, beats, chordIndex);

    final notes = pitches == null
        ? _twoFeel(first, root, tones, next, beats)
        : [
            for (var b = 0; b < pitches.length; b++)
              _note(
                pitches[b],
                b.toDouble(),
                0.85 + random.nextDouble() * 0.12,
                accent: b == 0,
              ),
          ];

    // The previous chord may have anticipated this downbeat already.
    if (skipNextDownbeat && notes.isNotEmpty && notes.first.beat == 0) {
      notes.removeAt(0);
    }
    skipNextDownbeat = false;

    return _smoothLine(_embellish(notes, next, beats, canAnticipate));
  }

  /// Safety net: keeps every note within an octave of the one before.
  List<BassNote> _smoothLine(List<BassNote> result) {
    for (var i = 0; i < result.length; i++) {
      final note = result[i];
      final pitch = _within12(note.pitch, previous);
      if (pitch != note.pitch) {
        result[i] = (
          pitch: pitch,
          beat: note.beat,
          length: note.length,
          velocity: note.velocity,
        );
      }
      previous = pitch;
    }
    return result;
  }

  // ── Bossa figures ──────────────────────────────────────────────────────

  List<BassNote> playGrooveChord(
    Chord chord,
    Chord next,
    int beats, {
    required int chordIndex,
    required bool canAnticipate,
    required _Style style,
    int beatInBar = 0,
  }) {
    final funk = style == _Style.funk;
    // Calypso, two chords to a bar: the second chord's root comes in early,
    // on the "and" of 2, and is held over 3 — the 3-3-2 across the change.
    final anticipated = _calypsoAnticipated;
    _calypsoAnticipated = false;
    if (beatsLeftInPhrase <= 0) _newPhrase();
    beatsLeftInPhrase -= beats;

    final centre = (previous * 2 + registerCentre) ~/ 3;
    var root = _within12(_nearest(chord.bass, centre), previous);
    final tones = _ChordTones(chord);
    // A Latin bass rocks *up* to the 5th; dropping to the 5th below is what
    // makes it sound like a rock bass line instead. So if the 5th above
    // would run off the top of the instrument, take the root down an octave
    // to make room — unless that would leave the line leaping.
    if (root + tones.fifth > bassHighest &&
        root - 12 >= bassLowest &&
        (root - 12 - previous).abs() <= 12) {
      root -= 12;
    }
    final fifthUp = root + tones.fifth;
    final fifth = _inRange(fifthUp) ? fifthUp : fifthUp - 12;
    final third = _nearest((chord.root + tones.third) % 12, root);
    final thirdUp = _inRange(root + tones.third) ? root + tones.third : third;
    final octave = root + 12 <= bassHighest ? root + 12 : root - 12;
    final nextRoot = _nearest(next.bass, fifth);
    final approach = _approachNote(nextRoot, fifth);

    // (weight, figure): each figure is (pitch, beat, length) notes.
    final figures = <(int, List<(int, double, double)>)>[
      if (style == _Style.calypso) ...[
        // The 3-3-2: 1, the "and" of 2 held over 3, then 4. Beat 3 is left
        // empty — that's what makes it lift rather than oom-pah.
        if (beats >= 4) ...[
          (5, [(root, 0, 1.4), (fifth, 1.5, 1.4), (root, 3, 0.9)]),
          (4, [(root, 0, 1.4), (thirdUp, 1.5, 1.4), (fifth, 3, 0.9)]),
          (3, [(root, 0, 1.4), (fifth, 1.5, 1.4), (approach, 3, 0.9)]),
          (2, [(root, 0, 1.4), (octave, 1.5, 1.4), (fifth, 3, 0.9)]),
          if (canAnticipate)
            (2, [(root, 0, 1.4), (fifth, 1.5, 1.9), (nextRoot, 3.5, 1.0)]),
        ] else if (beats >= 2 && beatInBar == 0 && canAnticipate) ...[
          // First of two chords: 1, then the next chord early on the "and"
          // of 2 (see below).
          (1, [(root, 0, 1.4), (nextRoot, 1.5, 1.4)]),
        ] else if (beats >= 2 && anticipated) ...[
          // Second of two, already sounding since the "and" of 2: just 4.
          (3, [(fifth, 1, 0.9)]),
          (2, [(root, 1, 0.9)]),
          (1, [(approach, 1, 0.9)]),
        ] else if (beats >= 2) ...[
          (4, [(root, 0, 1.4), (fifth, 1.5, 0.45)]),
          (2, [(root, 0, 1.9)]),
        ] else ...[
          (1, [(root, 0, 0.9)]),
        ],
      ] else if (funk) ...[
        if (beats >= 4) ...[
          (
            4,
            [
              (root, 0, 0.9),
              (root, 1.5, 0.4),
              (octave, 2, 0.4),
              (root, 2.5, 0.4),
              (approach, 3.5, 0.45),
            ],
          ),
          (
            3,
            [
              (root, 0, 0.9),
              (fifth, 1.5, 0.45),
              (root, 2, 0.9),
              (octave, 3.5, 0.45),
            ],
          ),
          (
            3,
            [
              (root, 0, 1.4),
              (root, 1.5, 0.45),
              (fifth, 2.5, 0.45),
              (approach, 3.5, 0.45),
            ],
          ),
          (
            2,
            [
              (root, 0, 0.45),
              (root, 0.5, 0.45),
              (fifth, 1, 0.9),
              (root, 2, 0.9),
              (approach, 3.5, 0.45),
            ],
          ),
          (
            2,
            [
              (root, 0, 1.9),
              (octave, 2, 0.45),
              (fifth, 2.5, 0.45),
              (root, 3, 0.9),
            ],
          ),
          if (canAnticipate)
            (
              2,
              [
                (root, 0, 0.9),
                (root, 1.5, 0.4),
                (fifth, 2, 0.9),
                (nextRoot, 3.5, 1.0),
              ],
            ),
        ] else if (beats >= 2) ...[
          (4, [(root, 0, 0.9), (root, 1.5, 0.45)]),
          (3, [(root, 0, 1.4), (approach, 1.5, 0.45)]),
          (2, [(root, 0, 0.45), (octave, 0.5, 0.45), (root, 1, 0.9)]),
        ] else ...[
          (1, [(root, 0, 0.9)]),
        ],
      ] else if (beats >= 4) ...[
        (
          5,
          [
            (root, 0, 1.4),
            (fifth, 1.5, 0.45),
            (fifth, 2, 1.4),
            (root, 3.5, 0.45),
          ],
        ),
        (2, [(root, 0, 1.4), (fifth, 1.5, 0.45), (fifth, 2, 1.9)]),
        (
          2,
          [
            (root, 0, 1.4),
            (root, 1.5, 0.45),
            (fifth, 2, 1.4),
            (fifth, 3.5, 0.45),
          ],
        ),
        (
          3,
          [
            (root, 0, 1.4),
            (fifth, 1.5, 0.45),
            (fifth, 2, 1.4),
            (approach, 3.5, 0.45),
          ],
        ),
        (2, [(root, 0, 1.9), (fifth, 2, 1.4), (approach, 3.5, 0.45)]),
        (
          2,
          [
            (root, 0, 1.4),
            (octave, 1.5, 0.45),
            (fifth, 2, 1.4),
            (fifth, 3.5, 0.45),
          ],
        ),
        (
          1,
          [
            (root, 0, 1.4),
            (fifth, 1.5, 0.45),
            (third, 2, 1.4),
            (approach, 3.5, 0.45),
          ],
        ),
        if (canAnticipate)
          (
            1,
            [
              (root, 0, 1.4),
              (fifth, 1.5, 0.45),
              (fifth, 2, 1.4),
              (nextRoot, 3.5, 1.0),
            ],
          ),
      ] else if (beats >= 2) ...[
        (4, [(root, 0, 1.4), (fifth, 1.5, 0.45)]),
        (2, [(root, 0, 1.4), (approach, 1.5, 0.45)]),
        (2, [(root, 0, beats - 0.1)]),
        if (canAnticipate) (1, [(root, 0, 1.4), (nextRoot, 1.5, 1.0)]),
      ] else ...[
        (1, [(root, 0, 0.9)]),
      ],
    ];

    if (style == _Style.calypso &&
        beats >= 2 &&
        beats < 4 &&
        beatInBar == 0 &&
        canAnticipate) {
      _calypsoAnticipated = true;
    }

    // Pick by weight, making last time's figure on this chord less likely.
    final avoid = lastShape[chordIndex];
    final weights = [
      for (var i = 0; i < figures.length; i++)
        i == avoid ? figures[i].$1 * 0.25 : figures[i].$1.toDouble(),
    ];
    var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    var chosen = 0;
    for (; chosen < figures.length - 1; chosen++) {
      roll -= weights[chosen];
      if (roll <= 0) break;
    }
    lastShape[chordIndex] = chosen;
    final figure = figures[chosen].$2;

    final notes = <BassNote>[
      for (final (pitch, beat, length) in figure)
        if (_inRange(pitch))
          (
            pitch: pitch,
            beat: beat == 0 ? 0.0 : beat + (random.nextDouble() - 0.5) * 0.015,
            length: length * (0.9 + random.nextDouble() * 0.08),
            velocity:
                ((beat % 1 == 0 ? 0.85 : 0.68) + random.nextDouble() * 0.15) *
                phraseDynamics,
          ),
    ];

    if (skipNextDownbeat && notes.isNotEmpty && notes.first.beat == 0) {
      notes.removeAt(0);
    }
    // An anticipated next root (a long note on the last "and") ties over.
    skipNextDownbeat =
        notes.isNotEmpty &&
        notes.last.pitch % 12 == next.bass &&
        notes.last.length >= 0.9 &&
        notes.last.beat > beats - 1;
    return _smoothLine(notes);
  }

  // ── Walking shapes ─────────────────────────────────────────────────────

  List<int> _pickShape(
    int first,
    int root,
    _ChordTones t,
    Chord next,
    int beats,
    int chordIndex,
  ) {
    if (beats == 1) return [first];

    int target(int from) => _nearest(next.bass, from);
    int approach(int from) => _approachNote(target(from), from);

    // Each shape: pitches for the middle beats, given the first note. The
    // last beat is added afterwards as an approach note unless the shape
    // brings its own.
    final List<List<int> Function()> shapes;
    if (beats == 2) {
      shapes = [
        () => [first, approach(first)],
        () => [first, approach(first)],
        () => [first, root + t.fifth],
        () => [first, first + (first + 12 <= bassHighest ? 12 : -12)],
        () => [first, target(first) + (random.nextBool() ? 2 : -2)],
      ];
    } else {
      final middle = beats - 2;
      List<int> walk(List<int> steps) {
        final line = [first, for (final s in steps.take(middle)) root + s];
        while (line.length < beats - 1) {
          line.add(root + [t.third, t.fifth, t.seventh][line.length % 3]);
        }
        return line..add(approach(line.last));
      }

      List<int> intoTarget(List<int> offsets) {
        final to = target(first);
        final line = [first, for (final o in offsets) to + o];
        return line.take(beats).toList();
      }

      shapes = [
        () => walk([t.third, t.fifth]), // arpeggio up
        () => walk([t.second, t.third]), // scale up
        () => walk([t.seventh - 12, t.sixth - 12]), // scale down
        () => walk([t.fifth - 12, t.third - 12]), // arpeggio down
        () => walk([t.fifth, t.sixth]), // 5th and 6th
        () => walk([12, t.seventh]), // octave leap, back down
        () => walk([0, t.fifth]), // repeated root
        () => walk([t.fifth, t.third]), // up and back
        () => walk([t.fifth - 12, 0]), // 5th below and back
        () => walk([t.third, t.fourth]), // 3rd to 4th
        () => intoTarget([3, 2, 1]), // chromatic run down into the next chord
        () => intoTarget([-3, -2, -1]), // chromatic run up into it
        () => intoTarget([2, 1, -1]), // enclosure: above, then below
        () => intoTarget([-2, -1, 1]), // enclosure: below, then above
        () => [
          first,
          root + t.third,
          root + t.fifth,
          root + t.seventh,
        ].take(beats).toList(), // straight up the chord to the 7th
      ];
    }

    // Try shapes in random order; skip the one used last time on this chord
    // and anything out of range or too jumpy.
    final order = List.generate(shapes.length, (i) => i)..shuffle(random);
    final avoid = lastShape[chordIndex];
    for (final pass in [true, false]) {
      for (final index in order) {
        if (pass && index == avoid) continue;
        final line = shapes[index]();
        if (line.length != beats) continue;
        if (!line.every(_inRange)) continue;
        if (!_smooth([previous, ...line])) continue;
        lastShape[chordIndex] = index;
        return line;
      }
    }
    return [first, for (var b = 1; b < beats; b++) root + t.fifth];
  }

  // ── Two-feel ───────────────────────────────────────────────────────────

  List<BassNote> _twoFeel(
    int first,
    int root,
    _ChordTones t,
    Chord next,
    int beats,
  ) {
    final fifth = _nearest((root + t.fifth) % 12, first);
    final approach = _approachNote(_nearest(next.bass, fifth), fifth);
    final options = <List<BassNote> Function()>[
      if (beats >= 4) ...[
        () => [_note(first, 0, 1.9, accent: true), _note(fifth, 2, 1.9)],
        () => [_note(first, 0, 1.9, accent: true), _note(approach, 2, 1.9)],
        () => [
          _note(first, 0, 1.9, accent: true),
          _note(fifth, 2, 0.9),
          _note(approach, 3, 0.9),
        ],
        () => [
          _note(first, 0, 1.4, accent: true),
          _ghost(first, 1 + 2 / 3),
          _note(fifth, 2, 1.9),
        ],
      ] else ...[
        () => [_note(first, 0, beats - 0.1, accent: true)],
        () => [_note(first, 0, 0.9, accent: true), _note(approach, 1, 0.9)],
      ],
    ];
    return options[random.nextInt(options.length)]();
  }

  // ── Rhythm and feel ────────────────────────────────────────────────────

  List<BassNote> _embellish(
    List<BassNote> notes,
    Chord next,
    int beats,
    bool canAnticipate,
  ) {
    final out = <BassNote>[];
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final isLast = i == notes.length - 1;
      final roll = random.nextDouble();
      final isQuarter = note.length < 1.2;

      // Only a note on the last beat can push into the next chord.
      final onLastBeat = (note.beat - (beats - 1)).abs() < 0.05;
      if (isLast && onLastBeat && canAnticipate && roll < 0.07) {
        // Push the next chord's root in a swung eighth early.
        final target = _nearest(next.bass, note.pitch);
        out
          ..add((
            pitch: note.pitch,
            beat: note.beat,
            length: 0.6,
            velocity: note.velocity,
          ))
          ..add(_note(target, note.beat + 2 / 3, 1.25, accent: true));
        skipNextDownbeat = true;
      } else if (note.beat > 0 && isQuarter && roll < 0.12) {
        // Triplet skip: a shortened note plus a quiet pickup.
        final pickup = random.nextDouble() < 0.6
            ? note.pitch
            : (i + 1 < notes.length ? notes[i + 1].pitch : note.pitch);
        out
          ..add((
            pitch: note.pitch,
            beat: note.beat,
            length: 0.6,
            velocity: note.velocity,
          ))
          ..add(_ghost(pickup, note.beat + 2 / 3));
      } else if (note.beat > 0 && isQuarter && !isLast && roll < 0.15) {
        // A muted "thump" instead of a full note.
        out.add((
          pitch: note.pitch,
          beat: note.beat,
          length: 0.22,
          velocity: 0.4,
        ));
      } else {
        out.add(note);
      }
    }
    return out;
  }

  BassNote _note(int pitch, double beat, double length, {bool accent = false}) {
    // Tiny timing looseness on everything but the chord's downbeat.
    final nudge = beat == 0 ? 0.0 : (random.nextDouble() - 0.5) * 0.02;
    // Jazz bassists lean slightly on beats 2 and 4.
    final backbeat = beat.round().isOdd ? 0.05 : 0.0;
    final velocity =
        ((accent ? 0.85 : 0.7) + backbeat + random.nextDouble() * 0.2) *
        phraseDynamics;
    return (
      pitch: pitch,
      beat: beat + nudge,
      length: length * (0.9 + random.nextDouble() * 0.08),
      velocity: velocity.clamp(0.3, 1.0),
    );
  }

  BassNote _ghost(int pitch, double beat) => (
    pitch: pitch,
    beat: beat,
    length: 0.28,
    velocity: 0.35 + random.nextDouble() * 0.15,
  );

  /// A note that leads into [target]: a semitone or step either side, or
  /// its 5th, weighted towards the most common choices.
  int _approachNote(int target, int from) {
    const options = [
      (-1, 30),
      (1, 22),
      (2, 16),
      (-2, 10),
      (7, 8),
      (-5, 8),
      (5, 6),
    ];
    final ranked = [
      for (final (offset, weight) in options)
        (offset, random.nextDouble() * weight),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    for (final (offset, _) in ranked) {
      final pitch = target + offset;
      if (_inRange(pitch) && pitch != from && (pitch - from).abs() <= 12) {
        return pitch;
      }
    }
    return target - 1 >= bassLowest ? target - 1 : target + 1;
  }
}

/// Semitones above the root for the notes a bassist reaches for.
class _ChordTones {
  _ChordTones(Chord chord) {
    final intervals = chord.quality.intervals;
    third = intervals.length > 1 ? intervals[1] : 4;
    fifth = intervals.length > 2 ? intervals[2] : 7;
    seventh = intervals.length > 3 && intervals[3] < 12
        ? intervals[3]
        : (third == 3 ? 10 : 11);
    second = intervals.contains(13) ? 1 : 2; // ♭9 chords use a ♭2
    fourth = 5;
    sixth = fifth == 8 ? 8 : (fifth == 6 ? 8 : 9);
  }

  late final int second;
  late final int third;
  late final int fourth;
  late final int fifth;
  late final int sixth;
  late final int seventh;
}

bool _inRange(int pitch) => pitch >= bassLowest && pitch <= bassHighest;

/// No leaps bigger than an octave between neighbouring notes.
bool _smooth(List<int> line) {
  for (var i = 1; i < line.length; i++) {
    if ((line[i] - line[i - 1]).abs() > 12) return false;
  }
  return true;
}

/// Moves [pitch] by octaves (staying in range) until it's within an octave
/// of [previous], so the line never leaps wildly.
int _within12(int pitch, int previous) {
  while (pitch - previous > 12 && pitch - 12 >= bassLowest) {
    pitch -= 12;
  }
  while (previous - pitch > 12 && pitch + 12 <= bassHighest) {
    pitch += 12;
  }
  return pitch;
}

/// The octave of [pitchClass] closest to [near], kept within range.
int _nearest(int pitchClass, int near) {
  var best = bassLowest + (pitchClass - bassLowest) % 12;
  for (var pitch = best; pitch <= bassHighest; pitch += 12) {
    if ((pitch - near).abs() < (best - near).abs()) best = pitch;
  }
  return best;
}
