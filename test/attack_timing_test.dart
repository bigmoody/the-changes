// The band plays to attacks, not to the front of a file.
//
// A recording begins when the engineer pressed record. The note begins
// when the player's hand did, and between the two sit a little silence
// and the beginning of the rise. Played from the front, every note
// lands that far behind its own beat: eleven milliseconds on average
// for the upright bass here, forty on one take, two for the drums and
// half of one for the brushes. The bass therefore dragged behind the
// kit on every note, and by a different amount each time, which is a
// bassist nobody would hire.
//
// So each recording is started by its own lead-in. These tests measure
// what comes out rather than what the code says it does.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/wav_file.dart';

/// Where the sound starts in [wav]: the first sample at a sixth of its
/// peak, in seconds.
double attackAt(Uint8List wav) {
  final audio = readWav(wav);
  var peak = 0.0;
  for (final sample in audio.samples) {
    final level = sample.abs().toDouble();
    if (level > peak) peak = level;
  }
  final threshold = peak / 6;
  for (var i = 0; i < audio.samples.length; i++) {
    if (audio.samples[i].abs() >= threshold) return i / audio.sampleRate;
  }
  return -1;
}

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  test('a bass note is heard when it was written, not later', () {
    // No room on it: a reverb tail smears the front of the sound, and
    // what is being measured here is the front of the sound.
    for (final at in [0.25, 0.5]) {
      for (final pitch in [40, 45, 50]) {
        final wav = renderSnippet(bank, [
          (pitch: pitch, start: at, length: 0.4, velocity: 0.8, bass: true),
        ], room: false);
        expect(
          attackAt(wav),
          closeTo(at, 0.005),
          reason: 'pitch $pitch at $at',
        );
      }
    }
  });

  test('and so is a note on the piano, the guitar and the kit', () {
    const at = 0.3;
    final piano = renderSnippet(bank, [
      (pitch: 60, start: at, length: 0.4, velocity: 0.8, bass: false),
    ], room: false);
    expect(attackAt(piano), closeTo(at, 0.005), reason: 'piano');

    final guitar = renderSnippet(
      bank,
      [(pitch: 55, start: at, length: 0.4, velocity: 0.8, bass: false)],
      guitar: true,
      room: false,
    );
    expect(attackAt(guitar), closeTo(at, 0.005), reason: 'guitar');
  });

  test('every recording in the bank knows its own lead-in', () {
    // And none of them is dragged more than the cap: a sound still
    // climbing after twenty-five milliseconds is one that swells, like a
    // brush circling a head, and pulling it forward by a third of its
    // turn would be a different kind of wrong.
    final leads = <int>[];
    for (final takes in bank.bass.notes.values) {
      for (final take in takes) {
        expect(take.lead, lessThanOrEqualTo(1102));
        expect(take.lead, greaterThanOrEqualTo(0));
        leads.add(take.lead);
      }
    }
    expect(leads, isNotEmpty);
    // The whole point: the bass is not a few samples late, it is
    // milliseconds late, and by a different amount from take to take.
    final longest = leads.reduce(math.max);
    expect(longest, greaterThan(44100 * 0.005), reason: 'over 5 ms');
  });
}
