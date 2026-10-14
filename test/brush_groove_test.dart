// What a brush player plays, as opposed to what they play it on.
//
// Swapping the kit alone was not enough and sounded wrong in exactly the
// way you would predict: a swing groove keeps the time on the ride, so a
// brush kit under the old pattern came out as a brushed cymbal. A brushed
// cymbal is wirier than a stick-struck one, so the kit that was meant to
// take the metal out put more in.
//
// What a brush player actually does is move the time onto the snare head
// and keep a circle going underneath it, and that is a change to the
// pattern rather than to the samples.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/music/tune.dart';

/// Every hit over [bars] bars of [feel].
List<DrumHit> played(
  Feel feel, {
  bool brushes = false,
  int beatsPerBar = 4,
  int bars = 32,
}) {
  final random = math.Random(7);
  return [
    for (var bar = 0; bar < bars; bar++)
      ...drumBar(
        feel: feel,
        bar: bar,
        beatsPerBar: beatsPerBar,
        random: random,
        swing: 0.62,
        brushes: brushes,
      ),
  ];
}

int countOf(List<DrumHit> hits, Drum drum) =>
    hits.where((hit) => hit.drum == drum).length;

void main() {
  group('swing, with the brushes out', () {
    test('the cymbal is not touched at all', () {
      // The whole complaint: brushes that sounded metallic, because the
      // time was still on the ride and only the stick had changed.
      expect(countOf(played(Feel.swing), Drum.ride), greaterThan(0));
      expect(countOf(played(Feel.swing, brushes: true), Drum.ride), 0);
    });

    test('the time moves to the snare head, beat for beat', () {
      // Not fewer notes played more quietly: the same rhythm, moved.
      expect(
        countOf(played(Feel.swing, brushes: true), Drum.snare),
        countOf(played(Feel.swing), Drum.ride),
      );
    });

    test('and a circle turns underneath it, one every two beats', () {
      // Half a circle to a beat, which is how it is played.
      expect(countOf(played(Feel.swing, brushes: true), Drum.swirl), 2 * 32);
    });

    test('the circles land on the beat, never between', () {
      for (final hit in played(Feel.swing, brushes: true)) {
        if (hit.drum != Drum.swirl) continue;
        expect(hit.beat % 1, 0, reason: 'a circle at ${hit.beat}');
      }
    });

    test('the hi-hat still closes underfoot on the backbeat', () {
      expect(
        countOf(played(Feel.swing, brushes: true), Drum.hiHatPedal),
        countOf(played(Feel.swing), Drum.hiHatPedal),
      );
    });

    test('and the kick is still feathered rather than dropped', () {
      final kicks = played(
        Feel.swing,
        brushes: true,
      ).where((hit) => hit.drum == Drum.kick);
      expect(kicks, isNotEmpty);
      expect(kicks.every((hit) => hit.velocity < 0.25), isTrue);
    });
  });

  group('a bar that does not divide in two', () {
    test('a waltz turns one circle a bar rather than one and a half', () {
      // Two beats to a circle leaves half of one hanging over the bar
      // line in three. Better a slower circle than a broken one.
      final hits = played(Feel.swing, brushes: true, beatsPerBar: 3, bars: 12);
      expect(countOf(hits, Drum.swirl), 12);
      for (final hit in hits.where((hit) => hit.drum == Drum.swirl)) {
        expect(hit.beat, 0);
      }
    });
  });

  group('a bossa, with the brushes out', () {
    // The second half of the same mistake. A bossa's pulse is steady
    // eighths on the hi-hat, and a fan of wire on a closed hi-hat is a
    // thin scratch, so a brush kit under the stick pattern came out
    // more metallic than the sticks had been.
    test('the hi-hat stops keeping the eighths', () {
      expect(countOf(played(Feel.bossa), Drum.hiHatClosed), greaterThan(0));
      expect(countOf(played(Feel.bossa, brushes: true), Drum.hiHatClosed), 0);
    });

    test('and the cymbal is not reached for either', () {
      // The stick bossa moves to the ride for a section at a time.
      expect(countOf(played(Feel.bossa), Drum.ride), greaterThan(0));
      expect(countOf(played(Feel.bossa, brushes: true), Drum.ride), 0);
    });

    test('a circle keeps them instead, one to a beat', () {
      // Standing in for the ganza running under the groove, which is
      // quicker than the arm's circle in a swing feel.
      final hits = played(Feel.bossa, brushes: true);
      expect(countOf(hits, Drum.swirl), 4 * 32);
      for (final hit in hits.where((hit) => hit.drum == Drum.swirl)) {
        expect(hit.beats, 1);
      }
    });

    test('and a swing circle still takes two beats', () {
      for (final hit in played(
        Feel.swing,
        brushes: true,
      ).where((hit) => hit.drum == Drum.swirl)) {
        expect(hit.beats, 2);
      }
    });

    test('the clave stays on the edge of the drum', () {
      expect(
        countOf(played(Feel.bossa, brushes: true), Drum.crossStick),
        countOf(played(Feel.bossa), Drum.crossStick),
      );
    });

    test('and the kick still plays the surdo', () {
      expect(
        countOf(played(Feel.bossa, brushes: true), Drum.kick),
        greaterThan(0),
      );
    });
  });

  group('the other grooves are left alone', () {
    // Brushes belong to a swing feel and to a bossa. A funk backbeat is
    // not played with them, and a brush kit under one is a choice
    // somebody made rather than a pattern that should rewrite itself.
    for (final feel in [Feel.funk, Feel.samba, Feel.calypso]) {
      test('${feel.name} plays the same bar either way', () {
        final sticks = played(feel);
        final brushed = played(feel, brushes: true);
        expect(brushed.length, sticks.length);
        for (var i = 0; i < sticks.length; i++) {
          expect(brushed[i].drum, sticks[i].drum);
          expect(brushed[i].beat, sticks[i].beat);
        }
      });
    }

    test('and none of them reaches for a swirl', () {
      for (final feel in Feel.values) {
        if (feel == Feel.swing || feel == Feel.bossa) continue;
        expect(countOf(played(feel, brushes: true), Drum.swirl), 0);
      }
    });
  });
}
