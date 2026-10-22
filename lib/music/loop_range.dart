import 'dart:math' as math;

import 'tune.dart';

/// The stretch of a tune being looped, measured in beats.
///
/// Measuring in beats (not bars) is what lets us loop a single chord inside
/// a bar, e.g. just the Cm7 in "| Cm7 F7 |".
class LoopRange {
  const LoopRange({required this.startBeat, required this.lengthBeats});

  /// Loops from bar [a] to bar [b] inclusive (0-based, in either order).
  factory LoopRange.bars(Tune tune, int a, int b) {
    final first = math.min(a, b);
    final last = math.max(a, b);
    return LoopRange(
      startBeat: tune.barStartBeat(first),
      lengthBeats: (last - first + 1) * tune.beatsPerBar,
    );
  }

  /// Loops a single chord.
  factory LoopRange.slot(ChordSlot slot) =>
      LoopRange(startBeat: slot.startBeat, lengthBeats: slot.beats);

  factory LoopRange.wholeTune(Tune tune) =>
      LoopRange.bars(tune, 0, tune.barCount - 1);

  final int startBeat;
  final int lengthBeats;

  int get endBeat => startBeat + lengthBeats;

  int firstBar(Tune tune) => startBeat ~/ tune.beatsPerBar;
  int lastBar(Tune tune) => (endBeat - 1) ~/ tune.beatsPerBar;

  bool isWholeTune(Tune tune) => this == LoopRange.wholeTune(tune);

  /// True when the loop is a whole number of bars (not a single chord).
  bool isBarAligned(Tune tune) =>
      startBeat % tune.beatsPerBar == 0 && lengthBeats % tune.beatsPerBar == 0;

  bool overlapsBar(Tune tune, int barIndex) {
    final barStart = tune.barStartBeat(barIndex);
    return barStart < endBeat && barStart + tune.beatsPerBar > startBeat;
  }

  bool containsSlot(ChordSlot slot) =>
      slot.startBeat < endBeat && slot.endBeat > startBeat;

  /// Grows the loop (in whole bars) so it also covers [barIndex].
  LoopRange extendedToBar(Tune tune, int barIndex) => LoopRange.bars(
    tune,
    math.min(firstBar(tune), barIndex),
    math.max(lastBar(tune), barIndex),
  );

  /// The chords inside the loop, in order.
  List<ChordSlot> slotsIn(Tune tune) => tune.slots.where(containsSlot).toList();

  /// A short human description, e.g. "Bars 7–8" or "Bar 4: Cm7 only".
  String describe(Tune tune) {
    if (isWholeTune(tune)) return 'Whole tune';
    final first = firstBar(tune) + 1;
    final last = lastBar(tune) + 1;
    if (!isBarAligned(tune)) {
      final chords = slotsIn(tune).map((s) => s.chord.display).join(' ');
      return 'Bar $first: $chords only';
    }
    return first == last ? 'Bar $first' : 'Bars $first–$last';
  }

  @override
  bool operator ==(Object other) =>
      other is LoopRange &&
      other.startBeat == startBeat &&
      other.lengthBeats == lengthBeats;

  @override
  int get hashCode => Object.hash(startBeat, lengthBeats);
}

/// Where a tune's intro is, if it has one: the bars from the top up to
/// the next section, when the first section is marked Intro. iReal Pro
/// plays those once and goes round the rest (see BackingRequest.intro).
/// Null when the tune does not open with an intro, or is nothing else.
LoopRange? introOf(Tune tune) {
  if (tune.sections[0] != 'Intro') return null;
  final next = tune.sections.keys
      .where((bar) => bar > 0)
      .fold<int?>(
        null,
        (first, bar) => first == null || bar < first ? bar : first,
      );
  if (next == null || next >= tune.barCount) return null;
  return LoopRange.bars(tune, 0, next - 1);
}

/// Where a count that has run past the end of [tune] has got to, in
/// beats: past the end it goes round again, from the top, or from just
/// after the intro where there is one, because the intro is played once
/// (see [introOf]). Before the start it goes round backwards, through the
/// whole tune.
int wrapBeat(Tune tune, int beat, {LoopRange? intro}) {
  final n = tune.totalBeats;
  if (beat >= 0 && beat < n) return beat;
  final introBeats = intro?.lengthBeats ?? 0;
  if (beat >= n && introBeats > 0 && introBeats < n) {
    return introBeats + (beat - introBeats) % (n - introBeats);
  }
  return (beat % n + n) % n;
}

/// The same, in bars.
int wrapBar(Tune tune, int bar, {LoopRange? intro}) {
  final n = tune.barCount;
  if (bar >= 0 && bar < n) return bar;
  final introBars = intro == null ? 0 : intro.lengthBeats ~/ tune.beatsPerBar;
  if (bar >= n && introBars > 0 && introBars < n) {
    return introBars + (bar - introBars) % (n - introBars);
  }
  return (bar % n + n) % n;
}
