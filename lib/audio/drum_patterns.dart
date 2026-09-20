// What the drummer plays, bar by bar, in each feel.
//
// A pattern is just a list of hits: which drum, on which beat of the bar,
// how hard. The synth turns those into recorded (or synthesised) sounds.
//
//  • Swing: the ride pattern "ding, ding-a ding" with the hi-hat pedal on 2
//    and 4, a barely-there kick, occasional quiet snare comping, the odd
//    kick accent ("dropping bombs") and a fill at the end of a phrase.
//  • Bossa nova: straight eighths on the hi-hat or ride, and the cross-stick
//    playing the bossa clave — a two-bar pattern, not a backbeat.
//  • Funk: eighths on the hi-hat, snare backbeat on 2 and 4, and a
//    syncopated kick that changes from bar to bar.
//  • Calypso: cowbell on the off-beats, toms instead of a snare backbeat,
//    and the kick on the 3-3-2 (1, the "and" of 2, 4) with the bass. No
//    clave (that's a bossa) and no backbeat over a kick on 1 and 3 (that's
//    a polka).

import 'dart:math' as math;

import '../music/tune.dart';

/// The pieces of the kit the patterns can call for.
enum Drum {
  ride,
  hiHatPedal,
  hiHatClosed,
  hiHatOpen,
  kick,
  snare,
  crossStick,
  cowbell,
  tomHigh,
  tomLow,
}

/// One hit: [beat] counts from the start of the bar.
///
/// [hard] asks for the harder-struck recording of the drum. That changes the
/// *tone* — more attack, more of the stick — not the loudness, which is
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
}

/// The hits for one bar of [feel]. [bar] counts from the start of the loop,
/// so two-bar patterns (like the clave) and phrase-ending fills line up.
List<DrumHit> drumBar({
  required Feel feel,
  required int bar,
  required int beatsPerBar,
  required math.Random random,
}) => [
  // Figures written for a four-beat bar lose whatever falls past the end
  // of a shorter one (a waltz keeps the first two beats of the clave).
  for (final hit in switch (feel) {
    Feel.swing => _swingBar(bar, beatsPerBar, random),
    Feel.bossa => _bossaBar(bar, beatsPerBar, random),
    Feel.funk => _funkBar(bar, beatsPerBar, random),
    Feel.calypso => _calypsoBar(bar, beatsPerBar, random),
  })
    if (hit.beat < beatsPerBar) hit,
];

double _human(math.Random random) => 0.85 + random.nextDouble() * 0.15;

/// The beats that carry the backbeat — where the hi-hat closes and the
/// snare cracks. In four, 2 and 4; in a waltz, 2 and 3; otherwise every
/// other beat. (Beats count from 0.)
List<int> _backbeats(int beatsPerBar) => switch (beatsPerBar) {
  3 => const [1, 2],
  <= 2 => const [1],
  _ => [for (var beat = 1; beat < beatsPerBar; beat += 2) beat],
};

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
      // The swung "a" after 2 and 4, and the hi-hat closing underfoot.
      hits.add(
        DrumHit(
          drum: Drum.ride,
          beat: beat + 2 / 3,
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
    final beat = random.nextInt(beatsPerBar) + 2 / 3;
    hits.add(
      DrumHit(drum: Drum.snare, beat: beat, velocity: 0.22 * _human(random)),
    );
  }
  // A kick accent dropped in occasionally — a bomb, struck hard.
  if (random.nextDouble() < 0.12) {
    hits.add(
      DrumHit(
        drum: Drum.kick,
        beat: random.nextInt(beatsPerBar) + 2 / 3,
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
      ..add(DrumHit(drum: Drum.snare, beat: from + 2 / 3, velocity: 0.45))
      ..add(
        DrumHit(
          drum: Drum.snare,
          beat: from + 1,
          velocity: 0.6 * _human(random),
        ),
      )
      ..add(DrumHit(drum: Drum.snare, beat: from + 1 + 2 / 3, velocity: 0.5));
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
  // section, not for the odd bar, so this changes only every eight bars —
  // switching at random made the ride wander in and out of the groove.
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
/// the calypso in place of a snare backbeat — the way Max Roach plays it.
const _calypsoToms = [
  ([1.0, 2.5], [3.0]),
  ([1.0, 2.5], [3.0, 3.5]),
  ([1.0, 1.5], [2.5, 3.0]),
  ([2.5], [1.0, 3.0]),
];

List<DrumHit> _calypsoBar(int bar, int beatsPerBar, math.Random random) {
  final hits = <DrumHit>[];
  // The bell on every off-beat, a soft touch on the downbeat: the sound of
  // the Caribbean more than anything else in the kit.
  for (var eighth = 0; eighth < beatsPerBar * 2; eighth++) {
    final offBeat = eighth.isOdd;
    if (!offBeat && eighth != 0) continue;
    hits.add(
      DrumHit(
        drum: Drum.cowbell,
        beat: eighth / 2,
        velocity: (offBeat ? 0.5 : 0.3) * _human(random),
        hard: offBeat,
      ),
    );
  }
  // Hi-hat foot on 2 and 4, keeping time underneath.
  for (final beat in _backbeats(beatsPerBar)) {
    hits.add(
      DrumHit(
        drum: Drum.hiHatPedal,
        beat: beat.toDouble(),
        velocity: 0.3 * _human(random),
      ),
    );
  }
  // The kick with the bass's 3-3-2: 1, the "and" of 2, 4.
  hits
    ..add(DrumHit(drum: Drum.kick, beat: 0, velocity: 0.55 * _human(random)))
    ..add(DrumHit(drum: Drum.kick, beat: 1.5, velocity: 0.42 * _human(random)))
    ..add(DrumHit(drum: Drum.kick, beat: 3, velocity: 0.38 * _human(random)));

  // A tom roll to close an eight-bar phrase; otherwise one of the figures,
  // mostly the first two so the groove settles.
  final (high, low) = bar % 8 == 7 && random.nextDouble() < 0.6
      ? ([2.0, 2.5], [3.0, 3.25, 3.5, 3.75])
      : _calypsoToms[random.nextDouble() < 0.7
            ? bar % 2
            : 2 + random.nextInt(2)];
  for (final beat in high) {
    hits.add(
      DrumHit(drum: Drum.tomHigh, beat: beat, velocity: 0.5 * _human(random)),
    );
  }
  for (final beat in low) {
    hits.add(
      DrumHit(drum: Drum.tomLow, beat: beat, velocity: 0.55 * _human(random)),
    );
  }
  return hits;
}

/// What the drummer plays when the band leaves them the bars — trading
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
}) {
  final hits = <DrumHit>[];
  final swung = feel == Feel.swing;
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

  // Which eighths are struck. The phrase leaves gaps — the rests are what
  // make it a phrase — but the last bar fills up as it drives back in.
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
    final beat = onBeat ? eighth / 2 : (eighth ~/ 2) + (swung ? 2 / 3 : 0.5);
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
          beat: beat + (random.nextBool() ? 0.0 : (swung ? 2 / 3 : 0.5)),
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
