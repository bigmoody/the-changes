// Comping: where in the bar the chord actually goes.
//
// Everything else in Learn is about which notes. For anybody holding a
// piano or a guitar this is most of the job and none of it is about
// notes at all: the chords are given to you on the chart, and what you
// are deciding, bar after bar, is when to put them down and when to
// shut up.
//
// Two things do most of the work. Comping is mostly holes: a good bar
// is two chords and a lot of nothing, because the bass and the drums
// already have the beats and a soloist needs somewhere to stand. And the
// chord tends to arrive off the beat, or before its own bar starts,
// which is what makes comping sound like it is pushing the music along
// rather than marking time.
//
// These are the band's own figures, not a parallel set written for a
// lesson: the pianist and the guitarist pick from this list every bar of
// every tune in the app.

/// One strike of the chord: which beat of the bar, how long it rings, and
/// how hard relative to the chord's own level.
typedef CompStrike = (double beat, double length, double weight);

/// Where a comper puts the chord in a bar of four.
enum CompFigure {
  charleston(
    'The Charleston',
    weight: 6,
    about:
        'Beat 1 and the "and" of 2, then nothing for the rest of the bar. '
        'The bread-and-butter jazz comping figure: two chords, most of '
        'the bar empty, and it never gets in anybody\'s way. If you learn '
        'one, learn this one.',
  ),
  pushed(
    'Pushed',
    weight: 3,
    about:
        'The chord arrives before its bar does: on the last "and" of the '
        'bar before. It is how a comper says the change is coming, and it '
        'is most of why comping can sound ahead of the beat without ever '
        'rushing. A push cannot open a tune: there has to be something '
        'already going for it to be early against.',
  ),
  offbeat(
    'Off the Beats',
    weight: 3,
    about:
        'Nothing on a downbeat at all: the "and" of 1 and the "and" of '
        '3. The bass and the drums have the beats covered, so a comper '
        'who stays off them is adding something instead of doubling what '
        'is already there.',
  ),
  twice(
    'Twice a Bar',
    weight: 3,
    about:
        'Beat 1 and the "and" of 3: the bar split in half, one at the '
        'front and one at the back. Plainer than the Charleston, and what '
        'you want when the soloist is busy.',
  ),
  three(
    'Three Times',
    weight: 2,
    about:
        'Beat 1, the "and" of 2 and beat 4. More than most bars need, and '
        'worth hearing for exactly that: it starts to crowd whoever is '
        'playing over it.',
  ),
  held(
    'Held',
    weight: 4,
    about:
        'Struck once and left to ring. Under a ballad, or under a soloist '
        'who wants room, this is often the whole job.',
  ),
  everyBeat(
    'On Every Beat',
    weight: 0,
    about:
        'Four square chords: what everybody does before somebody tells '
        'them not to. The band in this app has never played it once. '
        'Hear it against the others: it doubles the bass, it flattens the '
        'time, and it leaves the soloist nowhere to stand.',
  );

  const CompFigure(this.label, {required this.weight, required this.about});

  /// What it is called on screen.
  final String label;

  /// How often the band reaches for it, against the others. Nought means
  /// never; it is here to be heard and avoided.
  final int weight;

  /// What it is, and when you would want it.
  final String about;

  /// Whether this is something the band actually plays.
  bool get playedByTheBand => weight > 0;

  /// Whether it starts before its own bar, so it cannot open a tune.
  bool get startsEarly => this == pushed;

  /// Where the chord lands, given where the "and" falls inside the beat
  /// ([and]: a half in an even feel, more than that when it swings).
  ///
  /// A push lands on the "and" of the beat *before* the chord, so it is
  /// early by what is left of that beat rather than by the "and" itself.
  /// Pushing by the "and" put the chord on a triplet partial nobody
  /// plays, a third of a beat ahead of the bass.
  List<CompStrike> strikes(double and) => switch (this) {
    charleston => [(0, 0.6, 1), (1 + and, 1.4, 0.9)],
    pushed => [(and - 1, 2.2, 1)],
    offbeat => [(and, 0.7, 0.95), (2 + and, 1.1, 0.85)],
    twice => [(0, 0.5, 1), (2 + and, 1.0, 0.85)],
    three => [(0, 0.5, 1), (1 + and, 0.5, 0.8), (3, 0.9, 0.9)],
    held => [(0, 3.2, 0.9)],
    everyBeat => [(0, 0.5, 0.95), (1, 0.5, 0.8), (2, 0.5, 0.9), (3, 0.5, 0.8)],
  };
}

/// The figures the band picks from for a new chord lasting a whole bar,
/// each with its weight. [canPush] is false at the very top of a tune,
/// where there is nothing yet for a push to be early against.
List<(CompFigure, int)> bandFigures({required bool canPush}) => [
  for (final figure in CompFigure.values)
    if (figure.playedByTheBand && (canPush || !figure.startsEarly))
      (figure, figure.weight),
];

/// [figure]'s strikes, with a push brought onto the downbeat when there
/// is nothing before it to be early against.
///
/// A push is the one figure that starts before its own bar, so at the top
/// of a tune it has nowhere to come from. The band's own answer is to
/// pick something else that bar; when somebody has asked for this figure
/// and no other, the answer instead is to play it in the only place it
/// can go, which is on the beat, keeping its length so it still rings
/// across the bar the way a push does.
List<CompStrike> strikesAt(
  CompFigure figure,
  double and, {
  required bool canPush,
}) {
  if (canPush || !figure.startsEarly) return figure.strikes(and);
  return [
    for (final (beat, length, weight) in figure.strikes(and))
      (beat < 0 ? 0 : beat, length, weight),
  ];
}

/// What to call the beat a chord lands on: "1", 'the "and" of 2', or,
/// for a push, the last "and" of the bar before.
String beatName(double beat) {
  if (beat < 0) return 'the "and" of 4, before';
  final counted = beat.floor();
  final offBeat = beat - counted > 1e-9;
  return offBeat ? 'the "and" of ${counted + 1}' : '${counted + 1}';
}

/// Where the chord lands, written out: 'on 1 and the "and" of 2'.
///
/// Read off the figure itself rather than written beside it, so the
/// sentence cannot come to disagree with the sound.
String whereItLands(CompFigure figure, double and) {
  final names = [
    for (final (beat, _, _) in figure.strikes(and)) beatName(beat),
  ];
  if (names.length == 1) return 'on ${names.first}';
  final last = names.removeLast();
  return 'on ${names.join(', ')} and $last';
}

/// How many times the chord is struck in the bar.
int strikeCount(CompFigure figure) => figure.strikes(0.5).length;
