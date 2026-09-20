// Pitch: note names and frequencies, and how far a heard pitch is from a
// note.

import 'dart:math' as math;

/// Concert A.
const concertA = 440.0;

double midiToHz(num midi) => concertA * math.pow(2, (midi - 69) / 12);

double hzToMidi(double hz) => 69 + 12 * math.log(hz / concertA) / math.ln2;

const _sharpNames = [
  'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B', //
];
const _flatNames = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
];

/// A note's name, with both spellings for the black keys: "C♯/D♭".
String pitchClassName(int pitchClass, {String separator = '/'}) {
  final sharp = _sharpNames[pitchClass % 12];
  final flat = _flatNames[pitchClass % 12];
  return sharp == flat ? sharp : '$sharp$separator$flat';
}

/// A heard pitch described as a note: which note it's nearest, and how many
/// cents (hundredths of a semitone) sharp (+) or flat (−) of it.
typedef HeardNote = ({int midi, double cents});

/// [midi] may be fractional: 69.1 is A4, ten cents sharp.
HeardNote noteNear(double midi) {
  final nearest = midi.round();
  return (midi: nearest, cents: (midi - nearest) * 100);
}

/// How far [midi] is from the note [target] (a pitch class, 0 = C), in
/// cents, in whichever octave it's closest — a singer or a bass player
/// matching a note an octave away has still matched it.
double centsFromPitchClass(double midi, int target) {
  final difference = (midi - target) % 12; // 0 … 12
  final nearest = difference > 6 ? difference - 12 : difference;
  return nearest * 100;
}
