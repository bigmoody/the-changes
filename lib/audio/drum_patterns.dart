// What the drummer plays, bar by bar, in each feel.
//
// A pattern is just a list of hits: which drum, on which beat of the bar,
// how hard. The synth turns those into recorded (or synthesised) sounds.
//
//  • Swing: the ride pattern "ding, ding-a ding" with the hi-hat pedal on 2
//    and 4, a barely-there kick, occasional quiet snare comping, the odd
//    kick accent ("dropping bombs") and a fill at the end of a phrase.
//  • Bossa nova: straight eighths on the hi-hat or ride, and the cross-stick
//    playing the bossa clave: a two-bar pattern, not a backbeat.
//  • Funk: eighths on the hi-hat, snare backbeat on 2 and 4, and a
//    syncopated kick that changes from bar to bar.
//  • Jazz waltz: swing in three, with the skip note after 2 and beat 3
//    left plain, and the hi-hat closing under 2 and 3.
//  • Ballad: the slowest swing, with the brushes circling the head and
//    the right hand touching the time in on 2 and 4 rather than keeping
//    it on the cymbal.
//  • Second line: the New Orleans street beat, kick and snare only, no
//    cymbal, the kick picking up off the beat after each backbeat.
//  • Afro 6/8: the standard bell across a twelve-eighth cycle, the
//    bombo on the second beat of it, the hi-hat closing on the halves.
//  • Gypsy jazz: nothing. The Quintette had no drummer.
//  • Calypso: cowbell on the off-beats, toms instead of a snare backbeat,
//    and the kick on the 3-3-2 (1, the "and" of 2, 4) with the bass. No
//    clave (that's a bossa) and no backbeat over a kick on 1 and 3 (that's
//    a polka).

import 'dart:math' as math;

import '../music/swing.dart';
import '../music/tune.dart';

/// The pieces of the kit the patterns can call for.
enum Drum {
  ride('Ride Cymbal'),
  hiHatPedal('Hi-Hat, Pedal'),
  hiHatClosed('Hi-Hat, Closed'),
  hiHatOpen('Hi-Hat, Open'),
  kick('Kick'),
  snare('Snare'),
  crossStick('Cross-Stick'),
  cowbell('Cowbell'),
  tomHigh('Tom, High'),
  tomLow('Tom, Low'),

  /// The brush swirl: the left hand's circle on the snare head, which is
  /// the sound of a brush groove rather than an ornament on one. Only the
  /// brush kit has it; with sticks it is never asked for.
  ///
  /// Last in the list on purpose. A kit imported from a SoundFont is saved
  /// by each drum's position here, so a value inserted anywhere else would
  /// hand somebody's imported ride to their kick.
  swirl('Brush Swirl');

  const Drum(this.label);

  /// What to call it on screen, now that each one can be chosen on its
  /// own. Comma-first so a list of them sorts and scans by the drum
  /// rather than by which hi-hat it is.
  final String label;
}

/// The drums something imported can stand in for: all of them but the
/// swirl, which belongs to the brush kit. No SoundFont has a brush
/// circling a drumhead, and a row offering to replace one would be
/// offering something nobody can supply.
final importableDrums = [
  for (final drum in Drum.values)
    if (drum != Drum.swirl) drum,
];

/// One hit: [beat] counts from the start of the bar.
///
/// [hard] asks for the harder-struck recording of the drum. That changes the
/// *tone* (more attack, more of the stick), not the loudness, which is
/// [velocity]'s job. A jazz ride is stroked with the tip all night; a funk
/// backbeat is cracked.
class DrumHit {
  const DrumHit({
    required this.drum,
    required this.beat,
    required this.velocity,
    this.hard = false,
    this.beats = 2,
  });

  final Drum drum;
  final double beat;
  final double velocity;
  final bool hard;

  /// How long the sound lasts, in beats. Only the swirl reads it: the arm
  /// turns one full circle in this many beats, and the band stretches the
  /// recording to fit. A swing circle takes two beats, half a turn to a
  /// beat, as it is taught; a bossa's is quicker, because what it is
  /// standing in for there is a shaker and not a circle.
  ///
  /// Every other drum is struck and then left to ring for as long as it
  /// rings, so for them this says nothing.
  final double beats;

  /// The same hit, moved: how a straight pattern becomes a leaning one.
  DrumHit at(double beat) => DrumHit(
    drum: drum,
    beat: beat,
    velocity: velocity,
    hard: hard,
    beats: beats,
  );
}

