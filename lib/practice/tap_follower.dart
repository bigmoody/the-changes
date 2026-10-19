// Following a band by being told, not by listening.
//
// Listening to a real record or a real band to work out where it is in a
// tune failed: a soloist over the changes, comping that pushes and
// anticipates, a rhythm section playing around the beat, heard through a
// laptop's microphone. What a player on a stand can do instead is what
// they do anyway: feel the time and know where the top of the chorus is.
// So the chart is told those two things, by a tap or a foot pedal, and
// counts on in between.
//
// Three things it can be told:
//
//   Tap the Beat      a few taps along with the band. The count takes
//                     its tempo and its beats from them. Tapped before
//                     the band starts, they count it in, and bar 1 comes
//                     on the beat after the last tap. With the band
//                     already playing, they give the tempo, and a tap on
//                     the bar it is at gives the place.
//   Top of the Chorus the band is at bar 1 now. Pressed at the top of
//                     each chorus of a solo, the chart can never be more
//                     than a chorus out.
//   A bar on the chart the band is at that bar now.
//
// Between them it counts at the tempo tapped, and goes on doing so until
// told otherwise. A band that drifts is put right with a few more taps.
//
// Or by Beat This!, in builds being worked on, hearing a record another
// app is playing (see other_apps.dart). Each barline it hears may nudge
// the count, never more: half way to where it heard the bar start, and
// the bar a fifth of the way to the length that would have put it there,
// never more than a tenth from the tempo the count started at. A barline
// heard more than a fifth of a bar from where the count has one is not
// taken: it is a half bar, or a guess. Heard steadily enough before
// anything is tapped, the barlines start the count themselves. The
// numbers are the ones a tryout on recorded jazz settled on, tuned on half
// the recordings and checked on the other half.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../music/tune.dart';

class TapFollower extends ChangeNotifier {
  TapFollower({required this.tune, Duration Function()? clock})
    : _clock = clock ?? _stopwatch;

  final Tune tune;

  /// What time it is, for counting; a test's own clock in a test.
  final Duration Function() _clock;

  static final _watch = Stopwatch()..start();
  static Duration _stopwatch() => _watch.elapsed;

  /// When a beat was, and which beat of the tune it was: what the count
  /// runs on from. Null until it has a tempo and somewhere to start.
  ({Duration at, int beat})? _anchor;

  /// How long a beat is. Null until it has been tapped.
  Duration? _beatLength;

  final _taps = <Duration>[];

  /// The beat's length when the count last started, which a heard
  /// barline may move it a tenth from at most.
  Duration? _startLength;

  /// The last barlines heard, for starting on its own.
  final _heard = <Duration>[];

  static const _nudgePlace = 0.5;
  static const _nudgeLength = 0.2;
  static const _nearEnough = 0.2;
  static const _furthest = 0.1;

  /// How many heard barlines have moved the count.
  int get nudges => _nudges;
  var _nudges = 0;

  /// Whether a bar has been tapped since counting started: somebody who
  /// knows where the band is has said so, and the ear does not argue.
  bool get placedByHand => _placedByHand;
  var _placedByHand = false;

  /// Whether the count knows which bar of the tune the band is in. It
  /// does not when it started itself from barlines heard, which say where
  /// bars start and not which bars they are, until a bar is tapped or the
  /// place is heard (see form_finder.dart).
  bool get placeKnown => counting && !_startedByEar;
  var _startedByEar = false;

  /// The place in the tune heard, and right as it is.
  void placeHeard() {
    if (!_startedByEar) return;
    _startedByEar = false;
    notifyListeners();
  }

  /// What time it is by the count's clock.
  Duration get now => _clock();

  /// The bar of the tune the count had at [at], or null when it is not
  /// counting.
  int? barAt(Duration at) {
    final anchor = _anchor;
    final length = _beatLength;
    if (anchor == null || length == null) return null;
    final beats = ((at - anchor.at).inMicroseconds / length.inMicroseconds)
        .floor();
    // Rounded down, not toward nought: a bar before the anchor is a
    // whole bar back even when its beat comes out below nought.
    return ((anchor.beat + beats) / tune.beatsPerBar).floor() % tune.barCount;
  }

