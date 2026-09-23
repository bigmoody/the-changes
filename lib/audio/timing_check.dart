// Did they play to the click?
//
// The length of a file says whether a take is roughly the right size (see
// readTakeLength), and that catches a session run at the wrong tempo. It
// cannot catch drift: a take that rushes the first half and drags the
// second comes out exactly the right length and passes. So the only way
// to know whether a recording is usable is to look at where the hits
// actually landed against where the click said.
//
// The number that comes out of that is worth taking apart, because three
// quite different things are mixed up in it and only one of them is the
// players' fault:
//
//  • Offset. Everything sits twenty milliseconds late. Nobody played
//    badly; the file was trimmed a fraction off. The app can move the
//    take's start and it is gone.
//  • Drift. The error grows steadily down the take. The stated tempo is
//    wrong, and the slope says what it really was. This finds a tempo a
//    twentieth of a beat out, which the length check never would.
//  • Scatter. What is left once those two are taken out. This is how
//    tightly they played, it is the only part nobody can fix afterwards,
//    and it is the verdict.
//
// Reporting the three together would be worse than useless: a perfectly
// played take trimmed two frames late would read the same as a rhythm
// section that could not hold time.

import 'dart:math' as math;

import '../music/recorded_take.dart';
import 'onsets.dart';
import 'wav_file.dart';

/// How tightly it was played, in words.
///
/// As with the strain bands in recorded_take.dart, these boundaries are a
/// starting point rather than a measurement. What a good rhythm section
/// scatters to on a click is exactly one of the things the pilot is for,
/// and these are meant to be moved once there is an answer. The
/// milliseconds are always shown beside them for that reason.
enum TimingVerdict {
  locked('Locked to the click'),
  tight('Tight'),
  loose('Loose'),
  adrift('Not to a click'),

  /// Too few hits landed anywhere near the grid to say anything.
  cannotTell('Cannot tell');

  const TimingVerdict(this.label);
  final String label;
}

/// What the hits in a recording say about how it was played.
class TimingCheck {
  const TimingCheck({
    required this.beatsExpected,
    required this.beatsMatched,
    required this.statedBpm,
    required this.offsetSeconds,
    required this.impliedBpm,
    required this.scatterMs,
    required this.worstMs,
    required this.worstBeat,
    required this.beatsPerBar,
  });

  /// Nothing could be said, because nothing was found.
  static const nothing = TimingCheck(
    beatsExpected: 0,
    beatsMatched: 0,
    statedBpm: 0,
    offsetSeconds: 0,
    impliedBpm: 0,
    scatterMs: 0,
    worstMs: 0,
    worstBeat: null,
    beatsPerBar: 4,
  );

  final int beatsExpected;

  /// How many of them had a hit near enough to measure. A drummer does
  /// not strike every beat, so this is rarely all of them and is not
  /// supposed to be.
  final int beatsMatched;

  final double statedBpm;

  /// Where bar 1 really is, against where the take says it is. Positive
  /// means the music starts late, so the file has silence to trim.
  final double offsetSeconds;

  /// The tempo the playing itself says it was at.
  final double impliedBpm;

  /// The average distance from the click once the offset and the drift
  /// have been taken out. This is the verdict.
  final double scatterMs;

  final double worstMs;
  final int? worstBeat;
  final int beatsPerBar;

  /// The bar the worst one is in, counting from 1 as a person would.
  int? get worstBar => worstBeat == null ? null : worstBeat! ~/ beatsPerBar + 1;

  double get coverage => beatsExpected == 0 ? 0 : beatsMatched / beatsExpected;

  double get offsetMs => offsetSeconds * 1000;

  /// How far the stated tempo is out, as a percentage of itself.
  double get tempoErrorPercent =>
      statedBpm <= 0 ? 0 : (impliedBpm - statedBpm) / statedBpm * 100;

  /// Enough of the take was found to be worth believing.
  ///
  /// Half the beats is a low bar on purpose. A drummer playing a sparse
  /// two feel strikes far fewer than all of them, and there is no point
  /// refusing to measure a take for being played tastefully.
  bool get enoughToTell => beatsMatched >= 8 && coverage >= 0.4;

