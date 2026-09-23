// Working out what somebody played, from a recording of them playing it.
//
// A lick saved as audio can be listened back to and nothing else. Saved as
// notes it can be written on a stave, moved to any key, played back by the
// band, and checked against what you play next time. Everything anybody
// would want to do with a lick needs the notes, so the notes are what is
// worked out here.
//
// Two things the app already had do most of it. Spectral flux says when
// each note began (onsets.dart, built to measure whether a rhythm section
// was on the click, and accurate to a fraction of a millisecond). YIN says
// what pitch is sounding (pitch_detector.dart, the tuner). Between them,
// where and what.
//
// It is done on a finished recording rather than as you play, which is a
// great deal more reliable: nothing has to be decided before the note has
// finished sounding, and a note can be looked at as many times as it
// takes.
//
// One line at a time, for now. YIN finds one pitch, so this hears a
// saxophone or a single-note guitar line and would make nonsense of a
// piano chord. Licks are lines, so that is the right limit to start with,
// but it is a limit and the screen says so rather than quietly mangling a
// chord.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/midi_file.dart';
import '../music/tuning.dart';
import 'onsets.dart';
import 'pitch_detector.dart';
import 'wav_file.dart';

/// One note heard in a recording, in seconds from its start.
typedef PlayedNote = ({int pitch, double at, double length, double clarity});

/// How much of the front of a note to ignore when asking what pitch it is.
///
/// The attack of a note is a thump, a pick scrape or a puff of air, and it
/// has no pitch worth reading. Reading it anyway is how a transcription
/// ends up with a stray note a fifth out at the start of every phrase.
const _skipAttack = 0.03;

/// How clearly a window has to be one note to count towards a pitch.
const _clearEnough = 0.55;

/// The notes in [audio]: one line, played by one person.
///
/// [lowest] and [highest] are the range to look in, and narrowing them is
/// the cheapest way to stop octave mistakes: a tenor player has no use for
/// the app looking below a cello's bottom string.
List<PlayedNote> hearNotes(
  WavAudio audio, {
  double lowest = 70,
  double highest = 1400,
  double quietEnd = 0.2,
}) {
  final mono = _mono(audio);
  final rate = audio.sampleRate;
  // A line is not a drum kit. Struck drums come thick and a hit is a
  // clean spike; a note on a horn or a guitar swells and wavers as it
  // sounds, and read as keenly as a kit it comes out as three notes.
  // Measured on lines, this is where the count stops being wrong.
  final starts = findOnsets(audio, sensitivity: 2.5, closest: 0.08, grain: 128);
  if (starts.isEmpty) return const [];

  final detector = PitchDetector(
    sampleRate: rate,
    lowestHz: lowest,
    highestHz: highest,
  );
  final window = detector.windowSize;
  final out = <PlayedNote>[];
  var lastPeak = 0.0;

  for (var i = 0; i < starts.length; i++) {
    final from = (starts[i] * rate).round();
    final until = i + 1 < starts.length
        ? (starts[i + 1] * rate).round()
        : mono.length;
    if (until - from < window) continue;

    // Every window of the note that is clearly one pitch, and the middle
    // one of those. The middle rather than the average because a wrong
    // reading is usually wrong by an octave, and an octave averaged with
    // the truth is a note that was never played.
    final heard = <double>[];
    var clarity = 0.0;
    for (
      var at = from + (_skipAttack * rate).round();
      at + window <= until;
      at += window ~/ 2
    ) {
      final found = detector.detect(
        Float32List.sublistView(mono, at, at + window),
      );
      if (found == null || found.clarity < _clearEnough) continue;
      heard.add(hzToMidi(found.hz));
      clarity = math.max(clarity, found.clarity);
    }
    if (heard.isEmpty) continue;
    heard.sort();
    final pitch = heard[heard.length ~/ 2].round();
    final loudest = _peak(mono, from, math.min(until, from + window * 2));

    // A note dying away is not a new note. The end of a phrase, and
    // sometimes the middle of a long note, throws up a rise in the
    // spectrum that looks like a beginning; read as one it puts a phantom
    // note at the end of every lick, always the same pitch as the one
    // before and always quieter. A note struck again is as loud as the
    // one before it, so this loses the phantom and keeps the repeat.
    if (out.isNotEmpty &&
        out.last.pitch == pitch &&
        loudest < lastPeak * 0.75) {
      continue;
    }
    lastPeak = loudest;

    out.add((
      pitch: pitch,
      at: starts[i],
      length: _lengthOf(mono, rate, from, until, quietEnd),
      clarity: clarity,
    ));
  }
  return out;
}

/// The loudest the recording gets between [from] and [until].
double _peak(Float32List mono, int from, int until) {
  var loudest = 0.0;
  for (var i = math.max(0, from); i < math.min(until, mono.length); i++) {
    final level = mono[i].abs();
    if (level > loudest) loudest = level;
  }
  return loudest;
}

