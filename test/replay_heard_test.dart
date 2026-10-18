// Replays what the ear heard on somebody's device, saved from the stage
// with Save What It Heard, through the follower as it is now: the way to
// work out why a real record was not followed, and to see that a change
// makes it better rather than only the band's own audio.
//
// Skipped unless pointed at a recording:
//
//   EAR_WAV=/path/heard.wav EAR_TUNE="Autumn Leaves" EAR_TEMPO=140 \
//     flutter test test/replay_heard_test.dart
//
// EAR_TAPS can list taps to replay, as "seconds:bar" for a bar tapped and
// "seconds:beat" for Tap the Beat, comma separated. The log saved beside
// the recording has them.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/chart_follower.dart';

void main() {
  final path = Platform.environment['EAR_WAV'];
  test('replays what the ear heard', () {
    final wav = readWav(File(path!).readAsBytesSync());
    final title = Platform.environment['EAR_TUNE']!;
    final tune = standards.firstWhere((t) => t.title == title);
    final tempo = double.parse(Platform.environment['EAR_TEMPO']!);
    final taps = [
      for (final tap
          in (Platform.environment['EAR_TAPS'] ?? '')
              .split(',')
              .where((t) => t.isNotEmpty))
        (at: double.parse(tap.split(':')[0]), what: tap.split(':')[1]),
    ]..sort((a, b) => a.at.compareTo(b.at));
    final mono = Float32List(wav.frames);
    for (var i = 0; i < wav.frames; i++) {
      var sum = 0.0;
      for (var c = 0; c < wav.channels; c++) {
        sum += wav.samples[i * wav.channels + c];
      }
      mono[i] = sum / wav.channels;
    }
    final follower = ChartFollower(
      tune: tune,
      tempo: tempo,
      sampleRate: wav.sampleRate,
    );
    var at = 0;
    for (final tap in taps) {
      final until = (tap.at * wav.sampleRate).round().clamp(at, mono.length);
      for (; at < until; at += 2048) {
        follower.hear(
          Float32List.sublistView(mono, at, math.min(at + 2048, until)),
        );
      }
      at = until;
      if (tap.what == 'beat') {
        follower.tap();
      } else {
        follower.placeAt((int.parse(tap.what) - 1) * tune.beatsPerBar);
      }
    }
    for (; at < mono.length; at += 2048) {
      follower.hear(
        Float32List.sublistView(mono, at, math.min(at + 2048, mono.length)),
      );
    }
    // ignore: avoid_print
    print(
      '${wav.seconds.toStringAsFixed(1)} s heard, '
      '${follower.heardBeats.length} beats counted',
    );
    for (final beat in follower.heardBeats) {
      // ignore: avoid_print
      print(
        '${beat.at.toStringAsFixed(2).padLeft(7)}  bar '
        '${(beat.bar + 1).toString().padLeft(3)}.${beat.beat % tune.beatsPerBar + 1}'
        '  sure ${beat.confidence.toStringAsFixed(2)}'
        '  music ${beat.hearsMusic ? 'yes' : 'no '}'
        '  ${beat.tempo.toStringAsFixed(1)} BPM',
      );
    }
  }, skip: path == null ? 'no EAR_WAV given' : false);
}
