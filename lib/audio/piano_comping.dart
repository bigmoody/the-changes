// What the piano player comps, chord by chord.
//
// The guiding idea is that a pianist reacts to the chart rather than rolling
// dice every bar:
//
//  • A *new* chord gets an attack: on the beat, pushed an eighth early, or
//    the classic Charleston (beat 1 and the "and" of 2).
//  • A chord that is simply still sounding (bar 2 of "C6 | C6") is mostly
//    left alone. If anything, it gets a quiet off-beat reminder. Re-striking
//    a held chord on every downbeat is what made static tunes like "Take the
//    'A' Train" sound like a machine.
//  • The voicing only changes when the chord changes, and then it moves to
//    whichever shape is nearest the previous one; that's what makes comping
//    sound joined-up rather than scattered.

import 'dart:math' as math;

import '../music/chord.dart';
import '../music/voicings.dart';
import '../music/comping.dart';
import '../music/tune.dart';

// Where the voicings live now. Re-exported so the guitarist and the
// tests that reach for them through this file keep working.
export '../music/voicings.dart';

/// One comped chord: when to play it, how long, how hard, and which notes.
typedef CompHit = ({
  double beat,
  double length,
  double velocity,
  List<int> notes,
});

/// A rhythm: (beat, length in beats, how hard relative to the chord's level).
typedef _Pattern = List<(double, double, double)>;

class Comper {
  /// [shapes] replaces the piano's voicings with another instrument's (the
  /// guitar's), each already in place; [home] is where that hand's lowest
  /// note likes to sit.
  Comper(this.random, {this.shapes, this.home = compHome});

  final math.Random random;
  final List<List<int>> Function(Chord chord, {Chord? resolvingTo})? shapes;
  final int home;

  /// The voicing last played, which the next one moves smoothly from. Set it
  /// to carry a hand position over from an earlier stretch of playing.
  List<int>? previousVoicing;

  /// The chord last comped, to tell a new chord from one still sounding.
  String? _sounding;

  /// How many slots the current chord has been held for.
  int _held = 0;
  bool _started = false;
  String? _lastPattern;

  /// Comps one chord lasting [beats], starting at beat 0 of its own time.
  /// [next] is the chord it leads to, which decides whether a dominant is
  /// played plain or altered.
  ///
  /// With [held], each chord is simply struck and held for its whole length,
  /// re-struck gently on each new bar if it lasts that long.
  List<CompHit> comp(
    Chord chord,
    int beats,
    Feel feel, {
    Chord? next,
    bool held = false,
    bool calypso = false,
    double beatInBar = 0,
    required double swing,
  }) {
    final isNew = chord.display != _sounding;
    _held = isNew ? 0 : _held + 1;
    _sounding = chord.display;

    final pattern = held
        ? <(double, double, double)>[(0, beats - 0.05, isNew ? 0.9 : 0.6)]
        : calypso
        ? _calypsoPattern(beats, beatInBar)
        : _pickPattern(beats, feel, swing, isNew: isNew);
    if (pattern.isEmpty) return const [];
    final notes = _pickVoicing(chord, next, reuse: !isNew);
    // A chord that's still ringing is touched more gently than a fresh one.
    final loud = (isNew ? 0.66 : 0.5) + random.nextDouble() * 0.26;
    _started = true;
    return [
      for (final (beat, length, velocity) in pattern)
        (
          beat: beat,
          length: length,
          velocity: (loud * velocity).clamp(0.3, 1.0),
          notes: notes,
        ),
    ];
  }

  /// Calypso strums across a whole bar, as (beat, length, velocity). The
  /// off-beats carry the accents; that's the lift.
  /// Strums across a bar, as (beat, length, velocity).
  ///
  /// All three are the 3-3-2 (1, the "and" of 2, 4) because that is what
  /// the bass and the kick are playing, and a guitar answering with a
  /// different syncopation is what made this groove sound like a pile-up.
  /// What varies is how much is added around it, not where the weight
  /// falls.
  static const _calypsoStrums = <(int, _Pattern)>[
    // The figure, held: the plainest way to play it.
    (4, [(0, 1.3, 0.85), (1.5, 1.3, 0.95), (3, 0.9, 0.8)]),
    // The same, with a short chop on 2 filling the first gap.
    (4, [(0, 0.35, 0.8), (1, 0.3, 0.55), (1.5, 0.8, 0.95), (3, 0.8, 0.85)]),
    // And with a push into the next bar off the last beat.
    (2, [(0, 0.35, 0.8), (1.5, 0.8, 0.95), (3, 0.35, 0.8), (3.5, 0.45, 0.7)]),
  ];

  /// The part of a bar's strum that falls in a chord [beats] long starting
  /// [beatInBar] into the bar, so two chords sharing a bar share one strum.
  _Pattern _calypsoPattern(int beats, double beatInBar) {
    if (beatInBar == 0 || _strum == null) {
      final weights = [for (final (w, _) in _calypsoStrums) w.toDouble()];
      var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
      var chosen = 0;
      for (; chosen < weights.length - 1; chosen++) {
        roll -= weights[chosen];
        if (roll <= 0) break;
      }
      _strum = _calypsoStrums[chosen].$2;
    }
    final end = beatInBar + beats;
    return [
      for (final (beat, length, velocity) in _strum!)
        if (beat >= beatInBar && beat < end)
          (
            beat - beatInBar,
            // Never ringing into the next chord.
            length.clamp(0.1, end - beat - 0.05),
            velocity * 0.85,
          ),
    ];
  }

  _Pattern? _strum;

