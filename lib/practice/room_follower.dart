// Following a chart by ear without being told the tempo.
//
// On a stand there is no time to look up what tempo a band has counted
// off, and the tempo on the chart is whatever it was last practised at.
// So the tempo is heard, not told. Hearing it is the hard part: the
// attacks of a groove repeat every beat, but just as strongly every two
// (a ride pattern), every bar (a waltz), or every half beat (a straight
// eighth shaker), and from the attacks alone there is no telling which
// of those is the beat.
//
// The chart can tell. At the right tempo the chords change where the
// chart says they will, a bar or two bars apart; at half or twice the
// tempo they change in the middle of bars, or every other bar, and
// nothing lines up. So for a few seconds this only listens, for how far
// apart the attacks repeat; then it starts a follower for each tempo
// that spacing could be, hands each everything heard so far, lets them
// all listen on, and keeps the one that finds the tune. From then on
// it is that follower, counting forward.
//
// Tap the Beat settles it at once, for somebody who would rather not
// wait the few seconds.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/tune.dart';
import 'chart_follower.dart';

class RoomFollower {
  RoomFollower({required this.tune, this.sampleRate = 44100});

  final Tune tune;
  final int sampleRate;

  /// Listens for the pulse only. Its tempo is never used.
  late final _scout = ChartFollower(
    tune: tune,
    tempo: 120,
    sampleRate: sampleRate,
    fromTheTop: false,
  );

  /// Everything heard until a tempo is chosen, to hand to each follower
  /// that might be the one.
  final _heard = <Float32List>[];
  var _samples = 0;

  /// Where in what was heard each tap on a bar came, so the followers
  /// started later can be told at the moment it happened.
  final _placings = <({int at, int beat})>[];
  final _taps = <int>[];

  /// The followers being tried, one per tempo.
  List<ChartFollower>? _trying;
  int? _triedFrom;
  ChartFollower? _chosen;

  /// Whether the room was quiet when listening began, so that the band
  /// starting is the top of the tune.
  bool? _quietAtFirst;

  /// The follower doing the following, once a tempo has been chosen.
  ChartFollower? get following => _chosen;

  FollowedPosition? get position => _chosen?.position;
  List<FollowedPosition> get heardBeats => _chosen?.heardBeats ?? const [];
  double get level => (_chosen ?? _scout).level;
  double? get roomTempo => _chosen?.roomTempo;

  /// The tempos being tried, while one is still being chosen.
  List<double> get tryingTempos => [
    for (final follower in _trying ?? const <ChartFollower>[])
      follower.position?.tempo ?? 0,
  ];

  /// A few seconds before the tempos are tried: enough beats at any
  /// tempo for the spacing of the attacks to be clear.
  static const _listenFirst = 4.0;

  /// Kept no longer than this while choosing, which is plenty.
  static const _keepAtMost = 40;

  void hear(Float32List samples) {
    final chosen = _chosen;
    if (chosen != null) {
      chosen.hear(samples);
      return;
    }
    if (_samples < _keepAtMost * sampleRate) {
      _heard.add(Float32List.fromList(samples));
    }
    _samples += samples.length;
    _scout.hear(samples);
    _quietAtFirst ??= _samples >= sampleRate ~/ 2 ? _scout.level < 0.002 : null;
    final trying = _trying;
    if (trying == null) {
      if (_samples >= _listenFirst * sampleRate) _startTrying();
      return;
    }
    for (final follower in trying) {
      follower.hear(samples);
    }
    _choose();
  }

  void _startTrying() {
    final pulse = _scout.pulse;
    if (pulse.strength < 0.4 || pulse.seconds <= 0) return;
    // Every tempo the spacing could be the beat of. A groove repeats
    // every beat, but its strongest repeat can as well be half a beat (a
    // straight eighth shaker), two (a ride pattern), a beat and a half (a
    // bossa's dotted figure), three (a waltz's bar) or four (a bar of
    // four), so the spacing is tried as each of those.
    final tempos = <double>[];
    for (final beats in [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]) {
      final tempo = 60 / (pulse.seconds / beats);
      if (tempo < 50 || tempo > 300) continue;
      if (tempos.any((t) => (t / tempo - 1).abs() < 0.06)) continue;
      tempos.add(tempo);
    }
    if (tempos.isEmpty) return;
    _start(tempos);
  }

  void _start(List<double> tempos) {
    _trying = [
      for (final tempo in tempos)
        ChartFollower(
          tune: tune,
          tempo: tempo,
          sampleRate: sampleRate,
          fromTheTop: _quietAtFirst ?? false,
        ),
    ];
    _triedFrom = _samples;
    for (final follower in _trying!) {
      _replay(follower);
    }
  }

