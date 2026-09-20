// Arpeggios on the guitar and bass: every note of a chord, in one position,
// the way players learn them.
//
// A shape starts on the root on the lowest string or the next one up (the
// guitar's 6th or 5th, the bass's E or A) and climbs across the
// strings through each chord tone in turn, without moving the hand: every
// note under one finger per fret, four frets — or five, with a reach, when
// that's the only way to get further. Of the positions around the root, the
// one that goes furthest towards two octaves without skipping a chord tone
// wins — then the one with no reach, then the root under the 2nd finger, as
// in the standard shapes (CΔ7 from the 8th fret: C E G B C E G B C across
// frets 7–10).
//
// Where the G and B strings give the same note twice, the B string's is
// used: it's the lower fret, so no stretch.

import 'chord.dart';

/// The guitar's open strings, low E to high E, as MIDI notes (its real
/// pitch).
const guitarOpenStrings = [40, 45, 50, 55, 59, 64];

/// A four-string bass's open strings, E A D G, an octave below the guitar's.
const bassOpenStrings = [28, 33, 38, 43];

/// One note of a shape: which [string] (0 = the lowest), which [fret], its
/// [pitch] and which [degree] of the chord it is ("1", "♭3" …).
typedef FretNote = ({int string, int fret, int pitch, String degree});

class FretArpeggio {
  const FretArpeggio({
    required this.tuning,
    required this.rootString,
    required this.notes,
  });

  /// The open strings, lowest first.
  final List<int> tuning;

  /// The string the root is on, numbered as players do, from the highest:
  /// on a guitar 6 is the low E; on a bass 4 is.
  final int rootString;

  bool get isBass => tuning.length == 4;

  /// Low to high, in the order they're played.
  final List<FretNote> notes;

  int get lowestFret =>
      notes.map((n) => n.fret).reduce((a, b) => a < b ? a : b);
  int get highestFret =>
      notes.map((n) => n.fret).reduce((a, b) => a > b ? a : b);
}

/// [chord]'s arpeggio on the guitar in one position with its root on
/// [rootString] (6 or 5), or null if there's no complete one.
FretArpeggio? guitarArpeggio(Chord chord, {required int rootString}) {
  assert(rootString == 6 || rootString == 5);
  return fretArpeggio(chord, guitarOpenStrings, rootString: rootString);
}

/// [chord]'s arpeggio on a four-string bass with its root on [rootString]
/// (4, the E string, or 3, the A), or null if there's no complete one.
FretArpeggio? bassArpeggio(Chord chord, {required int rootString}) {
  assert(rootString == 4 || rootString == 3);
  return fretArpeggio(chord, bassOpenStrings, rootString: rootString);
}

/// [chord]'s arpeggio on strings tuned to [tuning], from a root on
/// [rootString].
FretArpeggio? fretArpeggio(
  Chord chord,
  List<int> tuning, {
  required int rootString,
}) {
  final strings = tuning.length;
  final start = strings - rootString;

  // Each note of the chord by its distance above the root, low to high.
  final degreeOf = <int, String>{};
  for (final degree in chord.quality.formula) {
    degreeOf.putIfAbsent(degreeToSemitones(degree) % 12, () => degree);
  }
  final intervals = degreeOf.keys.toList()..sort();

  // Two octaves, root to root, is the goal.
  final goal = 2 * intervals.length + 1;
  FretArpeggio? best;
  var bestScore = (0, 0, 0);
  var rootFret = (chord.root - tuning[start]) % 12;
  if (rootFret == 0) rootFret = 12; // movable shapes, not open strings
  for (; rootFret <= 15; rootFret += 12) {
    final rootPitch = tuning[start] + rootFret;
    for (final frets in [4, 5]) {
      for (var low = rootFret - frets + 1; low <= rootFret; low++) {
        if (low < 1) continue;
        // Every chord tone from the root up, within reach of this position.
        final byPitch = <int, FretNote>{};
        for (var string = start; string < strings; string++) {
          for (var fret = low; fret < low + frets; fret++) {
            final pitch = tuning[string] + fret;
            final degree = degreeOf[(pitch - rootPitch) % 12];
            if (pitch < rootPitch || degree == null) continue;
            // Higher strings overwrite lower: the B string over the G's
            // stretch.
            byPitch[pitch] = (
              string: string,
              fret: fret,
              pitch: pitch,
              degree: prettyDegree(degree),
            );
          }
        }
        // As far as it goes without skipping a chord tone, up to the goal.
        final notes = <FretNote>[];
        for (final (i, pitch) in (byPitch.keys.toList()..sort()).indexed) {
          final expected =
              rootPitch +
              12 * (i ~/ intervals.length) +
              intervals[i % intervals.length];
          if (pitch != expected || i == goal) break;
          notes.add(byPitch[pitch]!);
        }
        if (notes.length <= intervals.length) continue; // not even an octave

        // Furthest, a reach costing a note; then no reach; then the root
        // under the 2nd finger. Ties go to the lower position.
        final score = (
          notes.length - (frets == 5 ? 1 : 0),
          -frets,
          -(low - (rootFret - 1)).abs(),
        );
        if (best == null || _beats(score, bestScore)) {
          best = FretArpeggio(
            tuning: tuning,
            rootString: rootString,
            notes: notes,
          );
          bestScore = score;
        }
      }
    }
  }
  return best;
}

bool _beats((int, int, int) a, (int, int, int) b) =>
    a.$1 != b.$1 ? a.$1 > b.$1 : (a.$2 != b.$2 ? a.$2 > b.$2 : a.$3 > b.$3);