/// The hits for one bar of [feel]. [bar] counts from the start of the loop,
/// so two-bar patterns (like the clave) and phrase-ending fills line up.
///
/// [swing] is where the off-beat falls inside the beat: a half is even.
/// It reaches every feel. The patterns are written straight and the
/// off-beats are moved once, at the end, so the slider leans a shuffle
/// and a bossa the same way it leans a swing tune, and a pattern stays a
/// description of what is played rather than of when.
/// [brushes] changes what is played and not only what it is played on.
/// Swapping the kit alone leaves the time on the ride, so a brush groove
/// would come out as a brushed cymbal, which is the one part of the kit
/// brushes make sound more metallic rather than less. A brush player
/// moves the time onto the snare head and circles underneath it.
/// [compound] is a bar whose beat divides in three: six eight, twelve
/// eight. A swung groove plays its skip note on every beat there rather
/// than on the backbeats alone, which is the difference between a
/// twelve eight feel and a swing bar with the beats renamed.
List<DrumHit> drumBar({
  required Feel feel,
  required int bar,
  required int beatsPerBar,
  required math.Random random,
  required double swing,
  bool brushes = false,
  bool compound = false,
}) => [
  // Figures written for a four-beat bar lose whatever falls past the end
  // of a shorter one (a waltz keeps the first two beats of the clave).
  for (final hit in switch (feel) {
    Feel.swing when brushes => _swingBrushBar(
      bar,
      beatsPerBar,
      random,
      compound: compound,
    ),
    Feel.swing => _swingBar(bar, beatsPerBar, random, compound: compound),
    Feel.bossa when brushes => _bossaBrushBar(bar, beatsPerBar, random),
    Feel.bossa => _bossaBar(bar, beatsPerBar, random),
    Feel.funk => _funkBar(bar, beatsPerBar, random),
    Feel.calypso => _calypsoBar(bar, beatsPerBar, random),
    Feel.shuffle => _shuffleBar(bar, beatsPerBar, random),
    Feel.samba => _sambaBar(bar, beatsPerBar, random),
    Feel.jazzWaltz when brushes => _jazzWaltzBrushBar(bar, beatsPerBar, random),
    Feel.jazzWaltz => _jazzWaltzBar(bar, beatsPerBar, random),
    Feel.ballad when brushes => _balladBrushBar(bar, beatsPerBar, random),
    Feel.ballad => _balladBar(bar, beatsPerBar, random, compound: compound),
    Feel.secondLine => _secondLineBar(bar, beatsPerBar, random),
    Feel.afroSix => _afroSixBar(bar, beatsPerBar, random),
    // No drummer at all: the guitar's chop is the time. See [Feel.gypsy].
    Feel.gypsy => const <DrumHit>[],
  })
    if (hit.beat < beatsPerBar)
      hit.at(keepsTime(hit.drum) ? hit.beat : leaned(hit.beat, feel, swing)),
];

/// Whether this voice holds the pulse rather than leaning with it.
///
/// The closed hi-hat is the pulse of an even groove. Steady eighths are
/// what makes a bossa a bossa, and a pulse that leans is not a pulse:
/// leaned, its hi-hats lurch, which is the one thing in the kit you
/// cannot do that to.
///
/// Nothing is lost where the sixteenths are what lean: these patterns
/// write the hat in eighths, and an eighth does not move then.
bool keepsTime(Drum drum) =>
    drum == Drum.hiHatClosed ||
    drum == Drum.hiHatOpen ||
    // The circle is one unbroken motion of the arm. Leaning it would be
    // asking the left hand to hesitate half way round.
    drum == Drum.swirl;

/// Where a hit lands once the feel's off-beats are leaned.
double leaned(double beat, Feel feel, double swing) =>
    swungBeat(beat, swing, sixteenths: feel.swingsSixteenths);

double _human(math.Random random) => 0.85 + random.nextDouble() * 0.15;

/// The beats that carry the backbeat, where the hi-hat closes and the
/// snare cracks. In four, 2 and 4; in a waltz, 2 and 3; otherwise every
/// other beat. (Beats count from 0.)
List<int> _backbeats(int beatsPerBar) => switch (beatsPerBar) {
  3 => const [1, 2],
  <= 2 => const [1],
  _ => [for (var beat = 1; beat < beatsPerBar; beat += 2) beat],
};

/// Swing, played with brushes.
///
/// The same time, moved. The right hand taps the ride's rhythm on the
/// snare head instead of on the cymbal, and the left hand keeps a circle
/// going underneath: half a circle to a beat, so one full circle is two
/// beats, building into the backbeat where the hi-hat closes. The cymbal
/// is not touched at all, which is what the basic pattern asks for.
///
/// The taps are quieter than the ride's numbers look because they are not
/// the same drum. The kit is balanced as an overhead hears it, where the
/// snare is the loudest thing and the ride sits 3 dB under it, so the same
/// velocity on the snare is a harder stroke than it was on the cymbal.
List<DrumHit> _swingBrushBar(
  int bar,
  int beatsPerBar,
  math.Random random, {
  bool compound = false,
}) {
  final hits = <DrumHit>[];
  final backbeats = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    final isBackbeat = backbeats.contains(beat);
    // In compound time every beat carries the skip: see [_swingBar].
    final skips = isBackbeat || compound;
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: beat.toDouble(),
        velocity: (isBackbeat ? 0.41 : 0.35) * _human(random),
      ),
    );
    if (skips) {
      hits.add(
        DrumHit(
          drum: Drum.snare,
          beat: beat + 0.5,
          velocity: 0.27 * _human(random),
        ),
      );
    }
    if (isBackbeat) {
      hits.add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.5 * _human(random),
          hard: true,
        ),
      );
    }
    // One circle every two beats, started on the beat before the backbeat
    // so that it builds into it.
    if (beat.isEven) {
      hits.add(
        DrumHit(
          drum: Drum.swirl,
          beat: beat.toDouble(),
          // Well under the taps. A circle is the texture and the taps are
          // the time, and a wash is continuous where a tap is not, so the
          // same velocity makes it the loudest thing in the kit: it was
          // carrying more energy than anything else in either groove.
          velocity: 0.26 * _human(random),
        ),
      );
    }
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat.toDouble(),
        velocity: 0.16 * _human(random),
      ),
    );
  }
  // A bar of three leaves a half circle hanging. Better one circle over
  // the whole bar than two thirds of one.
  if (beatsPerBar.isOdd) {
    hits.removeWhere((hit) => hit.drum == Drum.swirl && hit.beat > 0);
  }
  // The fills are the stick kit's, which are snare fills already: a brush
  // plays them with the edge of the fan rather than the tip.
  if (bar % 8 == 7 && random.nextDouble() < 0.4) {
    final from = (beatsPerBar - 2).toDouble();
    hits
      ..add(
        DrumHit(drum: Drum.snare, beat: from, velocity: 0.5 * _human(random)),
      )
      ..add(DrumHit(drum: Drum.snare, beat: from + 0.5, velocity: 0.4))
      ..add(
        DrumHit(
          drum: Drum.snare,
          beat: from + 1,
          velocity: 0.55 * _human(random),
        ),
      );
  }
  return hits;
}

