// The band's version of an articulation line: every note heard starting.
//
// The piano used to ring a third of a second past each note and hold each
// one to the next, and the beat after a tongued "and" was played softer
// than it. The swung "and" starts only about a tenth of a second before
// the beat, so that beat disappeared under the "and" still ringing. Measured
// here on the real piano: how much louder the start of each beat is than
// the moment just before it.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/practice/line_exercise.dart';

Future<SampleBank> _bank() =>
    SampleBank.load((path) async => File('assets/sounds/$path').readAsBytes());

Int16List _pcm(Uint8List wav) =>
    Int16List.sublistView(Uint8List.fromList(wav.sublist(44)));

double _rms(Int16List pcm, double from, double to) {
  final a = math.max(0, (from * 44100).round());
  final b = math.min(pcm.length, (to * 44100).round());
  var sum = 0.0;
  for (var i = a; i < b; i++) {
    sum += pcm[i] * pcm[i].toDouble();
  }
  return math.sqrt(sum / math.max(1, b - a));
}

/// For each beat that follows an "and", how much louder the loudest 10 ms
/// of its first 20 are than the 20 ms before it, in dB: the attack, which
/// a longer window averages away. The weakest one is what decides
/// whether the line can be followed.
double _weakestBeat(Uint8List wav, List<SnippetNote> notes) {
  final pcm = _pcm(wav);
  var weakest = double.infinity;
  for (var i = 2; i < notes.length; i += 2) {
    final at = notes[i].start;
    final after = math.max(
      _rms(pcm, at, at + 0.01),
      _rms(pcm, at + 0.01, at + 0.02),
    );
    final before = _rms(pcm, at - 0.025, at - 0.005);
    weakest = math.min(weakest, 20 * math.log(after / before) / math.ln10);
  }
  return weakest;
}

void main() {
  test('the beat after a tongued "and" is heard starting', () async {
    final bank = await _bank();
    final line = lineIn(articulation.steps[1], 'G', floor: 60);
    for (final tempo in [100, 120, 140, 170]) {
      final now = guideNotes(line, tempo: tempo, times: 1, from: 0.5);
      final damped = _weakestBeat(
        renderSnippet(bank, now, pianoRelease: guideRelease),
        now,
      );

      // As it was: held to the next note, the slurred beat softer than the
      // "and", and the piano left to ring.
      final before = [
        for (final (i, n) in now.indexed)
          (
            pitch: n.pitch,
            start: n.start,
            length:
                (i + 1 < now.length ? now[i + 1].start : n.start + 0.3) -
                n.start,
            velocity: i.isEven && i > 0 ? 0.5 : n.velocity,
            bass: false,
          ),
      ];
      final ringing = _weakestBeat(renderSnippet(bank, before), before);

      // ignore: avoid_print
      print(
        'at $tempo, weakest beat start: ${ringing.toStringAsFixed(1)} dB '
        'before, ${damped.toStringAsFixed(1)} dB now',
      );
      expect(damped, greaterThan(ringing + 3), reason: 'at $tempo');
      expect(damped, greaterThan(6), reason: 'a start you can hear at $tempo');
    }
  });
}
