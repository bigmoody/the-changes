// Which bar of the tune the band is in, by ear. Builds being worked on
// only, with Beat This! (see tap_follower.dart).
//
// Beat This! hears where the bars start but not which bars they are: the
// count it starts begins on bar 1 wherever the band happens to be. So the
// notes sounding in each bar heard (the harmony, and the bass on its own,
// which most often plays the root; see BarPitches.swift) are matched to
// the chart's chords, with the chart slid along them a bar at a time. The
// place they fit best is where the band is.
//
// Tried offline on four broadcasts of St. Thomas, with the bar numbers
// somebody listening tapped as the answer: eight bars heard put it in the
// right bar 141 times in 143, twelve or more every time.
//
// The fit is added up over everything heard, not judged on the last few
// bars: on Miles Davis's Four, which a band plays with its own voicings
// over a form that repeats, the right place fitted best from the sixth
// bar on but never by much, so a small lead held for a long time is as
// good as a big one held briefly. The count is moved once the best fit's
// lead over the next, added up, is 0.8 (a tenth of a match a bar over
// eight bars). In the St. Thomas takes no wrong answer led by more than
// half that; on the Four take the right one passed it after about twenty
// bars. The figure was read off those same takes, so other records may
// want another. A tune whose sections repeat exactly cannot be told apart
// inside the repeats, only by the section that differs.

import 'dart:math';

import '../music/tune.dart';

class FormFinder {
  FormFinder({required this.tune});

  final Tune tune;

  /// Fewer bars than this are not enough to go on.
  static const fewest = 8;

  /// The most kept: two choruses of a 32-bar tune.
  static const most = 64;

  /// How much better than the runner-up the best fit must be, added up
  /// over the bars heard.
  static const lead = 0.8;

  /// The bass counts for half as much as the harmony.
  static const _bassWeight = 0.5;

  final _bars = <({Duration at, List<double> pitches})>[];

  /// What sounded in a bar that started at [at]: 48 numbers, the harmony
  /// and bass of its first half then of its second, twelve pitch classes
  /// each from C.
  void heard(Duration at, List<double> pitches) {
    if (pitches.length != 48) return;
    _bars.add((at: at, pitches: pitches));
    if (_bars.length > most) _bars.removeAt(0);
  }

  void clear() => _bars.clear();

  int get barsHeard => _bars.length;

  /// How many bars the count should move by to put the band where the
  /// chart fits what was heard, given the bar the count has at a time.
  /// Null while it cannot tell, or when the count is already there.
  int? shift(int? Function(Duration at) barAt) {
    if (_bars.length < fewest) return null;
    final placed = [
      for (final bar in _bars)
        if (barAt(bar.at) case final counted?) (counted: counted, bar: bar),
    ];
    if (placed.length < fewest) return null;
    final scores = [
      for (var k = 0; k < tune.barCount; k++)
        placed.fold(
          0.0,
          (sum, p) =>
              sum + _fit(p.bar.pitches, (p.counted + k) % tune.barCount),
        ),
    ];
    final order = [for (var k = 0; k < scores.length; k++) k]
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    if (order.length < 2) return null;
    final best = order[0];
    if (scores[best] - scores[order[1]] < lead || best == 0) return null;
    return best;
  }

  /// How well a bar heard fits the chart's bar [barIndex]: for each half,
  /// the harmony against the chord's notes, and the bass against its
  /// lowest note.
  double _fit(List<double> pitches, int barIndex) {
    var sum = 0.0;
    final perBar = tune.beatsPerBar;
    for (var half = 0; half < 2; half++) {
      final chord = tune
          .slotAtBeat(barIndex * perBar + half * (perBar ~/ 2))
          .chord;
      final tones = List<double>.filled(12, 0);
      for (final pc in chord.pitchClasses) {
        tones[pc] = 1;
      }
      final offset = half * 24;
      sum += _cosine(pitches.sublist(offset, offset + 12), tones);
      final bass = pitches.sublist(offset + 12, offset + 24);
      final length = _length(bass);
      if (length > 0) sum += _bassWeight * bass[chord.bass] / length;
    }
    return sum;
  }

  static double _length(List<double> v) =>
      sqrt(v.fold(0.0, (sum, x) => sum + x * x));

  static double _cosine(List<double> a, List<double> b) {
    final la = _length(a);
    final lb = _length(b);
    if (la == 0 || lb == 0) return 0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot / (la * lb);
  }
}
