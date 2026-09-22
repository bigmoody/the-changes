// The guitar's dynamics.
//
// The complaint these exist for was that the guitar sounded cheap, and the
// cause was that it had one recorded stroke: playing harder only turned it
// up. So what is checked here is the thing that was wrong, stated as
// plainly as it can be. A loud note must not be a quiet note with the
// volume raised, and the change between them must arrive gradually rather
// than at an edge a strum can fall off.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';

/// One guitar note on its own, rendered at [velocity].
List<double> _note(SampleBank bank, double velocity) {
  final wav = renderSnippet(bank, [
    (pitch: 60, start: 0.0, length: 1.5, velocity: velocity, bass: false),
  ], guitar: true);
  return [for (final s in decodeWav(wav)) s / 32768];
}

double _peak(List<double> s) =>
    s.fold(0, (most, x) => x.abs() > most ? x.abs() : most);

double _rms(List<double> s) =>
    math.sqrt(s.fold(0.0, (sum, x) => sum + x * x) / s.length);

/// How spiky the sound is: a hard pick stroke has a far bigger attack
/// against the note it leaves ringing than a gentle one does.
double _punch(List<double> s) => _peak(s) / _rms(s);

void main() {
  late SampleBank bank;

  setUpAll(() async {
    bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
  });

  test('every note has both strokes recorded', () {
    for (final layers in bank.guitar.values) {
      expect(layers.length, 2);
      for (final takes in layers) {
        expect(takes.length, 2);
        expect(takes.every((take) => take.isNotEmpty), isTrue);
      }
    }
  });

  test('a hard note is not a soft one turned up', () {
    final soft = _note(bank, 0.25);
    final hard = _note(bank, 1);
    // A rendered snippet is levelled, so the two come out the same height
    // and the question is what shape they are underneath it. If the
    // guitar had one stroke they would be the same shape and this ratio
    // would be 1.
    expect(
      _punch(hard) / _punch(soft),
      greaterThan(1.25),
      reason: 'the loud note is the quiet one with the fader up',
    );
  });

  test('the tone moves right through the middle of the range', () {
    // Where comping actually lives. If the change happened at an edge,
    // these would come in two flat groups instead of climbing.
    final punches = [
      for (final velocity in [0.35, 0.5, 0.65, 0.8, 0.95])
        _punch(_note(bank, velocity)),
    ];
    for (var i = 1; i < punches.length; i++) {
      expect(
        punches[i],
        greaterThan(punches[i - 1] * 0.98),
        reason: 'it went backwards at step $i: $punches',
      );
    }
    expect(punches.last / punches.first, greaterThan(1.15));
  });

  test('the quietest and loudest are the strokes themselves', () {
    // Below and above the crossfade only one recording sounds, so nothing
    // is being blended where it need not be.
    final under = _note(bank, guitarSoftest - 0.05);
    final over = _note(bank, guitarSoftest + guitarCrossfade + 0.05);
    expect(_punch(over) / _punch(under), greaterThan(1.3));
  });
}