List<DrumHit> _swingBar(
  int bar,
  int beatsPerBar,
  math.Random random, {
  bool compound = false,
}) {
  final hits = <DrumHit>[];
  final backbeats = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    final isBackbeat = backbeats.contains(beat);
    // Where the skip note goes. In four it is the "a" after 2 and 4,
    // and the beats between are plain quarters. In a compound bar the
    // beat is already in three and the ride takes the first and third
    // of every one of them: "DA-da, DA-da", long-short all the way
    // through, which is the twelve eight feel. A bar of six eight with
    // skips on the backbeats alone is a swing bar with its beats
    // renamed, and sounds like one.
    final skips = isBackbeat || compound;
    hits.add(
      DrumHit(
        drum: Drum.ride,
        beat: beat.toDouble(),
        velocity: (isBackbeat ? 0.62 : 0.52) * _human(random),
      ),
    );
    if (skips) {
      hits.add(
        DrumHit(
          drum: Drum.ride,
          beat: beat + 0.5,
          velocity: 0.4 * _human(random),
        ),
      );
    }
    if (isBackbeat) {
      // The hi-hat closing underfoot, on 2 and 4 as ever.
      hits.add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.5 * _human(random),
          hard: true,
        ),
      );
    }
    // Feathered kick: felt more than heard.
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat.toDouble(),
        velocity: 0.16 * _human(random),
      ),
    );
  }

  // Quiet snare comping on an off-beat, now and then.
  if (random.nextDouble() < 0.3) {
    final beat = random.nextInt(beatsPerBar) + 0.5;
    hits.add(
      DrumHit(drum: Drum.snare, beat: beat, velocity: 0.22 * _human(random)),
    );
  }
  // A kick accent dropped in occasionally: a bomb, struck hard.
  if (random.nextDouble() < 0.12) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: random.nextInt(beatsPerBar) + 0.5,
        velocity: 0.62 * _human(random),
        hard: true,
      ),
    );
  }
  // A small fill over the last two beats of an eight-bar phrase.
  if (bar % 8 == 7 && random.nextDouble() < 0.4) {
    final from = (beatsPerBar - 2).toDouble();
    hits
      ..add(
        DrumHit(drum: Drum.snare, beat: from, velocity: 0.55 * _human(random)),
      )
      ..add(DrumHit(drum: Drum.snare, beat: from + 0.5, velocity: 0.45))
      ..add(
        DrumHit(
          drum: Drum.snare,
          beat: from + 1,
          velocity: 0.6 * _human(random),
        ),
      )
      ..add(DrumHit(drum: Drum.snare, beat: from + 1 + 0.5, velocity: 0.5));
  }
  return hits;
}

/// The bossa clave, in eighth notes across two bars (3–2):
/// bar 1 → 1, the "and" of 2, 4;  bar 2 → 2, the "and" of 3.
const _claveBarOne = [0.0, 1.5, 3.0];
const _claveBarTwo = [1.0, 2.5];

/// A bossa, played with brushes.
///
/// The steady eighths come off the hi-hat. They are the pulse of the
/// groove and they are the one thing a brush cannot do: a fan of wire on
/// a closed hi-hat is a thin scratch, so leaving them there was the worst
/// of both, a brush kit sounding more metallic than the sticks it
/// replaced.
///
/// What goes in their place is a circle on the head. That is not a
/// substitution of convenience: in a bossa the brush is standing in for
/// the ganza, the shaker running underneath everything, and filling
/// between the clave is the job it is given. The circle turns once a beat
/// rather than once in two, because a shaker is quicker than an arm.
///
/// Everything else is as it was. The clave stays where every source puts
/// it, on the edge of the drum, and the surdo-like kick stays on 1 and 3.
List<DrumHit> _bossaBrushBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  for (var beat = 0; beat < beatsPerBar; beat++) {
    hits.add(
      DrumHit(
        drum: Drum.swirl,
        beat: beat.toDouble(),
        // Leaning on 1 and 3 the way the hi-hat's eighths leaned on the
        // beat, so the pulse is still where it was.
        //
        // Well under what those eighths were, though, and for the reason
        // the swing circle is: a wash is continuous where a tick is not,
        // so it carries far more energy at the same velocity. At 0.46 the
        // circle alone was louder than everything else in the groove put
        // together.
        velocity: (beat.isEven ? 0.22 : 0.18) * _human(random),
        beats: 1,
      ),
    );
  }
  for (final beat in (bar.isEven ? _claveBarOne : _claveBarTwo).where(
    (beat) => beat < beatsPerBar,
  )) {
    hits.add(
      DrumHit(
        drum: Drum.crossStick,
        beat: beat,
        // Down from 0.7, which made the clave the loudest thing in the
        // kit: 2.7 dB over the eighths that are the pulse. Five strokes
        // in two bars is the clave and is not too many, but five strokes
        // on top of the groove rather than inside it is what busy sounds
        // like. The cross-stick recording is the quiet end of the
        // library's range and it was being brought right back up again.
        velocity: 0.42 * _human(random),
      ),
    );
  }
  hits
    ..add(DrumHit(drum: Drum.kick, beat: 0, velocity: 0.5 * _human(random)))
    ..add(DrumHit(drum: Drum.kick, beat: 2, velocity: 0.44 * _human(random)));
  if (random.nextDouble() < 0.2) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beatsPerBar - 0.5,
        velocity: 0.36 * _human(random),
      ),
    );
  }
  for (final beat in _backbeats(beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.hiHatPedal,
        beat: beat.toDouble(),
        velocity: 0.38 * _human(random),
        hard: true,
      ),
    );
  }
  return hits;
}

