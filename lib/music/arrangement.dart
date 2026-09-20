// How the band plays the form, rather than looping the same chorus for ever:
// how many times round, which of those is the melody, and who lays out
// while you play.
//
// A performance is counted in choruses — one pass through whatever is
// looped. Chorus 0 is the first one after the count-in.

import 'dart:math' as math;

/// Getting a tune up to speed: the band plays a little faster every time
/// round the form, so you practise at the edge of what you can play rather
/// than at one comfortable tempo.
class TempoRamp {
  const TempoRamp({this.step = 0, this.climb});

  static const off = TempoRamp();

  /// Beats a minute added each time round the form. Zero is no ramp.
  final int step;

  /// How much faster it gets in all, before it settles there. Null keeps it
  /// climbing (until it runs out of tempo).
  final int? climb;

  bool get isOn => step != 0;

  /// The tempo on [chorus] (counting from nought), starting [from].
  int tempoAt(int chorus, int from) {
    if (step == 0) return from;
    final added = math.min(step * chorus, climb ?? step * chorus);
    return (from + added).clamp(40, 320);
  }

  /// How many times round the form before it stops getting faster — so the
  /// band knows how long the changing part of the performance is.
  int chorusesToTop(int from) {
    if (step == 0) return 0;
    final top = climb == null ? 320 : math.min(from + climb!, 320);
    return ((top - from) / step).ceil().clamp(0, 200);
  }

  /// "+5 a chorus, up to 40 faster".
  String describe() {
    if (!isOn) return '';
    return climb == null
        ? '+$step a chorus'
        : '+$step a chorus, up to $climb faster';
  }

  @override
  bool operator ==(Object other) =>
      other is TempoRamp && other.step == step && other.climb == climb;

  @override
  int get hashCode => Object.hash(step, climb);
}

/// How many bars the band and the drummer swap while trading.
enum Trading {
  off('Off', 0),
  eights('Eights', 8),
  fours('Fours', 4),
  twos('Twos', 2);

  const Trading(this.label, this.bars);

  final String label;

  /// How many bars each takes in turn. Zero when nobody's trading.
  final int bars;
}

/// A part that can drop out and leave it to you.
enum LayOut {
  chords('Chords'),
  bass('Bass');

  const LayOut(this.label);

  final String label;
}

/// What the band does on one pass through the form.
typedef ChorusPlan = ({
  /// The melody: played by the whole band, whatever the solo choruses do.
  bool head,

  /// In two rather than walking.
  bool twoFeel,
  Trading trading,
  Set<LayOut> layOut,
});

class Arrangement {
  const Arrangement({
    this.choruses,
    this.headInAndOut = false,
    this.twoFeelOnHead = false,
    this.trading = Trading.off,
    this.layOut = const {},
    this.ramp = TempoRamp.off,
  });

  /// The plain loop: round and round until you stop it.
  static const keepGoing = Arrangement();

  /// How many times round the form, or null to keep going.
  final int? choruses;

  /// The first and last chorus are the melody, with solos in between.
  final bool headInAndOut;

  /// The head in two, the solos walking — how a band usually breathes.
  final bool twoFeelOnHead;

  /// Swapping bars with the drummer on the solo choruses.
  final Trading trading;

  /// Who lays out on the solo choruses, leaving their part to you.
  final Set<LayOut> layOut;

  /// Getting the tune up to speed a chorus at a time.
  final TempoRamp ramp;

  /// True when every chorus is the same, so the band can be written in one
  /// go rather than a chorus at a time.
  bool get isPlain =>
      !headInAndOut &&
      !twoFeelOnHead &&
      trading == Trading.off &&
      layOut.isEmpty &&
      !ramp.isOn;

  /// Whether [chorus] is a head. Without a count there's no last chorus to
  /// come back to, so only the first one is.
  bool isHead(int chorus) {
    if (!headInAndOut) return false;
    if (chorus == 0) return true;
    final total = choruses;
    return total != null && total >= 2 && chorus == total - 1;
  }

  ChorusPlan planFor(int chorus) {
    final head = isHead(chorus);
    return (
      head: head,
      twoFeel: head && twoFeelOnHead,
      // The melody is played straight through, by everyone.
      trading: head ? Trading.off : trading,
      layOut: head ? const <LayOut>{} : layOut,
    );
  }

  /// Whether the drummer has [bar] to themselves. [bar] counts from the
  /// start of the chorus.
  bool drummerHas(int chorus, int bar) {
    final swapping = planFor(chorus).trading;
    if (swapping == Trading.off) return false;
    return (bar ~/ swapping.bars).isOdd;
  }

  /// Whether [part] sounds in this bar: it hasn't laid out for the chorus,
  /// and the bar isn't the drummer's.
  bool plays(LayOut part, int chorus, int bar) =>
      !planFor(chorus).layOut.contains(part) && !drummerHas(chorus, bar);

  /// One line for the button: "Keep going", "4 choruses, head in and out".
  String describe() {
    final parts = <String>[
      if (choruses == null)
        'Keep going'
      else if (choruses == 1)
        '1 chorus'
      else
        '$choruses choruses',
      if (headInAndOut) 'head in and out',
      if (twoFeelOnHead) 'two-feel on the head',
      if (trading != Trading.off) 'trading ${trading.label.toLowerCase()}',
      if (ramp.isOn) ramp.describe(),
      for (final part in LayOut.values)
        if (layOut.contains(part)) 'no ${part.label.toLowerCase()}',
    ];
    return parts.join(', ');
  }

  Arrangement copyWith({
    int? choruses,
    bool keepGoing = false,
    bool? headInAndOut,
    bool? twoFeelOnHead,
    Trading? trading,
    Set<LayOut>? layOut,
    TempoRamp? ramp,
  }) => Arrangement(
    choruses: keepGoing ? null : (choruses ?? this.choruses),
    headInAndOut: headInAndOut ?? this.headInAndOut,
    twoFeelOnHead: twoFeelOnHead ?? this.twoFeelOnHead,
    trading: trading ?? this.trading,
    layOut: layOut ?? this.layOut,
    ramp: ramp ?? this.ramp,
  );

  @override
  bool operator ==(Object other) =>
      other is Arrangement &&
      other.choruses == choruses &&
      other.headInAndOut == headInAndOut &&
      other.twoFeelOnHead == twoFeelOnHead &&
      other.trading == trading &&
      other.layOut.length == layOut.length &&
      other.layOut.containsAll(layOut) &&
      other.ramp == ramp;

  @override
  int get hashCode => Object.hash(
    choruses,
    headInAndOut,
    twoFeelOnHead,
    trading,
    Object.hashAllUnordered(layOut),
    ramp,
  );
}
