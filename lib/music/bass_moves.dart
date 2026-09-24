// What a walking bassist does through one chord.
//
// Four beats, and the line has to arrive on the next chord sounding like
// it meant to. Between those two facts is nearly everything a bass player
// knows, and it is a surprisingly short list: go up the chord, go down
// it, walk the scale, leap the octave, or spend the whole bar creeping
// towards the next root from above or below.
//
// These are the band's own shapes, not a parallel set written for a
// lesson. The bassist picks from this list every bar of every tune in the
// app, the same way the pianist picks from the comping figures, so what
// is taught here cannot drift from what is played.
//
// Two things run through nearly all of them and are worth saying once
// rather than in every description. The first beat of a chord is almost
// always its root, because that is what tells everybody else the change
// has happened. And the last beat before a change is usually an approach
// note, a semitone or a step from where the line is about to land, which
// is what makes an arrival sound chosen rather than stumbled into.
//
// Usually, not always: Up to the 7th ends on the 7th and leaves the
// arrival to the next chord's own root. That is the exception and it is
// deliberate, so it is written down here rather than left for somebody
// to find and assume is a bug.

/// One shape through a chord.
enum BassMove {
  arpeggioUp(
    'Arpeggio up',
    'Root, 3rd, 5th, then a note leading into the next chord. The plainest '
        'thing that works, and half of all walking is some version of it.',
  ),
  scaleUp(
    'Scale up',
    'Root, 2nd, 3rd, and away. Smoother than the arpeggio and it covers '
        'less ground, so it sits well under a busy soloist.',
  ),
  scaleDown(
    'Scale down',
    'Root, then the 7th and 6th below it. Going down is the half of '
        'walking people forget, and a line that only ever climbs runs out '
        'of neck.',
  ),
  arpeggioDown(
    'Arpeggio down',
    'Root, then the 5th and 3rd below. The same shape as the arpeggio up, '
        'read the other way, and it lands somewhere quite different.',
  ),
  fifthAndSixth(
    'Fifth and sixth',
    'Root, 5th, 6th. The 6th is not in the chord and does not need to be: '
        'it is passing, and it is what stops the bar sounding like an '
        'exercise.',
  ),
  octaveLeap(
    'Octave leap',
    'Root, the octave above, then back down through the 7th. The leap '
        'gives the bar a shape you can hear from the back of the room.',
  ),
  repeatedRoot(
    'Repeated root',
    'The root twice, then the 5th. Doing less on purpose: under a busy '
        'chorus this is worth more than anything clever.',
  ),
  upAndBack(
    'Up and back',
    'Root, 5th, 3rd. It goes up and comes back, so it ends near where it '
        'started and the next bar can go anywhere.',
  ),
  fifthBelow(
    'Fifth below and back',
    'Root, the 5th underneath it, root again. It drops the floor out and '
        'puts it back, which is a very old sound.',
  ),
  thirdToFourth(
    'Third to fourth',
    'Root, 3rd, 4th. The 4th leans on the 3rd behind it and wants to keep '
        'moving, which is exactly what a bass line should be doing on '
        'beat 3.',
  ),
  chromaticDown(
    'Chromatic run down',
    'Three semitones above the next root, walking down onto it. The whole '
        'bar is an approach: you can hear where it is going from beat 2.',
  ),
  chromaticUp(
    'Chromatic run up',
    'The same from below, climbing onto the next root. Heavier than '
        'coming down, and it makes the arrival feel inevitable.',
  ),
  encloseAbove(
    'Enclosure, above first',
    'Round the next root before landing on it: above, then below, then '
        'in. The line circles the target rather than walking at it.',
  ),
  encloseBelow(
    'Enclosure, below first',
    'The same circle the other way round, below then above. It is the '
        'commonest way a bassist makes a change sound deliberate.',
  ),
  upToTheSeventh(
    'Up to the 7th',
    'Root, 3rd, 5th, 7th: straight up the chord, no passing notes and no '
        'approach note at the end. It says the harmony out loud, which is '
        'useful when the changes are unfamiliar to whoever is playing '
        'over them, and it lets the next root do the arriving.',
  );

  const BassMove(this.label, this.about);

  /// What it is called on screen.
  final String label;

  /// What it is, and when a bassist reaches for it.
  final String about;

  /// Whether the shape is built from the chord it is on, or aimed at the
  /// next chord's root.
  ///
  /// The four that aim at the next root are the ones that spend the whole
  /// bar arriving, and they are why a walking line sounds like it is
  /// going somewhere rather than describing where it is.
  bool get aimsAtTheNext => switch (this) {
    chromaticDown || chromaticUp || encloseAbove || encloseBelow => true,
    _ => false,
  };
}