  /// The count moved on by whole bars, its time left as it is: the place
  /// in the tune heard by ear (see form_finder.dart).
  void moveBars(int bars) {
    final anchor = _anchor;
    if (anchor == null) return;
    _startedByEar = false;
    _anchor = (
      at: anchor.at,
      beat: (anchor.beat + bars * tune.beatsPerBar) % tune.totalBeats,
    );
    notifyListeners();
  }

  /// Told of every tap as it comes: null for a beat, the bar for a bar.
  /// For keeping the taps beside a recording of what was tapped along to.
  void Function(int? bar)? onTapped;

  /// Whether the last taps were a count-in, still going.
  var _countingIn = false;

  static Duration _halfOf(Duration d) =>
      Duration(microseconds: d.inMicroseconds ~/ 2);
  Timer? _ticker;
  int? _lastBeat;

  /// The tempo being counted at, once tapped.
  double? get tempo =>
      _beatLength == null ? null : 60000000 / _beatLength!.inMicroseconds;

  /// Whether it is counting.
  bool get counting => _anchor != null && _beatLength != null;

  /// How many taps there have been toward the next tempo, so the screen
  /// can say how many more it needs.
  int get taps => _taps.length;

  /// The beat of the tune now beginning, or null when it is not counting.
  int? get beat {
    final anchor = _anchor;
    final length = _beatLength;
    if (anchor == null || length == null) return null;
    final since = _clock() - anchor.at;
    final beats = (since.inMicroseconds / length.inMicroseconds).floor();
    return (anchor.beat + beats) % tune.totalBeats;
  }

