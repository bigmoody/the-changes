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
///
/// Fourths belong on this list too and are not on it, because they have
/// a section of their own: a thing you can be shown is worth more than
/// a thing you can be told, and a stack of fourths can be drawn.
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
];

// ── Stacking a chord in fourths ─────────────────────────────────────────

/// One note of a stack: its name, how far above the root it sits, and the
/// interval from the note below it.
typedef StackStep = ({String note, int semitone, String? above});

/// Three semitones is a minor 3rd, five a perfect 4th, six a tritone.
String intervalName(int semitones) => switch (semitones) {
  3 => 'a minor 3rd',
  4 => 'a major 3rd',
  5 => 'a 4th',
  6 => 'a tritone',
  _ => '$semitones semitones',
};

/// A perfect fourth.
const _fourth = 5;

/// How tall a fourths stack is built before it has said enough. Five is
/// the So What voicing; more than that and both hands are busy.
const _stackNotes = 5;

/// [mode] stacked from [root] in thirds: the chord as its symbol is made,
/// root, 3rd, 5th and 7th.
List<StackStep> thirdsStack(Mode mode, String root) =>
    _stack(mode, root, step: 2, notes: 4);

/// [mode] stacked from [root] in fourths, stopping where the mode would
/// force a tritone and taking a third instead.
///
/// The stop is the interesting part and it is worked out rather than
/// written down. Piling fourths on D in Dorian gives D G C F, and the
/// next one would be B: a tritone, sitting right at the top where it is
/// heard most. So the stack takes the third above F instead, which is A,
/// and that is the voicing everybody knows off So What. In another mode
/// it stops somewhere else, and this finds that too.
List<StackStep> fourthsStack(Mode mode, String root) =>
    _stack(mode, root, step: 3, notes: _stackNotes, only: _fourth);

/// The note a fourths stack turned down, and what it would have been.
///
/// Null where the stack ran its full length without meeting one, which
/// is what happens in a mode with a flat 6th: Aeolian gives five clean
/// fourths and never has to decide anything.
///
/// Asked over the same height as the stack itself, so it cannot report a
/// refusal that happens past the end of what is drawn.
StackStep? refusedBy(Mode mode, String root) {
  final stack = _stack(mode, root, step: 3, notes: _stackNotes);
  for (var i = 1; i < stack.length; i++) {
    if (stack[i].semitone - stack[i - 1].semitone != _fourth) return stack[i];
  }
  return null;
}

/// Walks the mode in [step]s, gathering [notes] of them.
///
/// With [only] set, the walk stops as soon as a step is not that many
/// semitones, and takes one note a third above the last instead.
List<StackStep> _stack(
  Mode mode,
  String root, {
  required int step,
  required int notes,
  int? only,
}) {
  final names = mode.notesFrom(root);
  final semitones = mode.semitones;
  final length = names.length;
  final stack = <StackStep>[];
  var degree = 0;
  var octave = 0;
  var last = 0;
  for (var i = 0; i < notes; i++) {
    final semitone = semitones[degree] + octave * 12;
    final gap = i == 0 ? null : semitone - last;
    if (only != null && gap != null && gap != only) {
      // The mode will not give another one of these. A third above the
      // note below keeps the stack inside the mode and off the tritone.
      final third = (degree - step + 2 + length) % length;
      final wrapped = degree - step + 2 < 0 ? octave - 1 : octave;
      final at = semitones[third] + wrapped * 12;
      stack.add((
        note: names[third],
        semitone: at,
        above: intervalName(at - last),
      ));
      break;
    }
    stack.add((
      note: names[degree],
      semitone: semitone,
      above: gap == null ? null : intervalName(gap),
    ));
    last = semitone;
    final next = degree + step;
    if (next >= length) octave++;
    degree = next % length;
  }
  return stack;
}
