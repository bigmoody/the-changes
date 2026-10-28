// The chord identifier on the player's own guitar: a screen recording of
// a Cmaj7 (x35453) strummed on an iPad, its sound kept in ear_captures/
// (not in git, so skipped where it is not). A low C played hard spilled
// into the B below it, and the chord was named Cmaj7/B as long as it
// rang.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/chord_ear.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/chord_match.dart';

void main() {
  final file = File('ear_captures/chord-cmaj7-x35453.wav');
  test('a Cmaj7 ringing is Cmaj7, not Cmaj7/B', () {
    final raw = decodeWav(file.readAsBytesSync());
    final sound = Float32List.fromList([for (final s in raw) s / 32768]);
    const size = 16384;
    // The first strum, once it has settled: 0.6 to 2.5 seconds.
    for (var end = 26460; end < 110250; end += 5292) {
      final heard = listenForNotes(
        Float32List.sublistView(sound, end - size, end),
        sampleRate: 44100,
        size: size,
      );
      if (heard.pitches.length < 3) continue;
      final named = namesFor(
        heard.chroma,
        bass: heard.bass == null ? null : heard.bass! % 12,
      ).first;
      expect(named.display, 'CΔ7', reason: 'at ${end / 44100} s');
    }
  }, skip: file.existsSync() ? false : 'not on this machine');
}
