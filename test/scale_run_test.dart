// Scales as exercises: the notes run straight and in shapes, and every
// scale block on the roadmap names shapes and scales that exist.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/scale_patterns.dart';
import 'package:play_along/music/scale_run.dart';
import 'package:play_along/music/scales.dart';
import 'package:play_along/practice/roadmap.dart';

Mode _mode(String name) => modes.firstWhere((m) => m.name == name);

void main() {
  test('straight is up and down, the top note once', () {
    final run = scaleRun(
      _mode('Ionian'),
      'G',
      straightRun,
      octaves: 2,
      floor: 55,
    );
    // Fifteen up (two octaves and the top), fourteen back down.
    expect(run.pitches, hasLength(29));
    expect(run.pitches.first, 55, reason: 'G3');
    expect(run.pitches[14], 79, reason: 'G5, two octaves up');
    expect(run.pitches.last, 55);
    expect(run.names.take(8), ['G', 'A', 'B', 'C', 'D', 'E', 'F♯', 'G']);
  });

  test('it starts on the key at or above where the instrument wants', () {
    for (final (key, floor, first) in const [
      ('G', 40, 43), // bass: G2
      ('E', 40, 40), // bass: E2, the open string
      ('D♭', 52, 61), // guitar: D♭4, the first D♭ above E3
      ('C', 60, 60),
    ]) {
      final run = scaleRun(
        _mode('Ionian'),
        key,
        straightRun,
        octaves: 1,
        floor: floor,
      );
      expect(run.pitches.first, first, reason: '$key from $floor');
    }
  });

  test('an arpeggio is the seventh chord, up the octaves and back', () {
    final run = scaleRun(
      _mode('Mixolydian'),
      'G',
      arpeggioRun,
      octaves: 2,
      floor: 55,
    );
    expect(run.names.take(9), ['G', 'B', 'D', 'F', 'G', 'B', 'D', 'F', 'G']);
    expect(run.pitches[8], 79, reason: 'G two octaves up');
    expect(run.turn, 9);
    expect(run.names.last, 'G');
    expect(run.pitches.last, 55);
  });

  test('a shape goes up and comes back down mirrored', () {
    final run = scaleRun(
      _mode('Ionian'),
      'C',
      'In 3rds',
      octaves: 1,
      floor: 60,
    );
    expect(run.names.take(4), ['C', 'E', 'D', 'F']);
    expect(run.names.skip(run.names.length - 2), ['E', 'C']);
    expect(run.pitches.first, 60);
  });

  test('a shape too big for one octave is given the room it needs', () {
    final run = scaleRun(
      _mode('Major pentatonic'),
      'C',
      'Sevenths',
      octaves: 1,
      floor: 60,
    );
    expect(run.pitches, isNotEmpty);
  });

  test('every scale block plays shapes and scales that exist', () {
    final names = {
      for (final p in scalePatterns) p.name,
      straightRun,
      arpeggioRun,
    };
    final scales = {for (final m in modes) m.name};
    var blocks = 0;
    for (final instrument in RoadmapInstrument.values) {
      for (final stage in stagesFor(instrument)) {
        for (final block in stage.blocks) {
          final exercise = block.exercise;
          if (exercise == null) continue;
          blocks++;
          expect(block.modes, isNotEmpty, reason: block.title);
          expect(scales, containsAll(block.modes));
          expect(names, containsAll(exercise.ways));
          expect(exercise.to, greaterThan(exercise.from));
          for (final mode in block.modes) {
            for (final way in exercise.ways) {
              for (final key in stage.keys) {
                final run = scaleRun(
                  _mode(mode),
                  key,
                  way,
                  octaves: 2,
                  floor: 55,
                );
                expect(run.pitches, isNotEmpty, reason: '$key $mode $way');
              }
            }
          }
        }
      }
    }
    expect(blocks, greaterThan(20));
  });
}
