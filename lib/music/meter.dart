// What is written at the front of the chart, and what the band counts.
//
// For most of the tunes here they are the same thing: 4/4 is four beats
// in a bar and the band counts four. Compound time is where they part. A
// bar of 6/8 holds six eighth notes, but nobody counts six: it is felt
// in two, each of them three eighths long, and a tempo marking on a 6/8
// chart means those two. Count six and you have a fast 6/8; count two
// and you have the thing people actually play.
//
// So a meter carries both. [beats] and [unit] are what is written, and
// [pulses] is what the band counts, which is what the rest of the app
// has always called beatsPerBar: the clock, the loop, the bar numbers
// and the chart's cells are all built on the pulse and none of them has
// to know about any of this.
//
// What a compound pulse does change is the subdivision. A simple beat
// divides in two and swing leans the half; a compound one divides in
// three to begin with, which is the same place swing puts its "and".
// That is why a jazz band in 12/8 and a jazz band swinging in 4/4 are
// playing nearly the same thing, and why the band needs no new grooves
// to play in six: it needs its off-beats pinned to the triplet instead
// of following the tempo.

/// A time signature: what the chart says, and what the band counts.
class Meter {
  const Meter(this.beats, this.unit, {int? countedIn})
    // ignore: prefer_initializing_formals
    : _countedIn = countedIn;

  /// The common time: four beats in a bar.
  static const four = Meter(4, 4);

  /// What a tune can be written in, in the order they are offered.
  ///
  /// Short of everything a player might want (nothing here is in 9/8,
  /// and 2/4 comes in from iReal Pro rather than being offered), and
  /// each of these is a meter standards are actually played in: a waltz,
  /// Take Five, Unsquare Dance, a 6/8 vamp, a slow blues in 12/8.
  static const choices = [
    four,
    Meter(3, 4),
    Meter(5, 4),
    Meter(7, 4),
    Meter(6, 8),
    // The same bar, counted the other way. Six eight is felt in two at
    // most tempos and counted in six at slow ones, and which of those a
    // player wants is not something the app can know: a bar of six
    // eighths at a walking pulse is a different piece of music from two
    // dotted quarters at a bright one. Both are offered and the chart
    // says the same thing at the front either way.
    Meter(6, 8, countedIn: 6),
    Meter(12, 8),
  ];

  /// How many of them are written in a bar: the 6 of 6/8.
  final int beats;

  /// What one of them is: 4 for a quarter note, 8 for an eighth.
  final int unit;

  /// How many beats the band counts in the bar, where that is not what
  /// the usual reading of the meter would give.
  final int? _countedIn;

  /// Whether the beat divides in three rather than in two.
  ///
  /// 6/8 and 12/8 do; 3/8 would not, being three eighths counted as
  /// three. The rule is the usual one: eighths grouped in threes.
  bool get compound => unit == 8 && beats % 3 == 0 && pulses != beats;

  /// What the band counts in a bar, and what the player taps their foot
  /// on: two in 6/8, four in 12/8, the written beats everywhere else,
  /// and whatever was asked for where a meter says.
  int get pulses =>
      _countedIn ?? (unit == 8 && beats % 3 == 0 ? beats ~/ 3 : beats);

  /// How many of the written notes are in one pulse: three in compound
  /// time, one otherwise.
  int get perPulse => compound ? 3 : 1;

  /// "4/4", "6/8", "6/8 in six" …
  String get label => pulses == beats && unit == 8
      ? '$beats/$unit (in $beats)'
      : '$beats/$unit';

  /// What is written at the front of the chart, which is the same for a
  /// bar counted either way: six eight is six eight.
  String get written => '$beats/$unit';

  /// The meter a tune counting [pulses] to the bar is written in, for
  /// anything saved before meters were written down: every one of them
  /// was in quarter notes.
  static Meter ofPulses(int pulses) => Meter(pulses, 4);

  /// A meter read back, written as the chart writes it and with how it
  /// is counted after it where that is not the usual reading. Null if it
  /// is not one we play.
  static Meter? parse(String text) {
    final match = RegExp(r'^(\d+)/(\d+)(?:\s*\(in\s*(\d+)\))?$')
        .firstMatch(text.trim());
    if (match == null) return null;
    final counted = match[3] == null ? null : int.parse(match[3]!);
    final meter = Meter(
      int.parse(match[1]!),
      int.parse(match[2]!),
      countedIn: counted,
    );
    return meter.playable && (counted == null || counted == meter.beats)
        ? meter
        : null;
  }

  /// Whether the band can play it: a bar has to have beats in it, and
  /// the app counts in quarters or in groups of three eighths.
  bool get playable =>
      beats > 0 &&
      beats <= 12 &&
      pulses > 0 &&
      (unit == 4 || (unit == 8 && beats % 3 == 0));

  @override
  bool operator ==(Object other) =>
      other is Meter &&
      other.beats == beats &&
      other.unit == unit &&
      other.pulses == pulses;

  @override
  int get hashCode => Object.hash(beats, unit, pulses);

  @override
  String toString() => label;
}
