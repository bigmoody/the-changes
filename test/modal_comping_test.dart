// Comping a tune that does not change chord.
//
// Sixteen bars of Dm7 is the hardest thing in the book to comp, and it is
// hard for the reason the comper was built around: it reads the chart and
// reacts to it, and here the chart says the same thing sixteen times. So
// it reacted to nothing. It poked a chord on the "and" of 2 in three bars
// out of four, bar after bar, in the same place every time, and the
// sixteenth bar of the vamp was as busy as the third.
//
// What is left to play to on a modal tune is the form. The top of a
// section is somewhere a pianist arrives even when the harmony has not
// moved, and the bar before one is somewhere they lead through.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart' show Genre;
import 'package:play_along/music/tune_library.dart';

/// What the comper plays, bar by bar, for a whole chorus of [title].
List<List<CompHit>> compedChorus(String title, {int seed = 7}) {
  final tune = standards.firstWhere((t) => t.title == title);
  final slots = LoopRange.wholeTune(tune).slotsIn(tune);
  final comper = Comper(
    math.Random(seed),
    quartal: tune.tags.contains(Genre.modal),
    slide: tune.quartalSlide,
  );
  return [
    for (var i = 0; i < slots.length; i++)
      comper.comp(
        slots[i].chord,
        (slots[i].endBeat - slots[i].startBeat).toInt(),
        tune.style.piano.feel,
        next: slots[(i + 1) % slots.length].chord,
        beatsPerBar: tune.beatsPerBar,
        swing: 0.62,
        beatInBar: (slots[i].startBeat % tune.beatsPerBar).toDouble(),
        startsSection: tune.sections.containsKey(
          slots[i].startBeat ~/ tune.beatsPerBar,
        ),
        // Counting round the form, as the renderer does: the bar after the
        // last one is the first one.
        intoSection: tune.sections.containsKey(
          (slots[i].endBeat ~/ tune.beatsPerBar) % tune.barCount,
        ),
        bar: slots[i].startBeat ~/ tune.beatsPerBar,
      ),
  ];
}

