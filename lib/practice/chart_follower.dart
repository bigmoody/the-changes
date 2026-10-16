// Following a chart by ear: where in the tune the music in the room is.
//
// The scrolling stage can follow the app's own band because the band says
// where it is. Music from anywhere else (a record, a band on a stage) says
// nothing, so it has to be listened for. Two things are heard, and each
// covers what the other cannot.
//
// The beat, from the attacks. A kick, a bass note, a stroke on the ride:
// each is a moment when energy arrives across the spectrum at once, which
// is what spectral flux measures (see onsets.dart, where the same method
// finds a drummer's hits in a take). The beats are counted by a loop that
// expects the next one a beat after the last, looks for an attack near
// there, and nudges its idea of the tempo and the phase toward what it
// found. With nothing heard it carries on counting, the way a player does
// through a stop. Counting is what tells the first A section from the
// last: they sound the same, and only the number of bars gone by differs.
//
// The chords, from the notes. At every beat the notes sounding are heard
// (chord_ear.dart, the Chord Identifier's ear) and set against the chord
// the chart has at each place in the tune. It is not asked to name the
// chord, which is hard, only how well each of the chart's chords fits,
// which is much easier. And it is heard as which notes, not in what
// order: any voicing, any inversion, a rootless left hand, all fit the
// chord they spell. The bass is the one note whose place counts, a little.
//
// Together they make a running guess over every beat of the form. Each
// beat the guess moves on one, mostly, with a little left behind in case
// a beat was missed and a little sent on in case one was counted twice;
// then every place is weighed by how well its chord fits what was heard.
// Counting keeps the guess moving between changes, and the changes pull
// it back into place when the counting slips. A small share is always
// spread over everywhere, so a guess that has gone wrong can come back.

import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/chord_ear.dart';
import '../audio/fft.dart';
import '../music/chord.dart';
import '../music/tune.dart';

/// Where the follower thinks the music is.
class FollowedPosition {
  const FollowedPosition({
    required this.beat,
    required this.beatsPerBar,
    required this.confidence,
    required this.tempo,
    required this.at,
    this.hearsMusic = true,
  });

  /// Whether most of the last few beats had music in them: an attack
  /// where the beat was, and notes. Without that the place is only
  /// counted on from a guess, however sure the guess looks, and a quiet
  /// room or somebody talking should not read as a band being followed.
  final bool hearsMusic;

  /// The beat of the form, counting from 0 at the top, as the chart's
  /// own beats count: the bar is [bar].
  final int beat;
  final int beatsPerBar;

  /// How much of the guess is on this beat, from 0 to 1. Low while it is
  /// still finding its place, or where two places sound the same.
  final double confidence;

  /// The tempo it is counting at, in beats a minute.
  final double tempo;

  /// When the beat fell, in seconds from the first sound fed in.
  final double at;

  int get bar => beat ~/ beatsPerBar;
}

class ChartFollower {
  ChartFollower({
    required this.tune,
    required double tempo,
    this.sampleRate = 44100,
    this.fromTheTop = true,
  }) : _period = 60 / tempo * sampleRate / _hop,
       _expected = 60 / tempo * sampleRate / _hop,
       _told = 60 / tempo * sampleRate / _hop,
       _guess = Float64List(tune.totalBeats) {
    if (fromTheTop) {
      // The first beat heard is most likely the first of the tune: that
      // is how a tune starts. Not certainly, though: somebody who turns
      // the ear on halfway through a chorus should not have to wait for
      // the chords to talk it out of a certainty it never had.
      _spread(0, _atTheTop);
    } else {
      _guess.fillRange(0, _guess.length, 1 / _guess.length);
    }
    _templates = [
      for (var beat = 0; beat < tune.totalBeats; beat++)
        _templateFor(tune.slotAtBeat(beat).chord),
    ];
  }

  final Tune tune;
  final int sampleRate;

  /// Whether it starts knowing it is at the top of the tune, or has to
  /// find its place from nothing.
  final bool fromTheTop;

