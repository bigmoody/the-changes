// Arpeggios: each chord played as a broken chord, so you hear exactly which
// notes it's made of as the changes go by.
//
// Up through the chord to the octave and back (1 3 5 7 8 7 5 3 over a
// four-beat chord of eighths, 1 3 5 7 over two, 1 3 over one), starting on
// the root or, to practise inversions, on the 3rd, 5th or 7th. How fast
// they go by is chosen: see [ArpeggioRate].
// The chord in its plain form (a 7th chord, a 6th, a triad), not its
// extensions: this is for learning the shape of the changes. Each arpeggio
// starts on the note nearest the last one's start, so the line stays in one
// place on the keyboard instead of leaping about.

import '../music/chord.dart';
import '../music/enclosures.dart' show scaleFor;
import '../music/swing.dart';

typedef ArpeggioNote = ({
  int pitch,
  double beat,
  double length,
  double velocity,
});

/// Which chord tone each arpeggio starts on: the root, or an inversion.
enum ArpeggioStart {
  root('Root', 'From the root'),
  third('3rd', 'From the 3rd'),
  fifth('5th', 'From the 5th'),
  // A 6th chord has no 7th: its 6th takes the 7th's place.
  seventh('7th/6th', 'From the 7th (6th on a 6 chord)');

  const ArpeggioStart(this.short, this.label);
  final String short;
  final String label;
}

/// Where [chord]'s arpeggio starts when starting [from] that tone: the note
/// and which degree of the chord it is. "A", "6th" on C6 from the 7th.
({String note, String degree}) arpeggioStartOf(
  Chord chord,
  ArpeggioStart from,
) {
  final plain = chord.withoutExtensions;
  final formula = plain.quality.formula;
  final names = plain.noteNames;
  // In order up the octave, as the arpeggio climbs.
  final order = [for (var i = 0; i < formula.length; i++) i]
    ..sort(
      (a, b) => (degreeToSemitones(formula[a]) % 12).compareTo(
        degreeToSemitones(formula[b]) % 12,
      ),
    );
  final index = order[from.index % order.length];
  return (note: names[index], degree: _degreeName(formula[index]));
}

String _degreeName(String degree) => switch (degree) {
  '1' => 'root',
  '3' => '3rd',
  'b3' => '♭3rd',
  '4' => '4th',
  '5' => '5th',
  'b5' => '♭5th',
  '#5' => '♯5th',
  '6' => '6th',
  '7' => '7th',
  'b7' => '♭7th',
  'bb7' => '𝄫7th',
  _ => degree,
};

/// Where the arpeggios sit: first notes from G3 to G4, around middle C,
/// How fast the notes go by.
///
/// Eighths is what this was for a long time and is still the default: it
/// is the rate a line is actually played at. The others are there because
/// the exercise is not the same exercise at each of them. Quarters give
/// you time to see the next chord coming, which is the point when the
/// changes are new. Sixteenths leave none, which is the point when they
/// are not.
enum ArpeggioRate {
  quarters('Quarters', 1),
  eighths('Eighths', 2),
  triplets('Triplets', 3),
  sixteenths('Sixteenths', 4);

  const ArpeggioRate(this.label, this.perBeat);

  final String label;

  /// Notes to a beat.
  final int perBeat;

  /// Whether the off-beats lean with the swing.
  ///
  /// Quarters have no off-beats to lean. Triplets are already the
  /// subdivision a swung eighth is leaning *towards*, so leaning them as
  /// well would be swinging a swing.
  bool get swings => this == eighths || this == sixteenths;

  /// Whether it is the sixteenths that lean rather than the eighths, which
  /// is what [swungBeat] means by the word.
  bool get leansSixteenths => this == sixteenths;
}

/// How far up the chord to go.
enum ArpeggioReach {
  /// The chord in its plain form: 1 3 5 7, and the octave on top. What
  /// this was for a long time, and what you learn the shape of a chart
  /// from, because every note of it is unarguably the chord.
  plain('Plain'),

  /// Up to the 9th, which is the extension nearly every chord will take
  /// and the one a player reaches for first.
  ninth('9th'),

  /// Up to the 13th: 1 3 5 7 9 11 13, as the chord's own scale spells
  /// them. Seven rungs, so the climb takes a bar of eighths on its own
  /// and the way back down takes the next one.
  thirteenth('13th');

  const ArpeggioReach(this.label);

  final String label;
}

