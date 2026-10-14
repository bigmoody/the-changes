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
  });

  final Drum drum;
  final double beat;
  final double velocity;
  final bool hard;

  /// The same hit, moved: how a straight pattern becomes a leaning one.
  DrumHit at(double beat) =>
      DrumHit(drum: drum, beat: beat, velocity: velocity, hard: hard);
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
List<DrumHit> drumBar({
  required Feel feel,
  required int bar,
  required int beatsPerBar,
  required math.Random random,
  required double swing,
  bool brushes = false,
}) => [
  // Figures written for a four-beat bar lose whatever falls past the end
  // of a shorter one (a waltz keeps the first two beats of the clave).
  for (final hit in switch (feel) {
    Feel.swing when brushes => _swingBrushBar(bar, beatsPerBar, random),
    Feel.swing => _swingBar(bar, beatsPerBar, random),
    Feel.bossa => _bossaBar(bar, beatsPerBar, random),
    Feel.funk => _funkBar(bar, beatsPerBar, random),
    Feel.calypso => _calypsoBar(bar, beatsPerBar, random),
    Feel.shuffle => _shuffleBar(bar, beatsPerBar, random),
    Feel.samba => _sambaBar(bar, beatsPerBar, random),
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
List<DrumHit> _swingBrushBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  final backbeats = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    final isBackbeat = backbeats.contains(beat);
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: beat.toDouble(),
        velocity: (isBackbeat ? 0.41 : 0.35) * _human(random),
      ),
    );
    if (isBackbeat) {
      hits
        ..add(
          DrumHit(
            drum: Drum.snare,
            beat: beat + 0.5,
            velocity: 0.27 * _human(random),
          ),
        )
        ..add(
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
          velocity: 0.5 * _human(random),
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

List<DrumHit> _swingBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  final backbeats = _backbeats(beatsPerBar);
  for (var beat = 0; beat < beatsPerBar; beat++) {
    final isBackbeat = backbeats.contains(beat);
    hits.add(
      DrumHit(
        drum: Drum.ride,
        beat: beat.toDouble(),
        velocity: (isBackbeat ? 0.62 : 0.52) * _human(random),
      ),
    );
    if (isBackbeat) {
      // The "a" after 2 and 4, written straight and leaned at the end,
      // and the hi-hat closing underfoot.
      hits.add(
        DrumHit(
          drum: Drum.ride,
          beat: beat + 0.5,
          velocity: 0.4 * _human(random),
        ),
      );
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
        velocity: (eighth.isEven ? 0.34 : 0.24) * _human(random),
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
        velocity: 0.7 * _human(random),
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
const _funkKicks = [
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
  for (final beat in _backbeats(beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.snare,
        beat: beat.toDouble(),
        velocity: 0.95 * _human(random),
        hard: true,
      ),
    );
  }
  // Ghost snare between the backbeats, sometimes.
  if (random.nextDouble() < 0.4) {
    hits.add(
      DrumHit(drum: Drum.snare, beat: 2.5, velocity: 0.25 * _human(random)),
    );
  }
  for (final beat in _funkKicks[random.nextInt(_funkKicks.length)]) {
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
