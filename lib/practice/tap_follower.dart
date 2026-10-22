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
//
// A count the barlines started can be at twice the tempo: Beat This! takes
// half bars for bars in its first seconds, when it has heard little, and
// hears the bars right after. The count, by then twice as quick, hears
// them on every other one of its bars and never between. Beat This!
// hearing the beat at two to the count's bar as well, the count halves
// itself, from a bar the barlines were on. Barlines on every other bar
// alone are not enough: on Four, Beat This! missed every other barline for
// a while, and the count was right; its beats were four to the bar. And
// two beats to the bar alone are not: on I Got Rhythm at 284 they were,
// with a barline on every bar.
//
// Barlines heard steadily on another beat of the count's bar, four in a
// row and none where the count has them, move the bar to start on that
// beat, unless a bar was tapped.
//
// Without drums Beat This! cannot hear the beat, and the barlines it says
// are scattered. The chords can (ChordFollower.swift): every few seconds
// they say the tempo, where a bar started and which bar of the tune it
// was. Two of those in a row that agree start the count when nothing has,
// or take it over when the barlines heard have stopped falling on its
// bars; from then on each two that agree put it right. Not one alone: on
// Blue Monk the chords' best answer was seldom far ahead of the next. That is how the count finds beat 1 after
// Half Time (Beat This! heard every half bar as a bar, as it did on Blue
// Monk through a microphone, and nothing heard tells that from a quick
// tune heard right) or after the beat is tapped while it listens.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../music/loop_range.dart';
import '../music/tune.dart';

class TapFollower extends ChangeNotifier {
  TapFollower({required this.tune, Duration Function()? clock})
    : _clock = clock ?? _stopwatch;

  final Tune tune;

  /// The tune's intro, played once: past the end of the tune the count
  /// goes round from just after it, as the band does (see loop_range.dart),
  /// not back into an intro that never comes again.
  late final _intro = introOf(tune);
  int _wrapBeat(int beat) => wrapBeat(tune, beat, intro: _intro);
  int _wrapBar(int bar) => wrapBar(tune, bar, intro: _intro);

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

  /// Barlines heard in a row on one other beat of the count's bar: which
  /// beat, and how many.
  var _offBeat = (beat: 0, count: 0);

  /// Told when the count's bars are put somewhere else: half as quick, a
  /// new tempo tapped, or starting on another beat. What was heard of the
  /// tune's place no longer holds.
  VoidCallback? onRecounted;

  /// Whether the count's tempo came from barlines heard, not taps, and
  /// has not been halved since: only then may it halve itself.
  var _byBarlines = false;

  /// When the barlines the count took were, lately.
  final _taken = <Duration>[];

  /// How long the beat Beat This! hears steadily is, when it does.
  Duration? _pulse;

  /// Whether each of the last ten barlines heard while counting fell on
  /// one of the count's bars.
  final _fell = <bool>[];

  /// Whether the barlines heard have stopped agreeing with the count: six
  /// or more heard since it started or its bars last moved, and fewer
  /// than three in ten of them on its bars. Then it cannot hear where the
  /// bars are, and no bar is shown, unless one was tapped. On every take
  /// that was followed, three in ten or more always were, and six on
  /// every broadcast; on Blue Monk played without drums, none were, and
  /// every bar shown was wrong.
  bool get losesTheBars => !_byChords && _barlinesLost;

  bool get _barlinesLost =>
      !_placedByHand &&
      _fell.length >= 6 &&
      _fell.where((fell) => fell).length * 10 < 3 * _fell.length;

  /// Whether the count is the chords', not the barlines' or the taps'.
  bool get byChords => _byChords;
  var _byChords = false;

  /// What the chords said last: when the bar they said started was, which
  /// bar of the tune, and how long a beat is.
  ({Duration at, int bar, Duration beat})? _chords;

  /// Told when the chords set the count.
  VoidCallback? onChords;

  /// The beat Beat This! hears, steady or not: the middle gap between
  /// its beats lately.
  Duration? _lookBeat;

