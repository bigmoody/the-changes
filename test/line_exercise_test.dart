// Articulation lines: whole bars of eighths, marked the way they say,
// and written in the key asked for.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/practice/line_exercise.dart';
import 'package:play_along/practice/roadmap.dart';

void main() {
  for (final (name, exercise) in [
    ('articulation', articulation),
    ('ghosting', ghosting),
  ]) {
    test('$name: whole bars, a climbing tempo, no em dashes', () {
      expect(exercise.to, greaterThan(exercise.from));
      for (final step in exercise.steps) {
        expect(step.notes.length % 8, 0, reason: step.title);
        expect(step.how, isNot(contains('—')));
        // Played in every key without a hole in it.
        for (final key in ['C', 'F', 'B♭', 'E♭', 'G', 'D', 'F♯']) {
          final line = lineIn(step, key, floor: 60);
          for (final event in line) {
            if (event.touch == Touch.rest) continue;
            expect(event.pitch, inInclusiveRange(60, 60 + 11 + 12));
            expect(event.name, isNotEmpty);
          }
        }
      }
    });
  }

  test('tongue the off-beats: the "and"s tongued, the beats slurred', () {
    final step = articulation.steps[1];
    for (final (i, note) in step.notes.indexed) {
      if (i == 0) {
        expect(note.touch, Touch.tongue, reason: 'a line has to start');
      } else {
        expect(note.touch, i.isOdd ? Touch.tongue : Touch.slur);
      }
    }
  });

  test('ghost the beats: beats ghosted, "and"s accented', () {
    final step = ghosting.steps.first;
    for (final (i, note) in step.notes.indexed) {
      expect(note.touch, i.isOdd ? Touch.accent : Touch.ghost);
    }
  });

  test('start on the and: beat 1 is left out', () {
    final step = ghosting.steps[1];
    expect(step.notes.first.touch, Touch.rest);
    expect(step.notes[1].touch, Touch.accent);
  });

  test('a line is written in the key: G major starts on G', () {
    final line = lineIn(articulation.steps[1], 'G', floor: 60);
    expect(line.first.name, 'G');
    expect(line.first.pitch, 67);
    expect(line[6].name, 'F♯');
    expect(line[7].pitch, 79, reason: 'the octave');
  });

  test('the horn plays its articulation, not reads about it', () {
    final stages = stagesFor(RoadmapInstrument.horn);
    Block role(int stage) =>
        stages[stage - 1].blocks.firstWhere((b) => b.area == Area.role);
    expect(role(1).line, same(articulation));
    expect(role(2).exercise, isNotNull, reason: 'range is a scale to play');
    expect(role(3).line, same(ghosting));
  });
}
