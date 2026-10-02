// Whether a recording of real players will fit a chart they never played.
//
// The tests that matter most here are the refusals. Offering somebody's
// rhythm section to a chart whose changes it does not play is the worst
// thing this feature could do, because it does not sound like the app
// made a mistake, it sounds like you did. So: a blues is not rhythm
// changes, a minor tune is not its major, and a chart with an extra chord
// in one bar is a different chart.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_shape.dart';
import 'package:play_along/music/same_changes.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

Tune made(String chart, {String key = 'C'}) =>
    Tune.fromChart(title: 'x', key: key, defaultTempo: 120, chart: chart);

Tune named(String title) => standards.firstWhere((t) => t.title == title);

void main() {
  group('what counts as the same chord', () {
    test('the way it is written does not matter, the shape does', () {
      // A bass player walks the same notes under C6 and CΔ7 and the
      // difference between the two charts is somebody's pen.
      expect(shapeOf(Chord.parse('C6')), shapeOf(Chord.parse('C^7')));
      expect(shapeOf(Chord.parse('Dm7')), shapeOf(Chord.parse('Dm9')));
      expect(shapeOf(Chord.parse('G7')), shapeOf(Chord.parse('G13')));
      expect(shapeOf(Chord.parse('G7')), shapeOf(Chord.parse('G7b9')));
    });

    test('but a different 3rd is a different chord', () {
      // The line this is drawn at: letting these two pass would put the
      // wrong 3rd under everybody's solo.
      expect(shapeOf(Chord.parse('Cm7')), isNot(shapeOf(Chord.parse('C7'))));
      expect(shapeOf(Chord.parse('Cm7')), isNot(shapeOf(Chord.parse('C^7'))));
      expect(
        shapeOf(Chord.parse('Ch7')),
        isNot(shapeOf(Chord.parse('Cm7'))),
        reason: 'a half-diminished is not a minor 7th',
      );
      expect(shapeOf(Chord.parse('Co7')), ChordShape.diminished);
      expect(shapeOf(Chord.parse('C7sus4')), ChordShape.suspended);
    });
  });

  group('one chart onto another', () {
    test('the same changes in the same key move by nothing', () {
      final a = made('| Dm7 | G7 | C^7 | C^7 |');
      final b = made('| Dm7 | G7 | C^7 | C^7 |');
      expect(movesOnto(a, b)?.semitones, 0);
    });

    test('the same changes a tone up move by two', () {
      final a = made('| Dm7 | G7 | C^7 | C^7 |');
      final b = made('| Em7 | A7 | D^7 | D^7 |', key: 'D');
      expect(movesOnto(a, b)?.semitones, 2);
    });

    test('and written differently is still the same changes', () {
      final a = made('| Dm7 | G7 | C6 | C6 |');
      final b = made('| Dm9 | G13 | C^7 | C^7 |');
      expect(movesOnto(a, b)?.semitones, 0);
    });

    test('a different quality anywhere in it is a different tune', () {
      final a = made('| Dm7 | G7 | C^7 | C^7 |');
      final b = made('| Dm7 | G7 | Cm7 | Cm7 |');
      expect(movesOnto(a, b), isNull);
    });

    test('an extra chord in one bar is a different tune', () {
      final a = made('| Dm7 | G7 | C^7 | C^7 |');
      final b = made('| Dm7 | G7 | C^7 | C^7 A7 |');
      expect(movesOnto(a, b), isNull);
    });

    test('a different number of bars is a different tune', () {
      expect(movesOnto(made('| C^7 | C^7 |'), made('| C^7 |')), isNull);
    });

    test('a slash chord is not the chord without it', () {
      // The bass player is being told what to play, and a take without
      // that note underneath is not playing these changes.
      final a = made('| C^7 | C^7 |');
      final b = made('| C^7/G | C^7 |');
      expect(movesOnto(a, b), isNull);
    });
  });

  group('across the book', () {
    test('a blues backs every other blues, in any key', () {
      // The whole point: three files of people playing one blues are not
      // a blues in F, they are a blues.
      final after = named('After Hours');
      final billie = named("Billie's Bounce");
      final match = movesOnto(after, billie);
      expect(match, isNotNull);
      expect(match!.semitones, 5, reason: 'C up to F');
      expect(match.bars, 12);
    });

    test('and rhythm changes back rhythm changes', () {
      final match = movesOnto(named('52nd Street Theme'), named('Oleo'));
      expect(match, isNotNull);
      expect(match!.semitones, 10);
      expect(match.bars, 32);
    });

    test('a blues does not back rhythm changes', () {
      expect(movesOnto(named('After Hours'), named('Oleo')), isNull);
      expect(movesOnto(named('Oleo'), named('After Hours')), isNull);
    });

    test('nothing is offered a chart it does not play', () {
      // Every match in the book checked the slow way, bar by bar, so a
      // false positive anywhere would turn up here rather than under
      // somebody's solo.
      var checked = 0;
      for (final a in standards) {
        for (final b in standards) {
          final match = movesOnto(a, b);
          if (match == null) continue;
          checked++;
          expect(a.barCount, b.barCount, reason: '${a.title} / ${b.title}');
          for (var bar = 0; bar < a.barCount; bar++) {
            expect(
              a.bars[bar].length,
              b.bars[bar].length,
              reason: '${a.title} / ${b.title} bar ${bar + 1}',
            );
            for (var i = 0; i < a.bars[bar].length; i++) {
              final was = a.bars[bar][i].chord;
              final now = b.bars[bar][i].chord;
              expect(
                shapeOf(was),
                shapeOf(now),
                reason: '${a.title} / ${b.title} bar ${bar + 1}',
              );
              expect(
                (was.root + match.semitones) % 12,
                now.root % 12,
                reason: '${a.title} / ${b.title} bar ${bar + 1}',
              );
            }
          }
        }
      }
      expect(checked, greaterThan(500), reason: 'a real sweep');
    });

    test('a tune matches itself at no distance', () {
      for (final tune in standards.take(40)) {
        expect(movesOnto(tune, tune)?.semitones, 0, reason: tune.title);
      }
    });
  });
}
