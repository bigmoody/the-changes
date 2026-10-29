// Where each mode is heard: every mode has somewhere, every tune named is
// in the library, and every bar named holds the chord it says it does.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/mode_examples.dart';
import 'package:play_along/music/scales.dart';
import 'package:play_along/music/tune_library.dart';

/// The chord symbols in [bar] (counting from 1) of [title].
List<String> _bar(String title, int bar) {
  final tune = standards.firstWhere((t) => t.title == title);
  return [for (final slot in tune.bars[bar - 1]) slot.chord.display];
}

String _shown(String symbol) => Chord.parse(symbol).display;

void main() {
  test('every mode has somewhere it is heard', () {
    for (final mode in modes) {
      expect(modeExamples[mode.name], isNotEmpty, reason: mode.name);
    }
    // And nothing is filed under a name that is not a mode.
    final names = {for (final mode in modes) mode.name};
    expect(names, containsAll(modeExamples.keys));
  });

  test('every tune named is in the library', () {
    final titles = {for (final tune in standards) tune.title};
    for (final examples in modeExamples.values) {
      for (final example in examples) {
        if (example.tune case final tune?) expect(titles, contains(tune));
      }
    }
  });

  test("a tune is moved to today's key the shortest way", () {
    // Take the "A" Train is in C.
    expect(semitonesToKey('Take the "A" Train', 'G'), -5);
    expect(semitonesToKey('Take the "A" Train', 'D'), 2);
    expect(semitonesToKey('Take the "A" Train', 'C'), 0);
    expect(semitonesToKey('Take the "A" Train', 'F♯'), 6);
    // So What is in D Dorian; B Dorian is three down.
    expect(semitonesToKey('So What', 'B'), -3);
    expect(movedKeyLabel('So What', 'B'), 'B Dorian');
    expect(movedKeyLabel('Blue Bossa', 'G'), 'G minor');
    expect(movedKeyLabel('Take the "A" Train', 'B♭'), 'B♭');
    expect(semitonesToKey('Not a tune', 'G'), 0);
  });

  test('no em dashes', () {
    for (final examples in modeExamples.values) {
      for (final example in examples) {
        expect(example.text, isNot(contains('—')));
      }
    }
  });

  // Each bar an example names, checked against the chart it opens.
  for (final (title, bar, chord) in const [
    ('Take the "A" Train', 1, 'C6'),
    ('Take the "A" Train', 3, 'D7#11'),
    ('Take the "A" Train', 4, 'D7#11'),
    ('Take the "A" Train', 17, 'FΔ7'),
    ('So What', 1, 'Dm7'),
    ('So What', 17, 'Ebm7'),
    ('Oye Como Va', 1, 'Am7'),
    ('Oye Como Va', 2, 'D7'),
    ('Nardis', 1, 'Em'),
    ('Nardis', 2, 'FΔ7'),
    ('Freddie Freeloader', 1, 'Bb7'),
    ('Blue Bossa', 5, 'Dø7'),
    ('Blue Bossa', 6, 'G7b9'),
    ('Blue Bossa', 8, 'Cm6'),
    ('My Funny Valentine', 2, 'CmΔ7'),
    ('Solar', 1, 'CmΔ7'),
    ('Solar', 2, 'CmΔ7'),
    ('Maiden Voyage', 17, 'Eb7sus4'),
    ('The Girl from Ipanema', 3, 'G7'),
    ('The Girl from Ipanema', 4, 'G7'),
    ('Footprints', 9, 'F7#11'),
    ('Footprints', 10, 'E7#9'),
    ('Footprints', 10, 'A7#9'),
    ('Autumn Leaves', 18, 'D7'),
    ('Autumn Leaves', 19, 'Gm6'),
    ('Stella by Starlight', 1, 'Eø7'),
    ('Stella by Starlight', 16, 'D7b9'),
    ('Stella by Starlight', 17, 'G7#5'),
    ('Stella by Starlight', 18, 'G7#5'),
    ('Wave', 2, 'Bbo7'),
    ('Wave', 7, 'F#7alt'),
    ('Summertime', 2, 'Bø7'),
    ('Summertime', 2, 'E7b9'),
    ('Summertime', 5, 'Dm7'),
    ('St. Thomas', 14, 'F#o7'),
    ('Cantaloupe Island', 1, 'Fm7'),
  ]) {
    test('$title, bar $bar, has $chord', () {
      expect(_bar(title, bar), contains(_shown(chord)));
    });
  }
}
