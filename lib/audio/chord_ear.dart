// Hearing several notes at once: what's in a chord somebody just played.
//
// A plucked string doesn't produce one frequency but a stack of them — the
// note, then the octave above, then the fifth above that, and on up. So the
// loudest thing in the spectrum of a C major chord is often not C, E and G
// at all, and a peak at G may be the E's harmonic rather than a G anybody
// played.
//
// The way through is to score every *note* by how well its own stack of
// harmonics is present, take the best one, subtract what it explains, and
// look again. After half a dozen rounds what's left is noise, and the notes
// taken out are the ones being played.
//
// None of it is about guitars, and it hears a piano too. Where it is least
// sure is a chord closed up high on the keyboard, and a two-handed voicing
// with a very low left hand: down at the bottom of the keyboard a semitone
// is barely wider than one bin of the transform, so neighbouring notes are
// hard to tell apart.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/tuning.dart';
import 'fft.dart';

/// The lowest and highest notes it will look for: the bottom of a bass
/// guitar to the top of a piano's useful range.
const lowestHeard = 28; // E1
const highestHeard = 96; // C7

/// How many harmonics of a note are looked for, and how much each counts.
/// A string's harmonics fall away roughly like this, and weighting them
/// evenly would make every note sound like the octave below it.
const _harmonics = 8;
double _weightOf(int harmonic) => 1 / math.pow(harmonic, 0.7);

/// How much louder a note must be than the one above it before that one is
/// treated as merely its harmonic.
const _muchLouder = 1.5;

/// Up to here a note's own pitch may be quieter than its harmonics, so it's
/// worth asking whether the note below is the one being played. Above it,
/// that question only invents notes.
const _weakFundamentalsBelow = 62;

/// How quiet a note may be against the first one taken out, and against the
/// one before it, and still count as played.
const _quietestNote = 0.18;
const _dropOff = 0.25;

/// How much of a note's harmonics to clear away once it has been taken out.
/// Less than all of it: how loud a string's harmonics are varies from note
/// to note and instrument to instrument, and clearing more than a note can
/// account for deletes the chord above a low left hand.
const _takeOut = 1.0;

/// What was heard in a sound.
class HeardNotes {
  const HeardNotes({
    required this.pitches,
    required this.chroma,
    required this.level,
  });

  /// The notes taken out, loudest first. Empty when there was nothing to
  /// hear.
  final List<int> pitches;

  /// How much of each of the twelve notes there is, adding to one (or all
  /// zero when nothing was heard).
  final List<double> chroma;

  /// How loud the sound was (RMS).
  final double level;

  /// The lowest note played, which decides whether a chord is in its root
  /// position or turned over.
  int? get bass => pitches.isEmpty ? null : pitches.reduce(math.min);

  bool get isEmpty => pitches.isEmpty;
}

