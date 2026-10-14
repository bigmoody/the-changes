// Whether the chord dictionary offers grips a hand can actually make.
//
// A shape that is merely correct is not a chord. The rule the dictionary
// states is four fingers, a barre counting as one, and the thing it got
// wrong was the barre: it counted every note sharing the lowest fret as
// one finger, whether or not a finger could lie across them. Where a
// string inside them has to stay open or silent, it cannot, because a
// flat finger would sound it, and those notes are several fingers rather
// than one. That let through grips needing five.
//
// Checked over every chord symbol the book actually uses, rather than a
// chosen few, because the ones that got through were ordinary chords:
// G7, A7, Dm7, Gm7.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_chord_shapes.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/tune_library.dart';

/// How a grip is written on paper: x-5-7-5-6-x, lowest string first.
String tab(GuitarVoicing shape) =>
    shape.frets.map((fret) => fret == null ? 'x' : '$fret').join('-');

List<int> frettedOf(GuitarVoicing shape) => [
  for (final fret in shape.frets)
    if (fret != null && fret > 0) fret,
];

/// Every chord symbol in the book, which is what the section offers.
Set<String> get everySymbol => {
  for (final tune in standards)
    for (final bar in tune.bars)
      for (final slot in bar) slot.chord.display,
};

void main() {
  group('a hand can make every shape offered', () {
    test('nothing needs more than four fingers', () {
      final impossible = <String>[];
      for (final symbol in everySymbol) {
        for (final shape in allGuitarShapes(Chord.parse(symbol))) {
          final fretted = frettedOf(shape);
          if (fretted.isEmpty) continue;
          final lowest = fretted.reduce((a, b) => a < b ? a : b);
          // One finger for each fretted note, less whatever the barre
          // takes in, and only where there is a barre.
          final barred = shape.barre == null
              ? 0
              : fretted.where((fret) => fret == lowest).length - 1;
          final fingers = fretted.length - barred;
          if (fingers > 4) impossible.add('$symbol ${tab(shape)} ($fingers)');
        }
      }
      expect(impossible, isEmpty);
    });

    test('a barre is only claimed where a finger could lie across', () {
      // The bug itself: the strings a barre covers have to be fretted at
      // that fret or above. One that has to stay open or silent inside
      // the barre makes it impossible, however convenient it would be.
      for (final symbol in everySymbol) {
        for (final shape in allGuitarShapes(Chord.parse(symbol))) {
          final barre = shape.barre;
          if (barre == null) continue;
          for (var string = barre.from; string <= barre.to; string++) {
            final fret = shape.frets[string];
            expect(
              fret,
              isNotNull,
              reason:
                  '$symbol ${tab(shape)}: string $string is silent '
                  'inside the barre',
            );
            expect(
              fret,
              greaterThanOrEqualTo(barre.fret),
              reason:
                  '$symbol ${tab(shape)}: string $string is below '
                  'the barre',
            );
          }
        }
      }
    });

    test('the ones that used to get through are gone', () {
      // Four grips the section offered before this was fixed. Each has
      // two notes on the lowest fret with a string between them that has
      // to stay open or silent, so no barre is possible and each needs
      // five fingers.
      const wasOffered = {
        'G7': '3-x-5-4-6-3',
        'A7': '5-4-2-0-2-3',
        'Gm7': '3-1-0-3-3-1',
        'Dm7': '10-8-x-10-10-8',
      };
      for (final MapEntry(key: symbol, value: grip) in wasOffered.entries) {
        final shapes = allGuitarShapes(Chord.parse(symbol));
        expect(
          shapes.map(tab),
          isNot(contains(grip)),
          reason: '$symbol $grip needs five fingers',
        );
        expect(shapes, isNotEmpty, reason: '$symbol still has shapes');
      }
    });

    test('every chord in the book still has somewhere to put the hand', () {
      // A playability rule that leaves a chord with nothing is not a
      // fix, it is a different hole.
      for (final symbol in everySymbol) {
        expect(
          allGuitarShapes(Chord.parse(symbol)),
          isNotEmpty,
          reason: symbol,
        );
      }
    });
  });
}
