// Swing: how late the "and" is, and why that changes with the tempo.
//
// Everybody is told jazz eighths are long-short and most are then told
// they are triplets: the first note taking two thirds of the beat and
// the second the last third. That is true at about one tempo. At a
// ballad the long note is longer than that, closer to a dotted quaver,
// and at a burning tempo the two are near enough even and what makes it
// swing is the accent and the articulation rather than the clock.
//
// The reason is worth knowing because it explains the whole curve: the
// short note stays about the same length whatever the tempo, roughly a
// tenth of a second, about as fast as a hand comfortably plays a note
// and means it. The beat is what shrinks. So as the tempo climbs the
// short note takes up more and more of the beat until there is nothing
// left to swing, and the pair is straight.
//
// The band plays to this too. Every part that puts a note between the
// beats (the ride, the bass's ghosts and pushes, the comper, the
// arpeggios) asks [swingAt] rather than assuming two thirds, so what
// the Swing screen teaches is what a tune at that tempo actually does.

import 'dart:math' as math;

/// The short half of a swung pair, in seconds.
///
/// Near enough constant across tempos, which is the fact the whole of
/// this rests on. It is not a rule anybody plays to; it is what falls
/// out of measuring people who swing.
const shortEighth = 0.1;

/// Even eighths: the "and" exactly halfway, which is no swing at all.
const straight = 0.5;

/// The "and" two thirds of the way through the beat: 2 : 1, the triplet
/// everybody is taught, and about right at a medium-up tempo.
const tripletSwing = 2 / 3;

/// A dotted quaver and a semiquaver: 3 : 1, and about as hard as swing
/// is written down.
const dottedSwing = 0.75;

/// As long as the long note ever really gets, around 3.5 : 1. Slow
/// players swing harder than the notation admits, but not without limit.
const widestSwing = 0.78;

/// Where the "and" falls inside the beat at [tempo], as a fraction of the
/// beat.
///
/// Straight is 0.5 and the triplet is two thirds. Derived rather than
/// chosen: the short note holds at [shortEighth] and the beat shrinks
/// around it, so the answer flattens towards straight on its own as the
/// tempo climbs.
double swingAt(int tempo) {
  final beat = 60 / tempo;
  return math.max(straight, math.min(widestSwing, 1 - shortEighth / beat));
}

/// What to call a swing of [at], for somebody reading it off a slider.
String swingName(double at) => switch (at) {
  < 0.53 => 'Straight',
  < 0.58 => 'Barely There',
  < 0.64 => 'Light',
  < 0.70 => 'Triplet',
  < 0.775 => 'Dotted',
  _ => 'Hard',
};

/// The long note against the short one, the way a drummer would say it:
/// "two to one".
///
/// Written to one decimal, and without one where it is round, because
/// "2 : 1" is a thing people say and "2.0 : 1" is not.
String ratioText(double at) {
  final ratio = at / (1 - at);
  final written = ratio.toStringAsFixed(1);
  return '${written.endsWith('.0') ? ratio.round() : written} : 1';
}

/// One beat's worth of swung eighths, in seconds from the start.
typedef SwungPair = ({double downbeat, double and});

/// Where every eighth falls across [bars] bars of four, in seconds.
///
/// The whole of what the screen does to the sound, kept out here where
/// it can be measured: the downbeats are the beat, and the "and" is [at]
/// of the way through it.
List<SwungPair> swungEighths({
  required int tempo,
  required double at,
  int bars = 2,
}) {
  final beat = 60 / tempo;
  return [
    for (var b = 0; b < bars * 4; b++)
      (downbeat: b * beat, and: (b + at) * beat),
  ];
}

/// A tempo worth hearing it at, and what happens to the eighths there.
typedef SwingTempo = ({int tempo, String name, String about});

/// The tempos the screen offers, slow to fast.
///
/// Chosen so the curve is visible across them rather than to cover the
/// range evenly: the triplet everybody is taught turns up in the middle
/// of them, and the top one is genuinely straight.
const swingTempos = <SwingTempo>[
  (
    tempo: 80,
    name: 'Ballad',
    about:
        'Slow enough that the long note can take almost all of the beat. '
        'Harder than the triplet anybody writes down, and if you play a '
        'ballad with even eighths it sounds like a rehearsal.',
  ),
  (
    tempo: 140,
    name: 'Medium',
    about:
        'Still wider than a triplet. This is where most of the repertoire '
        'sits and where the long-short is most obvious to a listener.',
  ),
  (
    tempo: 200,
    name: 'Medium Up',
    about:
        'Two to one, near enough: the triplet everybody is taught. It is '
        'worth knowing that the rule you were given is a snapshot of one '
        'tempo rather than a description of swing.',
  ),
  (
    tempo: 260,
    name: 'Up',
    about:
        'Flattening out. There is not enough beat left to hold a long '
        'note and a short one, so the pair starts to even up whether you '
        'mean it to or not.',
  ),
  (
    tempo: 300,
    name: 'Burning',
    about:
        'Straight, and it still swings. At this tempo it is the accent '
        'and the articulation carrying it: the weight on the offbeats, '
        'and the notes joined rather than separated. Nothing to do with '
        'the clock at all.',
  ),
];