  /// Hands [follower] everything heard so far, with the taps on bars at
  /// the moments they came.
  void _replay(ChartFollower follower) {
    var at = 0;
    var placing = 0;
    for (final chunk in _heard) {
      var from = 0;
      while (placing < _placings.length &&
          _placings[placing].at < at + chunk.length) {
        final split = (_placings[placing].at - at).clamp(from, chunk.length);
        follower.hear(Float32List.sublistView(chunk, from, split));
        follower.placeAt(_placings[placing].beat);
        from = split;
        placing++;
      }
      follower.hear(Float32List.sublistView(chunk, from));
      at += chunk.length;
    }
    for (; placing < _placings.length; placing++) {
      follower.placeAt(_placings[placing].beat);
    }
  }

  /// Keeps the follower that has found the tune, once each has heard a
  /// few bars at its own tempo.
  void _choose() {
    final trying = _trying!;
    final heard = (_samples - _triedFrom!) / sampleRate;
    // How clearly the chart explains the beats each has counted, slid to
    // wherever they fit best: not where each has counted to, which may
    // not have settled yet even at the right tempo.
    double score(ChartFollower follower) => follower.chartExplains;

    final ready = trying.every(
      (f) => f.heardBeats.length >= 6 * tune.beatsPerBar,
    );
    if (!ready && heard < 12) return;
    final scores = [for (final follower in trying) score(follower)];
    final order = [for (var i = 0; i < trying.length; i++) i]
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final top = scores[order.first];
    if (top <= 0) return;
    // The runner-up that is a different tempo, not the same one twice (two
    // tried tempos can drift to the same place).
    final runnerUp = order
        .skip(1)
        .where((i) => !_same(trying[i], trying[order.first]))
        .map((i) => scores[i])
        .fold(0.0, math.max);
    int pick;
    if (top >= _clearly && top >= runnerUp * _ahead) {
      pick = order.first;
    } else if (heard < _waitAtMost) {
      // Not clearly any of them yet: it listens on rather than guess.
      return;
    } else {
      // Half a minute and still close: of those nearly as good, the one
      // nearest the tempo the tune is usually played at. Between a tempo
      // and twice it, the tune's usual tempo is rarely in doubt.
      pick = order.first;
      for (final i in order) {
        if (scores[i] < top * 0.8) continue;
        if (_fromUsual(trying[i]) < _fromUsual(trying[pick])) pick = i;
      }
    }
    // Chosen. It is started again, at the tempo it has settled on, and
    // given everything from the beginning: a follower that began a little
    // off has the right tempo now, but may have slipped a beat getting
    // there, and one started at the right tempo does not.
    final tempo =
        trying[pick].position?.tempo ?? trying[pick].heardBeats.last.tempo;
    final fresh = ChartFollower(
      tune: tune,
      tempo: tempo,
      sampleRate: sampleRate,
      fromTheTop: _quietAtFirst ?? false,
    );
    _replay(fresh);
    _chosen = fresh;
    _trying = null;
    _heard.clear();
  }

  /// Whether two followers have come to the same tempo.
  bool _same(ChartFollower a, ChartFollower b) {
    final x = a.position?.tempo;
    final y = b.position?.tempo;
    if (x == null || y == null) return false;
    return (x / y - 1).abs() < 0.04;
  }

  /// How far [follower]'s tempo is from the tune's usual one, as a
  /// ratio either way.
  double _fromUsual(ChartFollower follower) {
    final tempo = follower.position?.tempo ?? tune.defaultTempo.toDouble();
    return (math.log(tempo / tune.defaultTempo)).abs();
  }

  /// How clearly the chart must explain a tempo's beats before it is
  /// chosen without waiting longer, and how long it will wait.
  static const _clearly = 2.8;

  /// How far ahead of the next tempo the best must be to be chosen
  /// without waiting.
  static const _ahead = 1.15;
  static const _waitAtMost = 30.0;

  /// Tap the Beat: three taps choose the tempo at once.
  void tap() {
    final chosen = _chosen;
    if (chosen != null) {
      chosen.tap();
      return;
    }
    if (_taps.isNotEmpty && _samples - _taps.last > sampleRate * 1.5) {
      _taps.clear();
    }
    _taps.add(_samples);
    if (_taps.length < 3) return;
    final gaps = [
      for (var i = 1; i < _taps.length; i++) _taps[i] - _taps[i - 1],
    ]..sort();
    final tempo = 60 * sampleRate / gaps[gaps.length ~/ 2];
    if (tempo < 40 || tempo > 320) return;
    _start([tempo]);
    _chosen = _trying!.single;
    _trying = null;
    _heard.clear();
  }

  /// "We are here": the beat now beginning.
  void placeAt(int beat) {
    final chosen = _chosen;
    if (chosen != null) {
      chosen.placeAt(beat);
      return;
    }
    _placings.add((at: _samples, beat: beat));
    for (final follower in _trying ?? const <ChartFollower>[]) {
      follower.placeAt(beat);
    }
  }
}
