// Running a scale in shapes rather than straight up.
//
// The numbers here are checkable by hand, which is the point of writing
// them down: in thirds on a major scale is C E D F E G F A G B A C, and
// anybody who plays can say whether that is right.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/enclosures.dart' show scaleFor;
import 'package:play_along/music/scale_patterns.dart';
import 'package:play_along/music/scales.dart';

/// A major scale as semitones from its root.
const major = [0, 2, 4, 5, 7, 9, 11];

/// A major pentatonic, which is five notes and divides differently.
const pentatonic = [0, 2, 4, 7, 9];

ScalePattern named(String name) =>
    scalePatterns.firstWhere((one) => one.name == name);

/// Semitones turned into note names in C, so a test reads like music.
String inC(List<int> semitones) {
  const names = [
    'C',
    'C#',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];
  return [for (final s in semitones) names[s % 12]].join(' ');
}

void main() {
  group('in thirds, which is the one everybody knows', () {
    test('it is exactly what it should be', () {
      expect(
        inC(patternOn(major, named('In 3rds'))),
        'C E D F E G F A G B A C',
      );
    });

    test('and it stops at the octave rather than running past it', () {
      // Six pairs: the last one reaches the octave and there is no room
      // for another without going above it.
      expect(patternOn(major, named('In 3rds')), hasLength(12));
      expect(patternOn(major, named('In 3rds')).last, 12);
    });

    test('two octaves is twice as far, not twice the same thing', () {
      final two = patternOn(major, named('In 3rds'), octaves: 2);
      expect(two.last, 24);
      expect(two.length, greaterThan(20));
      expect(two.take(12).toList(), patternOn(major, named('In 3rds')));
    });
  });

  group('the other shapes', () {
    test('fourths', () {
      expect(inC(patternOn(major, named('In 4ths'))), 'C F D G E A F B G C');
    });

    test('fifths', () {
      expect(inC(patternOn(major, named('In 5ths'))), 'C G D A E B F C');
    });

    test('sixths', () {
      expect(inC(patternOn(major, named('In 6ths'))), 'C A D B E C');
    });

    test('triads on every degree', () {
      expect(inC(patternOn(major, named('Triads'))), 'C E G D F A E G B F A C');
    });

    test('sevenths on every degree', () {
      expect(inC(patternOn(major, named('Sevenths'))), 'C E G B D F A C');
    });

    test('in fours', () {
      expect(
        inC(patternOn(major, named('In fours'))),
        'C D E F D E F G E F G A F G A B G A B C',
      );
    });

    test('one two three five', () {
      expect(
        inC(patternOn(major, named('1 2 3 5'))),
        'C D E G D E F A E F G B F G A C',
      );
    });

    test('thirds turned inside out', () {
      expect(
        inC(patternOn(major, named('1 3 2 4'))),
        'C E D F D F E G E G F A F A G B G B A C',
      );
    });
  });

  group('coming down', () {
    test('it starts at the top and the groups descend', () {
      final down = patternOn(major, named('In 3rds'), down: true);
      expect(down.first, 12, reason: 'the octave');
      expect(inC(down.take(4).toList()), 'C A B G');
    });

    test('in pairs it is the ascending one backwards, and should be', () {
      // Descending in thirds is C A, B G, A F, which really is the
      // ascending run read from the other end. Anything else would be
      // wrong, so this says so rather than pretending otherwise.
      final up = patternOn(major, named('In 3rds'));
      final down = patternOn(major, named('In 3rds'), down: true);
      expect(down, up.reversed.toList());
    });

    test('but a longer shape descends, rather than being reversed', () {
      // 1 2 3 5 going down is C B A F: the shape keeps its own
      // direction inside each group. Reversed it would be C A G F.
      final up = patternOn(major, named('1 2 3 5'));
      final down = patternOn(major, named('1 2 3 5'), down: true);
      expect(inC(down.take(4).toList()), 'C B A F');
      expect(inC(up.reversed.take(4).toList()), 'C A G F');
      expect(down, isNot(up.reversed.toList()));
      expect(down, hasLength(up.length));
    });
  });

  group('scales that are not seven notes', () {
    test('a pentatonic in thirds comes out its own way', () {
      // Five notes, so a "third" is two of its steps: C E, D G, E A.
      expect(inC(patternOn(pentatonic, named('In 3rds'))), 'C E D G E A G C');
    });

    test('and reaches the octave after five steps, not seven', () {
      expect(patternOn(pentatonic, named('In 3rds')).last, 12);
    });

    test('a shape too wide for one octave asks for two', () {
      // Sevenths reach seven notes and a pentatonic has five.
      expect(octavesFor(5, named('Sevenths')), 2);
      expect(octavesFor(7, named('Sevenths')), 1);
      expect(octavesFor(7, named('In 3rds')), 1);
      expect(
        patternOn(pentatonic, named('Sevenths')),
        isEmpty,
        reason: 'within one octave there is no room',
      );
      expect(patternOn(pentatonic, named('Sevenths'), octaves: 2), isNotEmpty);
    });

    test('every scale in the app can be run in every pattern', () {
      for (final mode in modes) {
        for (final pattern in scalePatterns) {
          final octaves = octavesFor(mode.semitones.length, pattern);
          final line = patternOn(mode.semitones, pattern, octaves: octaves);
          expect(line, isNotEmpty, reason: '${mode.name} in ${pattern.name}');
          expect(
            line.every((note) => note >= 0 && note <= 12 * octaves),
            isTrue,
            reason: '${mode.name} in ${pattern.name} left its range',
          );
        }
      }
    });
  });

  group('a pentatonic is a scale to choose, not one to be handed', () {
    test('a 6 chord still gets the major scale, not the pentatonic', () {
      // What asks for a scale by chord counts in degrees up to the 7th,
      // and five notes cannot answer that. Adding the pentatonics broke
      // this and the number patterns caught it.
      expect(scaleFor(Chord.parse('C6')), hasLength(7));
      expect(scaleFor(Chord.parse('C6')).first, 'C');
      expect(scaleFor(Chord.parse('C7')), hasLength(7));
      expect(scaleFor(Chord.parse('Cm7')), hasLength(7));
    });

    test('and every chord anywhere gets seven notes or none', () {
      for (final symbol in ['C6', 'C', 'Cm', 'Cm6', 'CΔ7', 'G7alt', 'Co7']) {
        final scale = scaleFor(Chord.parse(symbol));
        expect(
          scale.length == 7 || scale.length == 8 || scale.isEmpty,
          isTrue,
          reason: '$symbol got ${scale.length} notes',
        );
      }
    });
  });

  group('nothing sensible asked for', () {
    test('gives nothing back rather than throwing', () {
      expect(patternOn(const [], named('In 3rds')), isEmpty);
      expect(patternSteps(0, named('In 3rds')), isEmpty);
      expect(patternSteps(7, named('In 3rds'), octaves: 0), isEmpty);
      expect(
        patternSteps(7, const ScalePattern(name: '', steps: [], about: '')),
        isEmpty,
      );
    });

    test('a shape that reaches further than the scale plays nothing', () {
      // Two notes cannot be run in sevenths inside one octave.
      expect(patternSteps(2, named('Sevenths')), isEmpty);
    });
  });

  group('the shapes themselves', () {
    test('each says how far it reaches and how many notes it has', () {
      expect(named('In 3rds').reach, 2);
      expect(named('In 3rds').length, 2);
      expect(named('Sevenths').reach, 6);
      expect(named('Sevenths').length, 4);
      expect(named('1 3 2 4').reach, 3, reason: 'the 4th is the highest');
    });

    test('all of them are named and explained', () {
      for (final pattern in scalePatterns) {
        expect(pattern.name, isNotEmpty);
        expect(pattern.about, isNotEmpty);
        expect(pattern.steps, isNotEmpty);
      }
      expect(
        scalePatterns.map((p) => p.name).toSet(),
        hasLength(scalePatterns.length),
      );
    });
  });
}