void main() {
  group('So What, sixteen bars of one chord', () {
    test('it rarely arrives in the same place two bars running', () {
      // The whole of what made it sound sloppy. Several figures began on
      // the "and" of 2 under different names, and the weighting that
      // stops a figure repeating compared the names, so it never saw
      // that they all landed together: whichever was picked you heard a
      // chord in the same place, and a vamp ticked.
      //
      // A rate and not a rule. Landing twice in a place is something a
      // player does; landing there all afternoon is the bug.
      //
      // Measured over forty choruses: 27 per cent with the old three
      // figures, two of which began on the same beat; 12 per cent once
      // they had five different beats to begin on; 5 with the weighting
      // against repeating a landing as well. Both halves of the fix pay,
      // and the spread of landings pays more than the weighting does.
      // Slides are left out of this. They are the tune's own answer and
      // they are meant to come round at the same place every two bars:
      // counting them, the rate is 41 per cent and ought to be. What this
      // guards is the figures in between, where the same place twice
      // running is the monotony it was written for.
      var repeats = 0, pairs = 0;
      for (var seed = 0; seed < 40; seed++) {
        final bars = compedChorus('So What', seed: seed);
        double? last;
        for (final bar in bars) {
          if (bar.isEmpty) continue;
          final slid = bar.length > 1 && bar.first.notes != bar.last.notes;
          if (slid) {
            last = null;
            continue;
          }
          if (last != null) {
            pairs++;
            if (bar.first.beat == last) repeats++;
          }
          last = bar.first.beat;
        }
      }
      expect(repeats / pairs, lessThan(0.15));
    });

    test('and it arrives in more than a couple of places over a chorus', () {
      final entries = {
        for (final bar in compedChorus('So What'))
          if (bar.isNotEmpty) bar.first.beat,
      };
      expect(entries.length, greaterThanOrEqualTo(4));
    });

    test('it lands on the top of each section', () {
      // A section beginning counts as new even though the chord has not
      // changed: the second A is somewhere you arrive, not somewhere you
      // happen to still be. The first bar of the tune is not in this,
      // because nothing has started yet for it to be new against.
      final bars = compedChorus('So What');
      for (final bar in [8, 16, 24]) {
        expect(bars[bar], isNotEmpty, reason: 'bar ${bar + 1}');
        expect(
          bars[bar].first.beat,
          lessThan(1),
          reason: 'bar ${bar + 1} should be played on, not after, the beat',
        );
      }
    });

    test('and nearly always plays through the bar before one', () {
      // The one place in sixteen bars of a single chord where something
      // is about to happen. Not every time: a turn figure on every
      // eighth bar without fail is its own tell, and the point of
      // playing it is that it leads somewhere, not that it is punctual.
      var played = 0, total = 0;
      for (var seed = 0; seed < 40; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (final bar in [7, 15, 23]) {
          total++;
          if (bars[bar].isNotEmpty) played++;
        }
      }
      expect(played / total, greaterThan(0.75));
    });

    test('it thins out through a section rather than keeping on', () {
      // Averaged over seeds: the back half of a section is quieter than
      // the front half. One chorus of one seed is too few bars to say
      // anything about a weighting.
      var front = 0, back = 0;
      for (var seed = 0; seed < 40; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (var bar = 0; bar < 32; bar++) {
          if (bars[bar].isEmpty) continue;
          // Bars 1 to 4 of each eight against bars 5 to 7, leaving out
          // the eighth, which leads into the next section by design.
          final inSection = bar % 8;
          if (inSection < 4) {
            front++;
          } else if (inSection < 7) {
            back++;
          }
        }
      }
      // Four bars against three, so the front has a third more bars to
      // fill; anything short of a clear gap is the weighting not biting.
      expect(back / 3, lessThan(front / 4 * 0.85));
    });
  });

  group('the slide gets played, not just defined', () {
    /// The bars where the comper moved between two shapes inside the bar.
    List<int> slidBars(List<List<CompHit>> bars) => [
      for (final (i, bar) in bars.indexed)
        if (bar.length > 1 && bar.any((hit) => hit.notes != bar.first.notes)) i,
    ];

    test('So What slides several times a chorus', () {
      // Often enough to be the sound of the tune, not so often that it is
      // the only thing the piano knows.
      // Every other bar, give or take a bar off: twelve bars of a chorus
      // are second-of-a-pair and not leading into a section, and the
      // answer goes in nearly all of them.
      final slid = slidBars(compedChorus('So What'));
      expect(slid.length, greaterThanOrEqualTo(8));
      expect(slid.length, lessThanOrEqualTo(12));
    });

    test('and every slide falls a whole step', () {
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (final i in slidBars(bars)) {
          final first = bars[i].first.notes;
          final last = bars[i].last.notes;
          expect(last, [
            for (final n in first) n - 2,
          ], reason: 'bar ${i + 1}, seed $seed');
        }
      }
    });

    test('it always comes back: nothing is left on the upper shape', () {
      // What it did wrong. The voicing picker was handed both shapes and
      // chose by which was nearer the hand, so the one a tone above
      // became home and sat there for bars at a time. The figure is a
      // fall; the top of it is somewhere you pass through.
      //
      // Note expect and not !=: comparing two Lists with != in Dart asks
      // whether they are the same object, which they never are, and the
      // first version of this check passed everything.
      final tune = standards.firstWhere((t) => t.title == 'So What');
      for (var seed = 0; seed < 20; seed++) {
        final slots = LoopRange.wholeTune(tune).slotsIn(tune);
        final bars = compedChorus('So What', seed: seed);
        for (final (i, bar) in bars.indexed) {
          if (bar.isEmpty) continue;
          final home = quartalHomeFor(slots[i].chord)!;
          expect(
            bar.last.notes,
            home,
            reason: 'bar ${i + 1}, seed $seed ends away from home',
          );
        }
      }
    });

    test('and the only shape above it ever appears is on the way down', () {
      final tune = standards.firstWhere((t) => t.title == 'So What');
      final slots = LoopRange.wholeTune(tune).slotsIn(tune);
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (final (i, bar) in bars.indexed) {
          final home = quartalHomeFor(slots[i].chord)!;
          for (final (j, hit) in bar.indexed) {
            if (hit.notes.first == home.first) continue;
            // Anything that is not home is the shape above, and it is
            // only allowed as the opening of a fall that lands.
            expect(j, 0, reason: 'bar ${i + 1}, seed $seed');
            expect(bar.length, greaterThan(1), reason: 'bar ${i + 1}');
            expect(bar.last.notes, home, reason: 'bar ${i + 1}');
          }
        }
      }
    });

    test('the upper shape never lands on a downbeat', () {
      // It is the leaning half of the figure and a bar does not open on
      // the lean. Nothing else in the comper may put it there either: it
      // is not a resting voicing, so the only hit it can ever be is the
      // opening of a slide.
      final tune = standards.firstWhere((t) => t.title == 'So What');
      final slots = LoopRange.wholeTune(tune).slotsIn(tune);
      for (var seed = 0; seed < 40; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (final (i, bar) in bars.indexed) {
          final home = quartalHomeFor(slots[i].chord)!;
          for (final hit in bar) {
            if (hit.notes.first == home.first) continue;
            expect(
              hit.beat % 4,
              isNot(0),
              reason: 'bar ${i + 1}, seed $seed opens the bar on the lean',
            );
          }
        }
      }
    });

    test('it comes in on the third beat and lands before the bar ends', () {
      // The figure is a two-bar phrase: a bar of the chord, then the
      // answer, which lands half a beat before the bar line, on the "and"
      // of the fourth, and rings on into the next bar.
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (final bar in bars) {
          if (bar.length < 2 || bar.first.notes == bar.last.notes) continue;
          expect(bar.first.beat, 2, reason: 'seed $seed');
          expect(bar.last.beat, closeTo(3.62, 0.001), reason: 'seed $seed');
        }
      }
    });

    test('the fall takes a beat and a half', () {
      // A beat apart was too quick and two and a half was too long. What
      // the gap is for is the suspension: the upper shape needs time to
      // sit there and be heard wanting to fall, and where it wants to
      // land is just before the bar line.
      //
      // The off-beat and not a literal half beat, so the figure leans
      // with whatever the swing is set to: at 0.62 the two are 1.62
      // apart, and at an even 0.5 they would be 1.5.
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('So What', seed: seed);
        for (final bar in bars) {
          if (bar.length < 2 || bar.first.notes == bar.last.notes) continue;
          expect(
            bar.last.beat - bar.first.beat,
            closeTo(1.62, 0.001),
            reason: 'seed $seed',
          );
        }
      }
    });

    test('and the upper shape holds until the landing', () {
      // Lifted off early it is a stab followed by a chord rather than one
      // falling onto the other, so it rings across the gap the way a
      // pedalled piano does.
      // Against the gap rather than a number of beats, so that moving the
      // landing cannot quietly turn the figure back into a stab: this
      // asked for two beats when the gap was two and a half, and the gap
      // is now a beat and a half.
      for (var seed = 0; seed < 20; seed++) {
        for (final bar in compedChorus('So What', seed: seed)) {
          if (bar.length < 2 || bar.first.notes == bar.last.notes) continue;
          final gap = bar.last.beat - bar.first.beat;
          expect(
            bar.first.length,
            greaterThan(gap * 0.85),
            reason: 'seed $seed',
          );
        }
      }
    });

    test('a tune that is not modal never slides', () {
      // The figure belongs to a vamp. Autumn Leaves has changes of its
      // own to play and does not need one borrowed.
      expect(slidBars(compedChorus('Autumn Leaves')), isEmpty);
    });
  });

  group('Impressions, the same figure the other way up', () {
    // Two tunes on one form, and the figure is most of what keeps them
    // from being one tune. So What's shape above falls onto the chord and
    // closes the phrase; Impressions lifts off the chord to the shape
    // above and leaves it there, so the phrase opens.
    List<CompHit> aSlide(String title, {int seed = 7}) {
      for (final bar in compedChorus(title, seed: seed)) {
        if (bar.length > 1 && bar.first.notes != bar.last.notes) return bar;
      }
      return const [];
    }

    test('it lifts where So What falls', () {
      final up = aSlide('Impressions');
      expect(up, isNotEmpty);
      expect(up.last.notes.first, up.first.notes.first + 2);

      final down = aSlide('So What');
      expect(down.last.notes.first, down.first.notes.first - 2);
    });

    test('the same two shapes, in the other order', () {
      final up = aSlide('Impressions');
      final down = aSlide('So What');
      expect(up.first.notes, down.last.notes);
      expect(up.last.notes, down.first.notes);
    });

    test('and it keeps the rhythm: in on three, over before the bar ends', () {
      for (var seed = 0; seed < 20; seed++) {
        for (final bar in compedChorus('Impressions', seed: seed)) {
          if (bar.length < 2 || bar.first.notes == bar.last.notes) continue;
          expect(bar.first.beat, 2, reason: 'seed $seed');
          expect(bar.last.beat, closeTo(3.62, 0.001), reason: 'seed $seed');
        }
      }
    });

    test('the bar after it plays, because its chord has not arrived', () {
      // The other way round from a fall. A fall delivers the chord half a
      // beat early, so the next bar has had it and says nothing; a lift
      // leaves the chord still to come, so the next bar brings it in and
      // the hanging shape above resolves.
      var played = 0, total = 0;
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('Impressions', seed: seed);
        for (final (i, bar) in bars.indexed) {
          if (bar.length < 2 || bar.first.notes == bar.last.notes) continue;
          if (i + 1 >= bars.length) continue;
          total++;
          if (bars[i + 1].isNotEmpty) played++;
        }
      }
      expect(played / total, greaterThan(0.8));
    });

    test('the shape above is left to hang before the chord answers', () {
      // What went wrong first time. The lift lands half a beat before the
      // bar line, and the answer was weighted onto the downbeat, which is
      // 0.38 of a beat later: at this tune's 240 that is under a tenth of
      // a second, so the shape above never hung at all. The downbeat is
      // where a suspension held over a bar line wants to land, and this
      // is not one of those, it is one that has only just arrived.
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('Impressions', seed: seed);
        for (final (i, bar) in bars.indexed) {
          if (bar.length < 2 || bar.first.notes == bar.last.notes) continue;
          if (i + 1 >= bars.length || bars[i + 1].isEmpty) continue;
          // The next bar's beats start a bar after this one's.
          final gap = 4 + bars[i + 1].first.beat - bar.last.beat;
          expect(
            gap,
            greaterThanOrEqualTo(1.5),
            reason: 'bar ${i + 1}, seed $seed answers after $gap beats',
          );
        }
      }
    });

    test('the hand still rests on the chord, never on the shape above', () {
      // The lift leaves the upper shape ringing, which is the point, but
      // it is still not somewhere to sit: every bar that is not the lift
      // itself plays the chord's own shape.
      final tune = standards.firstWhere((t) => t.title == 'Impressions');
      final slots = LoopRange.wholeTune(tune).slotsIn(tune);
      for (var seed = 0; seed < 20; seed++) {
        final bars = compedChorus('Impressions', seed: seed);
        for (final (i, bar) in bars.indexed) {
          if (bar.isEmpty) continue;
          final lift = bar.length > 1 && bar.first.notes != bar.last.notes;
          if (lift) continue;
          expect(
            bar.first.notes,
            quartalHomeFor(slots[i].chord),
            reason: 'bar ${i + 1}, seed $seed',
          );
        }
      }
    });
  });

  group('a tune with real changes is left as it was', () {
    test('every chord still gets played', () {
      // The fix is for static charts. Autumn Leaves changes chord nearly
      // every bar, so each one is new and already had something to say.
      final bars = compedChorus('Autumn Leaves');
      expect(bars.where((bar) => bar.isEmpty), isEmpty);
    });
  });
}
