// Licks in context: each one sits over its changes, moves the way it is
// played in every key, is spelled by its chord, and can be heard over the
// band playing those changes.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/practice/licks.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/screens/swing_screen.dart' show ridePattern;

const _keys = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B', //
];

void main() {
  for (final lick in licks) {
    group(lick.name, () {
      test('whole bars, and every note inside them', () {
        expect(lick.beats % 4, 0);
        for (final note in lick.notes) {
          expect(note.at + note.length, lessThanOrEqualTo(lick.beats));
        }
        expect(lick.about, isNot(contains('—')));
      });

      test('in every key: in range, and moving the way it is played', () {
        for (final key in _keys) {
          final line = lickIn(lick, key, floor: 58);
          for (final (i, e) in line.indexed) {
            expect(e.pitch, inInclusiveRange(58, 92), reason: key);
            if (i > 0) {
              expect(
                (e.pitch - line[i - 1].pitch).abs(),
                lessThanOrEqualTo(9),
                reason: '$key: ${line[i - 1].name} to ${e.name}',
              );
            }
          }
        }
      });
    });
  }

  test('spelled by the chord: the ♭9 of G7 is A♭, not G♯', () {
    final lick = licks.firstWhere((l) => l.name.startsWith('Up the ii'));
    final names = lickIn(lick, 'C', floor: 58).map((e) => e.name);
    expect(names, contains('A♭'));
    expect(names, isNot(contains('G♯')));
    expect(changesIn(lick, 'C').map((c) => c.chord.display), [
      'Dm7',
      'G7',
      'CΔ7',
    ]);
  });

  test('the enclosure surrounds the third of the I', () {
    final lick = licks.firstWhere((l) => l.name == 'Enclosure Into the Third');
    final line = lickIn(lick, 'C', floor: 58);
    final last = line.sublist(line.length - 3).map((e) => e.name);
    expect(last, ['F', 'D♯', 'E']);
  });

  test('every lick the roadmap names exists', () {
    final names = {for (final l in licks) l.name};
    for (final instrument in RoadmapInstrument.values) {
      for (final stage in stagesFor(instrument)) {
        for (final block in stage.blocks) {
          expect(names, containsAll(block.licks ?? const <String>[]));
        }
      }
    }
  });

  test('the lick can be heard over the band', () async {
    final bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
    const tempo = 120;
    List<SnippetDrum> ride(int bars) =>
        ridePattern(tempo: tempo, at: 0.66, bars: bars);
    // How strong [hz] is in [wav] between [from] and [to] seconds: the
    // level at the note's own pitch, which the lick adds to and the band,
    // playing other notes, mostly does not. A plain level would not do:
    // every snippet is scaled to the same peak.
    double at(Uint8List wav, double hz, double from, double to) {
      final pcm = Int16List.sublistView(Uint8List.fromList(wav.sublist(44)));
      final a = (from * 44100).round();
      final b = math.min(pcm.length, (to * 44100).round());
      final w = 2 * math.pi * hz / 44100;
      var re = 0.0, im = 0.0;
      for (var i = a; i < b; i++) {
        re += pcm[i] * math.cos(w * i);
        im += pcm[i] * math.sin(w * i);
      }
      return math.sqrt(re * re + im * im) / (b - a);
    }

    for (final lick in licks) {
      Uint8List render(bool withLick) {
        final band = lickBand(
          lick,
          'F',
          tempo: tempo,
          times: 1,
          floor: 58,
          lickOn: (_) => withLick,
          ride: ride,
        );
        return renderSnippet(
          bank,
          band.notes,
          drums: band.drums,
          pianoRelease: 0.08,
        );
      }

      final without = render(false);
      final withLick = render(true);
      final line = lickIn(lick, 'F', floor: 58);
      final starts = lickStarts(lick, tempo);
      var gain = 0.0;
      for (final (i, e) in line.indexed) {
        final hz = 440 * math.pow(2, (e.pitch - 69) / 12).toDouble();
        final from = starts[i] * 60 / tempo + 0.01;
        final to = from + 0.08;
        gain +=
            20 *
            math.log(at(withLick, hz, from, to) / at(without, hz, from, to)) /
            math.ln10;
      }
      gain /= line.length;
      // ignore: avoid_print
      print('${lick.name}: ${gain.toStringAsFixed(1)} dB at its own notes');
      expect(gain, greaterThan(10), reason: '${lick.name} heard over the band');
    }
  });
}
