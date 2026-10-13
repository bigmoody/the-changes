// Turning a recording into something you can look at.
//
// A phrase is four bars and the bit you want is a particular note in it.
// A bar with no picture on it means hunting for that note by ear, drag
// and listen and drag again, which is the same hunt as playing from the
// top only with more thumb. Drawn, the attacks are visible and the note
// you meant is somewhere to aim at.
//
// Peaks rather than an average, because an average of a sampled waveform
// is close to nothing everywhere and draws a flat grey sausage. The loud
// edge of each note is what the eye is looking for and the peak is where
// it lives.

import 'dart:math';
import 'dart:typed_data';

import 'wav_file.dart';

/// How many columns a drawn phrase is cut into.
///
/// Enough that a semiquaver at a fast tempo still gets a column of its
/// own in four bars, few enough that each one is wide enough to see on a
/// phone.
const waveformColumns = 160;

/// The loudest point in each slice of [audio], nought to one.
///
/// Scaled so the loudest moment of the recording reaches the top: a
/// phrase played quietly into the microphone is still a phrase, and one
/// drawn as a flat line in the middle of the bar tells nobody anything.
List<double> peaksOf(WavAudio audio, {int columns = waveformColumns}) {
  final frames = audio.frames;
  if (frames <= 0 || columns <= 0) return const [];
  final channels = max(audio.channels, 1);
  final peaks = List<double>.filled(columns, 0);
  var loudest = 0.0;

  for (var column = 0; column < columns; column++) {
    final from = (frames * column) ~/ columns;
    final to = max((frames * (column + 1)) ~/ columns, from + 1);
    var peak = 0.0;
    for (var frame = from; frame < to && frame < frames; frame++) {
      // Every channel, because a phrase recorded on one side of a stereo
      // file is not silence.
      for (var channel = 0; channel < channels; channel++) {
        final at = frame * channels + channel;
        if (at >= audio.samples.length) break;
        final level = audio.samples[at].abs();
        if (level > peak) peak = level;
      }
    }
    peaks[column] = peak;
    if (peak > loudest) loudest = peak;
  }

  if (loudest <= 0) return peaks;
  return [for (final peak in peaks) (peak / loudest).clamp(0.0, 1.0)];
}

/// Reads [wav] and draws it down to peaks, or gives back nothing where it
/// is not a WAV this app can read.
///
/// Nothing rather than a throw: a phrase whose file cannot be decoded
/// should still play and still scrub. The picture is the part that is
/// allowed to be missing.
List<double> peaksOfWav(Uint8List wav, {int columns = waveformColumns}) {
  try {
    return peaksOf(readWav(wav), columns: columns);
  } on WavFormatException {
    return const [];
  } catch (e) {
    return const [];
  }
}