/// How long the note starting at [from] actually sounds for.
///
/// Up to the next note, but cut short where it dies away first, so a
/// phrase with air in it comes out with rests in it rather than as a row
/// of notes all held into each other.
double _lengthOf(
  Float32List mono,
  int rate,
  int from,
  int until,
  double quietEnd,
) {
  const block = 256;
  var loudest = 0.0;
  final levels = <double>[];
  for (var at = from; at + block <= until; at += block) {
    var sum = 0.0;
    for (var i = at; i < at + block; i++) {
      sum += mono[i] * mono[i];
    }
    final level = math.sqrt(sum / block);
    levels.add(level);
    loudest = math.max(loudest, level);
  }
  if (levels.isEmpty || loudest == 0) return (until - from) / rate;
  for (var i = 0; i < levels.length; i++) {
    if (levels[i] < loudest * quietEnd) {
      return math.max(block, i * block) / rate;
    }
  }
  return (until - from) / rate;
}

/// The grids a phrase might have been played on.
///
/// Swung eighths are first because this is a jazz app and they are what a
/// line is usually played in; straight eighths would put every off-beat
/// note a third of a beat out and make a readable phrase look wrong.
enum NoteGrid {
  swungEighths('Swung eighths'),
  straightEighths('Straight eighths'),
  triplets('Triplets'),
  sixteenths('Sixteenths');

  const NoteGrid(this.label);
  final String label;

  /// Where notes may fall inside one beat, as fractions of it.
  List<double> get places => switch (this) {
    // The swung "and" sits two thirds of the way through the beat.
    swungEighths => const [0, 2 / 3],
    straightEighths => const [0, 0.5],
    triplets => const [0, 1 / 3, 2 / 3],
    sixteenths => const [0, 0.25, 0.5, 0.75],
  };

  /// [beat] moved onto the nearest place this grid allows.
  double snap(double beat) {
    final whole = beat.floor();
    final into = beat - whole;
    var best = places.first;
    for (final place in [...places, 1.0]) {
      if ((place - into).abs() < (best - into).abs()) best = place;
    }
    return whole + best;
  }

  /// How far [beat] had to move, in beats.
  double errorAt(double beat) => (snap(beat) - beat).abs();
}

/// [heard] placed in beats on [grid], ready to be written or played.
///
/// [startSeconds] is where the tune's first beat is in the recording: what
/// was going on before you came in, which for a take is the wait while the
/// band was written and counted you in.
List<MidiNote> onTheGrid(
  List<PlayedNote> heard, {
  required double bpm,
  required NoteGrid grid,
  double startSeconds = 0,
  double shortest = 1 / 4,
}) {
  if (bpm <= 0) return const [];
  final perBeat = 60 / bpm;
  final out = <MidiNote>[];
  for (final note in heard) {
    final beat = grid.snap((note.at - startSeconds) / perBeat);
    // A note is at least a sixteenth, however short it was cut off: a
    // stave has nothing shorter to draw and nobody meant to play it.
    final length = math.max(shortest, _snapLength(note.length / perBeat, grid));
    out.add((pitch: note.pitch, beat: beat, beats: length, velocity: 0.85));
  }
  out.sort((a, b) => a.beat.compareTo(b.beat));
  return out;
}

/// A length rounded to something the grid could write down.
double _snapLength(double beats, NoteGrid grid) {
  final step = grid.places.length > 2 ? 1 / grid.places.length : 0.5;
  return (beats / step).round() * step;
}

/// Which grid [heard] was most likely played on.
///
/// The one that had to move the notes least. A phrase of swung eighths
/// read as straight ones puts every off-beat note a sixth of a beat out,
/// which is far more than the same phrase read correctly, so this is
/// usually not a close call.
NoteGrid bestGrid(
  List<PlayedNote> heard, {
  required double bpm,
  double startSeconds = 0,
}) {
  if (heard.isEmpty || bpm <= 0) return NoteGrid.swungEighths;
  final perBeat = 60 / bpm;
  var best = NoteGrid.swungEighths;
  var least = double.infinity;
  for (final grid in NoteGrid.values) {
    var total = 0.0;
    for (final note in heard) {
      total += grid.errorAt((note.at - startSeconds) / perBeat);
    }
    // A plainer grid wins a tie: sixteenths can fit anything, and saying
    // a phrase of eighths is really sixteenths helps nobody.
    if (total < least - 1e-9) {
      least = total;
      best = grid;
    }
  }
  return best;
}

/// [audio] summed to mono at the rate it came in at.
Float32List _mono(WavAudio audio) {
  final channels = math.max(1, audio.channels);
  if (channels == 1) return audio.samples;
  final frames = audio.samples.length ~/ channels;
  final out = Float32List(frames);
  for (var frame = 0; frame < frames; frame++) {
    var total = 0.0;
    for (var channel = 0; channel < channels; channel++) {
      total += audio.samples[frame * channels + channel];
    }
    out[frame] = total / channels;
  }
  return out;
}