List<DrumHit> _bossaBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  // Straight eighths, on the hi-hat. A drummer moves to the ride for a whole
  // section, not for the odd bar, so this changes only every eight bars.
  // Switching at random made the ride wander in and out of the groove.
  final onRide = (bar ~/ 8) % 3 == 2;
  for (var eighth = 0; eighth < beatsPerBar * 2; eighth++) {
    final beat = eighth / 2;
    hits.add(
      DrumHit(
        drum: onRide ? Drum.ride : Drum.hiHatClosed,
        beat: beat,
        // The ride is a louder recording than the closed hat, so the
        // same velocity on it came out 2.6 dB up and the pulse jumped
        // every time the drummer moved across. It is the same part
        // either way and should be the same level.
        velocity:
            (eighth.isEven ? 0.34 : 0.24) *
            (onRide ? 0.74 : 1) *
            _human(random),
      ),
    );
  }
  // Cross-stick plays the clave, not a backbeat.
  // The clave as far as the bar goes: a short bar keeps its first strokes.
  for (final beat in (bar.isEven ? _claveBarOne : _claveBarTwo).where(
    (beat) => beat < beatsPerBar,
  )) {
    hits.add(
      DrumHit(
        drum: Drum.crossStick,
        beat: beat,
        // Down from 0.7, which made the clave the loudest thing in the
        // kit: 2.7 dB over the eighths that are the pulse. Five strokes
        // in two bars is the clave and is not too many, but five strokes
        // on top of the groove rather than inside it is what busy sounds
        // like. The cross-stick recording is the quiet end of the
        // library's range and it was being brought right back up again.
        velocity: 0.42 * _human(random),
      ),
    );
  }
  // Surdo-like kick on 1 and 3, with the odd push into the next bar.
  hits
    ..add(DrumHit(drum: Drum.kick, beat: 0, velocity: 0.5 * _human(random)))
    ..add(DrumHit(drum: Drum.kick, beat: 2, velocity: 0.44 * _human(random)));
  if (random.nextDouble() < 0.2) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beatsPerBar - 0.5,
        velocity: 0.36 * _human(random),
      ),
    );
  }
  // Hi-hat pedal keeps 2 and 4 underfoot.
  for (final beat in _backbeats(beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.hiHatPedal,
        beat: beat.toDouble(),
        velocity: 0.38 * _human(random),
        hard: true,
      ),
    );
  }
  return hits;
}

/// Kick figures, in eighths from the start of the bar.
const funkKicks = [
  [0.0, 1.5],
  [0.0, 1.5, 2.5],
  [0.0, 2.5, 3.5],
  [0.0, 0.75, 2.5],
  [0.0, 1.5, 3.0],
];

List<DrumHit> _funkBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  final openHatOnTheAnd = random.nextDouble() < 0.35;
  for (var eighth = 0; eighth < beatsPerBar * 2; eighth++) {
    final beat = eighth / 2;
    final isLastAnd = eighth == beatsPerBar * 2 - 1;
    hits.add(
      DrumHit(
        drum: openHatOnTheAnd && isLastAnd ? Drum.hiHatOpen : Drum.hiHatClosed,
        beat: beat,
        // Downbeats louder than the off-beats: that's the funk lilt.
        velocity: (eighth.isEven ? 0.72 : 0.45) * _human(random),
        hard: eighth.isEven || isLastAnd,
      ),
    );
  }
  // Backbeat.
  //
  // Down from 0.95, which was a number read as "a funk backbeat is struck
  // as hard as anything in the kit" without looking at what it was being
  // multiplied by. The snare is the loudest recording in the bank, 22 dB
  // over the kick, because the kit is balanced as an overhead hears it:
  // the snare cracks and the kick is across the room. At 0.95 the
  // backbeat came out 8 dB over the hats and 23 over the kick, and a
  // funk groove with an inaudible kick is not a funk groove.
  //
  // Still hard, so it is the hard-struck recording and keeps its crack.
  // Only the level of it has come down.
  for (final beat in _backbeats(beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: beat.toDouble(),
        velocity: 0.5 * _human(random),
        hard: true,
      ),
    );
  }
  // Ghost snare between the backbeats, sometimes. Scaled with the
  // backbeat: at a quarter against a backbeat of a half it would be
  // louder than the thing it is a ghost of, because it is not struck
  // hard and so is lifted to the loud layer's level by the levelling.
  if (random.nextDouble() < 0.4) {
    hits.add(
      DrumHit(drum: Drum.snare, beat: 2.5, velocity: 0.13 * _human(random)),
    );
  }
  // Taken from the bar rather than rolled, and held for two bars, because
  // a funk kick is a riff. Rolling it a bar at a time gave a drummer who
  // had never played the figure before and never would again. It is also
  // what lets the bass play the same one: both work it out from the bar
  // number rather than one of them having to be told.
  for (final beat in funkKicksFor(bar)) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat,
        velocity: 0.85 * _human(random),
        hard: true,
      ),
    );
  }
  return hits;
}

