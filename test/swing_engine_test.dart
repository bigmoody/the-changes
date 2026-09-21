// Whether the band actually swings the way the Swing screen says it
// does: every part that plays an off-beat eighth, asked at two tempos.
//
// The screen teaching one thing while the band played another was the
// state of it for a long time, so these are the tests that matter: not
// that the number is right, but that the number reaches the drums.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

/// The part of a beat each off-beat note sits at, with the ones on the
/// beat left out: what "how much swing" means, measured.
Set<String> offbeatsOf(Iterable<double> beats) => {
  for (final beat in beats)
    if ((beat - beat.roundToDouble()).abs() > 1e-9)
      (beat - beat.floorToDouble()).toStringAsFixed(3),
};

Tune _swingTune() => standards.firstWhere(
  (tune) => tune.style.drums == Feel.swing && tune.title == "Now's the Time",
);

BackingRequest _request({required int tempo, TempoRamp ramp = TempoRamp.off}) {
  final tune = _swingTune();
  return BackingRequest(
    tune: tune,
    loop: LoopRange.wholeTune(tune),
    tempo: tempo,
    comping: Comping.piano,
    seed: 1,
    arrangement: Arrangement(choruses: 4, ramp: ramp),
  );
}

void main() {
  group('the pass decides once', () {
    test('a fast tune swings less than a slow one', () {
      // The whole point of wiring it through. If these came out equal the
      // Swing screen would be teaching something the app does not do.
      expect(
        swingForPass(_request(tempo: 280), 0),
        lessThan(swingForPass(_request(tempo: 100), 0)),
      );
    });

    test('it is the same answer the screen gives', () {
      for (final tempo in [90, 140, 200, 260, 320]) {
        expect(swingForPass(_request(tempo: tempo), 0), swingAt(tempo));
      }
    });

    test('a tempo ramp moves it between passes, not inside one', () {
      // Everybody in a pass has to land in the same place, so the answer
      // is asked once per pass, and a ramp makes later passes straighter
      // because they are faster.
      final ramping = _request(tempo: 120, ramp: const TempoRamp(step: 40));
      final first = swingForPass(ramping, 0);
      final later = swingForPass(ramping, 3);
      expect(later, lessThan(first), reason: 'faster by then, so straighter');
    });
  });

  group('every part that plays one honours it', () {
    test('the drummer puts the ride where it is told', () {
      for (final swing in [straight, tripletSwing, widestSwing]) {
        final hits = drumBar(
          feel: Feel.swing,
          bar: 0,
          beatsPerBar: 4,
          random: math.Random(3),
          swing: swing,
        );
        final off = offbeatsOf([for (final hit in hits) hit.beat]);
        expect(off, isNotEmpty, reason: 'swing has off-beat strokes');
        expect(off, {swing.toStringAsFixed(3)}, reason: 'at $swing');
      }
    });

    test('so does the drummer trading fours', () {
      for (final swing in [straight, tripletSwing, widestSwing]) {
        final off = offbeatsOf([
          for (var seed = 0; seed < 25; seed++)
            for (final hit in drumSoloBar(
              feel: Feel.swing,
              bar: 0,
              of: 4,
              beatsPerBar: 4,
              random: math.Random(seed),
              swing: swing,
            ))
              hit.beat,
        ]);
        expect(off, isNotEmpty);
        expect(off, {swing.toStringAsFixed(3)}, reason: 'at $swing');
      }
    });

    test('and the bass, wherever it ghosts or pushes', () {
      // The bassist nudges everything by up to a hundredth of a beat, so
      // an exact match is the wrong question here. What matters is that
      // the off-beat notes sit on the swing and move when it does.
      //
      // Not quite all of them: a pickup ghosted off a note that is
      // already on the "and" lands a swing further on again, which is a
      // triplet partial and was doing that long before any of this.
      for (final swing in [tripletSwing, widestSwing]) {
        final between = [
          for (var seed = 0; seed < 40; seed++)
            for (final note in walkingBassLine(
              [
                (Chord.parse('Dm7'), 4),
                (Chord.parse('G7'), 4),
                (Chord.parse('C^7'), 4),
              ],
              choruses: 2,
              random: math.Random(seed),
              swing: swing,
            ))
              if (note.beat - note.beat.floorToDouble() case final part
                  when part > 0.2 && part < 0.9)
                part,
        ];
        expect(between, isNotEmpty, reason: 'somebody ghosted, at $swing');
        final onTheSwing = between
            .where((part) => (part - swing).abs() < 0.021)
            .length;
        expect(
          onTheSwing / between.length,
          greaterThan(0.8),
          reason: 'nearly all of them are on the swing, at $swing',
        );
        // And none of them is playing an even eighth under a swing line.
        for (final part in between) {
          expect(part, isNot(closeTo(straight, 0.021)), reason: 'at $swing');
        }
      }
    });

    test('and the comper', () {
      for (final swing in [straight, tripletSwing, widestSwing]) {
        final off = offbeatsOf([
          for (var seed = 0; seed < 25; seed++)
            for (final hit in Comper(
              math.Random(seed),
            ).comp(Chord.parse('Dm7'), 4, Feel.swing, swing: swing))
              hit.beat,
        ]);
        expect(off, isNotEmpty);
        expect(off, {swing.toStringAsFixed(3)}, reason: 'at $swing');
      }
    });

    test('and the arpeggios', () {
      for (final swing in [straight, tripletSwing, widestSwing]) {
        final line = arpeggioLine(
          [(Chord.parse('Dm7'), 4)],
          choruses: 1,
          swing: swing,
        );
        final off = offbeatsOf([for (final note in line.notes) note.beat]);
        expect(off, {swing.toStringAsFixed(3)}, reason: 'at $swing');
      }
    });
  });

  group('what does not move', () {
    test('a shuffle keeps its triplet, whatever the tempo', () {
      // A shuffle is a triplet feel by definition; it is the swing that
      // flexes, not the shuffle. Passing it a straight swing changes
      // nothing, because it never asked.
      final loose = drumBar(
        feel: Feel.shuffle,
        bar: 0,
        beatsPerBar: 4,
        random: math.Random(5),
        swing: straight,
      );
      final tight = drumBar(
        feel: Feel.shuffle,
        bar: 0,
        beatsPerBar: 4,
        random: math.Random(5),
        swing: widestSwing,
      );
      expect([for (final h in loose) h.beat], [for (final h in tight) h.beat]);
      expect(
        offbeatsOf([for (final h in loose) h.beat]),
        contains(tripletSwing.toStringAsFixed(3)),
      );
    });

    test('an even feel stays even', () {
      for (final feel in [Feel.bossa, Feel.funk, Feel.calypso, Feel.samba]) {
        final swung = drumBar(
          feel: feel,
          bar: 0,
          beatsPerBar: 4,
          random: math.Random(2),
          swing: widestSwing,
        );
        final even = drumBar(
          feel: feel,
          bar: 0,
          beatsPerBar: 4,
          random: math.Random(2),
          swing: straight,
        );
        expect(
          [for (final h in swung) h.beat],
          [for (final h in even) h.beat],
          reason: '$feel',
        );
      }
    });

    test('the beats themselves never move', () {
      // Swinging harder must not turn into a tempo change in disguise.
      for (final swing in [straight, widestSwing]) {
        final hits = drumBar(
          feel: Feel.swing,
          bar: 0,
          beatsPerBar: 4,
          random: math.Random(3),
          swing: swing,
        );
        final ride = [
          for (final hit in hits)
            if (hit.drum == Drum.ride && hit.beat == hit.beat.roundToDouble())
              hit.beat,
        ];
        expect(ride, [0.0, 1.0, 2.0, 3.0], reason: 'at $swing');
      }
    });
  });
}