/// Works out which notes are sounding in [samples].
///
/// [most] caps how many notes are taken out: six strings, or ten fingers.
HeardNotes listenForNotes(
  Float32List samples, {
  required int sampleRate,
  int most = 6,
  int size = 16384,
  double silence = 0.0015,
}) {
  var energy = 0.0;
  for (final sample in samples) {
    energy += sample * sample;
  }
  final level = math.sqrt(energy / math.max(samples.length, 1));
  if (level < silence) {
    return HeardNotes(
      pitches: const [],
      chroma: List.filled(12, 0),
      level: level,
    );
  }

  final spectrum = magnitudeSpectrum(samples, size: size);
  final binsPerHz = size / sampleRate;

  /// The strength of the spectrum at [hertz], taking the best of the bins
  /// either side so a string a little out of tune still counts.
  double at(Float64List from, double hertz) {
    final centre = (hertz * binsPerHz).round();
    if (centre < 1 || centre >= from.length - 1) return 0;
    return math.max(from[centre], math.max(from[centre - 1], from[centre + 1]));
  }

  /// Whether a note is really sounding at its own pitch, rather than merely
  /// having the notes above it fall in its harmonic series. Every note has
  /// a subharmonic far below that "explains" it arithmetically; what tells
  /// a played string from one of those is that it is ringing at its own
  /// pitch, however faintly.
  ///
  /// How faintly depends on the register. A low string is stiff and radiates
  /// its own note poorly — a piano's bottom octave is nearly all harmonics —
  /// while a note up the top is mostly its fundamental. So the test is
  /// lenient down low, where it would otherwise throw away real notes, and
  /// strict up high, where anything below is a phantom.
  bool sounding(Float64List from, int note, double salience) {
    if (salience <= 0) return true;
    final fraction = 0.03 + (note - 55).clamp(0, 23) / 23 * 0.22;
    return at(from, midiToHz(note)) >= salience * fraction;
  }

  /// How much of [note]'s stack of harmonics is present.
  double salienceOf(Float64List from, int note) {
    final root = midiToHz(note);
    var sum = 0.0;
    for (var harmonic = 1; harmonic <= _harmonics; harmonic++) {
      final hertz = root * harmonic;
      if (hertz * binsPerHz >= from.length) break;
      sum += _weightOf(harmonic) * at(from, hertz);
    }
    return sum;
  }

  final residual = Float64List.fromList(spectrum);
  final picked = <int>[];
  final strength = <double>[];
  double? first;
  double? previous;

  for (var round = 0; round < most; round++) {
    var best = -1;
    var bestScore = 0.0;
    for (var note = lowestHeard; note <= highestHeard; note++) {
      if (picked.contains(note)) continue;
      final score = salienceOf(residual, note);
      if (score > bestScore && sounding(residual, note, score)) {
        bestScore = score;
        best = note;
      }
    }
    if (best < 0) break;
    // A guitar's low strings can have a weak fundamental, so the octave or
    // twelfth above often scores higher than the note actually stopped.
    // If the note below explains nearly as much, it's the one being played
    // and the other is its harmonic.
    // Only down here. A thick low string radiates its own note poorly, so
    // the octave above can outscore it; a note up the top has no such
    // excuse, and "explaining" it by something a twelfth below is how a
    // chord played high turns into a chord nobody played.
    for (final below
        in best > _weakFundamentalsBelow ? const <int>[] : const [12, 19, 24]) {
      final lower = best - below;
      if (lower < lowestHeard || picked.contains(lower)) continue;
      final score = salienceOf(residual, lower);
      if (score >= bestScore * 0.85 && sounding(residual, lower, score)) {
        best = lower;
        bestScore = score;
      }
    }
    first ??= bestScore;
    // Two ways of knowing there's nothing left worth taking. Against the
    // first note out: what remains is the ring of the room. Against the one
    // before it: the notes of a chord are roughly as loud as each other, so
    // a sudden drop means the chord has been accounted for and what's left
    // is the residue of the subtraction.
    if (bestScore < first * _quietestNote) break;
    if (previous != null && bestScore < previous * _dropOff) break;
    previous = bestScore;
    picked.add(best);
    strength.add(bestScore);

    // Take out what this note explains, so its harmonics aren't mistaken
    // for notes of their own next time round — but only as much as it can
    // account for. A guitar's C and the G above it share a frequency
    // exactly, so clearing the bin outright would delete the G somebody
    // actually played; taking out what the C's own harmonic would amount
    // to leaves the rest of it standing.
    final root = midiToHz(best);
    final fundamental = at(residual, root);
    for (var harmonic = 1; harmonic <= _harmonics; harmonic++) {
      final centre = (root * harmonic * binsPerHz).round();
      final explained = fundamental * _weightOf(harmonic) * _takeOut;
      for (var bin = centre - 1; bin <= centre + 1; bin++) {
        if (bin < 1 || bin >= residual.length) continue;
        residual[bin] = math.max(0, residual[bin] - explained);
      }
    }
  }

  // A note sitting exactly on a harmonic of a louder note below it, and
  // much quieter than it, is that note's harmonic and not a note anybody
  // played. Left in, these turn plain triads into 9ths and 13ths.
  final notes = <int>[];
  final weights = <double>[];
  for (var i = 0; i < picked.length; i++) {
    var ghost = false;
    for (var j = 0; j < i && !ghost; j++) {
      if (picked[j] >= picked[i]) continue;
      if (strength[j] < strength[i] * _muchLouder) continue;
      final ratio = midiToHz(picked[i]) / midiToHz(picked[j]);
      final harmonic = ratio.round();
      if (harmonic < 2 || harmonic > 12) continue;
      final cents = 1200 * math.log(ratio / harmonic) / math.ln2;
      ghost = cents.abs() < 35;
    }
    if (ghost) continue;
    notes.add(picked[i]);
    weights.add(strength[i]);
  }

  final chroma = List.filled(12, 0.0);
  for (var i = 0; i < notes.length; i++) {
    chroma[notes[i] % 12] += weights[i];
  }
  final total = chroma.fold(0.0, (a, b) => a + b);
  if (total > 0) {
    for (var i = 0; i < 12; i++) {
      chroma[i] /= total;
    }
  }
  return HeardNotes(pitches: notes, chroma: chroma, level: level);
}
