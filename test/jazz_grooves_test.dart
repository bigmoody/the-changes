// The grooves a jazz band plays that the app could not: a waltz, a
// ballad, the New Orleans street beat and gypsy jazz.
//
// The first two were reachable before by picking swing and changing
// something else, and that is exactly why they are worth naming. Swing counted in
// three puts a skip note after every backbeat, which is a hurried waltz;
// swing at 60 beats a minute walks the bass and comps behind you, which
// is a ballad nobody plays. What changes in each is who plays what, not
// how fast it goes.
//
// The other two are not swing at all: a second line has no cymbal in it
// and gypsy jazz has no drummer, so what carries the time is the kick
// and the snare in one and the guitar's chop in the other.
//
// Where the patterns come from is written down in tool/groove_sources.txt
// beside the samples' own sources.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/guitar_comping.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/ireal_export.dart';
import 'package:play_along/music/ireal_import.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

/// One bar, written straight so the beats can be read as they were
/// written. [bar] picks which bar of the phrase it is.
List<DrumHit> bar(
  Feel feel, {
  bool brushes = false,
  int beatsPerBar = 3,
  int bar = 0,
  int seed = 7,
}) => drumBar(
  feel: feel,
  bar: bar,
  beatsPerBar: beatsPerBar,
  random: math.Random(seed),
  swing: straight,
  brushes: brushes,
);

/// The beats [drum] is played on, over [bars] bars of the same groove.
List<double> beatsOf(
  Feel feel,
  Drum drum, {
  bool brushes = false,
  int beatsPerBar = 3,
  int bars = 1,
  int seed = 7,
}) => [
  for (var i = 0; i < bars; i++)
    ...bar(
      feel,
      brushes: brushes,
      beatsPerBar: beatsPerBar,
      bar: i,
      seed: seed + i,
    ).where((hit) => hit.drum == drum).map((hit) => hit.beat),
];

