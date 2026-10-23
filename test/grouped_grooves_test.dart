// Every groove in three, five and seven, played as groups of two and
// three (grouped_grooves.dart) rather than a bar of four cut short or
// with a beat stuck on.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/grouped_grooves.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/comping.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';

void main() {
  test('five is three and two, seven is two, two and three', () {
    expect(meterGroups(3), [3]);
    expect(meterGroups(5), [3, 2]);
    expect(groupStarts(5), [0, 3]);
    expect(meterGroups(7), [2, 2, 3]);
    expect(groupStarts(7), [0, 2, 4]);
  });

  List<DrumHit> played(
    Feel feel,
    int beats, {
    int bar = 0,
    bool brushes = false,
  }) => drumBar(
    feel: feel,
    bar: bar,
    beatsPerBar: beats,
    random: math.Random(bar),
    swing: straight,
    brushes: brushes,
  );

  const drummed = [
    Feel.swing,
    Feel.jazzWaltz,
    Feel.ballad,
    Feel.shuffle,
    Feel.funk,
    Feel.bossa,
    Feel.samba,
    Feel.calypso,
    Feel.secondLine,
  ];

  for (final beats in [3, 5, 7]) {
    group('in $beats', () {
      test('every groove marks the front of every group', () {
        for (final feel in drummed) {
          for (final brushes in [false, true]) {
            for (var bar = 0; bar < 8; bar++) {
              final hits = played(feel, beats, bar: bar, brushes: brushes);
              for (final start in groupStarts(beats)) {
                expect(
                  hits.any((hit) => (hit.beat - start).abs() < 0.01),
                  isTrue,
                  reason: '${feel.name} brushes $brushes bar $bar: $start',
                );
              }
              expect(
                hits.every((hit) => hit.beat < beats),
                isTrue,
                reason: '${feel.name} hangs off the bar',
              );
            }
          }
        }
      });

      test('the hi-hat foot closes at the end of each group', () {
        if (beats == 3) return; // the jazz waltz keeps its 2 and 3
        final ends = [
          for (final (g, start) in groupStarts(beats).indexed)
            start + meterGroups(beats)[g] - 1.0,
        ];
        for (final feel in [Feel.swing, Feel.bossa, Feel.calypso]) {
          final feet = [
            for (final hit in played(feel, beats))
              if (hit.drum == Drum.hiHatPedal) hit.beat,
          ]..sort();
          expect(feet, ends, reason: feel.name);
        }
      });

      test('a funk backbeat cracks at the end of each group', () {
        final snares = {
          for (final hit in played(Feel.funk, beats))
            if (hit.drum == Drum.snare && hit.hard) hit.beat,
        };
        expect(snares, {
          for (final (g, start) in groupStarts(beats).indexed)
            start + meterGroups(beats)[g] - 1.0,
        });
      });

      test('no groove is swing standing in', () {
        for (final feel in drummed) {
          expect(feel.standIn(Meter(beats, 4)), feel, reason: feel.name);
        }
      });
    });
  }

  test('the funk bass in five plays on the drum\'s kicks', () {
    final chords = [(Chord.parse('Em7'), 5), (Chord.parse('A7'), 5)];
    final notes = funkBassLine(
      chords,
      choruses: 4,
      random: math.Random(2),
      swing: straight,
      beatsPerBar: 5,
    );
    for (var bar = 0; bar < 8; bar++) {
      final kicks = {
        for (final (g, start) in groupStarts(5).indexed)
          for (final kick in groupKicks(
            Feel.funk,
            meterGroups(5)[g],
            bar: bar,
            group: g,
          ))
            bar * 5 + start + kick,
      };
      final onBeat = {
        for (final note in notes)
          if (note.beat >= bar * 5 && note.beat < bar * 5 + 5)
            (note.beat * 2).round() / 2,
      };
      expect(onBeat.containsAll(kicks), isTrue, reason: 'bar $bar');
    }
  });

  test('a two-feel in seven fills the bar', () {
    final notes = twoFeelBassLine(
      [(Chord.parse('Dm7'), 7)],
      choruses: 4,
      random: math.Random(1),
      swing: tripletSwing,
      beatsPerBar: 7,
    );
    final last = notes
        .where((n) => n.beat < 7)
        .map((n) => n.beat)
        .reduce(math.max);
    expect(last, greaterThanOrEqualTo(4), reason: 'it went quiet after 3');
  });

  test('Twice a Bar in five is 1 and 4: the halves of Take Five', () {
    expect(
      [
        for (final (beat, _, _) in CompFigure.twice.strikes(
          0.5,
          beatsPerBar: 5,
        ))
          beat,
      ],
      [0.0, 3.0],
    );
  });
}
