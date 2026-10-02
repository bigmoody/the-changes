// One button that decides for you.
//
// Deciding what to practise is where a practice session goes. Which tune,
// which key, how fast, what feel: four questions before a note, each of
// them reasonable, and together they are the twenty minutes you had. For
// a lot of people, and for anybody with ADHD in particular, the deciding
// is the whole of the difficulty and the playing was never the problem.
//
// So this removes it. Not by offering a better way to choose, which is
// still choosing, but by choosing. The button goes straight to a tune
// that is already counting in, and the only thing left to decide is
// whether to let it.
//
// What it picks is meant to be kind rather than interesting. A tune you
// cannot play, in a key you have never tried, at a tempo you cannot
// manage is not a practice session, it is a reason to put the phone down,
// and somebody who needed this button is exactly the person who will not
// pick it up again. So: tunes you have shown an interest in where there
// are any, the written key most of the time, the tune's own feel most of
// the time, and a tempo near the one the tune carries.
//
// Everything it varies, it varies a little. The point is not a different
// tune every time; it is not having to answer anything.

import 'dart:math';

import '../music/tune.dart';

/// What to play, worked out so nobody has to.
typedef Suggestion = ({
  Tune tune,

  /// Semitones above the written key, 0 to 11.
  int semitones,
  int tempo,

  /// The feel to play it with, or null to leave the tune's own alone.
  BandStyle? style,
});

/// How far the tempo may wander below and above the one the tune carries.
///
/// Not the same both ways, because the two are not the same to be handed.
/// A tune written at 230 arriving at 184 is a pleasure; the same tune at
/// 276 is a wall, and somebody who needed a button to start practising is
/// exactly who stops at a wall. So a quarter slower is allowed and a
/// tenth faster is plenty.
const _slowerBy = 0.25;
const _fasterBy = 0.1;

/// How often it moves the tune out of its written key.
///
/// A third of the time. Often enough to be worth something, rarely enough
/// that the button is not a transposition drill: somebody who wanted one
/// of those knows where Changes in Twelve Keys is.
const _chanceOfAnotherKey = 0.34;

/// How often it plays the tune with a feel other than its own.
///
/// Less often than the key, because a feel is a bigger change to what you
/// have to play than a key is, and a bossa nova Cherokee is a joke rather
/// than a practice.
const _chanceOfAnotherFeel = 0.2;

/// Picks something to play from [book].
///
/// [starred] and [recent] are what the library knows about what somebody
/// has shown an interest in and what they have just done. Both are hints
/// rather than rules: a tune is drawn from what they have starred where
/// there is anything there, and the last few they were given are kept out
/// of the hat so the button does not hand back what it just handed over.
///
/// [random] is taken rather than made so a test can hold it still.
Suggestion? somethingToPlay(
  List<Tune> book, {
  Set<String> starred = const {},
  List<String> recent = const [],
  Random? random,
}) {
  if (book.isEmpty) return null;
  final dice = random ?? Random();

  // What somebody starred is what they said they wanted to play, so that
  // is the hat if there is anything in it.
  final mine = [
    for (final tune in book)
      if (starred.contains(tune.title)) tune,
  ];
  final from = mine.isEmpty ? book : mine;

  // Not the last few. Being handed the same tune twice running is the one
  // thing that makes a button like this feel broken rather than random.
  final lately = recent.take(3).toSet();
  final fresh = [
    for (final tune in from)
      if (!lately.contains(tune.title)) tune,
  ];
  final hat = fresh.isEmpty ? from : fresh;

  final tune = hat[dice.nextInt(hat.length)];
  final semitones = dice.nextDouble() < _chanceOfAnotherKey
      ? 1 + dice.nextInt(11)
      : 0;
  final style = dice.nextDouble() < _chanceOfAnotherFeel
      ? _anotherFeel(tune, dice)
      : null;

  // Around the tune's own tempo, then moved to suit whatever feel it is
  // being played with, because a groove carries its tempo with it.
  final slowest = tune.defaultTempo * (1 - _slowerBy);
  final fastest = tune.defaultTempo * (1 + _fasterBy);
  final wandered = slowest + dice.nextDouble() * (fastest - slowest);
  final feel = (style ?? tune.style).drums;
  final tempo = feel.tempoFor(wandered.round()).clamp(40, 320);

  return (tune: tune, semitones: semitones, tempo: tempo, style: style);
}

/// A feel that is not the one the tune is written with.
BandStyle? _anotherFeel(Tune tune, Random dice) {
  final others = [
    for (final feel in Feel.values)
      if (feel != tune.style.drums) feel,
  ];
  if (others.isEmpty) return null;
  // The whole band in the new feel, not the drums alone: a bossa with a
  // walking bass under it is neither thing.
  return BandStyle.of(others[dice.nextInt(others.length)]);
}

/// What the button says it has given you, in one line.
///
/// Said rather than left to be worked out: being handed a tune is the
/// point, being unable to tell what you were handed is not.
String describe(Suggestion picked) {
  final key = picked.tune.keyLabelBy(picked.semitones);
  final feel = picked.style?.drums.label;
  return [
    picked.tune.title,
    'in $key',
    'at ${picked.tempo}',
    if (feel != null) feel.toLowerCase(),
  ].join(', ');
}