  TimingVerdict get verdict {
    if (!enoughToTell) return TimingVerdict.cannotTell;
    return switch (scatterMs) {
      < 8 => TimingVerdict.locked,
      < 18 => TimingVerdict.tight,
      < 35 => TimingVerdict.loose,
      _ => TimingVerdict.adrift,
    };
  }

  /// Worth offering to move the take's start by.
  ///
  /// Ten milliseconds, which is a great deal more than this measures
  /// wrongly (the detector is good to well under one) and a great deal
  /// less than anybody can trim by hand.
  bool get worthNudging => enoughToTell && offsetSeconds.abs() > 0.01;

  /// Worth saying the tempo is not the one it was given.
  ///
  /// A twentieth of a per cent over six choruses of a blues is most of a
  /// beat by the end, which is enough to see on the chart.
  bool get worthRetempoing => enoughToTell && tempoErrorPercent.abs() > 0.05;
}

/// The stem to measure, out of whatever came in.
///
/// The kit, every time it is there. Spectral flux finds the beginnings of
/// sounds, and a struck drum is the clearest beginning there is; a
/// walking bass is the worst, because one note joins onto the next with
/// nothing much happening in between.
TakeStem? stemToTime(Iterable<TakeStem> stems) {
  for (final stem in [TakeStem.drums, TakeStem.comp, TakeStem.bass]) {
    if (stems.contains(stem)) return stem;
  }
  return null;
}

/// How far the hits in [audio] sit from where [take] says the beats are.
///
/// [onsets] can be given if they have already been found; otherwise they
/// are found here.
TimingCheck checkTiming(
  WavAudio audio, {
  required RecordedTake take,
  List<double>? onsets,
}) {
  final statedPeriod = take.bpm <= 0 ? 0.0 : 60 / take.bpm;
  final beats = take.beats;
  if (statedPeriod <= 0 || beats < 8) return TimingCheck.nothing;
  final hits = onsets ?? findOnsets(audio);
  if (hits.length < 8) return TimingCheck.nothing;
  final sorted = [...hits]..sort();

  // What tempo were they really playing at?
  //
  // This cannot be found by looking for the hit nearest each expected
  // beat, which was the first thing tried and is wrong. A take three per
  // cent fast slips a whole beat every thirty or so, and from then on
  // every expected beat still has a hit near it: the wrong one. The fit
  // that comes out of that says the tempo is fine and the playing is
  // perfect, which is the most dangerous answer this could give.
  //
  // So the period is searched for instead. The one they really played at
  // is the one that makes everything line up at once, and it is obvious
  // when found: at the right period the hits sit on the beats and almost
  // nothing is left over, and at any other period they are strewn about.
  //
  // Beyond eight per cent this gives up, on the grounds that a take that
  // badly mislabelled is the length check's to catch, and that searching
  // further starts finding half and double time.
  final period = _periodThatFits(sorted, take, statedPeriod) ?? statedPeriod;

  // Now the tempo is known, the nearest hit to each beat really is that
  // beat's. A line through what is left gives where the recording starts
  // and whatever tempo error the search did not quite reach.
  var offset = 0.0;
  var drift = 0.0;
  var matched = <({int beat, double deviation})>[];
  for (var pass = 0; pass < 2; pass++) {
    final reach = statedPeriod * (pass == 0 ? 0.4 : 0.25);
    matched = [];
    for (var beat = 0; beat < beats; beat++) {
      final at = take.startSeconds + beat * period + offset + drift * beat;
      final near = _nearest(sorted, at);
      if (near == null || (near - at).abs() > reach) continue;
      matched.add((
        beat: beat,
        deviation: near - (take.startSeconds + beat * period),
      ));
    }
    if (matched.length < 8) break;
    final fit = _line(matched);
    offset = fit.intercept;
    drift = fit.slope;
  }

  if (matched.length < 8) {
    return TimingCheck(
      beatsExpected: beats,
      beatsMatched: matched.length,
      statedBpm: take.bpm,
      offsetSeconds: 0,
      impliedBpm: take.bpm,
      scatterMs: 0,
      worstMs: 0,
      worstBeat: null,
      beatsPerBar: take.beatsPerBar,
    );
  }

  // What is left once the offset and the drift are accounted for.
  var total = 0.0;
  var worst = 0.0;
  int? worstBeat;
  for (final one in matched) {
    final left = one.deviation - (offset + drift * one.beat);
    total += left.abs();
    if (left.abs() > worst.abs()) {
      worst = left;
      worstBeat = one.beat;
    }
  }

  return TimingCheck(
    beatsExpected: beats,
    beatsMatched: matched.length,
    statedBpm: take.bpm,
    offsetSeconds: offset,
    impliedBpm: period + drift <= 0 ? take.bpm : 60 / (period + drift),
    scatterMs: total / matched.length * 1000,
    worstMs: worst * 1000,
    worstBeat: worstBeat,
    beatsPerBar: take.beatsPerBar,
  );
}

