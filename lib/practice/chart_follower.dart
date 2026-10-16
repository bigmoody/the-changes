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
  });

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
       _guess = Float64List(tune.totalBeats) {
    if (fromTheTop) {
      // The first beat heard is the first of the tune: a count-in, or a
      // tap on the first bar, says so.
      _guess[0] = 1;
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
  final double _expected;

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

  /// Every beat it has heard, in order: what the tests look back over.
  final heardBeats = <FollowedPosition>[];

  /// Feeds it more of the sound, as it arrives: mono, -1 to 1.
  void hear(Float32List samples) {
    _heard.addAll(samples);
    while (_heard.length - (_frames * _hop - _heardFrom) >= _frame) {
      _analyseFrame();
    }
    // Keep only what the chords are listened to over, and a frame.
    final keep = math.max(_chordWindow, _frame) + _hop;
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
    for (var i = 0; i < _frame; i++) {
      frame[i] = _heard[at + i];
    }
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
      if (_flux.length > 40 && _standsOut(now) > 2) {
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
    if (best != null && _standsOut(best) > 0.5) {
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
    }
    _move(_beats == 0 ? null : notes, (frame * _hop + _frame / 2) / sampleRate);
  }

  /// The guess is of the beat now beginning. What was heard up to now is
  /// the beat that has just ended, which is where the guess was, so it is
  /// weighed there first and then moved on a beat.
  void _move(HeardNotes? notes, double seconds) {
    final n = _guess.length;
    final first = _beats == 0;
    _beats++;
    if (notes != null && !notes.isEmpty) {
      final fits = Float64List(n);
      var best = -double.infinity;
      for (var k = 0; k < n; k++) {
        fits[k] = _fit(_templates[k], notes);
        best = math.max(best, fits[k]);
      }
      for (var k = 0; k < n; k++) {
        _guess[k] *= math.exp(_sharpness * (fits[k] - best));
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
    final position = FollowedPosition(
      beat: at,
      beatsPerBar: tune.beatsPerBar,
      confidence: _guess[at],
      tempo: 60 * sampleRate / (_period * _hop),
      at: seconds,
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
