// A real recording: St. Thomas, heard through a Mac's microphone from
// iReal Pro while the ear listened, saved with Save What It Heard. The
// recording is not in the repository (ear_captures/ is ignored), so this
// is skipped where it is not.
//
// Where the tune really was was worked out by ear from the chords in the
// recording: E half-diminished at 14.5 seconds, A7, Dm7, G7, then C, at
// 180 to the minute, which puts bar 1 of a chorus at 13.17 seconds.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/wav_file.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/chart_follower.dart';

const _path = 'ear_captures/heard-St-Thomas-2026-10-17T01-28-05.wav';

void main() {
  final there = File(_path).existsSync();
  test('St. Thomas off iReal Pro, switched on mid-song, chart 30 slow', () {
    final wav = readWav(File(_path).readAsBytesSync());
    final tune = standards.firstWhere((t) => t.title == 'St. Thomas');
    // What the chart said, which is not what the record was playing.
    final follower = ChartFollower(tune: tune, tempo: 150);
    for (var at = 0; at < wav.samples.length; at += 2048) {
      follower.hear(
        Float32List.sublistView(
          wav.samples,
          at,
          math.min(at + 2048, wav.samples.length),
        ),
      );
    }
    const barOne = 13.1667;
    const bar = 60 / 180 * 4;
    var right = 0;
    var counted = 0;
    for (final heard in follower.heardBeats) {
      if (heard.at < 12 || heard.at > 27) continue;
      // Half a beat's grace, either way, at the barlines.
      final actual = ((heard.at - barOne + bar / 8) / bar).floor() % 16;
      counted++;
      if (actual == heard.bar) right++;
    }
    final share = right / counted;
    // ignore: avoid_print
    print(
      'St. Thomas capture, no taps: ${(share * 100).toStringAsFixed(1)}% '
      'from 12 s, tempo heard ${follower.position?.tempo.toStringAsFixed(1)}',
    );
    // Without a tap: it notices the record was already playing, finds
    // the tempo and then its place, and follows from there.
    expect(follower.position!.tempo, closeTo(180, 3));
    expect(share, greaterThan(0.85));
  }, skip: there ? false : 'no capture here');
}