/// Tom figures for calypso, in beats: (high tom, low tom). The toms carry
/// the calypso in place of a snare backbeat, the way Max Roach plays it.
/// The 3-3-2, in beats: the figure the calypso is built on. Three eighths,
/// three eighths, two: the one everybody plays together.
const _tresillo = [0.0, 1.5, 3.0];

const _calypsoToms = [
  ([1.0, 2.5], [3.0]),
  ([1.0, 2.5], [3.0, 3.5]),
  ([1.0, 1.5], [2.5, 3.0]),
  ([2.5], [1.0, 3.0]),
];

/// The kick figure for [bar]: a two-bar riff, so the groove is something
/// being played rather than something being chosen.
List<double> funkKicksFor(int bar) => funkKicks[(bar ~/ 2) % funkKicks.length];

List<DrumHit> _calypsoBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  // The whole band is playing the 3-3-2 (the bass, the kick and the
  // accents all land on it), so the bell's job is to state a steady pulse
  // for it to lean against, not to syncopate as well. Eighths, with the
  // 3-3-2 picked out by weight rather than by leaving gaps: that contrast
  // is the lift, and everything still agrees on where the bar is.
  for (var eighth = 0; eighth < beatsPerBar * 2; eighth++) {
    final beat = eighth / 2;
    final accented = _tresillo.contains(beat);
    hits.add(
      DrumHit(
        drum: Drum.cowbell,
        // Well under the hi-hat a bossa keeps time on, because a cowbell
        // carries further than a hi-hat does at the same weight. The
        // in-between notes are ghosts: there to be felt rather than heard,
        // so what you hear is the figure and not the bell.
        beat: beat,
        velocity: (accented ? 0.34 : 0.13) * _human(random),
        hard: accented,
      ),
    );
  }
  // The kick on the 3-3-2 with the bass.
  for (final beat in _tresillo.where((beat) => beat < beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat,
        velocity: (beat == 0 ? 0.58 : 0.44) * _human(random),
      ),
    );
  }
  // A rim click on the backbeat. Without it nothing said where 2 and 4
  // were, and a groove made only of syncopation has nothing to be
  // syncopated against.
  for (final beat in _backbeats(beatsPerBar)) {
    hits
      ..add(
        DrumHit(
          drum: Drum.crossStick,
          beat: beat.toDouble(),
          velocity: 0.5 * _human(random),
        ),
      )
      ..add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.28 * _human(random),
        ),
      );
  }
  // Toms only to turn a phrase around. They used to play a figure every
  // bar, against the 3-3-2 rather than with it, and that was most of why
  // this groove sounded like three grooves at once.
  if (bar % 8 == 7 && random.nextDouble() < 0.7) {
    final (high, low) = _calypsoToms[random.nextInt(_calypsoToms.length)];
    for (final beat in high.where((beat) => beat < beatsPerBar)) {
      hits.add(
        DrumHit(drum: Drum.tomHigh, beat: beat, velocity: 0.5 * _human(random)),
      );
    }
    for (final beat in low.where((beat) => beat < beatsPerBar)) {
      hits.add(
        DrumHit(drum: Drum.tomLow, beat: beat, velocity: 0.55 * _human(random)),
      );
    }
  }
  return hits;
}

/// What the drummer plays when the band leaves them the bars: trading
/// fours, and the like.
///
/// It's a phrase, not a pattern: an answer to what you just played, built
/// out of eighth notes (swung in a swing feel) spread over the snare and
/// toms, with the kick underneath. The hi-hat stays on the backbeat all the
/// way through, because that's what keeps everyone's place, and the last bar
/// fills so the band knows to come back in.
///
/// [bar] counts from the start of the drummer's turn, [of] how many bars
/// they have.
List<DrumHit> drumSoloBar({
  required Feel feel,
  required int bar,
  required int of,
  required int beatsPerBar,
  required math.Random random,
  required double swing,
}) {
  final hits = <DrumHit>[];
  final swung = !feel.swingsSixteenths;
  final last = bar == of - 1;

  // The foot keeps the time, so the bar is never lost.
  for (final beat in _backbeats(beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.hiHatPedal,
        beat: beat.toDouble(),
        velocity: 0.42 * _human(random),
        hard: true,
      ),
    );
  }

  // Which eighths are struck. The phrase leaves gaps (the rests are what
  // make it a phrase), but the last bar fills up as it drives back in.
  final eighths = beatsPerBar * 2;
  for (var eighth = 0; eighth < eighths; eighth++) {
    final onBeat = eighth.isEven;
    final inTheRun = last && eighth >= eighths - 4;
    final chance = inTheRun
        ? 1.0
        : onBeat
        ? 0.6
        : 0.5;
    if (random.nextDouble() > chance) continue;
    // Swung eighths sit late, as they do on the ride.
    final beat = onBeat ? eighth / 2 : (eighth ~/ 2) + (swung ? swing : 0.5);
    // The snare leads; the toms answer it, lower as the phrase falls.
    final drum = inTheRun
        ? (eighth >= eighths - 2 ? Drum.tomLow : Drum.tomHigh)
        : switch (random.nextInt(5)) {
            0 => Drum.tomHigh,
            1 => Drum.tomLow,
            _ => Drum.snare,
          };
    hits.add(
      DrumHit(
        drum: drum,
        beat: beat,
        velocity: (onBeat ? 0.72 : 0.56) * _human(random),
        hard: onBeat,
      ),
    );
  }

  // The kick punctuates rather than keeps time.
  for (var beat = 0; beat < beatsPerBar; beat++) {
    if (random.nextDouble() < 0.3) {
      hits.add(
        DrumHit(
          drum: Drum.kick,
          beat: beat + (random.nextBool() ? 0.0 : (swung ? swing : 0.5)),
          velocity: 0.6 * _human(random),
          hard: true,
        ),
      );
    }
  }

  return [
    for (final hit in hits)
      if (hit.beat < beatsPerBar) hit,
  ];
}

