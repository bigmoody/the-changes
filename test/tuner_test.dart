import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/pitch_detector.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/tuning.dart';

const rate = 44100;

/// A plucked string: [harmonics] strengths, decaying, with a little noise.
Float32List pluck(
  double hz, {
  List<double> harmonics = const [1, 0.7, 0.4, 0.3, 0.2],
  double noise = 0.02,
  int length = 4096,
  int seed = 1,
}) {
  final random = math.Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < length; i++)
      () {
        final t = i / rate;
        var sample = 0.0;
        for (var h = 0; h < harmonics.length; h++) {
          sample += harmonics[h] * math.sin(2 * math.pi * hz * (h + 1) * t);
        }
        return 0.3 * sample * math.exp(-t * 2) +
            noise * (random.nextDouble() * 2 - 1);
      }(),
  ]);
}

double centsBetween(double a, double b) => 1200 * math.log(a / b) / math.ln2;

void main() {
  final detector = PitchDetector(sampleRate: rate);

  test('hears notes across the range, to within a cent', () {
    // Low E on a bass-ish guitar up to the top of a trumpet's range.
    for (final midi in [40, 45, 48, 55, 60, 64, 69, 72, 79, 84]) {
      final hz = midiToHz(midi);
      final heard = detector.detect(pluck(hz, length: detector.windowSize))!;
      expect(
        centsBetween(heard.hz, hz).abs(),
        lessThan(1),
        reason: 'MIDI $midi (${hz.toStringAsFixed(1)} Hz)',
      );
    }
  });

  test('not fooled by a loud second harmonic (the octave trap)', () {
    final hz = midiToHz(40);
    final heard = detector.detect(
      pluck(
        hz,
        harmonics: const [0.5, 1, 0.6, 0.3],
        length: detector.windowSize,
      ),
    )!;
    expect(centsBetween(heard.hz, hz).abs(), lessThan(1));
  });

  test('tells slightly sharp from slightly flat', () {
    for (final cents in [-12.0, -3.0, 4.0, 15.0]) {
      final hz = midiToHz(69) * math.pow(2, cents / 1200);
      final heard = detector.detect(pluck(hz, length: detector.windowSize))!;
      final note = noteNear(hzToMidi(heard.hz));
      expect(note.midi, 69);
      expect(note.cents, closeTo(cents, 1));
    }
  });

  test('silence and noise are not notes', () {
    expect(detector.detect(Float32List(detector.windowSize)), isNull);
    final random = math.Random(3);
    final hiss = Float32List.fromList([
      for (var i = 0; i < detector.windowSize; i++)
        0.3 * (random.nextDouble() * 2 - 1),
    ]);
    expect(detector.detect(hiss), isNull);
  });

  test('matching a note counts in any octave', () {
    const e = 4;
    expect(centsFromPitchClass(64, e), 0); // E4
    expect(centsFromPitchClass(40, e), 0); // E2: a bass player's E
    expect(centsFromPitchClass(76.1, e), closeTo(10, 1e-9)); // E5, sharp
    expect(centsFromPitchClass(63.8, e), closeTo(-20, 1e-9)); // flat E
    // A semitone off is a semitone off, whichever way round the octave.
    expect(centsFromPitchClass(65, e), closeTo(100, 1e-9)); // F
    expect(centsFromPitchClass(63, e), closeTo(-100, 1e-9)); // E♭
    expect(
      centsFromPitchClass(58, e),
      anyOf(closeTo(600, 1e-9), closeTo(-600, 1e-9)),
    );
  });

  test('notes are named both ways on the black keys', () {
    expect(
      [for (var p = 0; p < 12; p++) pitchClassName(p)].join(' '),
      'C C♯/D♭ D D♯/E♭ E F F♯/G♭ G G♯/A♭ A A♯/B♭ B',
    );
  });

  test('the reference notes are exactly in tune', () {
    for (final midi in [48, 55, 60, 64, 69, 71, 76]) {
      final hz = midiToHz(midi);
      final samples = decodeWav(referenceTone(hz));
      final window = Float32List.fromList([
        for (final s in samples.sublist(4000, 4000 + detector.windowSize))
          s / 32768,
      ]);
      final heard = detector.detect(window)!;
      expect(
        centsBetween(heard.hz, hz).abs(),
        lessThan(0.5),
        reason: 'MIDI $midi reference',
      );
    }
  });

  test('concert A is 440 Hz', () {
    expect(midiToHz(69), 440);
    expect(midiToHz(60), closeTo(261.63, 0.01)); // middle C
  });
}
