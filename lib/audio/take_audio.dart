// Cutting a recording to the chart.
//
// A recording is a fixed thing: six choruses, played once, in one order.
// The chart is not. Somebody loops two bars in the middle of a chorus,
// plays twenty choruses instead of six, and comes in after a count-in
// that was never recorded. This is the part that makes one fit the other.
//
// Three things happen here, and only these three. The tempo and the key
// are not touched: the audio engine does those with the play speed and
// the pitch shift filter, from the sums in recorded_take.dart, and doing
// any of it twice would be worse than doing none of it.
//
//  • Silence goes on the front, so the recording's bar 1 lands on the
//    band's bar 1 rather than on the moment Play was pressed. The length
//    of it works out as the count-in measured at the recording's own
//    tempo, because the speed the engine plays it at cancels exactly.
//  • Each time round the form takes the next chorus of the recording,
//    wrapping when it runs out. Six recorded choruses over a twenty
//    chorus run is still six different ones rather than the same one
//    twenty times, which is most of what makes real players worth having.
//  • A loop shorter than the form is cut out of the recording at the same
//    bars, so looping bars 7 and 8 gives the recording's bars 7 and 8
//    against the chart's, and not its first two.
//
// The joins are crossfaded with the music that really does follow in the
// recording, rather than butted together. Whether that is enough at a
// loop point with dry stems is one of the questions the pilot is for.

import 'dart:math' as math;
import 'dart:typed_data';

import '../music/recorded_take.dart';
import 'wav_file.dart';

/// How long the fade at a join is. Long enough to hide the step, short
/// enough not to swallow a beat at the top of a loop.
const takeCrossfadeSeconds = 0.012;

/// One stem cut to [choruses] passes of a loop, with the count-in on the
/// front, ready to be handed to the engine.
///
/// Everything is measured in the recording's own time, at the tempo it was
/// played at. The engine is what makes it the tempo you are playing at.
Float32List layStem(
  WavAudio audio, {
  required RecordedTake take,
  required int loopStartBeat,
  required int loopBeats,
  required int choruses,
  required int countInBeats,
  double crossfadeSeconds = takeCrossfadeSeconds,
}) {
  final channels = audio.channels;
  if (channels < 1 || choruses < 1 || loopBeats < 1 || take.bpm <= 0) {
    return Float32List(0);
  }
  final framesPerBeat = audio.sampleRate * 60 / take.bpm;
  final origin = take.startSeconds * audio.sampleRate;
  final formBeats = take.bars * take.beatsPerBar;

  final lead = (countInBeats * framesPerBeat).round();
  final segment = (loopBeats * framesPerBeat).round();
  final out = Float32List((lead + segment * choruses) * channels);

  // Never longer than a quarter of the segment: looping one bar at a fast
  // tempo leaves very little to fade across.
  final fade = math.min(
    (crossfadeSeconds * audio.sampleRate).round(),
    segment ~/ 4,
  );

  /// The frame [frame] of the recording holds, or silence past the end.
  double at(int frame, int channel) {
    if (frame < 0) return 0;
    final index = frame * channels + channel;
    return index < 0 || index >= audio.samples.length
        ? 0
        : audio.samples[index];
  }

  for (var chorus = 0; chorus < choruses; chorus++) {
    // Round the recording as many times as the run goes round the form.
    final fromChorus = chorus % math.max(1, take.choruses);
    final source =
        (origin + (fromChorus * formBeats + loopStartBeat) * framesPerBeat)
            .round();
    final into = lead + chorus * segment;

    for (var frame = 0; frame < segment; frame++) {
      for (var channel = 0; channel < channels; channel++) {
        out[(into + frame) * channels + channel] = at(source + frame, channel);
      }
    }

    // Join it to what came before with what really follows there in the
    // recording, so the fade is across music rather than into a gap.
    if (chorus == 0 || fade <= 0) continue;
    final beforeChorus = (chorus - 1) % math.max(1, take.choruses);
    final ran =
        (origin + (beforeChorus * formBeats + loopStartBeat) * framesPerBeat)
            .round() +
        segment;
    for (var frame = 0; frame < fade; frame++) {
      final mix = (frame + 0.5) / fade;
      for (var channel = 0; channel < channels; channel++) {
        final index = (into + frame) * channels + channel;
        out[index] = at(ran + frame, channel) * (1 - mix) + out[index] * mix;
      }
    }
  }
  return out;
}

/// [samples] as the 16-bit little-endian the engine's buffer streams read.
Uint8List pcm16(Float32List samples, {double gain = 1}) {
  final out = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(out);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(
      i * 2,
      ((samples[i] * gain).clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return out;
}

/// Whether [audio] holds as much music as [take] says it does.
///
/// A file that stops early is laid out as silence rather than refused,
/// because half a take is still worth hearing; but it is worth saying.
bool takeIsShort(WavAudio audio, RecordedTake take) =>
    audio.seconds + 0.05 < take.seconds + take.startSeconds;
