// Where am I? — keeping your place in the form.
//
// Knowing the changes and knowing where you are in them are two different
// things, and only one of them is on the chart. Take the page away and
// most people can still play the chords; far fewer can say, at any moment,
// which bar they are in. That is the thing that comes apart on a stand,
// and it is the reason people come off the form and cannot get back on.
//
// So: the band plays from the top with nothing on screen, cuts out
// somewhere, and you say which bar you were in. There is no trick to it
// and no chart to check against — you either kept count or you didn't.
//
// The band has to start at the top for the question to have an answer. Come
// in halfway and the first four bars of an AABA are the first four bars of
// the second A as well, and nobody could tell them apart, because there is
// nothing to tell apart.

import 'dart:math' as math;

import '../music/tune.dart';

/// Where the band cuts out: which time round the form, which bar of it, and
/// how far into that bar.
typedef StopPoint = ({int chorus, int bar, int beatInBar});

/// The fewest bars the band plays before cutting out.
///
/// Stop sooner and you are not keeping your place, you are remembering a
/// number you heard four seconds ago.
const leastBars = 5;

/// The most times round the form a question runs to.
const mostChoruses = 3;

/// The most bars it plays before cutting out, whatever the form.
///
/// Counted in bars rather than choruses because three choruses of a
/// thirty-two bar tune is the best part of three minutes of listening for
/// one question, and nobody will do that twice. Forty bars is a chorus and
/// a bit of a standard — long enough to get past the top and find out
/// whether you knew you had come round — and three of a blues.
const mostBars = 40;

/// A place for the band to stop on [tune], somewhere past [leastBars] and
/// inside [choruses] times round.
///
/// Never on the first beat of a bar: "it stopped going into bar 9" and "it
/// stopped in bar 9" are different answers to the same sound, and a
/// question you can be right about twice is a bad question.
StopPoint chooseStop(
  Tune tune,
  math.Random random, {
  int choruses = mostChoruses,
}) {
  final bars = tune.barCount;
  final total = math.min(bars * choruses, mostBars);
  final from = math.min(leastBars, total - 1);
  final at = from + random.nextInt(math.max(1, total - from));
  return (
    chorus: at ~/ bars,
    bar: at % bars,
    // Somewhere in the middle of the bar, so it is plainly inside it.
    beatInBar: 1 + random.nextInt(math.max(1, tune.beatsPerBar - 1)),
  );
}

/// Whether the band has reached [stop], given where it has got to.
///
/// [chorus] and [beat] are the controller's: the chorus counted from nought
/// and the beat of the tune counted from its top.
bool reached(
  StopPoint stop,
  Tune tune, {
  required int? chorus,
  required int? beat,
}) {
  if (chorus == null || beat == null) return false;
  if (chorus != stop.chorus) return chorus > stop.chorus;
  return beat >= stop.bar * tune.beatsPerBar + stop.beatInBar;
}

/// How far [answer] is from [actual], the short way round the form.
///
/// Round, because the form is: answering bar 32 when it was bar 1 is being
/// one bar out, not thirty-one. It is the same mistake as answering bar 2.
int barsOut(int answer, int actual, int barCount) {
  final apart = (answer - actual).abs() % barCount;
  return math.min(apart, barCount - apart);
}

/// What an answer was worth.
enum Marking {
  spotOn('Spot on'),

  /// A bar out is still lost, but it is the kind of lost you come back
  /// from — you had the form, you dropped a bar.
  nearly('A bar out'),

  lost('Lost');

  const Marking(this.label);

  final String label;

  bool get isRight => this == spotOn;
}

Marking markAnswer(int answer, int actual, int barCount) =>
    switch (barsOut(answer, actual, barCount)) {
      0 => Marking.spotOn,
      1 => Marking.nearly,
      _ => Marking.lost,
    };

/// How it has gone so far this sitting.
typedef Tally = ({int asked, int right});

String describeTally(Tally tally) =>
    tally.asked == 0 ? '' : '${tally.right} of ${tally.asked}';