void main() {
  group('the jazz waltz', () {
    test('the ride lifts after 2 and leaves 3 plain', () {
      // "One, two, and-of-two, three": the figure a waltz is taught as.
      // Beat three is the one that has to stay plain, because a skip
      // note there is what makes it swing in three instead.
      for (var i = 0; i < 32; i++) {
        final ride = bar(
          Feel.jazzWaltz,
          bar: i,
          seed: i,
        ).where((hit) => hit.drum == Drum.ride).map((hit) => hit.beat);
        expect(ride, containsAll([0.0, 1.0, 1.5, 2.0]), reason: 'bar $i');
        expect(ride, isNot(contains(0.5)), reason: 'nothing after 1');
      }
    });

    test('and it is a different bar from swing counted in three', () {
      // Swing in three skips after every backbeat, so it carries the
      // "and" of 3 in every bar. The waltz reaches past the bar now and
      // then, which is where its other syncopations live, but it is the
      // exception there rather than the pattern.
      var waltz = 0;
      var swing = 0;
      for (var i = 0; i < 64; i++) {
        bool skips(Feel feel) => bar(
          feel,
          bar: i,
          seed: i,
        ).any((hit) => hit.drum == Drum.ride && hit.beat == 2.5);
        if (skips(Feel.jazzWaltz)) waltz++;
        if (skips(Feel.swing)) swing++;
      }
      expect(swing, 64);
      expect(waltz, lessThan(32));
    });

    test('the hi-hat closes under 2 and 3', () {
      expect(beatsOf(Feel.jazzWaltz, Drum.hiHatPedal), [1.0, 2.0]);
    });

    test('the kick is feathered, never dropped', () {
      final kicks = bar(
        Feel.jazzWaltz,
        bar: 3,
      ).where((hit) => hit.drum == Drum.kick);
      expect(kicks, isNotEmpty);
      for (final kick in kicks) {
        expect(kick.velocity, lessThan(0.2), reason: 'felt, not heard');
        expect(kick.hard, isFalse, reason: 'no bombs in a waltz');
      }
    });

    test('the lift lands late once the feel is swung', () {
      final swung = drumBar(
        feel: Feel.jazzWaltz,
        bar: 0,
        beatsPerBar: 3,
        random: math.Random(7),
        swing: tripletSwing,
      ).where((hit) => hit.drum == Drum.ride).map((hit) => hit.beat);
      expect(swung, contains(closeTo(1 + tripletSwing, 1e-9)));
    });

    test('with brushes the time moves onto the head, one circle a bar', () {
      final brushed = bar(Feel.jazzWaltz, brushes: true);
      expect(
        brushed.where((hit) => hit.drum == Drum.ride),
        isEmpty,
        reason: 'the cymbal is not touched',
      );
      expect(
        beatsOf(Feel.jazzWaltz, Drum.snare, brushes: true),
        containsAll([0.0, 1.0, 1.5, 2.0]),
        reason: 'the ride figure, tapped on the head',
      );
      final circles = brushed.where((hit) => hit.drum == Drum.swirl).toList();
      expect(circles, hasLength(1));
      expect(circles.single.beat, 0);
      expect(
        circles.single.beats,
        3,
        reason: 'a circle that takes the whole bar, not two thirds of one',
      );
    });

    test('the band walks three and comps as it does in four', () {
      final style = BandStyle.of(Feel.jazzWaltz);
      expect(style.bass, BassStyle.walking);
      expect(style.piano, PianoStyle.swing);
      expect(Feel.jazzWaltz.swings, isTrue);
    });
  });

  group('the ballad', () {
    test('with brushes the right hand only touches 2 and 4', () {
      // The left hand circles without stopping and the pulse is in the
      // change of direction; the right hand is not keeping time at all.
      expect(beatsOf(Feel.ballad, Drum.snare, brushes: true, beatsPerBar: 4), [
        1.0,
        3.0,
      ]);
      expect(beatsOf(Feel.ballad, Drum.swirl, brushes: true, beatsPerBar: 4), [
        0.0,
        2.0,
      ], reason: 'half a circle to a beat');
      expect(
        bar(
          Feel.ballad,
          brushes: true,
          beatsPerBar: 4,
        ).where((hit) => hit.drum == Drum.ride),
        isEmpty,
      );
    });

    test('an odd bar gets one circle rather than a hanging half', () {
      final circles = bar(
        Feel.ballad,
        brushes: true,
      ).where((hit) => hit.drum == Drum.swirl).toList();
      expect(circles, hasLength(1));
      expect(circles.single.beats, 3);
    });

    test('with sticks it is quarters and one skip note, quietly', () {
      final hits = bar(Feel.ballad, beatsPerBar: 4);
      expect(beatsOf(Feel.ballad, Drum.ride, beatsPerBar: 4), [
        0.0,
        1.0,
        2.0,
        3.0,
        3.5,
      ]);
      expect(beatsOf(Feel.ballad, Drum.hiHatPedal, beatsPerBar: 4), [1.0, 3.0]);
      final ride = hits.where((hit) => hit.drum == Drum.ride);
      for (final hit in ride) {
        expect(hit.velocity, lessThan(0.5), reason: 'under a swing ride');
      }
    });

    test('nobody comments: no bombs, no fills, no snare answers', () {
      for (var i = 0; i < 64; i++) {
        final hits = bar(Feel.ballad, beatsPerBar: 4, bar: i, seed: i);
        expect(
          hits.where((hit) => hit.drum == Drum.snare),
          isEmpty,
          reason: 'bar $i',
        );
        expect(hits.where((hit) => hit.hard), isEmpty, reason: 'bar $i');
      }
    });

    test('the bass plays two and the piano holds the chord', () {
      final style = BandStyle.of(Feel.ballad);
      expect(style.bass, BassStyle.twoFeel);
      expect(style.piano, PianoStyle.held);
      expect(Feel.ballad.swings, isTrue, reason: 'a ballad is still swung');
    });

    test('and it is a ballad tempo or it is something else', () {
      expect(Feel.ballad.tempoFor(200), 85);
      expect(Feel.ballad.tempoFor(60), 60);
      expect(Feel.jazzWaltz.tempoFor(60), 80);
    });
  });

  group('the second line', () {
    test('the kick picks up off the beat after each backbeat', () {
      // "1, the a of 1, the and of 2, 3, the a of 3, the and of 4" is
      // the skeleton; the kick takes the downbeats and the pickups.
      expect(beatsOf(Feel.secondLine, Drum.kick, beatsPerBar: 4), [
        0.0,
        1.5,
        2.0,
        3.5,
      ]);
    });

    test('and nothing touches a cymbal', () {
      // A brass band has a bass drum and a snare. That is the band.
      for (var i = 0; i < 16; i++) {
        final hits = bar(Feel.secondLine, beatsPerBar: 4, bar: i, seed: i);
        expect(
          hits.where(
            (hit) =>
                hit.drum == Drum.ride ||
                hit.drum == Drum.hiHatClosed ||
                hit.drum == Drum.hiHatOpen,
          ),
          isEmpty,
          reason: 'bar $i',
        );
      }
    });

    test('the backbeat cracks and the ghost notes stay under it', () {
      final snares = bar(
        Feel.secondLine,
        beatsPerBar: 4,
      ).where((hit) => hit.drum == Drum.snare).toList();
      final cracks = snares.where((hit) => hit.hard);
      expect(cracks.map((hit) => hit.beat), containsAll([1.0, 3.0]));
      for (final ghost in snares.where((hit) => !hit.hard && hit.beat < 3.4)) {
        expect(ghost.velocity, lessThan(0.25), reason: 'at ${ghost.beat}');
      }
    });

    test('it swings, and the band walks under it', () {
      expect(Feel.secondLine.swings, isTrue);
      expect(BandStyle.of(Feel.secondLine).bass, BassStyle.walking);
      expect(Feel.secondLine.hasDrums, isTrue);
    });
  });

  group('gypsy jazz', () {
    test('there is no drummer, in any bar or any metre', () {
      for (final beats in [3, 4, 5]) {
        for (var i = 0; i < 16; i++) {
          expect(
            bar(Feel.gypsy, beatsPerBar: beats, bar: i, seed: i),
            isEmpty,
            reason: '$beats/4, bar $i',
          );
          expect(
            bar(Feel.gypsy, beatsPerBar: beats, bar: i, seed: i, brushes: true),
            isEmpty,
            reason: 'nor with brushes',
          );
        }
      }
      expect(Feel.gypsy.hasDrums, isFalse);
    });

    test('la pompe is four short chops with 2 and 4 carrying', () {
      final guitar = GuitarComper(math.Random(7));
      final hits = guitar.comp(
        Chord.parse('Am6')!,
        4,
        style: PianoStyle.laPompe,
        groove: Feel.gypsy,
        beatInBar: 0,
        bar: 0,
        swing: tripletSwing,
      );
      final downs = hits.where((hit) => hit.strum == Strum.down).toList();
      expect(downs.map((hit) => hit.beat), [0.0, 1.0, 2.0, 3.0]);
      for (final hit in downs) {
        expect(hit.length, lessThan(0.4), reason: 'the left hand mutes it');
      }
      final on2 = downs.firstWhere((hit) => hit.beat == 1);
      final on1 = downs.firstWhere((hit) => hit.beat == 0);
      expect(on2.velocity, greaterThan(on1.velocity));
      // The grace upstroke that lifts into 1 and 3, written where it
      // sounds: just before the stroke it leads to.
      final ups = hits.where((hit) => hit.strum == Strum.up);
      expect(ups.map((hit) => hit.beat), [1.9, 3.9]);
      for (final up in ups) {
        expect(up.velocity, lessThan(0.4), reason: 'a grace note, not a beat');
      }
    });

    test('and the band it belongs to', () {
      expect(BandStyle.of(Feel.gypsy).piano, PianoStyle.laPompe);
      expect(figuresApply(PianoStyle.laPompe, Comping.guitar), isFalse);
      expect(Feel.gypsy.swings, isTrue);
    });
  });

  group('sharing them', () {
    UserProgression progressionIn(Feel feel) => UserProgression(
      id: 'x',
      title: 'Test',
      key: 'C',
      tempo: feel.tempoFor(120),
      bars: const ['C'],
      style: BandStyle.of(feel),
      beatsPerBar: feel == Feel.jazzWaltz ? 3 : 4,
    );

    test('iReal Pro has names for both, and they go out under them', () {
      expect(
        irealLinkFor(progressionIn(Feel.jazzWaltz)),
        contains('Jazz%20Waltz'),
      );
      expect(
        irealLinkFor(progressionIn(Feel.ballad)),
        contains('Ballad%20Swing'),
      );
    });

    test('and a song shared the other way comes back playing them', () {
      final waltz = parseIrealPro(
        'irealbook://${Uri.encodeComponent('Three=Doe Jane=Jazz Waltz=C=n=[T34C^7 |F^7 |G7 |C^7 Z')}',
      ).single;
      expect(waltz.progression.style.drums, Feel.jazzWaltz);
      final ballad = parseIrealPro(
        'irealbook://${Uri.encodeComponent('Slow=Doe Jane=Ballad Swing=C=n=[T44C^7 |F^7 |G7 |C^7 Z')}',
      ).single;
      expect(ballad.progression.style.drums, Feel.ballad);
      // A Latin ballad is a Latin tune played slowly, not this groove.
      final bossa = parseIrealPro(
        'irealbook://${Uri.encodeComponent('Slow=Doe Jane=Bossa Ballad=C=n=[T44C^7 |F^7 |G7 |C^7 Z')}',
      ).single;
      expect(bossa.progression.style.drums, Feel.bossa);
    });
  });
}
