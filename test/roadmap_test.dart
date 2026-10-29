// The roadmap's content and the routine cut from it.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/roadmap_progress.dart';

void main() {
  final titles = {
    for (final tune in [...standards, ...practiceProgressions]) tune.title,
  };

  for (final instrument in RoadmapInstrument.values) {
    group(instrument.label, () {
      final stages = stagesFor(instrument);

      test('six stages, in order', () {
        expect([for (final s in stages) s.number], [1, 2, 3, 4, 5, 6]);
      });

      test('scales, chord tones and repertoire on every stage', () {
        for (final stage in stages) {
          final areas = {for (final goal in stage.goals) goal.area};
          expect(areas, containsAll([Area.chordTones, Area.repertoire]));
          expect(
            stage.blocks.map((b) => b.area),
            containsAll([Area.scales, Area.chordTones, Area.repertoire]),
            reason: 'stage ${stage.number}',
          );
          // Every stage has its job in the band, for this instrument.
          expect(areas, contains(Area.role));
        }
      });

      test('every tune is in the library', () {
        for (final stage in stages) {
          for (final title in stage.tunes) {
            expect(titles, contains(title), reason: 'stage ${stage.number}');
          }
        }
      });

      test('goals are named once, so a tick means one thing', () {
        final ids = [
          for (final stage in stages)
            for (final goal in stage.goals) goal.id,
        ];
        expect(ids.toSet().length, ids.length);
      });

      test('the routine fills the time, every length, every day', () {
        for (final stage in stages) {
          for (final minutes in sessionLengths) {
            for (var day = 0; day < 14; day++) {
              final routine = routineFor(stage, minutes, day: day);
              final total = routine.fold(0, (sum, b) => sum + b.minutes);
              expect(
                total,
                minutes,
                reason: 'stage ${stage.number}, $minutes min, day $day',
              );
              expect(routine.every((b) => b.minutes > 0), isTrue);
              // Warm up first, the tune last, and the tune the longest.
              expect(routine.first.block.area, Area.sound);
              expect(routine.last.tune, isNotNull);
              expect(
                routine.last.minutes,
                greaterThanOrEqualTo(minutes ~/ 4),
                reason: 'a quarter of it, at least, on the tune',
              );
              expect(
                routine.last.minutes,
                greaterThanOrEqualTo(
                  routine.map((b) => b.minutes).reduce((a, b) => a > b ? a : b),
                ),
              );
              for (final block in routine) {
                expect(block.how, isNot(contains('{')));
              }
            }
          }
        }
      });

      test('a short session leaves different things out on different '
          'days', () {
        final stage = stages[1];
        final seen = <String>{};
        for (var day = 0; day < 7; day++) {
          for (final block in routineFor(stage, 15, day: day)) {
            seen.add(block.block.title);
          }
        }
        expect(seen.length, greaterThan(3));
      });

      test('no em dashes in anything it says', () {
        for (final stage in stages) {
          final words = [
            stage.title,
            stage.aim,
            for (final goal in stage.goals) goal.text,
            for (final block in stage.blocks) ...[block.title, block.how],
          ];
          for (final text in words) {
            expect(text, isNot(contains('—')), reason: text);
          }
        }
      });
    });
  }

  test('the key and the tune move on each day', () {
    final stage = stagesFor(RoadmapInstrument.horn)[1];
    final monday = routineFor(stage, 60, day: 100);
    final tuesday = routineFor(stage, 60, day: 101);
    expect(monday.last.tune, isNot(tuesday.last.tune));
    expect(monday[1].how, isNot(tuesday[1].how));
  });

  test('ticks are kept for each instrument apart', () {
    final progress = RoadmapProgress.inMemory();
    final goal = stagesFor(RoadmapInstrument.guitar).first.goals.first;
    progress.tick(RoadmapInstrument.guitar, goal, true);
    expect(progress.isTicked(RoadmapInstrument.guitar, goal), isTrue);
    expect(progress.isTicked(RoadmapInstrument.horn, goal), isFalse);
  });

  test("what's done today is forgotten tomorrow", () {
    final progress = RoadmapProgress.inMemory();
    progress.markDone(10, 0, 'Time', true);
    expect(progress.isDone(10, 0, 'Time'), isTrue);
    expect(progress.isDone(11, 0, 'Time'), isFalse);
    progress.markDone(11, 1, 'Scale of the Day', true);
    expect(progress.isDone(10, 0, 'Time'), isFalse);
  });
}