  // ── The attacks ────────────────────────────────────────────────────────

  /// The analysis frame and the hop between them: about 23 and 12
  /// milliseconds at 44.1 kHz, fine enough to place a hit and coarse
  /// enough to be cheap.
  static const _frame = 1024;
  static const _hop = 512;

  /// Every sample heard, for as long as anything here looks back.
  final _heard = <double>[];
  var _heardFrom = 0;
  var _frames = 0;
  Float64List? _lastSpectrum;

  /// How strongly something began, frame by frame, from the start.
  final _flux = <double>[];

  /// A slowly moving level of the flux and how much it varies, so
  /// "strong" means standing out from this room: a soft ballad's brushes
  /// and a big band's shout are both heard, and so is a hit over a fan
  /// or a crowd, whose steady noise raises the level but not the spikes.
  var _fluxMean = 0.0;

  /// How loud the last frame was. Below [_quiet] nothing counts as a hit,
  /// however much it stands out: in a quiet room a keyboard being typed
  /// on stands out from the silence too.
  var _frameLevel = 0.0;
  static const _quiet = 0.001;
  var _fluxSpread = 0.0;

  /// How far [frame]'s flux stands out above the room, in spreads.
  double _standsOut(int frame) =>
      _fluxSpread == 0 ? 0 : (_flux[frame] - _fluxMean) / _fluxSpread;

  // ── The beat ───────────────────────────────────────────────────────────

  /// How long a beat is, in frames, as the follower hears it now, and as
  /// the chart said it would be. The first is let wander from the second
  /// by a fifth either way, which is a tempo nobody would call the same
  /// tune, and keeps it from settling on half or twice the beat.
  double _period;
  double _expected;

  /// The beat as the follower was told it, which a retune is measured
  /// against so it never wanders off by halves.
  final double _told;

  /// When the next beat is expected, in frames. Null until the first
  /// attack has been heard.
  double? _next;
  var _beats = 0;

  // ── Where in the tune ──────────────────────────────────────────────────

  final Float64List _guess;
  late final List<Float64List> _templates;
  FollowedPosition? _position;

  /// Where it thinks the music is, once it has heard a beat.
  FollowedPosition? get position => _position;

  /// How sure it starts that the first beat is the top of the tune.
  static const _atTheTop = 0.7;

  /// [share] of the guess on [beat], the rest spread everywhere.
  void _spread(int beat, double share) {
    final n = _guess.length;
    _guess.fillRange(0, n, (1 - share) / n);
    _guess[beat % n] += share;
  }

  /// Told where the music is: the beat now beginning is [beat].
  ///
  /// What a tap on a bar means: "we are here". Nearly, but not entirely,
  /// believed, in case the finger was a bar out.
  void placeAt(int beat) {
    _spread(beat, 0.9);
    final at = _position;
    _position = FollowedPosition(
      beat: beat % _guess.length,
      beatsPerBar: tune.beatsPerBar,
      confidence: 0.9,
      tempo: at?.tempo ?? 60 * sampleRate / (_period * _hop),
      at: at?.at ?? 0,
    );
  }

  /// How loud the room is, 0 to 1, for a meter that says the ear can
  /// hear anything at all.
  double get level => _level;
  var _level = 0.0;

  /// How much the attacks of the last few seconds repeat themselves a
  /// beat later, or two: near 1 for a groove, whatever it accents, and
  /// near 0 for a room's knocks and chatter, which have no beat.
  /// How much the attacks of the last few seconds repeat themselves
  /// [lag] frames later, as a correlation: near 1 for a groove at that
  /// spacing, near 0 for a room's knocks and chatter.
  double _repeatsAfter(int lag, int start, double mean) {
    var together = 0.0;
    var alone = 0.0;
    for (var i = start + lag; i < _flux.length; i++) {
      final a = _flux[i] - mean;
      final b = _flux[i - lag] - mean;
      together += a * b;
      alone += a * a;
    }
    return alone == 0 ? 0 : together / alone;
  }

