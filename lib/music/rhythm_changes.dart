// Rhythm changes: the other form worth knowing by heart.
//
// Learn the blues and you can sit in on half the gig. Learn rhythm
// changes and you have most of the rest. It is the chord form of "I Got
// Rhythm", and from the late thirties onwards players wrote new tunes
// over it by the dozen, because the changes were common property and the
// melody was theirs. This app has a dozen of them on its shelf already.
//
// What makes it worth an evening rather than a month is that both halves
// are one idea repeated.
//
// The A section is a turnaround, and then the same turnaround again, and
// then a trip up to the IV and home. If you can play I vi ii V you can
// already play most of it; the only bar that is genuinely new is the
// move to the IV at bar 5.
//
// The bridge is four dominant 7ths, two bars each, every one the V of
// the next: in B flat, D7 G7 C7 F7, and F7 is the V of B flat, so the
// last one walks you back into the A. No ii chords, no resolutions in
// the middle, just a chain of dominants falling by fifths. That same
// chain is the bridge of a great many tunes that are not rhythm changes
// at all, which is why it is the eight bars to learn first.

import 'chord.dart';
import 'tritone_subs.dart' show isDominant;
import 'tune.dart';

/// How many bars the form runs to, and how it is cut up.
const rhythmChangesBars = 32;
const rhythmChangesForm = 'AABA';

/// Where the bridge sits, counted from nought.
const bridgeFirstBar = 16;
const bridgeBars = 8;

/// A fourth up, which is the same move as a fifth down: how far each
/// chord of the bridge is from the one before it.
const upAFourth = 5;

/// The four dominants of [tune]'s bridge, in order, or null where its
/// bridge is not that cycle.
///
/// Asked of the chart rather than read off a tag, so a tune added to the
/// library later is found without anybody having to remember to label
/// it, and so a tune wrongly believed to be rhythm changes is not.
List<Chord>? bridgeCycleOf(Tune tune) {
  if (tune.barCount != rhythmChangesBars) return null;
  final cycle = <Chord>[];
  for (var bar = bridgeFirstBar; bar < bridgeFirstBar + bridgeBars; bar += 2) {
    // One chord, held for the two bars: a bridge that moves faster than
    // that is somebody else's bridge.
    final pair = [tune.bars[bar], tune.bars[bar + 1]];
    if (pair.any((slots) => slots.length != 1)) return null;
    if (pair.first.single.chord.display != pair.last.single.chord.display) {
      return null;
    }
    cycle.add(pair.first.single.chord);
  }
  if (!cycle.every(isDominant)) return null;
  for (var i = 1; i < cycle.length; i++) {
    if ((cycle[i].root - cycle[i - 1].root + 12) % 12 != upAFourth) return null;
  }
  return cycle;
}

/// Whether [tune] has that bridge, whatever else it is.
///
/// Thirty-two bars, AABA, and the cycle in the middle eight. Worth asking
/// on its own, because the bridge travels: tunes that are not rhythm
/// changes borrow it, which is the best argument there is for learning
/// those eight bars before anything else.
bool hasTheBridge(Tune tune) =>
    tune.barCount == rhythmChangesBars &&
    tune.form == rhythmChangesForm &&
    bridgeCycleOf(tune) != null;

/// Whether [tune] is rhythm changes: that bridge, and an A section that
/// starts at home.
///
/// The A sections vary from tune to tune and arguing about which variant
/// is the real one is how people avoid learning the form, so the only
/// thing asked of them is that they open on the I. That is enough to
/// tell rhythm changes from a tune wearing its bridge: Scrapple from the
/// Apple opens on the ii of somebody else's tune.
bool isRhythmChanges(Tune tune) => hasTheBridge(tune) && _opensAtHome(tune);

/// Whether [tune] has the bridge but is not rhythm changes: somebody
/// else's A sections with these eight bars in the middle.
bool borrowsTheBridge(Tune tune) => hasTheBridge(tune) && !_opensAtHome(tune);

bool _opensAtHome(Tune tune) {
  final first = tune.bars.first.firstOrNull?.chord;
  if (first == null) return false;
  final tonic = parseNoteName(
    RegExp(r'^[A-G][♭♯b#]?').stringMatch(tune.key) ?? '',
  );
  return tonic != null && pitchClassOf(tonic) == first.root;
}

/// Everything in [tunes] carrying that bridge, in the order given.
List<Tune> tunesWithTheBridge(Iterable<Tune> tunes) => [
  for (final tune in tunes)
    if (hasTheBridge(tune)) tune,
];

/// One step of the bridge: the chord, and the chord it is the V of.
typedef CycleStep = ({Chord chord, Chord resolvesTo, bool comesHome});

/// The bridge of [tune] as a chain, each chord pointing at the next, and
/// the last pointing back into the A section.
///
/// The last step is the one that explains the other three: F7 is not a
/// chord the bridge happens to end on, it is the V of the key, so the
/// whole cycle has been walking home since the first bar of it.
List<CycleStep> cycleSteps(Tune tune) {
  final cycle = bridgeCycleOf(tune);
  if (cycle == null) return const [];
  return [
    for (final (i, chord) in cycle.indexed)
      (
        chord: chord,
        resolvesTo: i + 1 < cycle.length
            ? cycle[i + 1]
            : Chord.parse(_nameOf((chord.root + upAFourth) % 12)),
        comesHome: i == cycle.length - 1,
      ),
  ];
}

/// What each pair of bars in the A section is doing, in numbers.
///
/// Numbers rather than chord names because the point is that it is the
/// same two bars three times: a chart tells you B♭ G7 Cm7 F7, and the
/// numbers tell you it is a turnaround.
typedef APart = ({String bars, String numerals, String about});

const aSectionParts = <APart>[
  (
    bars: '1–2',
    numerals: 'I  VI7  ii  V',
    about:
        'A turnaround: home, then the three chords that take you back to '
        'home. You have played this in every other tune you know.',
  ),
  (
    bars: '3–4',
    numerals: 'iii  VI7  ii  V',
    about:
        'The same turnaround, with the iii standing in for the I. Nothing '
        'new to learn, and two more bars gone.',
  ),
  (
    bars: '5–6',
    numerals: 'ii/IV  V/IV  IV  ivm',
    about:
        'The one move in the A section that is genuinely new: a ii–V into '
        'the IV, then the IV turning minor underneath you. This is the '
        'bar to practise.',
  ),
  (
    bars: '7–8',
    numerals: 'ii  V  I',
    about:
        'Home again, and into the next eight. The last A finishes on the '
        'I instead of turning around, because there is nothing left to '
        'turn around to.',
  ),
];

const _names = [
  'C',
  'D♭',
  'D',
  'E♭',
  'E',
  'F',
  'G♭',
  'G',
  'A♭',
  'A',
  'B♭',
  'B',
];

String _nameOf(int pitchClass) => _names[pitchClass % 12];