/// The shuffle: swing's triplet, played out loud.
///
/// Every beat gets its "a", the last note of the triplet, so the ride is
/// a constant long-short bounce rather than swing's spaced ding-ding-a-ding.
/// And the snare cracks on the backbeat instead of answering the soloist.
/// That backbeat is the whole difference: the same eighths, sat on.
List<DrumHit> _shuffleBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  final backbeats = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    final isBackbeat = backbeats.contains(beat);
    hits
      ..add(
        DrumHit(
          drum: Drum.ride,
          beat: beat.toDouble(),
          velocity: (isBackbeat ? 0.6 : 0.5) * _human(random),
        ),
      )
      // The "a", where the bounce lives. Written straight and leaned at
      // the end: a shuffle was pinned to the triplet here while the
      // comping over it followed the slider, so the two halves of the
      // band disagreed about the same groove.
      ..add(
        DrumHit(
          drum: Drum.ride,
          beat: beat + 0.5,
          velocity: 0.34 * _human(random),
        ),
      );
  }
  for (final beat in backbeats) {
    hits
      ..add(
        DrumHit(
          drum: Drum.snare,
          beat: beat.toDouble(),
          velocity: 0.78 * _human(random),
          hard: true,
        ),
      )
      ..add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.4 * _human(random),
        ),
      );
  }
  // Kick on the odd beats, under the snare rather than with it.
  for (var beat = 0; beat < beatsPerBar; beat += 2) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat.toDouble(),
        velocity: (beat == 0 ? 0.6 : 0.46) * _human(random),
      ),
    );
  }
  // A pickup into the next phrase, on the "a" of the last beat.
  if (bar % 4 == 3 && random.nextDouble() < 0.5) {
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: beatsPerBar - 1 + tripletSwing,
        velocity: 0.5 * _human(random),
      ),
    );
  }
  return hits;
}

/// The tamborim's figure, in beats, over two bars: the syncopation that
/// says samba rather than bossa. Eighths, and none of them on beat one.
const _tamborimBarOne = [1.0, 1.5, 2.5, 3.5];
const _tamborimBarTwo = [0.5, 1.5, 2.0, 3.0];

/// A samba: quicker than a bossa, and leaning the other way.
///
/// A bossa sits on beat one. A samba answers on the second half of the
/// bar (the surdo, the big low drum, is quiet on one and lands on three),
/// and everything else is hung off that.
///
/// Written in four, at the tempo a samba is actually counted off. A samba
/// is a 2/4 dance, and writing its sixteenths straight into a 4/4 bar is
/// how you end up playing it at twice the speed: at 200 to the bar that
/// was thirteen shaker notes a second and a surdo on every beat, where the
/// real thing is nearer seven and one every other beat.
List<DrumHit> _sambaBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  // The shaker of a bateria, played with a stick: eighths, the off-beats
  // lighter.
  for (var eighth = 0; eighth < beatsPerBar * 2; eighth++) {
    hits.add(
      DrumHit(
        drum: Drum.hiHatClosed,
        beat: eighth / 2,
        velocity: (eighth.isEven ? 0.28 : 0.17) * _human(random),
      ),
    );
  }
  // The surdo, every other beat: quiet on one, and the weight of the whole
  // thing on three.
  for (var beat = 0; beat < beatsPerBar; beat += 2) {
    final answering = beat != 0;
    hits
      ..add(
        DrumHit(
          drum: Drum.tomLow,
          beat: beat.toDouble(),
          velocity: (answering ? 0.72 : 0.3) * _human(random),
          hard: answering,
        ),
      )
      ..add(
        DrumHit(
          drum: Drum.kick,
          beat: beat.toDouble(),
          velocity: (answering ? 0.5 : 0.34) * _human(random),
        ),
      );
  }
  // The tamborim across the top, two bars long so it doesn't sit still.
  for (final beat in (bar.isEven ? _tamborimBarOne : _tamborimBarTwo).where(
    (beat) => beat < beatsPerBar,
  )) {
    hits.add(
      DrumHit(
        drum: Drum.crossStick,
        beat: beat,
        velocity: 0.55 * _human(random),
        hard: true,
      ),
    );
  }
  return hits;
}

