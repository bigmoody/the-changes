// Arpeggios: each chord played as a broken chord, so you hear exactly which
// notes it's made of as the changes go by.
//
// Eighth notes, up through the chord to the octave and back (1 3 5 7 8 7
// 5 3 over a four-beat chord, 1 3 5 7 over two, 1 3 over one), starting on
// the root or, to practise inversions, on the 3rd, 5th or 7th.
// The chord in its plain form (a 7th chord, a 6th, a triad), not its
// extensions: this is for learning the shape of the changes. Each arpeggio
// starts on the note nearest the last one's start, so the line stays in one
// place on the keyboard instead of leaping about.

import '../music/chord.dart';

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
  int? startNote,
}) {
  final notes = <ArpeggioNote>[];
  var previousStart = startNote ?? 60;
  var start = 0;
  for (var chorus = 0; chorus < choruses; chorus++) {
    for (final (chord, beats) in chords) {
      final plain = chord.withoutExtensions;
      final intervals = <int>{
        for (final interval in plain.quality.intervals) interval % 12,
      }.toList()..sort();
      final degree = from.index % intervals.length;

      // The starting note nearest the last one, kept in range.
      final startClass = (plain.root + intervals[degree]) % 12;
      var first = previousStart + ((startClass - previousStart + 6) % 12) - 6;
      while (first < arpeggioLowestStart) {
        first += 12;
      }
      while (first > arpeggioHighestStart) {
        first -= 12;
      }
      previousStart = first;

      // Up through the chord from there, to the same note an octave up.
      final up = [
        for (var i = 0; i < intervals.length; i++)
          first +
              intervals[(degree + i) % intervals.length] +
              (degree + i >= intervals.length ? 12 : 0) -
              intervals[degree],
        first + 12,
      ];
      // Then back down (without repeating the top).
      final cycle = [...up, ...up.reversed.skip(1).take(up.length - 2)];

      for (var eighth = 0; eighth < beats * 2; eighth++) {
        final onBeat = eighth.isEven;
        final beat = eighth ~/ 2 + (onBeat ? 0.0 : swing);
        notes.add((
          pitch: cycle[eighth % cycle.length],
          beat: start + beat,
          length: onBeat ? swing * 0.95 : (1 - swing) * 0.95,
          // The first note of each chord a little louder.
          velocity: eighth == 0 ? 0.72 : (onBeat ? 0.6 : 0.5),
        ));
      }
      start += beats;
    }
  }
  return (notes: notes, lastStart: previousStart);
}