  /// Tap the Beat.
  void tapBeat() {
    final now = _clock();
    onTapped?.call(null);
    // A pause of more than a couple of seconds starts a new set of taps.
    if (_taps.isNotEmpty && now - _taps.last > const Duration(seconds: 2)) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length >= 3) {
      final gaps = [
        for (var i = 1; i < _taps.length; i++) _taps[i] - _taps[i - 1],
      ]..sort();
      final length = gaps[gaps.length ~/ 2];
      // Fifty to three hundred and twenty: outside that it was not a beat.
      if (length >= const Duration(microseconds: 187500) &&
          length <= const Duration(milliseconds: 1200)) {
        final placed = _anchor;
        final countingIn =
            _countingIn && placed != null && now < placed.at + _halfOf(length);
        final current = countingIn ? null : beat;
        _beatLength = length;
        _startLength = length;
        if (current == null && placed != null && !countingIn) {
          // A bar was tapped before the tempo was: the band has gone on
          // from it since, by as many beats as there have been.
          final since = now - placed.at;
          _anchor = (
            at: now,
            beat:
                placed.beat +
                (since.inMicroseconds / length.inMicroseconds).round(),
          );
          _countingIn = false;
        } else if (current == null) {
          // Counting in: bar 1 comes on the beat after the last tap, and
          // every tap that comes before it puts it off by one more. The
          // count-in is over when a beat goes by without one.
          _anchor = (at: now + length, beat: 0);
          _countingIn = true;
        } else {
          // Counting already: the beats move to where the taps fell, and
          // the count keeps the beat it was on.
          _anchor = (at: now, beat: current);
          _countingIn = false;
        }
        _run();
      }
    }
    notifyListeners();
  }

  /// The band is at the top of the form now.
  void topOfChorus() => placeAtBar(0);

  /// The band is at [bar] now, its first beat.
  void placeAtBar(int bar) {
    onTapped?.call(bar);
    _placedByHand = true;
    _startedByEar = false;
    _anchor = (at: _clock(), beat: bar * tune.beatsPerBar);
    _countingIn = false;
    _taps.clear();
    _run();
    notifyListeners();
  }

  /// A barline Beat This! heard, [ago] before now.
  void heardBarline(Duration ago) {
    final at = _clock() - ago;
    // Kept in the order they were played, which is not always the order
    // they are heard in: a barline two looks only agree on late comes
    // after ones played later.
    _heard
      ..add(at)
      ..sort();
    if (_heard.length > 8) _heard.removeAt(0);
    if (counting) {
      _nudge(at);
    } else {
      _startFromHeard();
    }
  }

  /// Starts counting from the barlines heard alone, once the last five
  /// have come evenly: each gap a whole number of bars (one, two or three:
  /// a barline Beat This! was not sure of is left out, not guessed), each
  /// within 6% of it, at least two of them a single bar, and the bar
  /// between 0.8 and 4 seconds (quicker is half bars). A bar already
  /// tapped keeps its place; otherwise the count starts on bar 1.
  void _startFromHeard() {
    if (_heard.length < 5) return;
    final last = _heard.sublist(_heard.length - 5);
    final gaps = [
      for (var i = 1; i < last.length; i++)
        (last[i] - last[i - 1]).inMicroseconds,
    ];
    // The shortest gap as a first guess at a bar, then the bar the whole
    // stretch says, counting each gap as the bars it spans.
    final guess = gaps.reduce(min);
    final spans = [for (final gap in gaps) (gap / guess).round()];
    if (spans.any((n) => n < 1 || n > 3)) return;
    if (spans.where((n) => n == 1).length < 2) return;
    final bar =
        (last.last - last.first).inMicroseconds / spans.reduce((a, b) => a + b);
    if (bar < 800000 || bar > 4000000) return;
    for (var i = 0; i < gaps.length; i++) {
      if ((gaps[i] / spans[i] - bar).abs() >= 0.06 * bar) return;
    }
    final perBar = tune.beatsPerBar;
    final length = Duration(microseconds: (bar / perBar).round());
    final placed = _anchor;
    var startsOn = 0;
    if (placed != null) {
      final bars = ((last.last - placed.at).inMicroseconds / bar).round();
      startsOn = (placed.beat + bars * perBar) % tune.totalBeats;
    }
    _beatLength = length;
    _startLength = length;
    _anchor = (at: last.last, beat: startsOn);
    _startedByEar = placed == null;
    _countingIn = false;
    _taps.clear();
    _run();
    notifyListeners();
  }

  /// The count moved toward a barline heard at [at].
  ///
  /// Barlines are heard a second or so after they were played, so one may
  /// come from before the bar last tapped: it still says where the bars
  /// fall, counted back from the tap. A few bars back at most.
  void _nudge(Duration at) {
    final anchor = _anchor!;
    final length = _beatLength!.inMicroseconds;
    final perBar = tune.beatsPerBar;
    final since = (at - anchor.at).inMicroseconds;
    final barline = ((anchor.beat + since / length) / perBar).round() * perBar;
    final beats = barline - anchor.beat;
    if (beats < -4 * perBar) return;
    final expected = anchor.at.inMicroseconds + beats * length;
    final error = at.inMicroseconds - expected;
    final bar = length * perBar;
    if (error.abs() > _nearEnough * bar) return;
    // Bars from the count's anchor to the barline. Behind it, a barline
    // late by [error] means the bars are shorter, not longer.
    // The bar the count was last put on, heard: its place, not its length.
    final bars = beats / perBar;
    final across = bars.abs() < 1 ? bars.sign : bars;
    final started = (_startLength ?? _beatLength!).inMicroseconds * perBar;
    final lengthened = across == 0 ? 0 : _nudgeLength * error / across;
    final nudged = (bar + lengthened).clamp(
      started * (1 - _furthest),
      started * (1 + _furthest),
    );
    _anchor = beats > 0
        ? (
            at: Duration(
              microseconds: (expected + _nudgePlace * error).round(),
            ),
            beat: barline % tune.totalBeats,
          )
        : (
            at:
                anchor.at +
                Duration(microseconds: (_nudgePlace * error).round()),
            beat: anchor.beat,
          );
    _beatLength = Duration(microseconds: (nudged / perBar).round());
    _nudges++;
    notifyListeners();
  }

  /// Stops counting.
  void stop() {
    _anchor = null;
    _placedByHand = false;
    _startedByEar = false;
    _taps.clear();
    _heard.clear();
    _ticker?.cancel();
    _ticker = null;
    _lastBeat = null;
    notifyListeners();
  }

  /// Ticks over often enough to mark each beat as it comes, and tells
  /// whoever is watching only when the beat changes.
  void _run() {
    if (_beatLength == null || _ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 20), (_) {
      final now = beat;
      if (now != _lastBeat) {
        _lastBeat = now;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