/// A jazz waltz: swing in three, with the lift after 2.
///
/// The ride plays the figure a waltz is taught as, "one, two, and-of-two,
/// three": a skip note after the second beat and beat three left plain.
/// That is the whole difference from swing counted in three, which puts a
/// skip after every backbeat and comes out hurried. The hi-hat closes
/// under 2 and 3 (under 2 alone is the other common way), the kick is
/// feathered, and the snare answers now and then.
///
/// Beat one carries the accent. A waltz has a strong one in a way a swing
/// bar does not, and the ride is where that is heard.
List<DrumHit> _jazzWaltzBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  final closes = _backbeats(beatsPerBar);
  // The second beat of the bar: where the lift goes, whatever the bar
  // length, so a waltz figure asked for in four still leans where a
  // waltz leans.
  const lifts = 1;
  for (var beat = 0; beat < beatsPerBar; beat++) {
    hits.add(
      DrumHit(
        drum: Drum.ride,
        beat: beat.toDouble(),
        velocity: (beat == 0 ? 0.62 : 0.5) * _human(random),
      ),
    );
    if (beat == lifts) {
      hits.add(
        DrumHit(
          drum: Drum.ride,
          beat: beat + 0.5,
          velocity: 0.4 * _human(random),
        ),
      );
    }
    if (closes.contains(beat)) {
      hits.add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.5 * _human(random),
          hard: true,
        ),
      );
    }
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat.toDouble(),
        velocity: 0.16 * _human(random),
      ),
    );
  }
  // A second skip, after the last beat of the bar and into the next one.
  // Where a waltz's other syncopations live, and not in every bar.
  if (random.nextDouble() < 0.25) {
    hits.add(
      DrumHit(
        drum: Drum.ride,
        beat: beatsPerBar - 0.5,
        velocity: 0.38 * _human(random),
      ),
    );
  }
  // Snare comping, on the "and" of 2 or on 3: the two places the waltz
  // answers itself.
  if (random.nextDouble() < 0.3) {
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: random.nextBool() ? lifts + 0.5 : (beatsPerBar - 1).toDouble(),
        velocity: 0.22 * _human(random),
      ),
    );
  }
  if (bar % 8 == 7 && random.nextDouble() < 0.35) {
    hits
      ..add(
        DrumHit(
          drum: Drum.snare,
          beat: beatsPerBar - 1,
          velocity: 0.5 * _human(random),
        ),
      )
      ..add(DrumHit(drum: Drum.snare, beat: beatsPerBar - 0.5, velocity: 0.42));
  }
  return hits;
}

/// The same waltz, played with brushes.
///
/// The right hand taps the ride's figure on the head and the left hand
/// turns one circle to the bar, so the circle and the bar begin together.
/// Half a circle to a beat, as in four, would leave the third beat of
/// every bar half way round.
List<DrumHit> _jazzWaltzBrushBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[
    DrumHit(
      drum: Drum.swirl,
      beat: 0,
      velocity: 0.26 * _human(random),
      beats: beatsPerBar.toDouble(),
    ),
  ];
  for (final hit in _jazzWaltzBar(bar, beatsPerBar, random)) {
    hits.add(switch (hit.drum) {
      // The time comes off the cymbal and onto the head, quieter than the
      // ride's numbers look: the snare is the loudest thing an overhead
      // hears, so the same velocity is a harder stroke there.
      Drum.ride => DrumHit(
        drum: Drum.snare,
        beat: hit.beat,
        velocity: hit.velocity * 0.68,
      ),
      _ => hit,
    });
  }
  return hits;
}

/// A ballad, with sticks: the slowest swing there is, and nothing spare.
///
/// The ride keeps quarters with one skip note at the end of the bar
/// rather than after every backbeat, the hi-hat closes under 2 and 4, the
/// kick is feathered, and there are no bombs. A ballad is the one place
/// a drummer is not commenting.
List<DrumHit> _balladBar(
  int bar,
  int beatsPerBar,
  math.Random random, {
  bool compound = false,
}) {
  final hits = <DrumHit>[];
  final closes = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    hits.add(
      DrumHit(
        drum: Drum.ride,
        beat: beat.toDouble(),
        velocity: (closes.contains(beat) ? 0.42 : 0.36) * _human(random),
      ),
    );
    // A slow twelve eight is where the triplet ride belongs most of
    // all: the beat and the last third of it, every beat.
    if (compound) {
      hits.add(
        DrumHit(
          drum: Drum.ride,
          beat: beat + 0.5,
          velocity: 0.28 * _human(random),
        ),
      );
    }
    if (closes.contains(beat)) {
      hits.add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.38 * _human(random),
        ),
      );
    }
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat.toDouble(),
        velocity: 0.12 * _human(random),
      ),
    );
  }
  // The one skip note, into the next bar.
  hits.add(
    DrumHit(
      drum: Drum.ride,
      beat: beatsPerBar - 0.5,
      velocity: 0.3 * _human(random),
    ),
  );
  return hits;
}

/// A ballad, with brushes: what the tune is normally played with.
///
/// The left hand circles the head without stopping, half a circle to a
/// beat, and the change of direction at the top and bottom of the circle
/// is what marks the pulse. The right hand does not keep time at all: it
/// touches the head on 2 and 4, where the hands would cross. The hi-hat
/// closes under those two beats, barely.
List<DrumHit> _balladBrushBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  for (var beat = 0; beat < beatsPerBar; beat++) {
    if (beat.isEven) {
      hits.add(
        DrumHit(
          drum: Drum.swirl,
          beat: beat.toDouble(),
          velocity: 0.24 * _human(random),
        ),
      );
    }
    if (_backbeats(beatsPerBar).contains(beat)) {
      hits
        ..add(
          DrumHit(
            drum: Drum.snare,
            beat: beat.toDouble(),
            velocity: 0.3 * _human(random),
          ),
        )
        ..add(
          DrumHit(
            drum: Drum.hiHatPedal,
            beat: beat.toDouble(),
            velocity: 0.3 * _human(random),
          ),
        );
    }
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: beat.toDouble(),
        velocity: 0.1 * _human(random),
      ),
    );
  }
  // An odd bar leaves a half circle hanging: one circle over the whole
  // bar instead, as the waltz does.
  if (beatsPerBar.isOdd) {
    hits
      ..removeWhere((hit) => hit.drum == Drum.swirl)
      ..add(
        DrumHit(
          drum: Drum.swirl,
          beat: 0,
          velocity: 0.24 * _human(random),
          beats: beatsPerBar.toDouble(),
        ),
      );
  }
  return hits;
}

