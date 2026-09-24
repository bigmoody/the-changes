// Naming what you hear.
//
// Everything else in the app that listens, listens to you: the tuner, the
// chord identifier, the check on what you played, the lick follower. The
// microphone points at the player and the app marks them. This is the
// other way round, and it was the one thing missing: the app plays, and
// your ear is the thing being tested.
//
// That matters more in this music than in most. You can read a chart and
// never hear the changes, and it shows the moment somebody calls a tune
// you have not read. Hearing a ii-V go by, hearing the ♭VI arrive,
// hearing that the second chord was the tritone sub and not the V, is the
// difference between playing a tune and playing over it.
//
// Everything is written in C and moved to a key at random every time it
// is asked, which is the whole point: a question always asked in C
// teaches the pitch of C and nothing about the sound of a ii-V.
//
// The wrong answers offered are always from the same group as the right
// one, so a question is a real choice between things that could be
// confused rather than one obvious answer beside three silly ones.

import 'dart:math' as math;

import 'chord.dart';

/// What a question is about.
enum EarGroup {
  quality('Chord quality', 'One chord. What kind is it?'),
  movement(
    'Two chords',
    'Two chords, the first one home. Where did the second one go?',
  ),
  cadence('Cadences', 'A few chords. Which progression was that?');

  const EarGroup(this.label, this.about);
  final String label;
  final String about;
}

/// One thing that can be played and named, written in C.
class EarQuestion {
  const EarQuestion({
    required this.name,
    required this.group,
    required this.chords,
    required this.about,
  });

  /// What it is called in the list of answers.
  final String name;

  final EarGroup group;

  /// The chords, as typed, in C.
  final List<String> chords;

  /// What to listen for, shown once the answer is in. This is where the
  /// learning happens: getting it wrong and being told only that you were
  /// wrong teaches nothing.
  final String about;
}

const earQuestions = [
  // One chord. The ear has to hear the quality with nothing around it,
  // which is harder than it sounds and is what everything else rests on.
  EarQuestion(
    name: 'Major 7',
    group: EarGroup.quality,
    chords: ['C^7'],
    about:
        'Settled and bright. The 7th is a semitone under the octave, '
        'which is the note that makes it sound finished rather than '
        'going somewhere.',
  ),
  EarQuestion(
    name: 'Dominant 7',
    group: EarGroup.quality,
    chords: ['C7'],
    about:
        'Restless. The ♭7 against the major 3rd is the interval that '
        'wants to move, and nearly always moves down a fourth.',
  ),
  EarQuestion(
    name: 'Minor 7',
    group: EarGroup.quality,
    chords: ['Cm7'],
    about:
        'Dark but calm. Nothing in it is pulling anywhere, which is '
        'what separates it from a half-diminished.',
  ),
  EarQuestion(
    name: 'Half-diminished',
    group: EarGroup.quality,
    chords: ['Ch7'],
    about:
        'A minor 7 with the 5th flattened, and that one note makes it '
        'ache. Where a minor ii-V starts.',
  ),
  EarQuestion(
    name: 'Diminished 7',
    group: EarGroup.quality,
    chords: ['Co7'],
    about:
        'Every note a minor 3rd apart, so it has no top and no bottom '
        'and sounds like it could go anywhere. Usually it goes up a '
        'semitone.',
  ),
  EarQuestion(
    name: 'Minor major 7',
    group: EarGroup.quality,
    chords: ['Cm^7'],
    about:
        'A minor triad with a major 7th on it. The clash between the '
        '♭3 and the ♮7 is the sound, and it is not a mistake.',
  ),
  EarQuestion(
    name: 'Sixth',
    group: EarGroup.quality,
    chords: ['C6'],
    about:
        'Major, and more settled than a Δ7 because there is no '
        'semitone rubbing against the octave. What older tunes end on.',
  ),
  EarQuestion(
    name: 'Altered',
    group: EarGroup.quality,
    chords: ['C7alt'],
    about:
        'A dominant with everything that can be bent, bent. It sounds '
        'like it is straining, and the strain is the point.',
  ),
  EarQuestion(
    name: 'Suspended',
    group: EarGroup.quality,
    chords: ['C7sus4'],
    about:
        'The 4th where the 3rd should be, so it has no quality of its '
        'own: neither major nor minor, just waiting.',
  ),
  EarQuestion(
    name: 'Augmented',
    group: EarGroup.quality,
    chords: ['C+7'],
    about:
        'The 5th raised, so the top of the chord pushes upward. Rare '
        'on its own, common as the last chord before a ii.',
  ),

  // Two chords. The first is home; what matters is where the second went.
  EarQuestion(
    name: 'ii to V',
    group: EarGroup.movement,
    chords: ['Dm7', 'G7'],
    about:
        'Minor, then dominant a fourth up. The commonest pair of '
        'chords in the music, and the one to know cold.',
  ),
  EarQuestion(
    name: 'V to I',
    group: EarGroup.movement,
    chords: ['G7', 'C^7'],
    about:
        'The resolution: everything that was pulling stops pulling. '
        'This is what "home" sounds like.',
  ),
  EarQuestion(
    name: 'I to VI7',
    group: EarGroup.movement,
    chords: ['C^7', 'A7'],
    about:
        'Home, then a dominant a major 6th up, which is brighter and '
        'more unexpected than the minor vi it replaced. The front of a '
        'turnaround.',
  ),
  EarQuestion(
    name: 'IV to minor iv',
    group: EarGroup.movement,
    chords: ['F^7', 'Fm7'],
    about:
        'The same root turning minor under you. One of the saddest '
        'two chords in the music and it is everywhere.',
  ),
  EarQuestion(
    name: 'Tritone sub',
    group: EarGroup.movement,
    chords: ['Dm7', 'Db7'],
    about:
        'Where the V was expected, a dominant a semitone above the '
        'home chord instead. The bass slides down by one.',
  ),
  EarQuestion(
    name: 'I to I7',
    group: EarGroup.movement,
    chords: ['C^7', 'C7'],
    about:
        'The same chord going dominant, which turns home into a V of '
        'somewhere else. It is on its way to the IV.',
  ),
  EarQuestion(
    name: 'i to ♭VI',
    group: EarGroup.movement,
    chords: ['Cm7', 'Ab^7'],
    about:
        'Minor, then a major chord a major 3rd below. The lift is the '
        'whole effect, and it is the sound of a great many minor tunes.',
  ),
  EarQuestion(
    name: 'I to ♭III7',
    group: EarGroup.movement,
    chords: ['C^7', 'Eb7'],
    about:
        'A dominant on the flat 3rd, out of nowhere. Not a resolution '
        'and not a mistake: it is going somewhere sideways.',
  ),

  // A few chords: which progression.
  EarQuestion(
    name: 'ii V I',
    group: EarGroup.cadence,
    chords: ['Dm7', 'G7', 'C^7'],
    about:
        'The major cadence. If only one progression is in your ear, '
        'this is the one worth having there.',
  ),
  EarQuestion(
    name: 'Minor ii V i',
    group: EarGroup.cadence,
    chords: ['Dh7', 'G7b9', 'Cm6'],
    about:
        'The same shape in minor: the ii is half-diminished and the V '
        'has a ♭9 on it. Darker from the first chord.',
  ),
  EarQuestion(
    name: 'Backdoor',
    group: EarGroup.cadence,
    chords: ['Fm7', 'Bb7', 'C^7'],
    about:
        'A ii-V belonging to the flat 3rd, landing on home anyway. It '
        'arrives from underneath instead of from the V.',
  ),
  EarQuestion(
    name: 'Tritone sub ii V I',
    group: EarGroup.cadence,
    chords: ['Dm7', 'Db7', 'C^7'],
    about:
        'A ii-V-I with the V swapped for the chord a semitone above '
        'home, so the bass walks down by semitones into the tonic.',
  ),
  EarQuestion(
    name: 'Turnaround',
    group: EarGroup.cadence,
    chords: ['C^7', 'A7', 'Dm7', 'G7'],
    about:
        'Home, and three chords getting back to it. What the last two '
        'bars of most standards are doing.',
  ),
  EarQuestion(
    name: 'iii VI ii V',
    group: EarGroup.cadence,
    chords: ['Em7', 'A7', 'Dm7', 'G7'],
    about:
        'A turnaround that never touches home: it starts on the iii '
        'instead, so it keeps moving rather than settling first.',
  ),
  EarQuestion(
    name: 'Deceptive',
    group: EarGroup.cadence,
    chords: ['Dm7', 'G7', 'Am7'],
    about:
        'A ii-V that lands on the vi rather than the I. Everything '
        'says it is about to finish and then it does not.',
  ),
  EarQuestion(
    name: 'Plagal',
    group: EarGroup.cadence,
    chords: ['C^7', 'F^7', 'C^7'],
    about:
        'Home, to the IV, and back, with no dominant anywhere. It '
        'settles without ever having been unsettled.',
  ),
];