/// How far the search will look either side of the stated tempo.
const _reach = 0.08;

/// How much the whole take is allowed to slip between one candidate
/// tempo and the next: a fiftieth of a beat, so the right one cannot be
/// stepped over.
const _slipPerStep = 0.02;

/// The most candidates to try, so a very long take cannot take all day.
const _mostSteps = 4000;

/// The period they were really playing at, or null when nothing fits.
///
/// Every period within [_reach] of the stated one is tried, and each is
/// scored by how much is left over once the hits are matched to the beats
/// and the whole thing is slid into place. The right period leaves almost
/// nothing; a wrong one strews the hits about.
///
/// The count matters as well as the scatter, and it is taken first: a
/// wildly wrong period can match a handful of beats very tidily by
/// accident, and would win on scatter alone.
double? _periodThatFits(List<double> onsets, RecordedTake take, double stated) {
  final beats = take.beats;
  final steps = math.min(
    _mostSteps,
    (2 * _reach * beats / _slipPerStep).ceil(),
  );
  if (steps < 2) return null;
  final reach = stated * 0.4;

  var mostMatched = 0;
  final tried = <({double period, int count, double scatter})>[];
  for (var step = 0; step <= steps; step++) {
    final period = stated * (1 - _reach + 2 * _reach * step / steps);
    var count = 0;
    var total = 0.0;
    final deviations = <double>[];
    for (var beat = 0; beat < beats; beat++) {
      final at = take.startSeconds + beat * period;
      final near = _nearest(onsets, at);
      if (near == null || (near - at).abs() > reach) continue;
      count++;
      total += near - at;
      deviations.add(near - at);
    }
    if (count < 8) continue;
    // Slid into place first, so a recording that simply starts late is
    // not mistaken for one at the wrong tempo.
    final middle = total / count;
    var left = 0.0;
    for (final deviation in deviations) {
      left += (deviation - middle).abs();
    }
    if (count > mostMatched) mostMatched = count;
    tried.add((period: period, count: count, scatter: left / count));
  }
  if (tried.isEmpty) return null;

  double? best;
  var bestScatter = double.infinity;
  for (final one in tried) {
    if (one.count < mostMatched * 0.95) continue;
    if (one.scatter < bestScatter) {
      bestScatter = one.scatter;
      best = one.period;
    }
  }
  return best;
}

/// The onset closest to [at], or null when there are none.
double? _nearest(List<double> sorted, double at) {
  if (sorted.isEmpty) return null;
  var low = 0;
  var high = sorted.length - 1;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (sorted[middle] < at) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  final after = sorted[low];
  if (low == 0) return after;
  final before = sorted[low - 1];
  return (at - before).abs() <= (after - at).abs() ? before : after;
}

/// The straight line through the deviations: where they start, and how
/// fast they grow.
({double intercept, double slope}) _line(
  List<({int beat, double deviation})> points,
) {
  var beatTotal = 0.0;
  var deviationTotal = 0.0;
  for (final point in points) {
    beatTotal += point.beat;
    deviationTotal += point.deviation;
  }
  final beatMean = beatTotal / points.length;
  final deviationMean = deviationTotal / points.length;
  var top = 0.0;
  var bottom = 0.0;
  for (final point in points) {
    final spread = point.beat - beatMean;
    top += spread * (point.deviation - deviationMean);
    bottom += spread * spread;
  }
  final slope = bottom == 0 ? 0.0 : top / bottom;
  return (intercept: deviationMean - slope * beatMean, slope: slope);
}