  /// What the chords say (see the top): a bar that started [ago], [bar]
  /// of the tune, at [tempo]. Taken when the last thing they said agrees:
  /// the tempo within 4%, and this bar where that one puts it, to within
  /// four tenths of a bar.
  void heardChords(Duration ago, int bar, double tempo) {
    final at = _clock() - ago;
    final beat = Duration(microseconds: (60e6 / tempo).round());
    final last = _chords;
    _chords = (at: at, bar: bar, beat: beat);
    if (last == null || _placedByHand) return;
    final length = beat.inMicroseconds.toDouble();
    // A tune quicker than the chords look (ChordFollower.swift) is heard by
    // them at half its tempo, and Beat This! hears a beat twice as quick:
    // on Four at 210 the chords said 105. Beat This! keeps that one.
    final heard = _lookBeat;
    if (heard != null) {
      final ratio = length / heard.inMicroseconds;
      if (ratio > 1.8 && ratio < 2.2) return;
    }
    if ((length - last.beat.inMicroseconds).abs() > 0.04 * length) return;
    final perBar = tune.beatsPerBar;
    final bars =
        (at - last.at).inMicroseconds / (last.beat.inMicroseconds * perBar);
    final said = last.bar + bars;
    final apart =
        ((said - bar) % tune.barCount + tune.barCount) % tune.barCount;
    if (min(apart, tune.barCount - apart) > 0.4) return;
    if (counting && !_byChords && !_barlinesLost) return;
    _beatLength = beat;
    _startLength = beat;
    _anchor = (at: at, beat: bar * perBar);
    _byChords = true;
    _byBarlines = false;
    _startedByEar = false;
    _countingIn = false;
    _taken.clear();
    _offBeat = (beat: 0, count: 0);
    _run();
    onChords?.call();
    notifyListeners();
  }

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
    return _wrapBar(((anchor.beat + beats) / tune.beatsPerBar).floor());
  }

  /// The count moved on by whole bars, its time left as it is: the place
  /// in the tune heard by ear (see form_finder.dart).
  void moveBars(int bars) {
    final anchor = _anchor;
    if (anchor == null) return;
    _startedByEar = false;
    _anchor = (
      at: anchor.at,
      beat: _wrapBeat(anchor.beat + bars * tune.beatsPerBar),
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
    return _wrapBeat(anchor.beat + beats);
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
        final before = _beatLength;
        final retimed =
            current != null &&
            before != null &&
            (length - before).abs() > before * 0.2;
        _beatLength = length;
        _startLength = length;
        _byBarlines = false;
        _byChords = false;
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
          // the count keeps the beat it was on. At a new tempo, that beat
          // is a guess: what was heard of the place is let go, and the
          // barlines say where beat 1 is.
          _anchor = (at: now, beat: current);
          _countingIn = false;
          if (retimed) _recount();
        }
        _run();
      }
    }
    notifyListeners();
  }

  /// One look's beats, each how long before now it was: the beat Beat
  /// This! hears, for telling a count at twice the tempo (see the top).
  void heardBeats(List<Duration> beats) {
    final now = _clock();
    final at = [for (final ago in beats) now - ago]..sort();
    _pulse = _steady(at, now);
    final recent = [
      for (final b in at)
        if (b <= now - const Duration(seconds: 1) &&
            b >= now - const Duration(seconds: 12))
          b,
    ];
    final gaps = [
      for (var i = 1; i < recent.length; i++)
        (recent[i] - recent[i - 1]).inMicroseconds,
    ]..sort();
    _lookBeat = recent.length < 8
        ? null
        : Duration(microseconds: gaps[gaps.length ~/ 2]);
    _halveIfDouble();
  }

  /// How long a beat is, if [beats] from between twelve seconds and one
  /// second ago are eight or more and fall evenly, each within a sixth of
  /// a beat of one steady pulse, a beat left out here and there.
  Duration? _steady(List<Duration> beats, Duration now) {
    final heard = [
      for (final at in beats)
        if (at <= now - const Duration(seconds: 1) &&
            at >= now - const Duration(seconds: 12))
          at,
    ];
    if (heard.length < 8) return null;
    final gaps = [
      for (var i = 1; i < heard.length; i++)
        (heard[i] - heard[i - 1]).inMicroseconds,
    ]..sort();
    final guess = gaps[gaps.length ~/ 2];
    final span = (heard.last - heard.first).inMicroseconds;
    final count = (span / guess).round();
    if (count < 1 || heard.length < 0.75 * (count + 1)) return null;
    final length = span / count;
    final first = heard.first.inMicroseconds;
    for (final at in heard) {
      final x = (at.inMicroseconds - first) / length;
      if ((x - x.round()).abs() > 1 / 6) return null;
    }
    return Duration(microseconds: length.round());
  }

  /// Halves the count when the barlines taken over its last eight bars,
  /// four or more, were all an even number of its bars apart, and Beat
  /// This! hears two beats to its bar: it is at twice the tempo.
  void _halveIfDouble() {
    final length = _beatLength;
    final pulse = _pulse;
    final perBar = tune.beatsPerBar;
    if (!_byBarlines || _placedByHand || perBar.isOdd) return;
    if (length == null || pulse == null || _taken.length < 4) return;
    final bar = length.inMicroseconds * perBar;
    final halfBar = pulse.inMicroseconds * perBar / 2;
    if ((bar - halfBar).abs() > 0.08 * halfBar) return;
    final last = _taken.last;
    final recent = [
      for (final at in _taken)
        if ((last - at).inMicroseconds <= 8 * bar) at,
    ];
    if (recent.length < 4) return;
    if ((last - recent.first).inMicroseconds < 5.5 * bar) return;
    for (final at in recent) {
      final bars = ((last - at).inMicroseconds / bar).round();
      if (bars.isOdd) return;
    }
    // From the last barline taken, which is on a bar of the tempo halved.
    final anchor = _anchor!;
    final since = (last - anchor.at).inMicroseconds / length.inMicroseconds;
    final barline = ((anchor.beat + since) / perBar).round() * perBar;
    _anchor = (at: last, beat: _wrapBeat(barline));
    _beatLength = length * 2;
    _startLength = (_startLength ?? length) * 2;
    _byBarlines = false;
    _taken.clear();
    onHalved?.call();
    _recount();
    notifyListeners();
  }

  /// Told when the count halves itself, before [onRecounted].
  VoidCallback? onHalved;

  /// Half Time: the count's bars twice as long, from the barline it has
  /// now. Which half is the first is left to the barlines heard.
  void halfTime() {
    final length = _beatLength;
    final anchor = _anchor;
    if (length == null || anchor == null) return;
    final bar = length * tune.beatsPerBar;
    final since = _clock() - anchor.at;
    final bars = (since.inMicroseconds / bar.inMicroseconds).floor();
    final perBar = tune.beatsPerBar;
    final barline = ((anchor.beat ~/ perBar) + bars) * perBar;
    _anchor = (at: anchor.at + bar * bars, beat: _wrapBeat(barline));
    _beatLength = length * 2;
    _startLength = (_startLength ?? length) * 2;
    _byBarlines = false;
    _taken.clear();
    _recount();
    notifyListeners();
  }

  /// Double Time: the count's bars half as long, from the barline it has
  /// now. On a guitar and bass duo playing St. Thomas at about 250, Beat
  /// This!, the notes starting and the chords all heard 122, and nothing
  /// heard said otherwise, so it is the player's to say.
  void doubleTime() {
    final length = _beatLength;
    final anchor = _anchor;
    if (length == null || anchor == null) return;
    final perBar = tune.beatsPerBar;
    final bar = length * perBar;
    final bars = ((_clock() - anchor.at).inMicroseconds / bar.inMicroseconds)
        .floor();
    final barline = ((anchor.beat ~/ perBar) + bars) * perBar;
    _anchor = (at: anchor.at + bar * bars, beat: _wrapBeat(barline));
    _beatLength = length ~/ 2;
    _startLength = (_startLength ?? length) ~/ 2;
    _byBarlines = false;
    _byChords = false;
    _taken.clear();
    _recount();
    notifyListeners();
  }

  /// The count's bars moved: the place heard is let go, unless a bar was
  /// tapped, and the barlines start looking for beat 1 afresh.
  void _recount() {
    _offBeat = (beat: 0, count: 0);
    _fell.clear();
    if (!_placedByHand) _startedByEar = true;
    onRecounted?.call();
  }

  /// The band is at the top of the form now.
  void topOfChorus() => placeAtBar(0);

  /// The band is at [bar] now, its first beat.
  void placeAtBar(int bar) {
    onTapped?.call(bar);
    _placedByHand = true;
    _byChords = false;
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
      final before = _nudges;
      _nudge(at);
      _fell.add(_nudges > before);
      if (_fell.length > 10) _fell.removeAt(0);
    } else {
      _startFromHeard();
    }
  }

  /// Starts counting from the barlines heard alone, once the last five
  /// have come evenly: each gap a whole number of bars (one, two or three:
  /// a barline Beat This! was not sure of is left out, not guessed), each
  /// within 6% of it, at least two of them a single bar and not either
  /// side of the same barline, and the bar a bar's worth of beats between
  /// 300 and 60 to the minute (0.8 to 4 seconds in four; quicker is half
  /// bars). A barline heard wrongly half way through a
  /// bar makes two half bars side by side, and the bars either side of
  /// them look like two each: on Blue Monk that counted at twice the
  /// tempo. A bar already tapped keeps its place; otherwise the count
  /// starts on bar 1.
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
    final singles = [
      for (var i = 0; i < spans.length; i++)
        if (spans[i] == 1) i,
    ];
    if (singles.length < 2 || singles.last - singles.first < 2) return;
    final bar =
        (last.last - last.first).inMicroseconds / spans.reduce((a, b) => a + b);
    // A bar's worth of beats between 300 and 60 to the minute: in four,
    // 0.8 to 4 seconds; in three, a waltz's bar, 0.6 to 3. The same
    // limits in four only, as they were, turned a quick waltz's bars away
    // as half bars.
    final beats = tune.beatsPerBar;
    if (bar < beats * 200000 || bar > beats * 1000000) return;
    for (var i = 0; i < gaps.length; i++) {
      if ((gaps[i] / spans[i] - bar).abs() >= 0.06 * bar) return;
    }
    final perBar = tune.beatsPerBar;
    final length = Duration(microseconds: (bar / perBar).round());
    final placed = _anchor;
    var startsOn = 0;
    if (placed != null) {
      final bars = ((last.last - placed.at).inMicroseconds / bar).round();
      startsOn = _wrapBeat(placed.beat + bars * perBar);
    }
    _beatLength = length;
    _startLength = length;
    _anchor = (at: last.last, beat: startsOn);
    _startedByEar = placed == null;
    _byBarlines = true;
    _byChords = false;
    _fell.clear();
    _taken.clear();
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
    if (error.abs() > _nearEnough * bar) {
      _offBeatHeard(error / length);
      return;
    }
    _offBeat = (beat: 0, count: 0);
    _taken.add(at);
    if (_taken.length > 16) _taken.removeAt(0);
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
            beat: _wrapBeat(barline),
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

  /// A barline heard [beats] from the count's nearest, too far to nudge
  /// it: on another beat of the bar, four in a row put the bar there.
  void _offBeatHeard(double beats) {
    if (_placedByHand || _byChords) return;
    final whole = beats.round();
    if (whole == 0 || (beats - whole).abs() > 0.25) {
      _offBeat = (beat: 0, count: 0);
      return;
    }
    final perBar = tune.beatsPerBar;
    final on = whole % perBar;
    _offBeat = (beat: on, count: _offBeat.beat == on ? _offBeat.count + 1 : 1);
    if (_offBeat.count < 4) return;
    final anchor = _anchor!;
    _anchor = (at: anchor.at + _beatLength! * whole, beat: anchor.beat);
    _recount();
    notifyListeners();
  }

  /// Stops counting.
  void stop() {
    _anchor = null;
    _placedByHand = false;
    _startedByEar = false;
    _taps.clear();
    _heard.clear();
    _offBeat = (beat: 0, count: 0);
    _byBarlines = false;
    _byChords = false;
    _chords = null;
    _lookBeat = null;
    _taken.clear();
    _pulse = null;
    _fell.clear();
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
