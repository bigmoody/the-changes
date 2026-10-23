// The tuner and a guitar's low E as an iPad's own microphone hears it:
// the app's recorded guitar (assets/sounds/guitar, E2, three takes),
// rolled off below 150 Hz as a small microphone does, at a tenth of its
// level, with a little hiss. Played to the tuner 80 ms at a time, as the
// microphone hands it over.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/tuner_listener.dart';

/// A recorded note as a small microphone hears it.
Float32List throughSmallMicrophone(String path, {double level = 0.1}) {
  final raw = decodeWav(File(path).readAsBytesSync());
  var y = Float32List.fromList([for (final s in raw) s / 32768]);
  // Two first-order high-pass filters at 150 Hz.
  for (var pass = 0; pass < 2; pass++) {
    const rc = 1 / (2 * math.pi * 150);
    const dt = 1 / 44100;
    const a = rc / (rc + dt);
    final out = Float32List(y.length);
    for (var i = 1; i < y.length; i++) {
      out[i] = a * (out[i - 1] + y[i] - y[i - 1]);
    }
    y = out;
  }
  final hiss = math.Random(1);
  return Float32List.fromList([
    for (final s in y) s * level + (hiss.nextDouble() - 0.5) * 0.0006,
  ]);
}

/// What the tuner reads, every 80 ms, in cents from [hz]; null for none.
List<int?> readings(TunerListener tuner, Float32List sound, double hz) {
  const chunk = 3528; // 80 ms
  return [
    for (var at = 0; at + chunk <= sound.length; at += chunk)
      switch (tuner.playToIt(Float32List.sublistView(sound, at, at + chunk))) {
        final heard? => (1200 * math.log(heard.hz / hz) / math.ln2).round(),
        null => null,
      },
  ];
}

void main() {
  const lowE = 82.41;

  for (final take in ['rr1', 'rr2', 'rr3']) {
    test('a quiet low E on a small microphone is read as E ($take)', () {
      final sound = throughSmallMicrophone(
        'assets/sounds/guitar/guitar_40_$take.wav',
      );
      final read = readings(TunerListener(), sound, lowE);
      // The first reading needs a window's worth of sound.
      final heard = read.skip(2).toList();
      final onE = heard.where((c) => c != null && c.abs() < 50).length;
      expect(onE, greaterThanOrEqualTo(heard.length * 0.8), reason: '$read');
      // Never a harmonic, or any other note.
      expect(
        heard.where((c) => c != null && c.abs() >= 50),
        isEmpty,
        reason: '$read',
      );
    });
  }

  test('the B string plucked after the low E is the B', () {
    // B3 is three times E2, to a cent or two: plucked, it is louder at
    // once, and is not taken for the low E's third harmonic.
    final e = throughSmallMicrophone('assets/sounds/guitar/guitar_40_rr1.wav');
    // The recorded A3 played a whole tone faster: B3.
    final a = throughSmallMicrophone(
      'assets/sounds/guitar/guitar_57_rr1.wav',
      level: 0.3,
    );
    final step = math.pow(2, 2 / 12);
    final b = Float32List((a.length / step).floor() - 1);
    for (var i = 0; i < b.length; i++) {
      final x = i * step;
      final j = x.floor();
      b[i] = a[j] + (a[j + 1] - a[j]) * (x - j);
    }
    final tuner = TunerListener();
    readings(tuner, Float32List.sublistView(e, 0, 44100 ~/ 2), lowE);
    final read = readings(tuner, b, 246.94);
    final onB = read.where((c) => c != null && c.abs() < 50).length;
    expect(onB, greaterThanOrEqualTo(read.length * 0.7), reason: '$read');
  });
}
