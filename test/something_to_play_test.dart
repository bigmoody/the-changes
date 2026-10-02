// The button that decides for you.
//
// What is worth testing is that it is kind. A tune you cannot play, in a
// key you have never tried, at a tempo you cannot manage is not a
// practice session, it is a reason to put the phone down, and somebody
// who needed this button is exactly the person who will not pick it up
// again. So: the tempo stays near the tune's own, the key is usually the
// written one, and it does not hand back what it just handed over.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/something_to_play.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

/// A thousand picks, so what is random can be talked about.
List<Suggestion> many({
  Set<String> starred = const {},
  List<String> recent = const [],
  int times = 1000,
}) {
  final dice = Random(7);
  return [
    for (var i = 0; i < times; i++)
      somethingToPlay(
        standards,
        starred: starred,
        recent: recent,
        random: dice,
      )!,
  ];
}

void main() {
  group('it always gives you something', () {
    test('an empty book is nothing rather than a crash', () {
      expect(somethingToPlay(const []), isNull);
    });

    test('a book of one hands back that one', () {
      final only = standards.first;
      expect(somethingToPlay([only])?.tune.title, only.title);
    });
  });

  group('and it is kind about it', () {
    test('the tempo stays near the one the tune carries', () {
      // A ballad must never arrive as a burn-up. Allowed to wander a
      // fifth either way, and then moved to suit the feel, which is why
      // this is checked loosely rather than exactly.
      for (final picked in many()) {
        expect(picked.tempo, greaterThanOrEqualTo(40));
        expect(picked.tempo, lessThanOrEqualTo(320));
      }
    });

    test('and it leans slow rather than fast', () {
      // Not the same both ways. A tune written at 230 arriving at 184 is
      // a pleasure and the same tune at 276 is a wall, and the person who
      // needed a button to start is the person who stops at a wall.
      final plain = many().where((p) => p.style == null);
      expect(plain, isNotEmpty);
      for (final picked in plain) {
        final own = picked.tune.defaultTempo;
        expect(
          picked.tempo,
          greaterThanOrEqualTo((own * 0.74).floor()),
          reason: '${picked.tune.title} at ${picked.tempo}, written $own',
        );
        expect(
          picked.tempo,
          lessThanOrEqualTo((own * 1.11).ceil()),
          reason: '${picked.tune.title} at ${picked.tempo}, written $own',
        );
      }
    });

    test('mostly the written key, sometimes not', () {
      final picks = many();
      final moved = picks.where((p) => p.semitones != 0).length;
      // A third or so. Often enough to be worth something, rarely enough
      // that the button is not a transposition drill.
      expect(moved / picks.length, greaterThan(0.2));
      expect(moved / picks.length, lessThan(0.5));
    });

    test('mostly the tune own feel, sometimes not', () {
      final picks = many();
      final rephrased = picks.where((p) => p.style != null).length;
      expect(rephrased / picks.length, greaterThan(0.1));
      expect(
        rephrased / picks.length,
        lessThan(0.3),
        reason: 'a bossa nova Cherokee is a joke, not a practice',
      );
    });

    test('a key is always one of the twelve', () {
      for (final picked in many()) {
        expect(picked.semitones, greaterThanOrEqualTo(0));
        expect(picked.semitones, lessThan(12));
      }
    });
  });

  group('what it draws from', () {
    test('what you starred, when you have starred anything', () {
      final picks = many(starred: {'Blue Monk', 'Autumn Leaves'});
      expect(picks.map((p) => p.tune.title).toSet(), {
        'Blue Monk',
        'Autumn Leaves',
      });
    });

    test('the whole book when you have not', () {
      expect(many().map((p) => p.tune.title).toSet().length, greaterThan(50));
    });

    test('and it does not hand back what it just handed over', () {
      // The one thing that makes a button like this feel broken.
      final lately = standards.take(3).map((t) => t.title).toList();
      for (final picked in many(recent: lately, times: 200)) {
        expect(lately, isNot(contains(picked.tune.title)));
      }
    });

    test('unless that is all there is', () {
      final only = standards.first;
      final picked = somethingToPlay([only], recent: [only.title]);
      expect(picked?.tune.title, only.title);
    });

    test('a star on a tune that is not in the book is ignored', () {
      final picks = many(starred: {'Not a Tune'});
      expect(picks.map((p) => p.tune.title).toSet().length, greaterThan(50));
    });
  });

  group('what it says it gave you', () {
    test('the tune, the key and the tempo, and the feel when it moved it', () {
      final tune = standards.firstWhere((t) => t.title == 'Blue Monk');
      final said = describe((
        tune: tune,
        semitones: 0,
        tempo: 120,
        style: null,
      ));
      expect(said, contains('Blue Monk'));
      expect(said, contains('at 120'));

      final moved = describe((
        tune: tune,
        semitones: 2,
        tempo: 140,
        style: BandStyle.of(Feel.bossa),
      ));
      expect(moved, contains('bossa'));
      expect(
        moved,
        contains(tune.keyLabelBy(2)),
        reason: 'the key it will actually be in',
      );
    });
  });
}