/// The second line: New Orleans' street beat.
///
/// The kick carries the figure. The accent skeleton a parade is taught
/// by runs "1, the a of 1, the and of 2, 3, the a of 3, the and of 4",
/// and the kick takes the downbeats and the off-beat pickups out of it:
/// 1, the "and" of 2, 3 and the "and" of 4, that last one leaning into
/// the next bar. The snare cracks the backbeat on 2 and 4 with ghost
/// notes around it, and there is no cymbal at all: a brass band has two
/// drummers, a bass drum and a snare, and this is them.
///
/// It is swung, but not squarely: the sources put it between swung
/// eighths and loose sixteenths, which is what the feel's own swing
/// setting does with it once the tempo is known.
List<DrumHit> _secondLineBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  final backbeats = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    if (beat.isEven) {
      // The downbeats of the figure: 1 and 3 in four.
      hits.add(
        DrumHit(
          drum: Drum.kick,
          beat: beat.toDouble(),
          velocity: (beat == 0 ? 0.72 : 0.6) * _human(random),
          hard: beat == 0,
        ),
      );
    } else {
      // The pickup off the beat after each backbeat, which is what makes
      // it a second line rather than a march.
      hits.add(
        DrumHit(
          drum: Drum.kick,
          beat: beat + 0.5,
          velocity: 0.62 * _human(random),
          hard: true,
        ),
      );
    }
    if (backbeats.contains(beat)) {
      hits
        ..add(
          DrumHit(
            drum: Drum.snare,
            beat: beat.toDouble(),
            velocity: 0.72 * _human(random),
            hard: true,
          ),
        )
        // The ghost notes the backbeat sits in: played, but under the
        // band rather than on top of it.
        ..add(
          DrumHit(
            drum: Drum.snare,
            beat: beat + 0.5,
            velocity: 0.18 * _human(random),
          ),
        );
    } else {
      hits.add(
        DrumHit(
          drum: Drum.snare,
          beat: beat + 0.5,
          velocity: 0.16 * _human(random),
        ),
      );
    }
    // The hi-hat keeps the walking pulse under all of it, on the
    // backbeats as it does everywhere else in this file.
    if (backbeats.contains(beat)) {
      hits.add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: beat.toDouble(),
          velocity: 0.42 * _human(random),
        ),
      );
    }
  }
  // The snare's own vocabulary: an extra crack off the beat, now and
  // then, in place of a fill.
  if (random.nextDouble() < 0.35) {
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: (beatsPerBar - 1) + 0.5,
        velocity: 0.5 * _human(random),
        hard: true,
      ),
    );
  }
  return hits;
}

/// The standard bell, in eighths of its twelve-eighth cycle.
///
/// Seven strokes: the first on the downbeat, then the third, fifth,
/// sixth, eighth, tenth and twelfth eighth. It is the same pattern
/// whether it is written in 6/8, 12/8 or 3/4, which is why it is kept
/// here as a cycle of eighths and laid over whatever bar it meets.
const _bellEighths = [0, 2, 4, 5, 7, 9, 11];

/// How long that cycle is in the band's beats: four pulses of three.
const _bellBeats = 4;

/// Afro 6/8: the bell over a compound bar.
///
/// Written as a cycle rather than as a bar, because the bell is twelve
/// eighths long whatever the bar is: in 6/8 it takes two bars, in 12/8
/// one, and on a tune in four it is the same seven strokes over a bar of
/// triplets. [bar] says where in the cycle this bar starts.
///
/// The kick is the bombo, on the second beat of the cycle. The hi-hat
/// closes on the two halves of it; where a hi-hat goes in this groove is
/// the one thing the sources would not agree on, and a drummer who knows
/// the music warns that the waltzy foot heard in some jazz versions is
/// not Cuban practice, so it is kept to the halves and out of the way.
List<DrumHit> _afroSixBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  // Where this bar begins inside the twelve-eighth cycle.
  final start = (bar * beatsPerBar) % _bellBeats;
  double? inThisBar(double atInCycle) {
    final at = atInCycle - start;
    return at >= 0 && at < beatsPerBar ? at : null;
  }

  for (final eighth in _bellEighths) {
    final at = inThisBar(eighth / 3);
    if (at == null) continue;
    hits.add(
      DrumHit(
        drum: Drum.cowbell,
        // The downbeat of the cycle carries the weight; the rest are the
        // pattern going round.
        velocity: (eighth == 0 ? 0.6 : 0.46) * _human(random),
        beat: at,
      ),
    );
  }
  // The bombo, on the second beat of the cycle.
  final bombo = inThisBar(1);
  if (bombo != null) {
    hits.add(
      DrumHit(drum: Drum.kick, beat: bombo, velocity: 0.6 * _human(random)),
    );
  }
  for (final half in [0.0, 2.0]) {
    final at = inThisBar(half);
    if (at != null) {
      hits.add(
        DrumHit(
          drum: Drum.hiHatPedal,
          beat: at,
          velocity: 0.4 * _human(random),
        ),
      );
    }
  }
  // The cross-stick the handouts call optional: now and then, on the
  // half way round, where it answers the bell rather than doubling it.
  final answer = inThisBar(2);
  if (answer != null && random.nextDouble() < 0.4) {
    hits.add(
      DrumHit(
        drum: Drum.crossStick,
        beat: answer,
        velocity: 0.4 * _human(random),
      ),
    );
  }
  return hits;
}
