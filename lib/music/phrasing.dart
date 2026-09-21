// Where a phrase starts, and which notes get the weight.
//
// Everything else in Learn is about which notes to play. This is about
// when, and it is the thing that separates a line that sounds like jazz
// from the same notes sounding like an exercise.
//
// Two habits do most of the work. Bebop phrases almost never begin on
// beat one; they come in on an upbeat, most often the "and" of 4 leading
// over the barline, so the line is already moving when the bar turns
// over. And in a run of quavers the weight goes on the upbeats, not the
// downbeats, which is the opposite of what a beginner does and most of
// why their eighth notes sound stiff.
//
// Neither is a rule, and neither needs a transcription to demonstrate:
// take any four notes, move where they start, and the difference is
// plain. That is what this is for.

/// Where a phrase comes in, counted in quavers from the top of the bar.
///
/// Eight to a bar, so the even ones are beats and the odd ones are the
/// "and"s between them. Negative counts back into the bar before, which
/// is where the most useful one of all lives.
typedef Placement = ({int at, String name, String about});

/// The eighth positions worth trying, from the bar before to beat 3.
const placements = <Placement>[
  (
    at: -1,
    name: 'The & Of 4, Before',
    about:
        'Coming in on the last quaver of the bar before, so the line is '
        'already moving when the bar turns over. If bebop has a default '
        'this is it, and it is the one worth getting into your hands '
        'first.',
  ),
  (
    at: 0,
    name: 'On 1',
    about:
        'Square, and the one everybody does without meaning to. Useful to '
        'hear so you know what you are avoiding: it lands at the same '
        'moment as the bass and the drums, so nothing sticks out.',
  ),
  (
    at: 1,
    name: 'The & Of 1',
    about:
        'A quaver late. Nothing else is playing on it, so the line is '
        'heard on its own rather than with the band.',
  ),
  (
    at: 2,
    name: 'On 2',
    about:
        'On the beat but not on the downbeat. Steadier than an upbeat '
        'start and still not square.',
  ),
  (
    at: 3,
    name: 'The & Of 2',
    about:
        'Late into the bar and off the beat. It leaves room at the front, '
        'which is worth more than it sounds: a phrase that starts later '
        'says more.',
  ),
  (
    at: 5,
    name: 'The & Of 3',
    about:
        'Halfway through and climbing over the barline. A short phrase '
        'from here has the same lift as coming in on the & of 4.',
  ),
];

/// Which notes get the weight in a run of quavers.
enum Accent {
  /// One, two, three, four: what a beginner does, and what makes the
  /// line sound like it is being counted rather than played.
  downbeats('On The Beats'),

  /// The and of one, the and of two: where bebop puts it.
  upbeats('Off The Beats'),

  /// Nothing pushed, which is worth hearing beside the other two.
  even('Flat');

  const Accent(this.label);

  final String label;

  /// How hard the quaver at [position] is played, nought to one.
  double weightAt(int position) => switch (this) {
    even => 0.75,
    downbeats => position.isEven ? 0.95 : 0.55,
    upbeats => position.isEven ? 0.55 : 0.95,
  };
}

/// Whether a quaver position falls between the beats.
bool isUpbeat(int at) => at % 2 != 0;

/// What you say out loud at [at]: "1", "&", "2", "&" …
///
/// Counted inside whichever bar it falls in, so the quaver before the bar
/// line is the "&" of 4 and not a minus something.
String countName(int at) {
  final within = at % 8;
  return isUpbeat(within) ? '&' : '${within ~/ 2 + 1}';
}

/// A phrase of [length] quavers starting at [at], as positions counted
/// from the top of the bar it is heard in.
///
/// A phrase that starts before the bar or runs past it keeps going: the
/// barline is not a wall, and a line that stops at it is the stiff thing
/// this is meant to cure.
List<int> positionsOf(int at, int length) => [
  for (var i = 0; i < length; i++) at + i,
];

/// How many quavers of rest go before the phrase within its own bar.
///
/// A pick-up from the bar before has none of its own; it is drawn in the
/// bar it belongs to, and what sits in front of it is the bar line.
int restsBefore(int at) => at < 0 ? 0 : at;

/// Whether a phrase starting at [at] and running [length] quavers goes
/// over a bar line, which most good ones do.
///
/// Either end counts. A pick-up starts before the line and lands after
/// it, which is the whole reason it is the one to learn first: saying
/// it sits "inside the bar" because it happens to finish there would be
/// the opposite of the point.
bool crossesTheBar(int at, int length) => at < 0 || at + length > 8;