/// The rungs of [chord]'s arpeggio, in semitones above its root.
///
/// The extensions are the 9th, 11th and 13th of the chord's own scale,
/// which is what gets the alterations right without a table: a ♭9 where
/// the scale has one, a ♯11 where the chord is Lydian, a ♭13 on an
/// altered dominant.
///
/// The 11th is left out where it would clash. A natural 11th is a
/// semitone above a major 3rd, which is the avoid note of the whole
/// system: on a major or a dominant chord it is either raised to a ♯11 or
/// it is not played, and a scale that has a ♯11 in it hands one over here
/// already. On a minor chord there is no major 3rd to clash with and the
/// 11th is one of the better sounds in the music, so it stays.
List<int> arpeggioRungsOf(Chord chord, ArpeggioReach reach) {
  final plain = chord.withoutExtensions;
  final basic = <int>{
    for (final interval in plain.quality.intervals) interval % 12,
  }.toList()..sort();
  if (reach == ArpeggioReach.plain) return basic;

  final spelled = scaleFor(chord);
  final scale = <int>{
    for (final note in spelled)
      if (parseNoteName(note) case final s?)
        (pitchClassOf(s) - chord.root) % 12,
  }.toList()..sort();
  if (scale.length < 7) {
    // A chord the book has no mode for: take whatever extensions it is
    // written with and nothing invented. Still only as far as asked,
    // since a C13 arpeggiated to the 9th should stop at the 9th.
    final ceiling = reach == ArpeggioReach.ninth ? 15 : 21;
    return [
      ...basic,
      for (final interval in chord.quality.intervals)
        if (interval > 11 && interval <= ceiling) interval,
    ]..sort();
  }

  final hasMajorThird = chord.quality.intervals.any((i) => i % 12 == 4);
  final eleventh = scale[3];
  return [
    ...basic,
    scale[1] + 12,
    if (reach == ArpeggioReach.thirteenth) ...[
      // The avoid note, and only it: a ♯11 is scale[3] too and is fine.
      if (!(hasMajorThird && eleventh == 5)) eleventh + 12,
      scale[5] + 12,
    ],
  ];
}

/// above the bass, in the middle of the piano.
const arpeggioLowestStart = 55;
const arpeggioHighestStart = 67;

/// The arpeggio line over [chords] (each with how many beats it lasts), for
/// [choruses] passes, and the note it last started from (for the next
/// stretch to carry on from). [swing] is where the off-beat eighth falls
/// inside the beat: a half is even, and anything more is swung.
///
/// Each chord goes up four chord tones from [from] (the root, 3rd, 5th or
/// 7th) to that note an octave higher, then back down. On a triad the "7th"
/// is the root an octave up; on a 6th chord it's the 6th.
({List<ArpeggioNote> notes, int lastStart}) arpeggioLine(
  List<(Chord, int)> chords, {
  required int choruses,
  required double swing,
  ArpeggioStart from = ArpeggioStart.root,
  ArpeggioRate rate = ArpeggioRate.eighths,
  ArpeggioReach reach = ArpeggioReach.plain,
  int? startNote,
}) {
  final notes = <ArpeggioNote>[];
  var previousStart = startNote ?? 60;
  var start = 0;
  for (var chorus = 0; chorus < choruses; chorus++) {
    for (final (chord, beats) in chords) {
      final rungs = arpeggioRungsOf(chord, reach);
      // Inversions are of the chord and not of its extensions: starting
      // an arpeggio on the 11th is not an inversion of anything.
      final basic = chord.withoutExtensions.quality.intervals.length;
      final degree = from.index % (basic < rungs.length ? basic : rungs.length);

      // The starting note nearest the last one, kept in range.
      final startClass = (chord.root + rungs[degree]) % 12;
      var first = previousStart + ((startClass - previousStart + 6) % 12) - 6;
      while (first < arpeggioLowestStart) {
        first += 12;
      }
      while (first > arpeggioHighestStart) {
        first -= 12;
      }
      previousStart = first;

      // Up through the chord from there: the rungs above the one it
      // started on, then the ones below it an octave higher. Plain, the
      // climb is closed off with the starting note an octave up, which is
      // the shape everybody practises. With extensions the top rung is
      // already above that octave, so there is nothing to close.
      final up = [
        for (var i = degree; i < rungs.length; i++)
          first + rungs[i] - rungs[degree],
        for (var i = 0; i < degree; i++) first + rungs[i] + 12 - rungs[degree],
        if (reach == ArpeggioReach.plain) first + 12,
      ];
      // Then back down (without repeating the top).
      final cycle = [...up, ...up.reversed.skip(1).take(up.length - 2)];

      // Where a note lands: straight, then leaned if the rate has
      // off-beats to lean. Through swungBeat rather than by adding the
      // swing here, so a leaning arpeggio leans the way everything else
      // in the band does.
      double at(int step) {
        final straight = step / rate.perBeat;
        return rate.swings
            ? swungBeat(straight, swing, sixteenths: rate.leansSixteenths)
            : straight;
      }

      for (var step = 0; step < beats * rate.perBeat; step++) {
        final onBeat = step % rate.perBeat == 0;
        final beat = at(step);
        notes.add((
          pitch: cycle[step % cycle.length],
          beat: start + beat,
          // Up to the next note, whatever the rate and wherever the lean
          // has put it, so a leaning pair is still long-then-short.
          length: (at(step + 1) - beat) * 0.95,
          // The first note of each chord a little louder.
          velocity: step == 0 ? 0.72 : (onBeat ? 0.6 : 0.5),
        ));
      }
      start += beats;
    }
  }
  return (notes: notes, lastStart: previousStart);
}
