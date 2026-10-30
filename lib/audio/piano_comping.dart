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
import '../music/meter.dart';
import '../music/swing.dart';
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
  Comper(
    this.random, {
    this.shapes,
    this.home = compHome,
    this.quartal = false,
    this.slide = QuartalSlide.down,
  });

  final math.Random random;
  final List<List<int>> Function(Chord chord, {Chord? resolvingTo})? shapes;
  final int home;

  /// Voice the minor sevenths in fourths: the sound of a modal tune, and
  /// the reason So What is the name of a chord as well as of a tune.
  final bool quartal;

  /// Which way the quartal figure moves. Down onto the chord closes the
  /// phrase, up off it leaves it open, and the two sound like two
  /// different tunes on the same form, which is what they are.
  final QuartalSlide slide;

  /// The voicing last played, which the next one moves smoothly from. Set it
  /// to carry a hand position over from an earlier stretch of playing.
  List<int>? previousVoicing;

  /// The chord last comped, to tell a new chord from one still sounding.
  String? _sounding;

  /// How many slots the current chord has been held for.
  int _held = 0;
  bool _started = false;
  String? _lastPattern;

  /// The beat the last figure arrived on, so the next one can arrive
  /// somewhere else.
  double? _lastEntry;

  /// The slide, as the tune plays it: the shape above on the third beat of
  /// the second bar of a pair, falling to the shape on the chord half a
  /// beat before the bar ends.
  ///
  /// A beat apart was too quick and two and a half was too long. What the
  /// gap is for is the suspension, and where it wants to land is just
  /// before the bar line: the answer arrives on the "and" of the fourth
  /// and rings on over into the next bar.
  ///
  /// The off-beat rather than a literal half beat, so the figure leans
  /// with whatever the swing is set to. Everything else the piano plays
  /// off the beat does.
  ///
  /// The shape above never falls on a downbeat. It is the leaning half of
  /// the figure and a bar does not open on the lean.
  static _Pattern _slide(double and) => [
    // Held across the gap and let go as the landing arrives, not through
    // it: two five-note stacks a tone apart sounding together is ten
    // notes, and that is not a suspension resolving, it is a smudge.
    (2, 1.5, 0.8),
    // Rings on past the bar line, which is where a resolution wants to
    // go, and is why the bar after it does not play a figure of its own.
    (3 + and, 1.2, 0.9),
  ];

  /// Whether the last bar's slide resolves into this one.
  bool _resolving = false;

  /// The figures that are a slide, and so play two shapes rather than one.
  static const _slides = {'slide'};

  /// Comps one chord lasting [beats], starting at beat 0 of its own time.
  /// [next] is the chord it leads to, which decides whether a dominant is
  /// played plain or altered.
  ///
  /// With [held], each chord is simply struck and held for its whole length,
  /// re-struck gently on each new bar if it lasts that long.
  ///
  /// [startsSection] and [intoSection] are where the form is, and on a
  /// modal tune they are the only thing there is to play to. Sixteen bars
  /// of Dm7 gave the comper nothing to react to, so it reacted to nothing
  /// and poked at the same off-beat bar after bar. The top of a section is
  /// a place a pianist lands on even when the harmony has not moved, and
  /// the bar before one is a place they lead through.
  List<CompHit> comp(
    Chord chord,
    int beats,
    Feel feel, {
    Chord? next,
    bool held = false,
    bool calypso = false,
    bool pompe = false,
    double beatInBar = 0,
    CompFigure? figure,
    int beatsPerBar = 4,
    bool startsSection = false,
    bool intoSection = false,
    int bar = 0,
    required double swing,
  }) {
    // A section beginning counts as new even when the chord has not
    // changed. It is the one thing that makes a vamp playable: the second
    // A of So What is somewhere a pianist arrives rather than somewhere
    // they happen to still be.
    final isNew = chord.display != _sounding || (startsSection && _started);
    _held = isNew ? 0 : _held + 1;
    _sounding = chord.display;

    // The bar after a slide, either way up, plays nothing.
    //
    // After a fall the chord has already arrived, half a beat before the
    // bar line, and a figure on top of a resolution is two pianists.
    // After a lift the shape above is left hanging and is meant to stay
    // hanging: the chord coming in underneath it in the next bar is what
    // stopped there being a lift to hear at all.
    if (_resolving) {
      _resolving = false;
      // The chord it is sounding and how long it has been held are both
      // counted above, for this bar like any other: the bar is not a gap
      // in the tune, it is a bar whose chord came in early.
      return const [];
    }

    // The quartal slide, where the chord has one: the shape a tone above
    // falling onto the shape on the chord. Offered as a figure the comper
    // can choose, because that is what it is.
    //
    // Only in the second bar of a pair. The figure is a two-bar phrase, a
    // bar of the chord and then the answer, and the answer lands in the
    // bar after it: an Em11 on the third beat falls on the "and" of the
    // first beat of the next bar, which is that bar's Dm11 arriving. Put
    // in every bar it is not an answer to anything.
    //
    // Never in the bar before a section, where the turn figure leads in
    // and where a resolution landing just after the downbeat would take
    // the top of the section's own arrival away from it.
    //
    // The lift goes in the other bar of the pair: Impressions goes up to
    // the minor shape a tone above (E minor over D minor) on the "and" of
    // 4 of every odd-numbered bar, 1, 3, 5, which count from nought here
    // and so are even, and every time rather than most. The eighth bar of
    // a section is then the bar after a lift, so it never meets the turn.
    final lifts = slide == QuartalSlide.up;
    final pair =
        quartal &&
            slide != QuartalSlide.none &&
            (lifts ? bar.isEven : bar.isOdd && !intoSection)
        ? slideFor(chord)
        : null;
    // Up is the same two shapes in the other order: the chord first and
    // the one above it second, left ringing rather than resolved.
    final moving = pair == null
        ? null
        : switch (slide) {
            QuartalSlide.down => pair,
            QuartalSlide.up => (from: pair.to, to: pair.from),
            // Ruled out above: a tune with no figure never reaches here.
            QuartalSlide.none => null,
          };
    // Every lift bar lifts: not one figure weighed against a rest. A bar
    // where the chord arrives, the top of a section, keeps its downbeat
    // as well, so the section still lands before it opens.
    final and = feel.swingsSixteenths ? 0.5 : swing;
    final lift = lifts && moving != null && !held && beats >= beatsPerBar
        ? <(double, double, double)>[if (isNew) (0, 1.5, 0.9), ..._slide(and)]
        : null;
    if (lift != null) _lastPattern = 'slide';
    final pattern =
        lift ??
        (held
            ? <(double, double, double)>[(0, beats - 0.05, isNew ? 0.9 : 0.6)]
            : pompe
            ? _pompePattern(beats, beatInBar, beatsPerBar)
            : calypso
            ? _calypsoPattern(beats, beatInBar, beatsPerBar, swing)
            : _pickPattern(
                beats,
                feel,
                swing,
                isNew: isNew,
                figure: figure,
                beatInBar: beatInBar,
                beatsPerBar: beatsPerBar,
                intoSection: intoSection,
                canSlide: moving != null,
              ));
    if (pattern.isEmpty) return const [];

    // A slide is two chords and not one, so it is the one figure whose
    // notes are not the same for every hit: the first lands on the shape
    // above and the rest on the shape it falls to. The hand finishes on
    // the lower one, which is where the next chord moves from.
    if (moving != null && _slides.contains(_lastPattern)) {
      // The hand rests on the chord's own shape whichever way the figure
      // went. Sliding up leaves the shape above ringing, but it is still
      // not somewhere to sit: the next thing played is the chord.
      previousVoicing = quartalHomeFor(chord);
      _started = true;
      // Either way up, the bar after it belongs to the figure: a fall has
      // put the chord there already and a lift is still ringing into it.
      _resolving = true;
      final loud = (isNew ? 0.66 : 0.5) + random.nextDouble() * 0.26;
      return [
        for (final (index, (beat, length, velocity)) in pattern.indexed)
          (
            beat: beat,
            length: length,
            velocity: (loud * velocity).clamp(0.3, 1.0),
            // Down leans in from the shape above and falls; up sits on
            // the chord and lifts with the last strike.
            notes: (lifts ? index < pattern.length - 1 : index == 0)
                ? moving.from
                : moving.to,
          ),
      ];
    }

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
  /// La pompe, for whoever is holding the chords.
  ///
  /// It is a guitar part, and the guitarist plays it as strokes; a
  /// pianist handed a gypsy tune plays the same shape of bar, which is
  /// four short chords with 2 and 4 carrying. There are no grace notes
  /// here: an upstroke on the bass strings is a thing a pick does and
  /// not a thing a piano can do.
  ///
  /// The beats that carry are the ones that are not the front of a group:
  /// 2 and 4 in four, 2 and 3 in a waltz (the valse musette's pompe, the
  /// bass alone on 1), 2, 3 and 5 in five.
  _Pattern _pompePattern(int beats, double beatInBar, int beatsPerBar) {
    final fronts = beatsPerBar == 4
        ? const {0, 2}
        : groupStarts(beatsPerBar).toSet();
    return [
      for (var beat = 0.0; beat < beats; beat++)
        if (!fronts.contains(((beatInBar + beat) % beatsPerBar).round()))
          (beat, 0.3, 0.85)
        else
          (beat, 0.22, 0.62),
    ];
  }

  /// The strum for a bar of three, five or seven: in each group of three
  /// the 3+3 (1 and the "and" of 2, held), in each group of two the "2"
  /// of the 3-3-2, a chord on its front, chopped on its second beat now
  /// and then. The same points the bass and the kick are on.
  _Pattern _groupedStrum(int beatsPerBar) {
    final chop = random.nextDouble() < 0.4;
    return [
      for (final (g, length) in meterGroups(beatsPerBar).indexed)
        ...switch (length) {
          3 => [
            (groupStarts(beatsPerBar)[g] + 0.0, 1.3, 0.85),
            (groupStarts(beatsPerBar)[g] + 1.5, 1.3, 0.95),
          ],
          _ => [
            (groupStarts(beatsPerBar)[g] + 0.0, chop ? 0.35 : 0.9, 0.8),
            if (chop) (groupStarts(beatsPerBar)[g] + 1.0, 0.3, 0.55),
          ],
        },
    ];
  }

  _Pattern _calypsoPattern(
    int beats,
    double beatInBar,
    int beatsPerBar,
    double swing,
  ) {
    if (beatsPerBar != 4 && (beatInBar == 0 || _strum == null)) {
      _strum = _groupedStrum(beatsPerBar);
    } else if (beatInBar == 0 || _strum == null) {
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
      for (final (written, length, velocity) in _strum!)
        // The "and"s leaned with the band, so a strum in twelve eight
        // lands on the last triplet with the bell and not between.
        if (swungBeat(written, swing) case final beat
            when beat >= beatInBar && beat < end)
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
    CompFigure? figure,
    double beatInBar = 0,
    int beatsPerBar = 4,
    bool intoSection = false,
    bool canSlide = false,
  }) {
    // The swung "and" of a beat lands late; in straight feels it's halfway,
    // and how late is the band's business rather than this one's.
    // Taken as given rather than gated on the feel: an even groove
    // arrives with an even value, and a slider that has been moved
    // arrives moved, whatever the groove is called.
    final and = feel.swingsSixteenths ? 0.5 : swing;
    // A push lands on the "and" of the beat *before* the chord, so it's
    // early by what's left of that beat, not by the "and" itself. In swing
    // that's a third of a beat; pushing by two thirds put the chord on a
    // triplet partial nobody plays, a third of a beat ahead of the bass.
    final push = and - 1;
    // A push starts before the chord does, so it can't open the tune.
    final canPush = _started;
    // Holding the same chord for a third bar or more: lean towards silence.
    final quiet = _held >= 2;
    // And the longer it sits, the further towards silence. The old
    // weighting moved once, at the third bar, and then never again, so the
    // sixteenth bar of a vamp was as busy as the third and a modal tune
    // came out as one poked off-beat a bar for a page. Rising instead
    // gives each section an arc: a pianist states the chord, then gets out
    // of the way, and the top of the next section brings them back in.
    // Capped, because a vamp is sparse and not abandoned.
    final settled = math.min(_held, 5);

    // Somebody has asked for one figure and no other, so it is played in
    // every bar, new chord or not. That is not what a band does and is
    // not meant to be: it is how you hear what one figure does across a
    // whole chorus of real changes, which two bars of a ii-V on the Learn
    // screen cannot show you.
    if (figure != null && beats > 0) {
      _lastPattern = figure.name;
      return _figureAcross(
        figure,
        and,
        canPush: canPush,
        beats: beats,
        beatInBar: beatInBar,
        beatsPerBar: beatsPerBar,
        isNew: isNew,
      );
    }

    // Which set of figures: one for a chord that lasts a whole bar, one
    // for a chord that has half of it, one for anything shorter. It used
    // to be four beats and two beats flat, which is the same thing in
    // 4/4 and the wrong thing everywhere else: a chord filling a bar of
    // three was handed the half-bar figures, so a waltz was comped with
    // one chord at the front of every bar and nothing else.
    final wholeBar = beats >= beatsPerBar;
    final halfBar = beats * 2 >= beatsPerBar;
    // Where the figures that move with the bar land.
    final last = (beatsPerBar - 1).toDouble();
    // The second half of a bar of five or seven is its last group, not
    // its middle beat (see [meterGroups]).
    final half = beatsPerBar == 5 || beatsPerBar == 7
        ? groupStarts(beatsPerBar).last.toDouble()
        : (beatsPerBar ~/ 2).toDouble();

    /// Whether every strike of a figure falls inside the bar, so a
    /// short bar is never given a figure that hangs off the end of it.
    bool fits(_Pattern strikes) =>
        strikes.every((strike) => strike.$1 < beatsPerBar);

    final patterns = <(String, int, _Pattern)>[
      if (wholeBar) ...[
        if (isNew) ...[
          // The figures themselves live in music/comping.dart, where the
          // screen that teaches them reads the same list, so what is
          // taught and what is played cannot drift apart.
          for (final (figure, weight) in bandFigures(canPush: canPush))
            (
              figure.name,
              weight,
              figure.strikes(and, beatsPerBar: beatsPerBar),
            ),
        ] else if (intoSection) ...[
          // The bar before a new section: the one place in sixteen bars of
          // one chord where something is about to happen, so it is played
          // through rather than rested on however long the chord has sat.
          // Not without fail, because a turn figure on every eighth bar
          // exactly is a tell of its own.
          ('turn', 7, [(1 + and, 0.6, 0.8), (last, 1.1, 0.9)]),
          ('turn up', 5, [(half, 0.7, 0.75), (last + and, 0.9, 0.9)]),
          ('rest', 2, const []),
        ] else if (canSlide) ...[
          // The second bar of a pair, on a tune whose chord has a slide.
          // This is not one figure among several here: the pair of bars
          // exists to put the tune's own answer in the second of them, so
          // the answer is what goes there. Weighted against the full
          // palette it turned up once or twice a chorus and So What did
          // not sound like itself.
          //
          // A bar off now and then so that it breathes and so the figure
          // is still something that arrives.
          ('slide', 9, _slide(and)),
          ('rest', 1, const []),
        ] else ...[
          // Still the same chord: mostly leave it alone, and more so the
          // longer it has been sounding.
          ('rest', 5 + settled * 3, const []),
          // Five ways in rather than one. Every one of these used to begin
          // on the "and" of 2, so whichever was picked you heard a chord
          // in the same place, and a vamp ticked. The weighting that keeps
          // a figure from repeating compares names, and these had
          // different names and the same landing, so it never noticed.
          ('remind', _held.isOdd ? 2 : 4, [(1 + and, 1.1, 0.75)]),
          ('lift', 3, [(last + and, 0.9, 0.8)]),
          // In three, half way is the "and" of 2, where the reminder
          // already lands: the waltz's 2 and 3 instead.
          (
            'inside',
            3,
            beatsPerBar == 3
                ? [(1.0, 0.5, 0.7), (2.0, 0.7, 0.75)]
                : [(half + and, 1.0, 0.8)],
          ),
          ('on four', 2, [(last, 0.9, 0.75)]),
          ('echo', 3, [(1 + and, 0.7, 0.75), (last, 0.6, 0.65)]),
          ('answer', 3, [(half, 0.5, 0.7), (last + and, 0.9, 0.8)]),
          ('again', quiet ? 1 : 2, [(0, 1.2, 0.7)]),
          // Answering a chord that is simply still sounding is the figure's
          // own job on the record: Evans plays it into the gaps rather than
          // under the melody. Weighted to be heard without becoming the
          // only thing a vamp does.
        ],
      ] else if (halfBar) ...[
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

    // A bar of two pulses cannot hold a figure that lands on its third,
    // and half of a figure is not the figure: anything that does not
    // fit is left out rather than cut short.
    patterns.removeWhere((pattern) => !fits(pattern.$3));
    if (patterns.isEmpty) return const [];

    // Weighted pick, with last time's rhythm made less likely so the same
    // figure doesn't repeat back to back, and with anything that lands
    // where the last one landed made less likely too.
    //
    // The second half of that is what a vamp needs. What an ear picks out
    // over sixteen bars of one chord is where the chord keeps arriving,
    // not which entry in a table it came from, and several of these begin
    // on the same beat under different names.
    // The slide is exempt from both. They are there to stop a lone jab
    // becoming the only thing a vamp says, and a figure that is the tune
    // is meant to come round again: penalised for repeating and for
    // landing where it landed, a weight of nine against a rest of one
    // came out at 0.81 against 1 and the answer skipped half its bars.
    final weights = [
      for (final (name, weight, strikes) in patterns)
        if (_slides.contains(name))
          weight.toDouble()
        else
          weight *
              (name == _lastPattern ? 0.3 : 1.0) *
              (strikes.isNotEmpty && strikes.first.$1 == _lastEntry
                  ? 0.3
                  : 1.0),
    ];
    var roll = random.nextDouble() * weights.fold(0.0, (a, b) => a + b);
    var chosen = 0;
    for (; chosen < patterns.length - 1; chosen++) {
      roll -= weights[chosen];
      if (roll <= 0) break;
    }
    _lastPattern = patterns[chosen].$1;
    final strikes = patterns[chosen].$3;
    // A rest is not a landing, so it does not clear where the last one
    // was: the thing to avoid is two bars running that arrive in the same
    // place, whether or not there was a bar off between them.
    if (strikes.isNotEmpty) _lastEntry = strikes.first.$1;
    return strikes;
  }

  /// [figure] laid over the bars a chord covers, cut to that chord.
  ///
  /// A figure is a bar's worth of rhythm, and most tunes do not give a
  /// comper whole bars: rhythm changes is two chords a bar for forty-four
  /// of its fifty-four, and a blues in F is half and half. So the figure
  /// belongs to the bar, and each chord in it plays whichever of its
  /// strikes fall while that chord is the one sounding. A chord no strike
  /// lands on is not played at all, which is not an oversight: it is what
  /// the figure means. The Charleston is two chords at the front of the
  /// bar, so on a bar of two chords it catches the first and leaves the
  /// second alone, and hearing that is most of the point of asking for
  /// it.
  ///
  /// A chord lasting more than a bar gets the figure again in each bar it
  /// covers, rather than once at the front and silence after.
  ///
  /// A change that no strike lands on is played on its own beat anyway.
  /// The Charleston is two chords at the front of the bar, so on a bar of
  /// two chords it has nothing left for the second one, and a chorus of
  /// rhythm changes with every other chord missing stops being the tune.
  /// It is struck a little lighter than the figure's own chords, because
  /// it is a change being caught rather than an accent being chosen,
  /// which is what a comper does when a figure and the changes disagree.
  /// A chord that is only the one before it carrying on is left alone:
  /// there is nothing to catch.
  _Pattern _figureAcross(
    CompFigure figure,
    double and, {
    required bool canPush,
    required int beats,
    required double beatInBar,
    required int beatsPerBar,
    required bool isNew,
  }) {
    final strikes = strikesAt(
      figure,
      and,
      canPush: canPush,
      beatsPerBar: beatsPerBar,
    );
    final end = beatInBar + beats;
    final out = <CompStrike>[];
    for (var bar = 0; bar * beatsPerBar < end; bar++) {
      for (final (at, length, weight) in strikes) {
        final where = bar * beatsPerBar + at;
        // A push comes before its own bar, so at the very top of the bar
        // it belongs to the chord that starts there rather than to the
        // chord before, which may be a different one.
        if (bar == 0 && at < 0) {
          if (beatInBar != 0) continue;
        } else if (where < beatInBar || where >= end) {
          continue;
        }
        out.add((
          where - beatInBar,
          // Never ringing past the chord it belongs to.
          math.min(length, end - where),
          weight,
        ));
      }
    }
    if (out.isEmpty && isNew && strikes.isNotEmpty) {
      final (_, length, weight) = strikes.first;
      out.add((0, math.min(length, beats - 0.05), weight * 0.9));
    }
    return out;
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
      // On a modal tune the hand rests on the shape that sits on the
      // chord, and only there. The shape a tone above is half of a fall,
      // not a voicing to settle on: offered as one it became home and
      // stayed there, which is a suspension nobody ever resolves.
      final home = quartal ? quartalHomeFor(chord) : null;
      final forms = home == null
          ? voicingsFor(chord, resolvingTo: next)
          : [home];
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