  /// The groove the room has: how strongly its attacks repeat at the
  /// beat being counted (one or two beats on, whatever it accents), and
  /// how strongly at whatever spacing they repeat best, and what that is.
  ({double counted, double anywhere, double spacing}) _groove() {
    final span = math.min(_flux.length, (4 * sampleRate / _hop).round());
    final shortest = _framesPerBeatAt(_fastest).round();
    if (span < shortest * 4) return (counted: 0, anywhere: 0, spacing: 0);
    final start = _flux.length - span;
    var mean = 0.0;
    for (var i = start; i < _flux.length; i++) {
      mean += _flux[i];
    }
    mean /= span;
    final reach = span ~/ 3;
    var counted = 0.0;
    for (var beats = 1; beats <= 2; beats++) {
      final lag = (_period * beats).round();
      if (lag + 2 > reach) break;
      for (var d = -2; d <= 2; d++) {
        counted = math.max(counted, _repeatsAfter(lag + d, start, mean));
      }
    }
    var anywhere = 0.0;
    var spacing = 0.0;
    final longest = math.min(_framesPerBeatAt(_slowest).round(), reach);
    for (var lag = shortest; lag <= longest; lag++) {
      final here = _repeatsAfter(lag, start, mean);
      if (here > anywhere) {
        anywhere = here;
        spacing = lag.toDouble();
      }
    }
    return (counted: counted, anywhere: anywhere, spacing: spacing);
  }

  /// How many frames a beat lasts at [tempo].
  double _framesPerBeatAt(double tempo) => 60 / tempo * sampleRate / _hop;

  /// The tempos anything here will consider.
  static const _slowest = 50.0;
  static const _fastest = 280.0;

  /// How many beats in a row the room has had a groove the count is not
  /// on.
  var _offTempo = 0;

  /// The tempo the room's groove most likely is, when the count is not on
  /// it: of the spacing its attacks repeat at, and whole fractions and
  /// twice it, the one nearest what the follower was told. A guess, and
  /// said as one: a ride pattern repeats every two beats, a waltz every
  /// bar, and the sound alone cannot always say which is the beat.
  double? _roomTempo;

  /// Taps on the beat, in frames, while somebody is tapping along.
  final _taps = <int>[];