  _Pattern _pickPattern(
    int beats,
    Feel feel,
    double swing, {
    required bool isNew,
  }) {
    // The swung "and" of a beat lands late; in straight feels it's halfway,
    // and how late is the band's business rather than this one's.
    final and = feel == Feel.swing ? swing : 0.5;
    // A push lands on the "and" of the beat *before* the chord, so it's
    // early by what's left of that beat, not by the "and" itself. In swing
    // that's a third of a beat; pushing by two thirds put the chord on a
    // triplet partial nobody plays, a third of a beat ahead of the bass.
    final push = and - 1;
    // A push starts before the chord does, so it can't open the tune.
    final canPush = _started;
    // Holding the same chord for a third bar or more: lean towards silence.
    final quiet = _held >= 2;

    final patterns = <(String, int, _Pattern)>[
      if (beats >= 4) ...[
        if (isNew) ...[
          // The figures themselves live in music/comping.dart, where the
          // screen that teaches them reads the same list, so what is
          // taught and what is played cannot drift apart.
          for (final (figure, weight) in bandFigures(canPush: canPush))
            (figure.name, weight, figure.strikes(and)),
        ] else ...[
          // Still the same chord: mostly leave it alone.
          ('rest', quiet ? 8 : 5, const []),
          ('remind', 4, [(1 + and, 1.1, 0.75)]),
          ('lift', 3, [(3 + and, 0.9, 0.8)]),
          ('echo', 2, [(1 + and, 0.7, 0.75), (3, 0.6, 0.65)]),
          ('again', quiet ? 1 : 2, [(0, 1.2, 0.7)]),
        ],
      ] else if (beats >= 2) ...[
        if (isNew) ...[
          ('half', 6, [(0, 0.6, 1)]),
          ('half held', 3, [(0, 1.6, 0.9)]),
          ('half off', 2, [(and, 0.9, 0.9)]),
          if (canPush) ('half push', 3, [(push, 1.4, 1)]),
        ] else ...[
          ('rest', 6, const []),
          ('half remind', 2, [(and, 0.8, 0.7)]),
        ],
      ] else ...[
        if (isNew) ('short', 5, [(0, 0.8, 0.95)]),
        ('rest', isNew ? 1 : 6, const []),
      ],
    ];

    // Weighted pick, with last time's rhythm made less likely so the same
    // figure doesn't repeat back to back.
    final weights = [
      for (final (name, weight, _) in patterns)
        (name == _lastPattern ? weight * 0.3 : weight.toDouble()),
    ];
    var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    var chosen = 0;
    for (; chosen < patterns.length - 1; chosen++) {
      roll -= weights[chosen];
      if (roll <= 0) break;
    }
    _lastPattern = patterns[chosen].$1;
    return patterns[chosen].$3;
  }

  /// Picks a voicing: the same one again while the chord hasn't changed,
  /// otherwise the shape that moves least from the chord before.
  /// The voicing for [chord] (leading to [next]) without playing it: the
  /// one still sounding if the chord hasn't changed, otherwise the nearest
  /// new shape. For a player with their own rhythms who wants the voicing.
  List<int> voice(Chord chord, Chord? next) {
    final isNew = chord.display != _sounding;
    _sounding = chord.display;
    return _pickVoicing(chord, next, reuse: !isNew);
  }

  List<int> _pickVoicing(Chord chord, Chord? next, {required bool reuse}) {
    final previous = previousVoicing;
    if (reuse && previous != null) return previous;

    final List<List<int>> shapes;
    final ownShapes = this.shapes?.call(chord, resolvingTo: next);
    if (ownShapes != null && ownShapes.isNotEmpty) {
      shapes = ownShapes;
    } else {
      final forms = voicingsFor(chord, resolvingTo: next);
      shapes =
          <List<int>>[
                for (final form in forms)
                  for (final octave in [-12, 0, 12])
                    [for (final n in form) n + octave],
              ]
              .where(
                (shape) =>
                    shape.first >= compLowest && shape.last <= compHighest,
              )
              .toList();
      if (shapes.isEmpty) shapes.add(forms.first);
    }

    var best = shapes.first;
    var bestScore = double.infinity;
    for (final shape in shapes) {
      // How far the hand has to move: compare each note with the nearest
      // note of the previous voicing, and keep the top note in a sensible
      // register when there's nothing to compare with.
      // Keep the hand near its home register: without this, a sequence
      // falling in fifths (as half of jazz does) walks the comping down
      // into the bass's register and stays there.
      var score = _crowding(shape) + 0.5 * (shape.first - home).abs();
      if (previous == null) {
        score += (shape.first - home).abs();
      } else {
        for (final note in shape) {
          var nearest = 99;
          for (final old in previous) {
            nearest = math.min(nearest, (note - old).abs());
          }
          score += nearest;
        }
        // Just enough randomness to break ties between equal shapes.
        score += random.nextDouble() * 0.6;
      }
      if (score < bestScore) {
        bestScore = score;
        best = shape;
      }
    }
    previousVoicing = best;
    return best;
  }
}

/// How muddy a shape is. Three notes packed inside four semitones is a
/// cluster; down low it's mud. Used to steer away from shapes like
/// C–E–F♯–G♯ on a D7♯11 in favour of the open F♯–G♯–C–E.
double _crowding(List<int> shape) {
  var penalty = 0.0;
  for (var i = 0; i + 2 < shape.length; i++) {
    final span = shape[i + 2] - shape[i];
    if (span <= 4) penalty += 5 - span;
  }
  return penalty;
}
