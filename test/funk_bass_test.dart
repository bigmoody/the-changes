// The funk bass, and the kick it is half of.
//
// The two were each rolling their own syncopation every bar out of their
// own random, so a funk groove was a bass player and a drummer who had
// not met. In funk they are one part: the line is the kick with notes on
// it. Both work the figure out from the bar number now, so they agree
// without either being told.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';

/// The bass line for a chorus of [title], bar by bar, with beats counted
/// from the start of each bar.
List<List<BassNote>> byBar(String title, {int seed = 7}) {
  final tune = standards.firstWhere((t) => t.title == title);
  final slots = LoopRange.wholeTune(tune).slotsIn(tune);
  final line = funkBassLine(
    [for (final s in slots) (s.chord, (s.endBeat - s.startBeat).toInt())],
    choruses: 1,
    random: math.Random(seed),
    swing: 0.5,
  );
  return [
    for (var bar = 0; bar < slots.length; bar++)
      [
        for (final note in line)
          if (note.beat >= bar * 4 && note.beat < (bar + 1) * 4)
            (
              pitch: note.pitch,
              beat: note.beat - bar * 4,
              length: note.length,
              velocity: note.velocity,
            ),
      ],
  ];
}

/// What the drummer's kick plays in that bar.
List<double> kicksIn(int bar) => funkKicksFor(bar);

void main() {
  group('the bass plays the kick', () {
    test('there is a note on every kick', () {
      for (var seed = 0; seed < 10; seed++) {
        final bars = byBar('Cantaloupe Island', seed: seed);
        for (final (bar, notes) in bars.indexed) {
          for (final kick in kicksIn(bar)) {
            expect(
              notes.any((n) => (n.beat - kick).abs() < 0.05),
              isTrue,
              reason: 'bar ${bar + 1}, seed $seed has no note on $kick',
            );
          }
        }
      }
    });

    test('and the kick is a two-bar riff rather than a roll of the dice', () {
      // Held for two bars, then it turns. A kick figure chosen afresh
      // every bar is a drummer who has never played it before.
      for (var bar = 0; bar < 16; bar += 2) {
        expect(
          kicksIn(bar),
          kicksIn(bar + 1),
          reason: 'bars ${bar + 1}–${bar + 2}',
        );
      }
      expect(kicksIn(0), isNot(kicksIn(2)));
    });

    test('so two bars of a riff are the same line twice', () {
      // Within the pitches: the beats carry a few milliseconds of human
      // jitter, which is the one thing that should differ.
      final bars = byBar('Cantaloupe Island');
      for (var bar = 0; bar < 16; bar += 2) {
        if (bars[bar].isEmpty) continue;
        // Only where the chord does not change under them, since the bar
        // before a change takes a leading note the other does not.
        if (bar % 4 == 2) continue;
        expect(
          [for (final n in bars[bar]) n.pitch],
          [for (final n in bars[bar + 1]) n.pitch],
          reason: 'bars ${bar + 1} and ${bar + 2}',
        );
      }
    });
  });

  group('where it sits', () {
    test('the line stays in one register across a chord', () {
      // It used to be anchored to the last note played, two to one
      // against the register's centre, which is right for a walking line
      // and wrong for a riff: on four bars of one chord it walked itself
      // down an octave, because every bar started where the one before
      // it finished.
      for (var seed = 0; seed < 10; seed++) {
        final bars = byBar('Cantaloupe Island', seed: seed);
        for (var bar = 0; bar + 1 < 4; bar++) {
          if (bars[bar].isEmpty || bars[bar + 1].isEmpty) continue;
          expect(
            bars[bar + 1].first.pitch,
            bars[bar].first.pitch,
            reason: 'seed $seed moved register inside the first Fm7',
          );
        }
      }
    });

    test('and never reaches below the instrument', () {
      for (var seed = 0; seed < 10; seed++) {
        for (final notes in byBar('Cantaloupe Island', seed: seed)) {
          for (final note in notes) {
            expect(note.pitch, greaterThanOrEqualTo(bassLowest));
            expect(note.pitch, lessThanOrEqualTo(bassHighest));
          }
        }
      }
    });
  });

  group('leading notes', () {
    test('only into a chord that actually changes', () {
      // Four bars of one chord used to get four leading notes, each
      // walking into a chord that never came.
      final tune = standards.firstWhere((t) => t.title == 'Cantaloupe Island');
      final slots = LoopRange.wholeTune(tune).slotsIn(tune);
      for (var seed = 0; seed < 10; seed++) {
        final bars = byBar('Cantaloupe Island', seed: seed);
        for (var bar = 0; bar < bars.length; bar++) {
          final changes =
              slots[(bar + 1) % slots.length].chord.bass !=
              slots[bar].chord.bass;
          if (changes) continue;
          // Nothing off the chord where nothing is coming: every note is
          // a tone of it.
          final root = slots[bar].chord.bass;
          for (final note in bars[bar]) {
            expect(
              const [0, 3, 4, 7, 10, 11].contains((note.pitch - root) % 12),
              isTrue,
              reason: 'bar ${bar + 1}, seed $seed plays ${note.pitch}',
            );
          }
        }
      }
    });
  });

  group('the other grooves are untouched', () {
    test('a walking line still follows the hand', () {
      // The anchoring is funk's alone: a walking line is smooth because
      // each note starts from the last one.
      final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
      final slots = LoopRange.wholeTune(tune).slotsIn(tune);
      final line = walkingBassLine(
        [for (final s in slots) (s.chord, (s.endBeat - s.startBeat).toInt())],
        choruses: 1,
        random: math.Random(7),
        swing: 0.62,
      );
      expect(line, isNotEmpty);
      for (var i = 1; i < line.length; i++) {
        expect(
          (line[i].pitch - line[i - 1].pitch).abs(),
          lessThanOrEqualTo(12),
          reason: 'a walking line should not leap more than an octave',
        );
      }
    });
  });
}
