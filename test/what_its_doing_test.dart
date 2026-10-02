// What the chart says about itself, and what it refuses to say.
//
// Two kinds of test here and the second kind matters more. One says the
// analysis names a ii-V-I when there is one. The other says it stays
// quiet when it does not know, because a label printed under a chord
// carries authority, and somebody learning cannot tell a confident wrong
// answer from a right one.
//
// The tune that decides whether the whole approach works is Cherokee. Its
// bridge modulates away from the written key, and the point of reading
// relationships instead of keys is that the bridge should come out as
// three ii-V-Is stepping down rather than as numbers measured from a key
// the music has left.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/what_its_doing.dart';

List<Chord> chords(String symbols) =>
    symbols.split(' ').map(Chord.parse).toList();

ChordMeaning? at(String symbols, int index) =>
    whatItIsDoing(chords(symbols), index);

ChordJob? jobAt(String symbols, int index) => at(symbols, index)?.job;

void main() {
  group('the phrase everything is built from', () {
    test('a ii-V-I is named at each of its three chords', () {
      const line = 'Dm7 G7 C^7';
      expect(jobAt(line, 0), ChordJob.approach);
      expect(jobAt(line, 1), ChordJob.dominant);
      expect(jobAt(line, 2), ChordJob.tonic);
      expect(at(line, 0)!.short, 'ii of a ii-V-I into C');
      expect(at(line, 1)!.short, 'The V of C');
      expect(at(line, 1)!.tag, 'V of C');
    });

    test('and in a minor key, where the ii is half-diminished', () {
      const line = 'Dh7 G7 Cm7';
      expect(jobAt(line, 0), ChordJob.approach);
      expect(jobAt(line, 1), ChordJob.dominant);
      expect(
        at(line, 0)!.short,
        'ii of a ii-V-I into Cm',
        reason: 'the minor target is named as minor',
      );
    });

    test('a ii-V that never lands is still a ii-V, and says so', () {
      // The pair is the gesture. Half the ii-Vs in this music go
      // somewhere else, and calling them broken would be wrong.
      const line = 'Dm7 G7 Eb^7';
      expect(jobAt(line, 0), ChordJob.approach);
      expect(at(line, 0)!.short, 'ii of a ii-V into C');
      expect(jobAt(line, 1), ChordJob.deceptive);
    });

    test('both halves of a ii-V name the target the same way', () {
      // The first fix went into the ii and not the V, so a chart read
      // "ii of Dm" over "V of D" about the same chord. One of them had
      // to be wrong and a reader could not tell which.
      expect(at('Eh7 A7 Dm7', 0)!.tag, 'ii of Dm');
      expect(at('Eh7 A7 Dm7', 1)!.tag, 'V of Dm');
      expect(at('Em7 A7 D^7', 1)!.tag, 'V of D');
    });

    test('the chord it lands on is named with its quality', () {
      // Eø7 A7 into Dm is a different phrase from Em7 A7 into D: a
      // different scale on every chord of it. "into D" for both hid the
      // one thing somebody needed off the line.
      expect(at('Eh7 A7 Dm7', 0)!.tag, 'ii of Dm');
      expect(at('Em7 A7 D^7', 0)!.tag, 'ii of D');
    });

    test('a ii-V landing on another ii-V says it is handing over', () {
      // The question this answers: St Thomas is in C, so why does a line
      // under its second bar say D? Because Eø7 A7 goes to Dm, and Dm is
      // not where the tune is going, it is the start of the pair that is.
      final doing = at('Eh7 A7 Dm7 G7 C^7', 0)!;
      expect(doing.tag, 'ii of Dm');
      expect(doing.long, contains('handing over'));
      // And where it really is an arrival, it does not say that.
      expect(at('Em7 A7 D^7', 0)!.long, isNot(contains('handing over')));
    });

    test('a minor chord not in front of a dominant is left alone', () {
      // Dm7 to E♭Δ7 is not a ii-V and must not be called one.
      expect(jobAt('Dm7 Eb^7 C^7', 0), isNull);
    });
  });

  group('dominants, by where they go', () {
    test('up a fourth is the plain one', () {
      expect(jobAt('G7 C^7', 0), ChordJob.dominant);
      expect(at('G7 C^7', 0)!.short, 'The V of C');
    });

    test('down a semitone is the tritone sub, and it names the chord it '
        'stands in for', () {
      final sub = at('Db7 C^7', 0)!;
      expect(sub.job, ChordJob.tritoneSub);
      expect(sub.short, 'Tritone sub, for the V of C');
      expect(sub.long, contains('G7'), reason: 'the chord it replaced');
    });

    test('up a whole tone into a major chord is the backdoor', () {
      final back = at('Bb7 C^7', 0)!;
      expect(back.job, ChordJob.backdoor);
      expect(back.short, 'Backdoor, into C');
    });

    test('a ii-V that goes elsewhere is the one that did not land', () {
      // The ii in front is what makes it a thwarted resolution rather
      // than simply a chord going somewhere.
      expect(jobAt('Dm7 G7 Ab^7', 1), ChordJob.deceptive);
      expect(
        at('Dm7 G7 Ab^7', 1)!.long,
        contains('C'),
        reason: 'where it was leaning',
      );
    });

    test('a dominant with nothing setting it up says nothing', () {
      // Most of the dominants in a blues go somewhere other than up a
      // fourth, and they are the sound of the style rather than failures.
      // A twelve-bar had these words under half its bars, every one of
      // them telling its reader something untrue.
      expect(jobAt('G7 Ab^7', 0), isNull);
      // A blues: the IV7 going home to the I7, and the I7 to the VI7.
      expect(jobAt('D7 A7', 0), isNull);
      expect(jobAt('A7 F#7', 0), isNull);
    });

    test('a run of dominants is a chain, not a string of cadences', () {
      // The bridge of rhythm changes: D7 G7 C7 F7, each the dominant of
      // the next. Calling each one a cadence would be four arrivals in a
      // row, which is the opposite of how it sounds.
      const bridge = 'D7 G7 C7 F7 Bb^7';
      expect(jobAt(bridge, 0), ChordJob.chain);
      expect(jobAt(bridge, 1), ChordJob.chain);
      expect(jobAt(bridge, 2), ChordJob.chain);
      // The last one does land, so it is an arrival again.
      expect(jobAt(bridge, 3), ChordJob.dominant);
    });

    test('a 7sus counts as a dominant, because it goes to the same place', () {
      expect(jobAt('G7sus4 C^7', 0), ChordJob.dominant);
    });

    test('a dominant with nothing after it says nothing', () {
      expect(jobAt('G7', 0), isNull);
    });
  });

  group('staying put', () {
    test('the same chord twice is named as going nowhere', () {
      expect(jobAt('C^7 C^7', 0), ChordJob.staying);
    });

    test('a dominant held for a bar is the V of where it goes, both bars', () {
      // A chart writes the second bar as %. Reading that as a resolution
      // that did not happen put "V, no land" under half the bars of a
      // bridge, which is the kind of wrong that teaches somebody
      // something untrue. Reading it as "stays" would be true and less
      // use than saying where it is going.
      expect(jobAt('C7 C7 F^7', 0), ChordJob.dominant);
      expect(jobAt('C7 C7 F^7', 1), ChordJob.dominant);
      expect(at('C7 C7 F^7', 0)!.tag, 'V of F');
    });

    test('but a held chord with nothing to say is held', () {
      expect(jobAt('Dm7 Dm7 Dm7', 0), ChordJob.staying);
    });

    test('a chain of dominants survives being written with repeats', () {
      // The bridge of Ah-Leu-Cha: four dominants a bar each, written as
      // C#7 % F#7 % B7 % E7 %. Read slot by slot, every other one looked
      // like a failure; read as changes, it is one run.
      const bridge = 'C#7 C#7 F#7 F#7 B7 B7 E7 E7 A^7';
      expect(jobAt(bridge, 0), ChordJob.chain);
      expect(jobAt(bridge, 1), ChordJob.chain);
      expect(jobAt(bridge, 3), ChordJob.chain);
      expect(jobAt(bridge, 5), ChordJob.chain);
      expect(jobAt(bridge, 7), ChordJob.dominant, reason: 'the last lands');
    });

    test('a ii-V reads through a repeat between its two chords', () {
      expect(jobAt('Dm7 Dm7 G7 C^7', 1), ChordJob.approach);
      expect(at('Dm7 Dm7 G7 C^7', 1)!.short, 'ii of a ii-V-I into C');
    });

    test('a different chord of the same root is not the same chord', () {
      expect(jobAt('C^7 C7', 0), isNull);
    });
  });

  group('what it refuses to say', () {
    test('out of range is nothing rather than a crash', () {
      expect(whatItIsDoing(chords('Dm7 G7'), -1), isNull);
      expect(whatItIsDoing(chords('Dm7 G7'), 9), isNull);
      expect(whatItIsDoing(const [], 0), isNull);
    });

    test('a lone major chord going nowhere in particular', () {
      expect(jobAt('C^7 Ab^7', 0), isNull);
    });
  });

  group('on real tunes', () {
    /// Every chord of [title], in order, one per change.
    List<Chord> tuneChords(String title) {
      final tune = standards.firstWhere((t) => t.title == title);
      return [
        for (final bar in tune.bars)
          for (final slot in bar) slot.chord,
      ];
    }

    test(
      'Cherokee reads its bridge as ii-V-Is, not as numbers from B flat',
      () {
        // The tune this whole approach exists for. Written in B♭, and the
        // bridge is ii-V-I in B, then A, then G. Measured against B♭ those
        // chords are ♭iii ♭VI ♭II and so on, which is true and useless.
        final all = tuneChords('Cherokee');
        final named = <String>[];
        for (var i = 0; i < all.length; i++) {
          final meaning = whatItIsDoing(all, i);
          if (meaning?.job == ChordJob.approach) named.add(meaning!.short);
        }
        // The bridge's three ii-Vs, named by where each one is heading
        // rather than by how far it is from home.
        expect(named, contains('ii of a ii-V-I into B'));
        expect(named, contains('ii of a ii-V-I into A'));
        expect(named, contains('ii of a ii-V-I into G'));
      },
    );

    test('it stays quiet more often than it speaks, across the book', () {
      // The honest shape of this: most chords in most tunes are not doing
      // anything nameable, and a chart that found something to say about
      // every one of them would be making it up.
      var said = 0;
      var total = 0;
      for (final tune in standards.take(60)) {
        final all = [
          for (final bar in tune.bars)
            for (final slot in bar) slot.chord,
        ];
        for (var i = 0; i < all.length; i++) {
          total++;
          if (whatItIsDoing(all, i) != null) said++;
        }
      }
      expect(total, greaterThan(500), reason: 'enough to mean something');
      // Not a quality bar, a sanity one: it should be saying something
      // about a good share of chords without claiming to know them all.
      expect(said / total, greaterThan(0.3));
      expect(said / total, lessThan(0.95));
    });

    test('every tune in the book is analysed without throwing', () {
      for (final tune in standards) {
        final all = [
          for (final bar in tune.bars)
            for (final slot in bar) slot.chord,
        ];
        for (var i = 0; i < all.length; i++) {
          expect(
            () => whatItIsDoing(all, i),
            returnsNormally,
            reason: '${tune.title} chord $i',
          );
        }
      }
    });
  });

  group('the line on the chart', () {
    // The chart gives this a few characters beside a chord symbol, and
    // shrinks whatever it is handed to fit. A sentence there would come
    // out too small to read, so the tag is held to about the width of
    // the guide tones it sits in place of.
    test('every tag is short enough to read at chart size', () {
      final seen = <String>{};
      for (final tune in standards) {
        final all = [
          for (final bar in tune.bars)
            for (final slot in bar) slot.chord,
        ];
        for (var i = 0; i < all.length; i++) {
          if (whatItIsDoing(all, i) case final meaning?) seen.add(meaning.tag);
        }
      }
      expect(seen, isNotEmpty);
      for (final tag in seen) {
        expect(
          tag.length,
          lessThanOrEqualTo(11),
          reason: '"\$tag" is too long for the line under a chord',
        );
      }
    });

    test('the tag says the same thing as the sentence', () {
      expect(at('Dm7 G7 C^7', 1)!.tag, 'V of C');
      expect(at('Dm7 G7 C^7', 0)!.tag, 'ii of C');
      expect(at('Db7 C^7', 0)!.tag, 'sub \u2192 C');
      expect(at('Bb7 C^7', 0)!.tag, 'backdoor');
      expect(at('C^7 C^7', 0)!.tag, 'stays');
    });
  });

  group('swept over the whole book', () {
    // The checks that would have caught by machine what reading St
    // Thomas caught by eye. Every label is checked against the chords it
    // actually sits on, over all 204 charts, so a reading cannot be
    // merely plausible: it has to be true of the chord either side.

    List<Chord> chordsOf(Tune tune) => [
      for (final bar in tune.bars)
        for (final slot in bar) slot.chord,
    ];

    int up(Chord a, Chord b) => (b.root - a.root) % 12;

    int? nextChange(List<Chord> all, int i) {
      for (var j = i + 1; j < all.length; j++) {
        if (all[j].display != all[i].display) return j;
      }
      return null;
    }

    test('every label is true of the chords around it', () {
      final wrong = <String>[];
      var checked = 0;
      for (final tune in standards) {
        final all = chordsOf(tune);
        for (var i = 0; i < all.length; i++) {
          final meaning = whatItIsDoing(all, i);
          if (meaning == null) continue;
          checked++;
          final n = nextChange(all, i);
          void bad(String why) => wrong.add(
            '\${tune.title}: \${all[i].display} "\${meaning.tag}" \$why',
          );
          switch (meaning.job) {
            case ChordJob.dominant:
            case ChordJob.chain:
              if (n == null || up(all[i], all[n]) != 5) {
                bad('is not a fourth below');
              }
            case ChordJob.tritoneSub:
              if (n == null || up(all[i], all[n]) != 11) {
                bad('is not a semitone above');
              }
            case ChordJob.backdoor:
              if (n == null) bad('has nothing after it');
            case ChordJob.approach:
            case ChordJob.handsOver:
              if (n == null) bad('has nothing after it');
            case ChordJob.tonic:
            case ChordJob.deceptive:
              break;
            case ChordJob.staying:
              if (i + 1 >= all.length || all[i + 1].display != all[i].display) {
                bad('does not repeat');
              }
          }
        }
      }
      expect(checked, greaterThan(4000), reason: 'a real sweep');
      expect(wrong, isEmpty);
    });

    test('the two halves of a ii-V never disagree about where it goes', () {
      // The fault somebody found by reading: "ii of Dm" printed over "V
      // of D" about the same chord, one of them wrong and no way to tell
      // which from the page.
      final disagree = <String>[];
      var pairs = 0;
      for (final tune in standards) {
        final all = chordsOf(tune);
        for (var i = 0; i < all.length; i++) {
          final ii = whatItIsDoing(all, i);
          if (ii?.job != ChordJob.approach) continue;
          final n = nextChange(all, i);
          if (n == null) continue;
          final v = whatItIsDoing(all, n);
          if (v == null || !v.tag.startsWith('V of ')) continue;
          pairs++;
          if (ii!.tag.replaceFirst('ii of ', '') !=
              v.tag.replaceFirst('V of ', '')) {
            disagree.add('\${tune.title}: "\${ii.tag}" then "\${v.tag}"');
          }
        }
      }
      // Fewer than there are ii-Vs: where the V is itself a backdoor or
      // handing over it is not labelled "V of", and those are checked by
      // the tests above instead.
      expect(pairs, greaterThan(800), reason: 'enough pairs to mean it');
      expect(disagree, isEmpty);
    });

    test('a chord shoved up a semitone and brought back is not a sub', () {
      // All Blues pushes its D7#9 up to Eb7#9 and straight back down.
      // Nothing has been substituted for anything, so nothing is said.
      expect(jobAt('D7#9 Eb7#9 D7#9', 1), isNull);
      // But a real sub, which does not come from where it is going, is.
      expect(jobAt('Dm7 Db7 C^7', 1), ChordJob.tritoneSub);
    });

    test('a turnaround is ii-Vs handing over, not a row of failures', () {
      // Dm7 G7 | Em7 A7 is two ii-Vs, and calling the G7 a resolution
      // that did not happen put those words through every turnaround in
      // the book: 311 of them, against 34 that really are deceptive.
      expect(jobAt('Dm7 G7 Em7 A7', 1), ChordJob.handsOver);
      expect(at('Dm7 G7 Em7 A7', 1)!.tag, 'hands over');
    });

    test('the chord in front of a backdoor is part of the backdoor', () {
      // Fm7 Bb7 going to C is not a ii-V into Eb that failed. Saying
      // "ii of Eb" over "backdoor" was the same two halves disagreeing.
      expect(jobAt('Fm7 Bb7 C^7', 0), ChordJob.backdoor);
      expect(at('Fm7 Bb7 C^7', 0)!.tag, 'backdoor iv');
      expect(jobAt('Fm7 Bb7 C^7', 1), ChordJob.backdoor);
    });
  });
}