/// The keys questions are moved to.
///
/// Every one of the twelve, spelled the way anybody would write it. A
/// question always asked in C teaches the pitch of C and nothing about
/// the sound of the thing being asked about.
const _keys = 'C Db D Eb E F Gb G Ab A Bb B';

/// One question as it is being asked: moved to a key, with the answers to
/// choose between.
class EarAsk {
  const EarAsk({
    required this.answer,
    required this.choices,
    required this.chords,
    required this.key,
  });

  final EarQuestion answer;

  /// Everything offered, the right one among them, in the order shown.
  final List<EarQuestion> choices;

  /// What is actually played.
  final List<Chord> chords;

  /// The key it was moved to, for saying afterwards.
  final String key;

  bool isRight(EarQuestion picked) => picked.name == answer.name;
}

/// Deals out questions from one group, never the same one twice running.
class EarDealer {
  EarDealer({required this.group, math.Random? random, this.choices = 4})
    : random = random ?? math.Random();

  final EarGroup group;
  final math.Random random;

  /// How many answers are offered, the right one included.
  final int choices;

  String? _last;

  List<EarQuestion> get _pool => [
    for (final q in earQuestions)
      if (q.group == group) q,
  ];

  EarAsk next() {
    final pool = _pool;
    final wanted = [
      for (final q in pool)
        if (pool.length < 2 || q.name != _last) q,
    ];
    final answer = wanted[random.nextInt(wanted.length)];
    _last = answer.name;

    // The wrong answers come from the same group, so the choice is
    // between things that could be confused.
    final others = [
      for (final q in pool)
        if (q.name != answer.name) q,
    ]..shuffle(random);
    final offered = [answer, ...others.take(math.max(0, choices - 1))]
      ..shuffle(random);

    final key = _keys.split(' ')[random.nextInt(12)];
    return EarAsk(
      answer: answer,
      choices: offered,
      chords: inKey(answer, key),
      key: key,
    );
  }
}

/// [question]'s chords, moved from C to [key].
List<Chord> inKey(EarQuestion question, String key) {
  final tonic = parseNoteName(key);
  if (tonic == null) return const [];
  final move = Transposition(
    letterSteps: tonic.letter,
    semitones: pitchClassOf(tonic),
  );
  return [
    for (final symbol in question.chords) Chord.parse(symbol).transposed(move),
  ];
}
