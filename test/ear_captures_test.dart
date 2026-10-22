// Every recording saved from the stage with Save What It Heard, replayed
// through the ear as it is now, told nothing but the tune.
//
// Recordings live in ear_captures/ (kept out of git), each with the log
// it was saved with, whose first line names the tune. Without anybody
// having worked out by ear where each bar really falls, the check is how
// clearly the chart explains what was heard at the place the ear says it
// is: the same measure it chooses a tempo by. A recording it follows
// stands well clear; one it has lost does not.
//
// It reports and does not fail: the ear here is the hand-made one, which
// real records defeat. Run it with the recordings in place and read what
// it prints:
//   flutter test test/ear_captures_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/room_follower.dart';

import 'band_audio.dart';

void main() {
  final folder = Directory('ear_captures');
  final recordings = folder.existsSync()
      ? (folder
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.wav'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  for (final wav in recordings) {
    final log = File(wav.path.replaceFirst(RegExp(r'\.wav$'), '.txt'));
    final title = log.existsSync()
        ? RegExp(r'^# (.+?), ')
              .firstMatch(log.readAsLinesSync().first)
              ?.group(1)
        : null;
    final tune = standards.where((t) => t.title == title).firstOrNull;
    test('replays ${wav.uri.pathSegments.last}', () {
      final samples = readWavSamples(wav.readAsBytesSync());
      final follower = RoomFollower(tune: tune!);
      for (var at = 0; at < samples.length; at += 2048) {
        follower.hear(
          Float32List.sublistView(
            samples,
            at,
            math.min(at + 2048, samples.length),
          ),
        );
      }
      final chosen = follower.following;
      final beats = follower.heardBeats;
      final music = beats.where((b) => b.hearsMusic).length;
      // ignore: avoid_print
      print(
        '${tune.title}: ${(samples.length / 44100).toStringAsFixed(0)} s, '
        'tempo ${chosen == null ? 'not found' : chosen.tempo.toStringAsFixed(1)}, '
        'music on ${beats.isEmpty ? 0 : (100 * music / beats.length).round()}% '
        'of beats, chart explains it '
        '${chosen?.chartExplains.toStringAsFixed(1) ?? '-'} spreads clear',
      );
      // A report, not a check: this is the hand-made ear, which is known
      // to lose real records (see the-changes notes); what it prints is
      // what is worth reading. Beat This! is judged on the device.
    }, skip: tune == null ? 'no tune named for it' : false);
  }
}
