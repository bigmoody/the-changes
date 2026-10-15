// Voicing a modal tune in fourths.
//
// The rootless voicings are not wrong on So What, they are just not the
// sound. A 3rd and a 7th are there to say which chord it is, and on
// sixteen bars of one chord nobody is in any doubt. What holds a modal
// chorus up is the colour of the stack, which is why So What is the name
// of a chord as well as of a tune.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/voicings.dart';

/// The gaps between the notes of a voicing, in semitones.
List<int> gaps(List<int> notes) => [
  for (var i = 1; i < notes.length; i++) notes[i] - notes[i - 1],
];

Chord chord(String symbol) => Chord.parse(symbol);

const kRoots = [
  'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B', //
];

void main() {
  group('the So What chord', () {
    test('it is three fourths with a third on top', () {
      // What makes it the sound: everything is a perfect fourth apart
      // except the top interval, which is a major third.
      final forms = quartalVoicingsFor(chord('Dm7'))!;
      expect(gaps(forms.first), [5, 5, 5, 4]);
    });

    test('and on D minor it is the notes Bill Evans plays', () {
      // E A D G B, in his register: E3 up to B4.
      expect(quartalVoicingsFor(chord('Dm7'))!.first, [52, 57, 62, 67, 71]);
    });

    test('which over a bass playing the root is 9, 5, 8ve, 11, 13', () {
      final notes = quartalVoicingsFor(chord('Dm7'))!.first;
      // D is 50, so the degrees above the root in semitones.
      expect([for (final n in notes) n - 50], [2, 7, 12, 17, 21]);
    });

    test('the second form is the same stack from the root', () {
      // So the two can be alternated the way the rootless A and B forms
      // are, and the hand has somewhere to move to.
      final forms = quartalVoicingsFor(chord('Dm7'))!;
      expect(gaps(forms[1]), [5, 5, 5, 4]);
      expect(forms[1], isNot(forms.first));
    });

    test('and it planes: the shape is the shape in any key', () {
      // Moving it up bodily is the whole point of a chord built from
      // fourths, and how So What gets from its A to its B.
      for (final symbol in ['Dm7', 'E♭m7', 'Gm7', 'B♭m7']) {
        expect(gaps(quartalVoicingsFor(chord(symbol))!.first), [5, 5, 5, 4]);
      }
    });

    test('E♭m7 is a semitone above Dm7, note for note', () {
      final d = quartalVoicingsFor(chord('Dm7'))!.first;
      final eb = quartalVoicingsFor(chord('E♭m7'))!.first;
      expect(eb, [for (final n in d) n + 1]);
    });
  });

  group('the slide, which is what the tune is made of', () {
    // Two voicings of one chord that happen to sit a tone apart is not
    // the figure. The figure is the move: the shape a tone above falling
    // onto the shape on the chord, which is side-slipping, and it is what
    // Evans answers the melody with in the gaps.
    test('it falls a whole step, and the shape never changes', () {
      final slide = slideFor(chord('Dm7'))!;
      expect(slide.to, [for (final n in slide.from) n - 2]);
      expect(gaps(slide.from), gaps(slide.to));
    });

    test('from the So What chord onto the chord itself', () {
      // E A D G B, then D G C F A.
      final slide = slideFor(chord('Dm7'))!;
      expect(slide.from, [52, 57, 62, 67, 71]);
      expect(slide.to, [50, 55, 60, 65, 69]);
    });

    test('which is Em11 falling to Dm11', () {
      // The same five notes read as either, because the stack has no 3rd
      // and no 7th of its own to argue with the bass. Over E: root, 11,
      // ♭7, ♭3, 5. Over D the shape below it says the same of D.
      final slide = slideFor(chord('Dm7'))!;
      expect([for (final n in slide.from) (n - 52) % 12], [0, 5, 10, 3, 7]);
      expect([for (final n in slide.to) (n - 50) % 12], [0, 5, 10, 3, 7]);
    });

    test('it is a fall and never a climb', () {
      for (final root in kRoots) {
        final slide = slideFor(chord('${root}m7'));
        if (slide == null) continue;
        expect(slide.from.first, greaterThan(slide.to.first), reason: root);
      }
    });

    test('and is not offered in the two keys where it would climb', () {
      // Where the stacking drops the upper shape an octave to keep its
      // top note in range, it lands under the one it would fall to, and
      // a slide that goes up is not this figure.
      final without = [
        for (final root in kRoots)
          if (slideFor(chord('${root}m7')) == null) root,
      ];
      expect(without, ['A♭', 'A']);
    });

    test('a chord with no quartal voicing has no slide either', () {
      expect(slideFor(chord('G7')), isNull);
      expect(slideFor(chord('CΔ7')), isNull);
    });
  });

  group('and only where it belongs', () {
    test('a dominant keeps its own voicings', () {
      // A fourth stack over a dominant is a different idea, not this one.
      expect(quartalVoicingsFor(chord('G7')), isNull);
    });

    test('so does a major seventh', () {
      expect(quartalVoicingsFor(chord('CΔ7')), isNull);
    });

    test('and a half-diminished, which is not a dorian chord', () {
      // It has the ♭3 and the ♭7, so it would otherwise slip through.
      expect(quartalVoicingsFor(chord('Dø7')), isNull);
    });

    test('the top never goes above the comping range', () {
      // Which is the one that matters: a comping voicing pushed up an
      // octave turns shrill, and above this range it is in the soloist's
      // way.
      for (final root in kRoots) {
        for (final form in quartalVoicingsFor(chord('${root}m7'))!) {
          expect(form.last, lessThanOrEqualTo(compHighest), reason: root);
        }
      }
    });

    test('and the bottom gives by a tone at most, in four keys of twelve', () {
      // A five-note stack of fourths is 19 semitones wide where the
      // rootless voicings are 10 or 11, so it does not always have an
      // octave to sit in. Where it does not, the top note is kept inside
      // and the bottom is let go under: two semitones below C3 is still
      // well clear of the bass, and an octave up would not be.
      var under = 0;
      for (final root in kRoots) {
        for (final form in quartalVoicingsFor(chord('${root}m7'))!) {
          expect(
            form.first,
            greaterThanOrEqualTo(compLowest - 2),
            reason: root,
          );
          if (form.first < compLowest) under++;
        }
      }
      expect(under, 4);
    });
  });
}
