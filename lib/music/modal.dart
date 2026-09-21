// Modal tunes: what to do when one chord lasts sixteen bars.
//
// Everything else in Learn is aimed at keeping up. The changes go past
// faster than you can think, and the work is knowing what is coming and
// having something ready for it. A modal tune takes that away. So What
// gives you sixteen bars of one chord; Anthropology gives you two beats.
//
// Which sounds easier and is not, for two reasons.
//
// The first is that a chord symbol stops carrying the information. On a
// bebop tune "Dm7" only has to last long enough to get to G7, so nobody
// minds that it does not say which minor. Hold it for sixteen bars and
// the question will not go away: is the 6th natural or flat? Dorian and
// Aeolian are both written Dm7 and they do not sound remotely alike, and
// the chart will not tell you. The tune's key does, which is why the
// library writes "D Dorian" where other tunes just say "D minor".
//
// The second is that running the changes was doing more work than
// anybody admitted. Take the changes away and a line has to hold up on
// its own: a shape worth repeating, somewhere to go, and the nerve to
// stop. That part cannot be reduced to a rule, and this file does not
// pretend otherwise. What it can do is say what the chart is actually
// asking, which is more than most charts manage.

import 'scales.dart';
import 'tune.dart';

/// How many bars one chord has to last before running changes stops
/// being the job.
///
/// Eight is the shortest stay anybody would call modal: a whole phrase
/// with nowhere to go. Below that you are still travelling.
const modalStay = 8;

/// The longest run of one unbroken chord in [tune], counted in bars.
///
/// A bar with two chords in it breaks the run, because the question this
/// is asking is how long you are left alone with one sound.
int longestStay(Tune tune) {
  var longest = 0;
  var run = 0;
  String? sounding;
  for (final bar in tune.bars) {
    if (bar.length != 1) {
      run = 0;
      sounding = null;
      continue;
    }
    final chord = bar.single.chord.display;
    run = chord == sounding ? run + 1 : 1;
    sounding = chord;
    if (run > longest) longest = run;
  }
  return longest;
}

/// Whether [tune] is modal: one chord held long enough that the job
/// changes from keeping up to having something to say.
///
/// Asked of the chart rather than a tag, so it cannot disagree with what
/// the band plays, and so a tune added later is found on its own.
bool isModal(Tune tune) => longestStay(tune) >= modalStay;

/// The modal tunes in [tunes], the longest stay first: the ones that
/// leave you alone longest are the ones to be ready for.
List<Tune> modalTunes(Iterable<Tune> tunes) {
  final found = [
    for (final tune in tunes)
      if (isModal(tune)) tune,
  ];
  found.sort((a, b) {
    final stay = longestStay(b).compareTo(longestStay(a));
    return stay != 0 ? stay : a.title.compareTo(b.title);
  });
  return found;
}

/// Every mode a chart's [symbol] could be asking for.
///
/// The heart of it: a chord symbol names a stack of notes, and several
/// modes fit the same stack. Written over two beats that hardly matters.
/// Written over sixteen bars it is the only question worth asking.
List<Mode> modesWritten(String symbol) => [
  for (final mode in modes)
    if (mode.chord == symbol && mode.family == ScaleFamily.major) mode,
];

/// What separates [mode] from its neighbours, as degrees: Dorian's ♮6,
/// Lydian's ♯4.
///
/// The mode's own [Mode.colour], named here so the screen and the
/// reference page cannot drift apart.
List<String> colourOf(Mode mode) => mode.colour;

/// A degree as it is spoken rather than as it is stored: "6th", "♭6th",
/// "♭2nd".
///
/// The stored form is a formula, good for arithmetic and wrong on a
/// page: nobody says "the b6 in red".
String degreeLabel(String degree) {
  final flat = degree.startsWith('b');
  final sharp = degree.startsWith('#');
  final number = degree.replaceAll(RegExp('^[b#]'), '');
  const ordinals = {'1': 'st', '2': 'nd', '3': 'rd'};
  final sign = flat ? '♭' : (sharp ? '♯' : '');
  return '$sign$number${ordinals[number] ?? 'th'}';
}

/// Which degrees [a] and [b] disagree about.
///
/// Usually one. Dorian and Aeolian differ by a single note out of seven,
/// and that note is the entire difference between the two most common
/// sounds in modal jazz.
List<String> differenceBetween(Mode a, Mode b) {
  final theirs = b.semitones.toSet();
  return [
    for (final (i, degree) in a.degrees.indexed)
      if (!theirs.contains(a.semitones[i])) degree,
  ];
}

/// What holds a modal solo up once the changes are not doing it.
///
/// Not rules. There is no substitute for the changes, which is the
/// honest thing to say, but these are what people reach for and they
/// are worth knowing you are allowed to reach for.
typedef ModalIdea = ({String name, String about});

const modalIdeas = <ModalIdea>[
  (
    name: 'A Shape, Then The Same Shape',
    about:
        'With no changes to mark the time, repetition is what tells a '
        'listener where they are. Play three notes, play them again a '
        'step up, and you have built something that a run up the scale '
        'never builds.',
  ),
  (
    name: 'Leaving It Alone',
    about:
        'Sixteen bars is a long time to fill and nobody asked you to fill '
        'it. Silence over one chord is not a gap in the music, it is the '
        'thing that makes the next entry mean something.',
  ),
  (
    name: 'Moving The Register',
    about:
        'The harmony is not going anywhere, so let the line go somewhere '
        'instead. Starting a chorus an octave up does more for a modal '
        'solo than any note choice.',
  ),
  (
    name: 'Fourths',
    about:
        'Stacked fourths fit the mode without spelling the chord, so they '
        'sound open rather than like an arpeggio. It is the piano voicing '
        'everybody associates with So What, and it works in a line too.',
  ),
];
