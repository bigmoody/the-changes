// The guitar library, as it now is.
//
// It used to carry two recorded dynamics and crossfade between them. That
// went after measuring it: with the tone rolled back to 3 kHz the two
// strokes came out 0 to 7 per cent apart in brightness, in no consistent
// direction, so a firmer stroke was only a louder one and velocity
// already does louder. What is left is one gentle stroke in three takes,
// and these say so, so that nobody adds a layer back without first
// checking it earns its download.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';

/// One guitar note on its own, rendered at [velocity], dry: this measures
/// the instrument, and a room's tail would colour it.
List<double> _note(SampleBank bank, double velocity) {
  final wav = renderSnippet(
    bank,
    [(pitch: 60, start: 0.0, length: 1.5, velocity: velocity, bass: false)],
    guitar: true,
    room: false,
  );
  return [for (final s in decodeWav(wav)) s / 32768];
}

/// Energy above 2 kHz against energy overall.
double _brightness(List<double> s) {
  final a = math.exp(-2 * math.pi * 2000 / 44100);
  var hp = 0.0;
  var previous = 0.0;
  var high = 0.0;
  var all = 0.0;
  for (final x in s) {
    hp = a * (hp + x - previous);
    previous = x;
    high += hp * hp;
    all += x * x;
  }
  return all == 0 ? 0 : math.sqrt(high / all);
}

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  test('three takes of every note, and all of them there', () {
    expect(bank.guitar.notes.length, SampleBank.guitarPitches.length);
    for (final takes in bank.guitar.notes.values) {
      expect(takes.length, 3);
      expect(takes.every((take) => take.isNotEmpty), isTrue);
    }
  });

  test('the takes of a note match each other', () {
    // They are alternated at random, so one brighter than the rest would
    // be heard as a wobble through a comp.
    for (final MapEntry(key: pitch, value: takes)
        in bank.guitar.notes.entries) {
      final bright = [
        for (final take in takes)
          _brightness([for (final s in take) s / 32768]),
      ];
      expect(
        bright.reduce(math.max) / bright.reduce(math.min),
        lessThan(1.35),
        reason: 'pitch $pitch: the takes do not sound alike',
      );
    }
  });

  test(
    'it is one stroke: the tone does not change with how hard it is hit',
    () {
      // The positive statement of what was measured. If somebody adds a
      // velocity layer back, this fails, and they should then delete it and
      // say why in the commit rather than leaving both true.
      final quiet = _brightness(_note(bank, 0.3));
      final loud = _brightness(_note(bank, 1));
      expect(loud / quiet, closeTo(1, 0.1));
    },
  );

  test('but playing harder is still louder', () {
    double rms(List<double> s) =>
        math.sqrt(s.fold(0.0, (sum, x) => sum + x * x) / s.length);
    // Rendered snippets are levelled, so this is measured before that: a
    // note asked for at full velocity carries more of the mix than a
    // quiet one in the same render.
    final wav = renderSnippet(
      bank,
      [
        (pitch: 55, start: 0.0, length: 1.0, velocity: 0.25, bass: false),
        (pitch: 67, start: 1.5, length: 1.0, velocity: 1.0, bass: false),
      ],
      guitar: true,
      room: false,
    );
    final s = [for (final x in decodeWav(wav)) x / 32768];
    final first = rms(s.sublist(0, 44100));
    final second = rms(s.sublist((1.5 * 44100).round(), (2.5 * 44100).round()));
    expect(second / first, greaterThan(1.8));
  });
}
