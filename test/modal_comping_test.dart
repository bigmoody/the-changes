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
import 'package:play_along/music/tune_library.dart';

/// What the comper plays, bar by bar, for a whole chorus of [title].
List<List<CompHit>> compedChorus(String title, {int seed = 7}) {
  final tune = standards.firstWhere((t) => t.title == title);
  final slots = LoopRange.wholeTune(tune).slotsIn(tune);
  final comper = Comper(math.Random(seed));
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
        intoSection: tune.sections.containsKey(
          slots[i].endBeat ~/ tune.beatsPerBar,
        ),
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
      var repeats = 0, pairs = 0;
      for (var seed = 0; seed < 40; seed++) {
        final bars = compedChorus('So What', seed: seed);
        double? last;
        for (final bar in bars) {
          if (bar.isEmpty) continue;
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

  group('a tune with real changes is left as it was', () {
    test('every chord still gets played', () {
      // The fix is for static charts. Autumn Leaves changes chord nearly
      // every bar, so each one is new and already had something to say.
      final bars = compedChorus('Autumn Leaves');
      expect(bars.where((bar) => bar.isEmpty), isEmpty);
    });
  });
}