  /// The beat, tapped along with the music: the count takes its tempo
  /// from the taps and its beats from where they fell.
  ///
  /// The way through what the sound cannot settle: whether a groove is
  /// in two or in four, at half time or double. Three taps are enough.
  void tap() {
    final now = _frames;
    if (_taps.isNotEmpty &&
        now - _taps.last > _framesPerBeatAt(_slowest) * 1.5) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length < 3) return;
    final gaps = [
      for (var i = 1; i < _taps.length; i++)
        (_taps[i] - _taps[i - 1]).toDouble(),
    ]..sort();
    final beat = gaps[gaps.length ~/ 2].clamp(
      _framesPerBeatAt(_fastest),
      _framesPerBeatAt(_slowest),
    );
    _expected = beat;
    _period = beat;
    _offTempo = 0;
    _roomTempo = null;
    _quietFor = 0;
    if (_next == null) {
      // Not counting yet: the taps start it.
      _hitThisBeat = true;
      _beatAt(_taps.last.toDouble());
    }
    _next = _taps.last + beat;
  }

  /// The tempo of the room, when it has a groove the count is not on.
  double? get roomTempo => _roomTempo;

  /// Below this the attacks are not a groove.
  static const _aGroove = 0.35;

  /// Above this, somewhere, they plainly are: higher than [_aGroove],
  /// because looking at every spacing finds something in noise too.
  static const _plainly = 0.55;

  /// Every beat it has heard, in order: what the tests look back over.
  final heardBeats = <FollowedPosition>[];

  /// Feeds it more of the sound, as it arrives: mono, -1 to 1.
  void hear(Float32List samples) {
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    _level = samples.isEmpty ? 0 : math.sqrt(energy / samples.length);
    _heard.addAll(samples);
    while (_heard.length - (_frames * _hop - _heardFrom) >= _frame) {
      _analyseFrame();
    }
    // Keep what the chords are listened to over, reaching back from a
    // beat that is only counted once a little more than a fifth of a beat
    // after it has gone by, and stopping short of it by a quarter: two
    // beats more than the window is room enough, at the slowest tempo the
    // count will go to.
    final keep =
        _chordWindow + (2 * _framesPerBeatAt(_slowest) * _hop).ceil() + _frame;
    final start = _frames * _hop - _heardFrom;
    if (start > keep * 2) {
      final drop = start - keep;
      _heard.removeRange(0, drop);
      _heardFrom += drop;
    }
  }

  void _analyseFrame() {
    final at = _frames * _hop - _heardFrom;
    final frame = Float32List(_frame);
    var energy = 0.0;
    for (var i = 0; i < _frame; i++) {
      frame[i] = _heard[at + i];
      energy += frame[i] * frame[i];
    }
    _frameLevel = math.sqrt(energy / _frame);
    final spectrum = magnitudeSpectrum(frame, size: _frame);
    // Logarithmic, so a quiet hit is a rise as well as a loud one.
    for (var i = 0; i < spectrum.length; i++) {
      spectrum[i] = math.log(1 + 1000 * spectrum[i]);
    }
    var rise = 0.0;
    final before = _lastSpectrum;
    if (before != null) {
      // Nothing above about five kilohertz says when a hit began (as in
      // onsets.dart), and up there is where a room's hiss lives.
      final top = math.min(spectrum.length, 5000 * _frame ~/ sampleRate);
      for (var i = 0; i < top; i++) {
        final change = spectrum[i] - before[i];
        if (change > 0) rise += change;
      }
    }
    _lastSpectrum = spectrum;
    _flux.add(rise);
    // Settles over about a second and a half.
    const pace = 0.008;
    if (_flux.length == 1) {
      _fluxMean = rise;
    } else {
      final off = rise - _fluxMean;
      _fluxMean += pace * off;
      final variance =
          (1 - pace) * (_fluxSpread * _fluxSpread + pace * off * off);
      _fluxSpread = math.sqrt(variance);
    }
    _frames++;
    _countBeats();
  }

  /// How far either side of where a beat is expected an attack is taken
  /// as that beat, as a share of the beat. Wide enough for a player
  /// pushing or laying back, narrow enough not to take the swung "and".
  static const _reach = 0.2;

  void _countBeats() {
    final now = _frames - 1;
    final next = _next;
    if (next == null) {
      // The first real attack is the first beat, once there has been
      // long enough to know what the room sounds like.
      if (_flux.length > 40 && _standsOut(now) > 2 && _frameLevel > _quiet) {
        _hitThisBeat = true;
        _beatAt(now.toDouble());
        _next = now + _period;
      }
      return;
    }
    final reach = _period * _reach;
    // Wait until the whole of the window round the beat has been heard.
    if (now < next + reach) return;
    final best = _strongestNear(next, reach);
    var heardAt = next;
    final hit = best != null && _standsOut(best) > 0.5 && _frameLevel > _quiet;
    _hitThisBeat = hit;
    _quietFor = hit ? 0 : _quietFor + 1;
    // Two bars and more with nothing on the beat: the music has stopped.
    // Rather than count on into nothing, it holds where it is and waits
    // for the next attack to be the next beat.
    if (_quietFor >= 2 * tune.beatsPerBar) {
      _next = null;
      _quietFor = 0;
      return;
    }
    if (hit) {
      final error = best - next;
      heardAt = next + error * 0.5;
      _period = (_period + error * 0.1).clamp(
        _expected * 0.8,
        _expected * 1.25,
      );
    }
    _checkTheOffBeats(heardAt);
    if (_swapPending) {
      // Not this one: the beat is half a beat on, and is counted there.
      _swapPending = false;
      return;
    }
    _beatAt(heardAt);
    _next = heardAt + _period;
  }

  /// The frame near [at] where something most clearly began, nearer
  /// counting for more, so a strong off-beat does not pull the count away
  /// from a softer beat.
  int? _strongestNear(double at, double reach) {
    final from = math.max(0, (at - reach).floor());
    final to = math.min(_flux.length - 1, (at + reach).ceil());
    int? best;
    var bestScore = 0.0;
    for (var f = from; f <= to; f++) {
      final off = (f - at) / reach;
      final score = math.max(0.0, _standsOut(f)) * math.exp(-2 * off * off);
      if (score > bestScore) {
        bestScore = score;
        best = f;
      }
    }
    return best;
  }

  /// Whether each of the last few beats had both an attack on it and
  /// notes in it.
  var _musical = <bool>[];
  static const _remembered = 8;

  /// Whether the beat being counted now had an attack on it. The first
  /// beat always did: an attack is what it was taken from.
  var _hitThisBeat = true;
  var _quietFor = 0;

  /// How strongly things begin on the beats being counted, and halfway
  /// between them, over the last several beats.
  var _onTheBeat = 0.0;
  var _between = 0.0;
  var _sinceSwapped = 0;

  /// Whether the count has settled on the off-beats, and if so, moves it.
  ///
  /// Coming in on the middle of a tune, the first attack heard may as
  /// well be an "and" as a beat, and the tempo is the same either way:
  /// only which half of the beat it is counting on is wrong. The beats
  /// are where the bass and the kick land and the ride is struck, so
  /// over a few bars they are the stronger half. When the half between
  /// the counted beats is plainly stronger, the count moves over to it.
  void _checkTheOffBeats(double beat) {
    final reach = _period * _reach / 2;
    double strength(double at) {
      final f = _strongestNear(at, reach);
      return f == null ? 0 : math.max(0.0, _standsOut(f));
    }

    const pace = 0.15;
    _onTheBeat += pace * (strength(beat) - _onTheBeat);
    _between += pace * (strength(beat - _period / 2) - _between);
    _sinceSwapped++;
    if (_sinceSwapped > 8 && _between > _onTheBeat * 1.4) {
      _next = beat + _period / 2;
      _swapPending = true;
      final was = _onTheBeat;
      _onTheBeat = _between;
      _between = was;
      _sinceSwapped = 0;
    }
  }

  /// Set when the count has just moved over half a beat, so the beat
  /// about to be counted is the one it moved to.
  var _swapPending = false;

  // ── The chords ─────────────────────────────────────────────────────────

  /// How much is listened to for the chord at each beat: about a third
  /// of a second, which the ear needs to tell low notes apart.
  static const _chordWindow = 16384;

  void _beatAt(double frame) {
    final sample = (frame * _hop).round() + _frame ~/ 2;
    // What has been heard in the run up to this beat, which is the beat
    // just played, and so the one this is evidence for.
    // Stopping a quarter of a beat short: comping anticipates, and the
    // last eighth before a change is often already the next chord.
    final end = sample - (_period * _hop * _anticipation).round() - _heardFrom;
    final start = end - _chordWindow;
    HeardNotes? notes;
    if (start >= 0 && end <= _heard.length) {
      final window = Float32List(_chordWindow);
      for (var i = 0; i < _chordWindow; i++) {
        window[i] = _heard[start + i];
      }
      notes = listenForNotes(window, sampleRate: sampleRate, most: 8);
      _pitched = _howPitched(window);
    }
    _move(_beats == 0 ? null : notes, (frame * _hop + _frame / 2) / sampleRate);
  }

  /// How much what was heard has notes in it, from 0 to 1.
  var _pitched = 1.0;

  /// How much of what is in [window] is notes, from 0 to 1.
  ///
  /// Drums alone (a drum solo, trading fours) have pitches of a kind, and
  /// the ear finds eight "notes" in a cymbal; set against the chart those
  /// pull the guess to wherever their accidental notes fit, and it loses
  /// its place in a bar or two. So what is heard is asked how much of it
  /// is notes: sharp peaks standing well clear of the spectrum round them,
  /// where the bass and the chords live. A note is a peak; a cymbal, a
  /// snare and a room's hiss are a floor. Measured on the band, the drums
  /// alone put a tenth of their sound or less into peaks, and the band
  /// with a loud room over it still a fifth or more, so it is averaged
  /// over a few beats and the chords count in proportion between the two.
  double _howPitched(Float32List window) {
    final spectrum = magnitudeSpectrum(window, size: _chordWindow);
    final low = (60 * _chordWindow / sampleRate).round();
    final high = (1500 * _chordWindow / sampleRate).round();
    var inPeaks = 0.0;
    var total = 0.0;
    var logs = 0.0;
    for (var i = low; i < high; i++) {
      logs += math.log(spectrum[i] + 1e-9);
      final around = [
        for (
          var j = math.max(0, i - 30);
          j <= math.min(spectrum.length - 1, i + 30);
          j++
        )
          spectrum[j],
      ]..sort();
      final floor = around[around.length ~/ 2];
      total += spectrum[i];
      if (spectrum[i] > floor * 4) inPeaks += spectrum[i] - floor;
    }
    final share = total == 0 ? 0.0 : inPeaks / total;
    _peaks += 0.3 * (share - _peaks);
    // And how flat the spectrum is: notes are spiky and drums are flat,
    // measured on the band below 0.47 for anything with the bass or the
    // piano in it and above 0.52 for the drums alone. A room's hiss is
    // flat too, which is why this is the second question and not the
    // only one: music under a loud room fails it and passes the first,
    // and the drums alone fail both.
    final n = high - low;
    final flatness = total == 0 ? 1.0 : math.exp(logs / n) / (total / n);
    _flatness += 0.3 * (flatness - _flatness);
    final spiky = ((0.55 - _flatness) / 0.1).clamp(0.0, 1.0);
    final peaky = ((_peaks - 0.16) / 0.08).clamp(0.0, 1.0);
    return math.max(spiky, peaky);
  }

  var _flatness = 0.3;

  /// The share of the sound in peaks, over the last few beats.
  var _peaks = 0.3;

  /// The guess is of the beat now beginning. What was heard up to now is
  /// the beat that has just ended, which is where the guess was, so it is
  /// weighed there first and then moved on a beat.
  void _move(HeardNotes? notes, double seconds) {
    final n = _guess.length;
    final first = _beats == 0;
    _beats++;
    var best = -double.infinity;
    if (notes != null && !notes.isEmpty) {
      final fits = Float64List(n);
      for (var k = 0; k < n; k++) {
        fits[k] = _fit(_templates[k], notes);
        best = math.max(best, fits[k]);
      }

      for (var k = 0; k < n; k++) {
        _guess[k] *= math.exp(_pitched * _sharpness * (fits[k] - best));
      }
    }
    var total = 0.0;
    for (final g in _guess) {
      total += g;
    }
    // Never quite certain: a share everywhere, so it can find its way
    // back from a wrong turn.
    for (var k = 0; k < n; k++) {
      _guess[k] = 0.995 * _guess[k] / total + 0.005 / n;
    }
    if (!first) {
      // Mostly one on; a little held back for a missed beat and a little
      // sent two on for one counted twice.
      final moved = Float64List(n);
      for (var k = 0; k < n; k++) {
        moved[k] =
            (1 - 2 * _slip) * _guess[(k - 1 + n) % n] +
            _slip * _guess[k] +
            _slip * _guess[(k - 2 + n) % n];
      }
      _guess.setAll(0, moved);
    }
    var at = 0;
    for (var k = 1; k < n; k++) {
      if (_guess[k] > _guess[at]) at = k;
    }
    final heard = first ? null : _groove();
    // Whether the spacing the room's attacks repeat at best is a whole
    // number of the beats being counted, or half of one. A count at the
    // wrong tempo can still line up now and then (two beats at 100 are
    // three at 150), but the room's own strongest repeat will not be a
    // whole number of its beats.
    final onTheCount =
        heard != null &&
        (heard.anywhere < _plainly ||
            [0.5, 1.0, 2.0, 3.0, 4.0].any(
              (beats) => (heard.spacing / _period / beats - 1).abs() < 0.07,
            ));
    final groove = heard != null && heard.counted >= _aGroove && onTheCount;
    if (heard != null) {
      // A groove plainly there, and not at the beat being counted.
      _offTempo = !onTheCount ? _offTempo + 1 : 0;
      if (_offTempo >= 4) {
        final candidates =
            [
                  for (final k in [1, 2, 3, 4]) heard.spacing / k,
                  heard.spacing * 2,
                ]
                .where(
                  (p) =>
                      p >= _framesPerBeatAt(_fastest) &&
                      p <= _framesPerBeatAt(_slowest),
                )
                .toList()
              ..sort(
                (a, b) =>
                    (math.log(a / _told))
                        .abs()
                        .compareTo((math.log(b / _told)).abs()),
              );
        _roomTempo = candidates.isEmpty
            ? null
            : 60 * sampleRate / (candidates.first * _hop);
      } else if (_offTempo == 0) {
        _roomTempo = null;
      }
    }
    if (!first) {
      _musical = [
        ..._musical.skip(_musical.length >= _remembered ? 1 : 0),
        _hitThisBeat && notes != null && !notes.isEmpty && groove,
      ];
    }
    final musical = _musical.where((m) => m).length;
    final position = FollowedPosition(
      beat: at,
      beatsPerBar: tune.beatsPerBar,
      confidence: _guess[at],
      tempo: 60 * sampleRate / (_period * _hop),
      at: seconds,
      hearsMusic: musical >= _remembered ~/ 2,
    );
    _position = position;
    heardBeats.add(position);
  }

  /// How hard what was heard pulls the guess toward the chords it fits.
  static const _sharpness = 3.0;

  /// How likely the count is to have missed a beat, or counted one twice.
  /// Small, because the count is mostly right; not nothing, because when
  /// it is wrong the chords have to be able to say so.
  static const _slip = 0.01;

  /// How much of the end of each beat is left out when listening for its
  /// chord, as a share of the beat.
  static const _anticipation = 0.25;

  /// The chord as twelve weights: its notes, the root a little more.
  static Float64List _templateFor(Chord chord) {
    final weights = Float64List(13);
    for (final pc in chord.pitchClasses) {
      weights[pc] = 1;
    }
    weights[chord.root] = 1.3;
    // The thirteenth place holds the bass the chord asks for.
    weights[12] = chord.bass.toDouble();
    var length = 0.0;
    for (var i = 0; i < 12; i++) {
      length += weights[i] * weights[i];
    }
    length = math.sqrt(length);
    for (var i = 0; i < 12; i++) {
      weights[i] /= length;
    }
    return weights;
  }

  /// How well [notes] fit a chord: the angle between what was heard and
  /// the chord's notes, and a little more if the bass is the chord's.
  static double _fit(Float64List chord, HeardNotes notes) {
    var dot = 0.0;
    var length = 0.0;
    for (var i = 0; i < 12; i++) {
      dot += chord[i] * notes.chroma[i];
      length += notes.chroma[i] * notes.chroma[i];
    }
    var fit = length == 0 ? 0.0 : dot / math.sqrt(length);
    final bass = notes.bass;
    if (bass != null) {
      final pc = bass % 12;
      if (pc == chord[12].round()) {
        fit += 0.15;
      } else if (chord[pc] > 0) {
        fit += 0.05;
      }
    }
    return fit;
  }
}
