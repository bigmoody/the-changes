// Naming what you hear.
//
// The thing that decides whether this teaches anything is not the sound,
// it is the questions: asked in a different key every time, and offered
// against wrong answers that could genuinely be confused with the right
// one. A quiz that always asks in C teaches the pitch of C, and one that
// offers a ii-V-I against three chord qualities is not a question.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/ear_training.dart';

EarDealer dealer(EarGroup group, {int seed = 1, int choices = 4}) =>
    EarDealer(group: group, random: math.Random(seed), choices: choices);

List<EarQuestion> inGroup(EarGroup group) => [
  for (final q in earQuestions)
    if (q.group == group) q,
];

void main() {
  group('the questions themselves', () {
    test('every one is named, explained and playable', () {
      for (final question in earQuestions) {
        expect(question.name, isNotEmpty);
        expect(question.about, isNotEmpty, reason: question.name);
        expect(question.chords, isNotEmpty, reason: question.name);
      }
    });

    test('no two share a name, since the name is the answer', () {
      expect(
        earQuestions.map((q) => q.name).toSet(),
        hasLength(earQuestions.length),
      );
    });

    test('every chord in every question parses', () {
      for (final question in earQuestions) {
        final chords = inKey(question, 'C');
        expect(
          chords,
          hasLength(question.chords.length),
          reason: '${question.name}: ${question.chords}',
        );
      }
    });

    test('each group has enough in it to be a real choice', () {
      for (final group in EarGroup.values) {
        expect(
          inGroup(group).length,
          greaterThanOrEqualTo(4),
          reason: group.label,
        );
      }
    });

    test('a quality question is one chord, a cadence is several', () {
      for (final question in inGroup(EarGroup.quality)) {
        expect(question.chords, hasLength(1), reason: question.name);
      }
      for (final question in inGroup(EarGroup.movement)) {
        expect(question.chords, hasLength(2), reason: question.name);
      }
      for (final question in inGroup(EarGroup.cadence)) {
        expect(
          question.chords.length,
          greaterThanOrEqualTo(3),
          reason: question.name,
        );
      }
    });
  });

  group('moving it to a key', () {
    test('in C it is what was written', () {
      final twoFive = earQuestions.firstWhere((q) => q.name == 'ii V I');
      expect(inKey(twoFive, 'C').map((c) => c.display).toList(), [
        'Dm7',
        'G7',
        'CΔ7',
      ]);
    });

    test('and in another key it is the same shape, spelled properly', () {
      final twoFive = earQuestions.firstWhere((q) => q.name == 'ii V I');
      expect(inKey(twoFive, 'Eb').map((c) => c.display).toList(), [
        'Fm7',
        'B♭7',
        'E♭Δ7',
      ]);
      expect(inKey(twoFive, 'A').map((c) => c.display).toList(), [
        'Bm7',
        'E7',
        'AΔ7',
      ]);
    });

    test('every question survives every key', () {
      for (final question in earQuestions) {
        for (final key in 'C Db D Eb E F Gb G Ab A Bb B'.split(' ')) {
          final chords = inKey(question, key);
          expect(
            chords,
            hasLength(question.chords.length),
            reason: '${question.name} in $key',
          );
          for (final chord in chords) {
            expect(chord.display, isNotEmpty);
          }
        }
      }
    });

    test('a key that is not a key gives nothing rather than throwing', () {
      expect(inKey(earQuestions.first, 'H'), isEmpty);
    });
  });

  group('being asked', () {
    test('the right answer is always among the choices', () {
      final deal = dealer(EarGroup.cadence);
      for (var i = 0; i < 40; i++) {
        final ask = deal.next();
        expect(ask.choices.map((c) => c.name), contains(ask.answer.name));
      }
    });

    test('the wrong answers come from the same group', () {
      // A ii-V-I offered against three chord qualities is not a question.
      for (final group in EarGroup.values) {
        final ask = dealer(group).next();
        for (final choice in ask.choices) {
          expect(choice.group, group, reason: choice.name);
        }
      }
    });

    test('as many choices as asked for, and no repeats among them', () {
      for (final count in [2, 3, 4, 5]) {
        final ask = dealer(EarGroup.quality, choices: count).next();
        expect(ask.choices, hasLength(count));
        expect(ask.choices.map((c) => c.name).toSet(), hasLength(count));
      }
    });

    test('asking for more choices than exist gives what there is', () {
      final ask = dealer(EarGroup.movement, choices: 99).next();
      expect(ask.choices, hasLength(inGroup(EarGroup.movement).length));
    });

    test('it moves key, rather than always asking in C', () {
      // The whole point: a question always in C teaches the pitch of C.
      final deal = dealer(EarGroup.quality, seed: 3);
      final keys = {for (var i = 0; i < 40; i++) deal.next().key};
      expect(keys.length, greaterThan(4));
    });

    test('the chords played are the answer, in that key', () {
      final deal = dealer(EarGroup.cadence, seed: 7);
      for (var i = 0; i < 20; i++) {
        final ask = deal.next();
        expect(
          ask.chords.map((c) => c.display).toList(),
          inKey(ask.answer, ask.key).map((c) => c.display).toList(),
        );
      }
    });

    test('the same question is not asked twice running', () {
      final deal = dealer(EarGroup.movement, seed: 5);
      var last = deal.next().answer.name;
      for (var i = 0; i < 50; i++) {
        final now = deal.next().answer.name;
        expect(now, isNot(last));
        last = now;
      }
    });

    test('marking is by what it is, not by which button', () {
      final ask = dealer(EarGroup.quality).next();
      expect(ask.isRight(ask.answer), isTrue);
      final wrong = ask.choices.firstWhere((c) => c.name != ask.answer.name);
      expect(ask.isRight(wrong), isFalse);
    });

    test('every question in a group does come up', () {
      final deal = dealer(EarGroup.cadence, seed: 11);
      final seen = {for (var i = 0; i < 400; i++) deal.next().answer.name};
      expect(seen, hasLength(inGroup(EarGroup.cadence).length));
    });
  });

  group('the groups', () {
    test('each says what it is and what it is asking', () {
      for (final group in EarGroup.values) {
        expect(group.label, isNotEmpty);
        expect(group.about, isNotEmpty);
      }
    });
  });
}
