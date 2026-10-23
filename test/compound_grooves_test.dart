// Every groove in six eight and twelve eight, written in its own
// triplets (compoundDrumBar) rather than the Afro bell standing in for
// all of them or a bar of four with its "and"s moved.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/meter.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';

void main() {
  const triplets = [
    Feel.shuffle,
    Feel.ballad,
    Feel.funk,
    Feel.secondLine,
    Feel.bossa,
    Feel.samba,
    Feel.calypso,
  ];

  List<DrumHit> played(
    Feel feel,
    int pulses, {
    int bar = 0,
    bool brushes = false,
  }) => drumBar(
    feel: feel,
    bar: bar,
    beatsPerBar: pulses,
    random: math.Random(bar),
    swing: tripletSwing,
    brushes: brushes,
    compound: true,
  );

  for (final pulses in [2, 4]) {
    final name = pulses == 2 ? 'six eight' : 'twelve eight';
    group('in $name', () {
      test('every groove is played as itself', () {
        for (final feel in triplets) {
          expect(
            BandStyle.of(feel).inMeter(Meter(pulses * 3, 8)).drums,
            feel,
            reason: feel.name,
          );
        }
      });

      test('every note is on a triplet, inside the bar', () {
        for (final feel in triplets) {
          for (final brushes in [false, true]) {
            for (var bar = 0; bar < 8; bar++) {
              for (final hit in played(
                feel,
                pulses,
                bar: bar,
                brushes: brushes,
              )) {
                final thirds = hit.beat * 3;
                expect(
                  (thirds - thirds.round()).abs(),
                  lessThan(1e-6),
                  reason: '${feel.name} at ${hit.beat}',
                );
                expect(hit.beat, lessThan(pulses));
              }
            }
          }
        }
      });

      test('the backbeat is on 2 (and 4)', () {
        for (final feel in [Feel.shuffle, Feel.funk, Feel.secondLine]) {
          final cracks = {
            for (final hit in played(feel, pulses))
              if (hit.drum == Drum.snare && hit.hard) hit.beat,
          };
          expect(cracks, {
            for (var b = 1; b < pulses; b += 2) b.toDouble(),
          }, reason: feel.name);
        }
      });

      test('the pulse is marked on the first of every bar', () {
        for (final feel in triplets) {
          expect(
            played(feel, pulses).any((hit) => hit.beat == 0),
            isTrue,
            reason: feel.name,
          );
        }
      });
    });
  }

  test('a slow blues in twelve eight: triplets on the ride', () {
    final ride = [
      for (final hit in played(Feel.shuffle, 4))
        if (hit.drum == Drum.ride) hit.beat,
    ];
    expect(ride, hasLength(12));
  });

  test('the funk bass in twelve eight lands on the drum\'s kicks', () {
    final kicks = {
      for (final hit in played(Feel.funk, 4))
        if (hit.drum == Drum.kick) (hit.beat * 3).round(),
    };
    final notes = funkBassLine(
      [(Chord.parse('Em7'), 4)],
      choruses: 1,
      random: math.Random(1),
      swing: tripletSwing,
      compound: true,
    );
    final played_ = {for (final note in notes) (note.beat * 3).round()};
    expect(played_.containsAll(kicks), isTrue, reason: '$kicks $played_');
  });
}
