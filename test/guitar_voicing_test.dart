// The grips the fretboard search comes up with have to be the ones a
// guitarist would actually play.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/tune_library.dart';

String grid(String symbol) {
  final voicing = guitarVoicingFor(Chord.parse(symbol));
  return voicing!.frets.map((fret) => fret == null ? 'x' : '$fret').join('-');
}

void main() {
  test('finds the textbook shapes', () {
    expect(grid('C'), 'x-3-2-0-1-x'); // open C
    expect(grid('CΔ7'), 'x-3-2-0-0-x'); // open Cmaj7
    expect(grid('Cm7'), 'x-3-5-3-4-x'); // the drop-2 everyone learns
    expect(grid('Cø7'), 'x-3-4-3-4-x');
    expect(grid('C°7'), 'x-3-4-2-4-x');
    expect(grid('C7♭9'), 'x-3-2-3-2-3');
    expect(grid('F♯m7'), '2-x-2-2-2-x'); // 6th-string root, 5th muted
    expect(grid('B♭Δ7'), 'x-1-3-2-3-x');
  });

  // Everything a player can meet: every chord in every tune, in concert
  // pitch and for B♭ and E♭ instruments, and every chord type the drills
  // use, in all twelve keys — both as written and without extensions.
  final everyChord = <String, Chord>{
    for (final tune in [...standards, ...practiceProgressions])
      for (final semitones in [0, 2, 9])
        for (final slot in tune.transposed(semitones).slots) ...{
          slot.chord.display: slot.chord,
          slot.chord.withoutExtensions.display: slot.chord.withoutExtensions,
        },
    for (final quality in chordQualities)
      for (final root in 'C Db D Eb E F F# G Ab A Bb B'.split(' '))
        '$root${quality.symbols.first}': Chord.parse(
          '$root${quality.symbols.first}',
        ),
  };

  test('every chord has a shape a hand can actually play', () {
    expect(everyChord.length, greaterThan(300));
    for (final chord in everyChord.values) {
      final voicing = guitarVoicingFor(chord);
      expect(voicing, isNotNull, reason: 'no shape for ${chord.display}');
      final frets = voicing!.frets;
      final shape = frets.map((f) => f ?? 'x').join('-');
      final why = '${chord.display}: $shape';

      final played = [for (final f in frets) ?f];
      expect(played.length, greaterThanOrEqualTo(3), reason: why);
      final fretted = played.where((f) => f > 0).toList();
      final lowest = fretted.reduce((a, b) => a < b ? a : b);
      final highest = fretted.reduce((a, b) => a > b ? a : b);

      // Three frets at most: a four-fret stretch near the nut is out of
      // reach for most hands.
      expect(highest - lowest, lessThanOrEqualTo(2), reason: why);
      // Open strings only in shapes at the nut.
      if (frets.contains(0)) {
        expect(highest, lessThanOrEqualTo(3), reason: why);
      }
      // Four fingers, one of which may barre the lowest fret — but a barre
      // can't leave a string under it muted or open.
      if (fretted.length > 4) {
        expect(
          fretted.where((f) => f != lowest).length,
          lessThanOrEqualTo(3),
          reason: why,
        );
        final barred = [
          for (var s = 0; s < 6; s++)
            if (frets[s] == lowest) s,
        ];
        for (var s = barred.first; s <= barred.last; s++) {
          expect(frets[s], isNot(anyOf(isNull, 0)), reason: why);
        }
      }

      // Strings are only missed out at the bottom, or the one under a
      // 6th-string root that the thumb mutes.
      final strings = [
        for (var i = 0; i < 6; i++)
          if (frets[i] != null) i,
      ];
      final gaps = [
        for (var i = strings.first; i <= strings.last; i++)
          if (frets[i] == null) i,
      ];
      expect(gaps.length, lessThanOrEqualTo(1), reason: why);
      if (gaps.isNotEmpty) expect(gaps.single, 1, reason: why);

      // Every note belongs to the chord, the lowest one is its bass, and
      // the 3rd, the 7th and any altered 5th are there to say which chord
      // it is.
      // (A slash chord no grip can put the bass under is played without
      // it: see guitarShapeChord.)
      final shown = guitarShapeChord(chord);
      final tones = shown.pitchClasses.toSet();
      final sounded = voicing.pitches.map((pitch) => pitch % 12).toList();
      expect(sounded.toSet(), everyElement(isIn(tones)), reason: why);
      expect(sounded.first, shown.bass, reason: why);
      final intervals = chord.quality.intervals;
      for (final degree in [3, 4, 5, 9, 10, 11, 6, 8]) {
        final defining = [6, 8].contains(degree)
            ? !intervals.contains(7)
            : true;
        if (intervals.contains(degree) && defining) {
          expect(
            sounded,
            contains((chord.root + degree) % 12),
            reason: '$why is missing its $degree',
          );
        }
      }
    }
  });

  test('a slash bass goes under the grip when a hand can reach it', () {
    // F/A: A is in the chord, so it can be the lowest note.
    final fOverA = Chord.parse('F/A');
    expect(guitarShapeChord(fOverA), same(fOverA));
    expect(guitarVoicingFor(fOverA)!.pitches.first % 12, 9);
    // D/E♭: E♭ isn't in a D chord, so the guitar plays D and the bass
    // player takes the E♭.
    final dOverEb = Chord.parse('D/Eb');
    expect(guitarShapeChord(dOverEb).display, 'D');
    expect(guitarVoicingFor(dOverEb), isNotNull);
  });

  test('the shapes that used to be out of reach', () {
    // Each of these once needed a four-fret stretch with an open string.
    expect(grid('C#7'), 'x-4-6-4-6-x');
    expect(grid('Ab^7'), '4-x-5-5-4-x');
    expect(grid('Db^7'), 'x-4-6-5-6-x');
    // And this one had lost the ♯5 that makes it a 7♯5.
    expect(grid('C7#5'), '8-x-8-9-9-x');
  });
}
