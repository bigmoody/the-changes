// The beat as something you feel rather than hear.
//
// A click is not available to everybody. It is painful to some people to
// listen to, it disappears inside a loud texture, and it is no use at all
// if you are practising with the sound off or cannot hear it well. The
// pulse itself is not an audio fact though: it is just a regular moment,
// and a phone can deliver one through your hand.
//
// So the same beat the band is already counting is tapped out on the
// phone. It runs beside the click rather than instead of it, because
// somebody who wants both should have both and somebody who wants only
// this can turn the click off where it already turns off.
//
// The 1 is a harder tap than the rest. A pulse you can feel tells you the
// tempo; a pulse where one of them is heavier tells you where you are in
// the bar, which is the thing that actually goes missing when you are
// lost, and it costs nothing to say.

import 'package:flutter/services.dart';

/// Where the beat is tapped out, if at all.
enum FeelTheBeat {
  off('Off'),
  everyBeat('Every Beat'),
  backbeat('2 And 4'),
  theOne('The 1');

  const FeelTheBeat(this.label);

  final String label;

  /// Whether this makes sense in a bar of [beatsPerBar] beats. There is no
  /// 4 in a bar of three, so the backbeat is only offered in even time.
  /// The same rule the click uses, so the two read alike.
  bool suits(int beatsPerBar) => this != backbeat || beatsPerBar.isEven;

  /// Whether a tap falls on [beat] of the bar, counted from nought.
  ///
  /// A backbeat asked for in odd time taps every beat rather than
  /// nothing, because a setting that silently does nothing is worse than
  /// one that does the obvious thing.
  bool taps(int beat, int beatsPerBar) => switch (this) {
    off => false,
    everyBeat => true,
    backbeat => suits(beatsPerBar) ? beat.isOdd : true,
    theOne => beat % beatsPerBar == 0,
  };
}

/// Taps the phone for [beat] of a bar of [beatsPerBar], if [feel] says to.
///
/// [beat] is counted from the top of the bar, so beat 0 is the 1. A tune
/// beat works just as well: it is taken modulo the bar.
void feelBeat(FeelTheBeat feel, {required int beat, required int beatsPerBar}) {
  if (beatsPerBar < 1) return;
  final inBar = beat % beatsPerBar;
  if (!feel.taps(inBar, beatsPerBar)) return;
  // Heavier on the 1, so the bar has a shape and not just a rate. Not on
  // a backbeat setting, where the 1 is deliberately the beat you are not
  // being given and leaning on it would undo the exercise.
  if (inBar == 0 && feel != FeelTheBeat.backbeat) {
    _tap(HapticFeedback.heavyImpact());
  } else {
    _tap(HapticFeedback.lightImpact());
  }
}

/// Taps every beat of a count-in.
///
/// Whatever the setting says about where the taps fall, a count-in is
/// tapped out in full: it exists to say when to come in, and one you can
/// only feel on the 1 does not do that job.
void feelCountIn(FeelTheBeat feel) {
  if (feel == FeelTheBeat.off) return;
  _tap(HapticFeedback.lightImpact());
}

/// Fire and forget. A tap that arrives late is worse than no tap, so
/// nothing waits on the platform here, and a platform that refuses one
/// (no taptic engine, haptics turned off in the system settings, a phone
/// in low power) is not an error worth interrupting anybody's practice
/// for.
void _tap(Future<void> going) {
  going.catchError((Object _) {});
}
