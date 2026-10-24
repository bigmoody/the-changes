// The tuner on the player's own guitar: two screen recordings of open
// E4 then E2, one of this tuner on an iPad and one of another tuner on a
// phone, their sound kept in ear_captures/ (not in git, so skipped where
// it is not). Every reading must be E4 or E2: anything else is the tuner
// naming an overtone, an undertone or a string ringing in sympathy.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/tuner_listener.dart';
import 'package:play_along/music/tuning.dart';

void main() {
  for (final (name, atLeast) in [
    ('tuner-ipad-open-e', 160),
    ('tuner-iphone-open-e', 170),
  ]) {
    final file = File('ear_captures/$name.wav');
    test('$name: only ever E4 or E2, and most of the time', () {
      final raw = decodeWav(file.readAsBytesSync());
      final sound = Float32List.fromList([for (final s in raw) s / 32768]);
      final tuner = TunerListener();
      var named = 0;
      for (var at = 0; at + 3528 <= sound.length; at += 3528) {
        final heard = tuner.playToIt(
          Float32List.sublistView(sound, at, at + 3528),
        );
        if (heard == null) continue;
        named++;
        final midi = noteNear(hzToMidi(heard.hz)).midi;
        expect(midi, anyOf(64, 40), reason: 'reading at $at');
      }
      expect(named, greaterThanOrEqualTo(atLeast));
    }, skip: file.existsSync() ? false : 'not on this machine');
  }
}
