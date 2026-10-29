// What a jam session asks of you that practising alone does not: coming
// in on somebody else's intro, taking the right number of choruses,
// trading, getting out together, doing your job when it is not your solo,
// and finding your place again when you have lost it.
//
// Each drill is played on the tune of the day, with the band set up the
// way the drill needs (starting four bars from the end, trading against
// the time, laying out), so it is practised on a tune you are learning
// rather than read about. The signals are the one thing here that is only
// knowledge, and they are written down because nobody stops a session to
// explain them.

import '../music/arrangement.dart';
import 'roadmap.dart';

/// How the band is set up for a drill.
class DrillSetup {
  const DrillSetup({this.barsFromEnd, this.arrangement});

  /// Start this many bars before the end of the form, as an intro: the
  /// band plays them, then comes round to the top.
  final int? barsFromEnd;
  final Arrangement? arrangement;
}

class SessionDrill {
  const SessionDrill({
    required this.title,
    required this.how,
    this.setup,
    this.only,
  });

  final String title;
  final String how;

  /// How to play it, or null for something to know rather than play.
  final DrillSetup? setup;

  /// Who it is for, when it is not everybody.
  final Set<RoadmapInstrument>? only;

  bool isFor(RoadmapInstrument instrument) =>
      only == null || only!.contains(instrument);
}

/// The things a session expects you to know how to do.
const sessionSkills = <SessionDrill>[
  SessionDrill(
    title: 'The Last-Four Intro',
    how:
        'The most common intro there is: the band plays the last four bars '
        'of the tune, and the head starts at the top. Listen to the four '
        'bars, count them, and come in on bar 1 with the melody.',
    setup: DrillSetup(barsFromEnd: 4),
  ),
  SessionDrill(
    title: 'Head, Two Choruses, Head',
    how:
        'The shape of a tune at a session: the head in, your solo, the head '
        'out. Four times round: the melody, two choruses of solo, the '
        'melody again, and land on the last chord with the band. Two '
        'choruses is plenty; nobody at a session wants five.',
    setup: DrillSetup(
      arrangement: Arrangement(choruses: 4, headInAndOut: true),
    ),
  ),
  SessionDrill(
    title: 'Trade Fours',
    how:
        'After the solos, the drummer often trades: four bars you, four bars '
        'them. Play a short, complete idea in your four, and come back in on '
        'time after theirs.',
    setup: DrillSetup(
      arrangement: Arrangement(choruses: 4, trading: Trading.fours),
    ),
  ),
  SessionDrill(
    title: 'Comp Behind the Soloist',
    how:
        'Most of a session is accompanying. The band\'s chords lay out: '
        'comp for the whole tune as you would behind somebody else\'s solo. '
        'Short chords, space, nothing on top of the melody.',
    setup: DrillSetup(arrangement: Arrangement(layOut: {LayOut.chords})),
    only: {RoadmapInstrument.guitar, RoadmapInstrument.piano},
  ),
  SessionDrill(
    title: 'Hold the Bottom',
    how:
        'The bass lays out: walk the whole tune yourself, the way the band '
        'leans on you when somebody else is soloing. Roots on the changes, '
        'the time steady, the form never in doubt.',
    setup: DrillSetup(arrangement: Arrangement(layOut: {LayOut.bass})),
    only: {RoadmapInstrument.bass},
  ),
  SessionDrill(
    title: 'Lay Out',
    how:
        'When it is not your solo, rest, and listen. Play the head, then '
        'stop for two choruses and count every bar of them, and come back '
        'in on the head out at exactly the right place.',
    setup: DrillSetup(
      arrangement: Arrangement(choruses: 4, headInAndOut: true),
    ),
    only: {RoadmapInstrument.horn},
  ),
  SessionDrill(
    title: 'End Together',
    how:
        'On the last time through the head the band ends on the home chord. '
        'Play the melody to the end and land on its last note with them, '
        'held, and stop when they stop.',
    setup: DrillSetup(arrangement: Arrangement(choruses: 2)),
  ),
  SessionDrill(
    title: 'The Signals',
    how:
        'Nobody stops to explain these, and every session has its own '
        'habits, but most use them. A hand on the head, or pointing at it: '
        'the next chorus is the head, take it out. Four fingers held up: '
        'trade fours (two, or eight, likewise). A nod or eye contact from '
        'whoever is leading: your turn, or the solo is ending. A raised '
        'fist, often at the end of the head out: stop here. When in doubt, '
        'watch the person who called the tune.',
  ),
  SessionDrill(
    title: 'Count It Off',
    how:
        'If you call the tune, you count it in. Feel the tempo first, sing a '
        'bar of the melody in your head at it, then out loud: "one... two... '
        'one, two, three, four", the first two on beats 1 and 3. The band '
        'here counts a bar; count with it, out loud, every time.',
    setup: DrillSetup(),
  ),
];

/// Losing your place, and finding it again: the band drops out and comes
/// back, and you have to come back with it.
const recoverDrills = <SessionDrill>[
  SessionDrill(
    title: 'Two Bars Gone',
    how:
        'The whole band drops out for two bars in every four. Keep playing '
        'through the gap, keep the time, and be exactly where they are when '
        'they come back in.',
    setup: DrillSetup(
      arrangement: Arrangement(
        trading: Trading.twos,
        tradeWith: TradeWith.time,
      ),
    ),
  ),
  SessionDrill(
    title: 'Four Bars Gone',
    how:
        'Four bars of silence in every eight. Count them in your head and '
        'hear the changes go past without anybody playing them.',
    setup: DrillSetup(
      arrangement: Arrangement(
        trading: Trading.fours,
        tradeWith: TradeWith.time,
      ),
    ),
  ),
  SessionDrill(
    title: 'Eight Bars Gone',
    how:
        'Half the time the band is not there: eight bars alone, then eight '
        'with them. This is what it is like when the drummer takes a break '
        'and nobody else knows where bar 1 is but you.',
    setup: DrillSetup(
      arrangement: Arrangement(
        trading: Trading.eights,
        tradeWith: TradeWith.time,
      ),
    ),
  ),
  SessionDrill(
    title: 'Find Bar 1',
    how:
        'If you are lost at a session: stop playing, listen for the next '
        'turnaround or the start of a section, and come back in there. '
        'Practise it: start the tune, stop playing in the middle of a '
        'chorus, and come back in at the next A section without looking at '
        'the chart.',
    setup: DrillSetup(),
  ),
];
