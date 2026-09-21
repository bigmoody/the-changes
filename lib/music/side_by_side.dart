// Two or three versions of the same form, bar against bar.
//
// Every twelve-bar blues has the same skeleton: you are on the IV at bar
// five and heading home from bar nine. What changes between one blues and
// another is how much traffic fills the gaps. That is nearly invisible
// reading one chart at a time and obvious the moment they are side by
// side — which the app could not do at all, because it shows one tune.
//
// It only works if they are in the same key, so they are all moved into
// one. Comparing an F blues with a B♭ one bar by bar tells you nothing
// except that they are in different keys.

import 'chord.dart';
import 'tune.dart';

/// A set of versions worth reading against each other.
class Comparison {
  const Comparison({
    required this.name,
    required this.about,
    required this.titles,
    required this.key,
  });

  final String name;

  /// What the comparison is for, and what to look at.
  final String about;

  /// The tunes, in the order they are shown. Two or three: a fourth column
  /// is narrower than a chord.
  final List<String> titles;

  /// The key they are all moved into.
  final String key;
}

/// The ones built in.
const comparisons = <Comparison>[
  Comparison(
    name: 'The Blues, Three Ways',
    key: 'F',
    about:
        'Three chords, then the jazz blues, then what bebop did to it. '
        'Look at bar 5: whatever else happens, every version is on the IV. '
        'That is the load-bearing wall, and bars 9 to 12 are the door. '
        'Everything between them is filling, and the third column fills '
        'the first half with a dozen chords to reach the same B♭.',
    titles: ['Night Train', "Now's the Time", 'Blues for Alice'],
  ),
  Comparison(
    name: 'Monk And The Blues',
    key: 'F',
    about:
        'Two of Monk\'s against the ordinary jazz blues. He changes very '
        'little on paper — the interest is in what is played over it, '
        'which is exactly why the charts are worth reading against each '
        'other first.',
    titles: ["Now's the Time", 'Blue Monk', 'Straight, No Chaser'],
  ),
  Comparison(
    name: 'A Contrafact',
    key: 'G',
    about:
        'Ornithology is How High the Moon with a new tune written over it '
        '— a contrafact, which is how a good deal of the bebop repertoire '
        'got made. The form is the same and most of the changes are too. '
        'The handful of bars that move are where bebop sharpened them: a '
        'plain ii–V becomes a minor one, a major 7th becomes a dominant.',
    titles: ['How High the Moon', 'Ornithology'],
  ),
  Comparison(
    name: 'Major And Minor',
    key: 'C',
    about:
        'The same twelve bars in the same key, one major and one minor. '
        'Almost every bar moves — but look at bar 10, where they agree: '
        'both are heading home the same way, and everything either of '
        'them does has to get there.',
    titles: ["Now's the Time", 'Mr. P.C.'],
  ),
];

/// One bar across the versions.
typedef BarRow = ({
  /// Counted from one, as it is written on a chart.
  int bar,

  /// What each version has in that bar, written out, in column order. An
  /// empty string where a version is shorter than the others.
  List<String> cells,

  /// Whether they are not all the same.
  bool differs,
});

/// The note a key is built on, as a pitch class. "C minor" and "C" are
/// the same tonic: the mode is not what stops two charts lining up.
int tonicOf(String key) {
  final note = parseNoteName(RegExp(r'^[A-G][♭♯b#]?').stringMatch(key) ?? 'C');
  return note == null ? 0 : pitchClassOf(note);
}

/// How far [tune] has to move to be in [key].
int semitonesInto(Tune tune, String key) {
  return (tonicOf(key) - tonicOf(tune.key)) % 12;
}

/// Everything in one bar of [tune], written as it is on the chart.
String barText(Tune tune, int bar) {
  if (bar >= tune.barCount) return '';
  return [for (final slot in tune.bars[bar]) slot.chord.display].join(' ');
}

/// [tunes] laid out bar against bar, all of them already in one key.
///
/// As long as the longest, because a version with more bars in it is worth
/// seeing rather than quietly cut off.
List<BarRow> alignBars(List<Tune> tunes) {
  if (tunes.isEmpty) return const [];
  final longest = tunes.map((t) => t.barCount).reduce((a, b) => a > b ? a : b);
  return [
    for (var bar = 0; bar < longest; bar++)
      (
        bar: bar + 1,
        cells: [for (final tune in tunes) barText(tune, bar)],
        // Only where there is something to compare: a bar one version
        // hasn't got is not a disagreement about that bar.
        differs:
            {
              for (final tune in tunes)
                if (bar < tune.barCount) barText(tune, bar),
            }.length >
            1,
      ),
  ];
}

/// How many of [rows] the versions disagree on.
int barsThatDiffer(List<BarRow> rows) =>
    rows.where((row) => row.differs).length;
