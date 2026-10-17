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

import 'dart:async';

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
    _anchor = (at: _clock(), beat: bar * tune.beatsPerBar);
    _countingIn = false;
    _taps.clear();
    _run();
    notifyListeners();
  }

  /// Stops counting.
  void stop() {
    _anchor = null;
    _taps.clear();
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
