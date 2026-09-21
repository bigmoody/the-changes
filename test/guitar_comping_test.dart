// The guitarist: jazz voicings laid out as a guitar plays them, moving
// smoothly, in each style's own rhythm.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/audio/guitar_comping.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';

List<GuitarHit> bar(
  String symbol,
  PianoStyle style,
  Feel groove, {
  int index = 0,
  int seed = 1,
}) => GuitarComper(math.Random(seed)).comp(
  Chord.parse(symbol),
  4,
  style: style,
  groove: groove,
  beatInBar: 0,
  bar: index,
  swing: tripletSwing,
);

/// Whether [notes] sit on four strings with no fret more than three apart.
bool playable(List<int> notes) {
  for (final strings in [
    [2, 3, 4, 5],
    [1, 2, 3, 4],
    [0, 2, 3, 4],
    [1, 3, 4, 5],
  ]) {
    final frets = [
      for (var i = 0; i < 4; i++) notes[i] - guitarTuning[strings[i]],
    ];
    if (frets.every((f) => f >= 1 && f <= 14) &&
        frets.reduce(math.max) - frets.reduce(math.min) <= 3) {
      return true;
    }
  }
  return false;
}

void main() {
  test('jazz voicings a hand can play, with the 3rd and 7th', () {
    for (final symbol in [
      'C^7', 'Dm7', 'G7', 'Bb7', 'F#m7b5', 'Eb6', 'Abm6', 'Bo7', //
      'D7#11', 'C13', 'E7alt', 'Gm^7', 'F7sus4', 'Db^7', 'A7b9',
    ]) {
      final chord = Chord.parse(symbol);
      final shapes = guitarCompVoicings(chord);
      expect(shapes, isNotEmpty, reason: symbol);
      final intervals = chord.quality.intervals.map((i) => i % 12).toSet();
      final third = intervals.contains(4) ? 4 : (intervals.contains(3) ? 3 : 5);
      for (final shape in shapes) {
        expect(shape, hasLength(4), reason: symbol);
        expect(playable(shape), isTrue, reason: '$symbol: $shape');
        final pcs = shape.map((n) => (n - chord.root) % 12).toSet();
        expect(pcs, contains(third), reason: '$symbol: $shape has its 3rd');
      }
    }
  });

  test('every chord in every tune, in every key, has a guitar shape', () {
    final missing = <String>{};
    for (final tune in [...standards, ...practiceProgressions]) {
      for (var key = 0; key < 12; key++) {
        final slots = tune.transposed(key).slots;
        for (var i = 0; i < slots.length; i++) {
          final chord = slots[i].chord;
          final next = slots[(i + 1) % slots.length].chord;
          if (guitarCompVoicings(chord, resolvingTo: next).isEmpty) {
            missing.add(chord.display);
          }
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('a dominant resolving to minor is voiced altered', () {
    final shapes = guitarCompVoicings(
      Chord.parse('E7'),
      resolvingTo: Chord.parse('Am7'),
    );
    for (final shape in shapes) {
      final pcs = shape.map((n) => (n - 4) % 12).toSet();
      expect(pcs, anyOf(contains(1), contains(8)), reason: '♭9 or ♭13');
    }
  });

  test('swing: varied rhythms, and the shapes move smoothly', () {
    final comper = GuitarComper(math.Random(4));
    final rhythms = <String>{};
    List<int>? last;
    var movement = 0;
    var changes = 0;
    final changesInTune = [
      'Dm7', 'G7', 'C^7', 'A7', 'Dm7', 'G7', 'Em7', 'A7', //
      'Dm7', 'G7', 'C^7', 'C^7',
    ];
    for (var i = 0; i < changesInTune.length; i++) {
      final hits = comper.comp(
        Chord.parse(changesInTune[i]),
        4,
        style: PianoStyle.swing,
        groove: Feel.swing,
        beatInBar: 0,
        bar: i,
        next: Chord.parse(changesInTune[(i + 1) % changesInTune.length]),
        swing: tripletSwing,
      );
      rhythms.add(hits.map((h) => h.beat.toStringAsFixed(2)).join(' '));
      for (final hit in hits) {
        expect(hit.notes, hasLength(4));
        if (last != null && hit.notes != last) {
          movement += [
            for (var v = 0; v < 4; v++) (hit.notes[v] - last[v]).abs(),
          ].reduce((a, b) => a + b);
          changes++;
        }
        last = hit.notes;
      }
    }
    expect(rhythms.length, greaterThan(3), reason: 'not the same every bar');
    // Four voices moving less than two semitones each, on average.
    expect(movement / changes, lessThan(8));
  });

  test('bossa: the voicing plucked on a two-bar figure', () {
    for (var seed = 0; seed < 10; seed++) {
      final comper = GuitarComper(math.Random(seed));
      final first = comper.comp(
        Chord.parse('Dm7'),
        4,
        style: PianoStyle.straight,
        groove: Feel.bossa,
        beatInBar: 0,
        bar: 0,
        swing: tripletSwing,
      );
      final second = comper.comp(
        Chord.parse('G7'),
        4,
        style: PianoStyle.straight,
        groove: Feel.bossa,
        beatInBar: 0,
        bar: 1,
        swing: tripletSwing,
      );
      final figure =
          '${first.map((h) => h.beat).toList()} '
          '${second.map((h) => h.beat).toList()}';
      expect(
        figure,
        isIn([
          '[0.0, 1.5, 3.0] [1.0, 2.5]',
          '[0.0, 1.5, 2.5] [0.5, 2.0, 3.5]',
          '[0.0, 0.5, 1.5, 2.5] [0.5, 1.0, 2.5]',
        ]),
      );
      expect(first.every((h) => h.strum == Strum.together), isTrue);
      expect(first.first.notes, hasLength(4));
    }
  });

  test('calypso: the strum, with upstrokes on the off-beats', () {
    for (var seed = 0; seed < 10; seed++) {
      final hits = bar('C6', PianoStyle.calypso, Feel.calypso, seed: seed);
      for (final hit in hits) {
        expect(
          hit.strum,
          hit.beat % 1 == 0 ? Strum.down : Strum.up,
          reason: 'beat ${hit.beat}',
        );
      }
    }
  });

  test('funk: short, high chops', () {
    final hits = bar('Bbm7', PianoStyle.straight, Feel.funk);
    expect(hits.length, greaterThanOrEqualTo(5));
    for (final hit in hits) {
      expect(hit.length, lessThan(0.2));
      expect(hit.notes.length, lessThanOrEqualTo(3));
    }
  });

  test('slow funk is soul: small chords on the backbeat', () {
    final comper = GuitarComper(math.Random(3));
    for (var index = 0; index < 8; index++) {
      final hits = comper.comp(
        Chord.parse(index.isEven ? 'Bb7' : 'Eb7'),
        4,
        style: PianoStyle.straight,
        groove: Feel.funk,
        beatInBar: 0,
        bar: index,
        tempo: 72,
        swing: tripletSwing,
      );
      expect(hits.map((h) => h.beat).where((b) => b % 1 == 0), [
        1,
        3,
      ], reason: 'on 2 and 4');
      expect(hits.every((h) => h.notes.length <= 3), isTrue);
    }
  });

  test('a funk riff is held for a phrase, not changed every bar', () {
    final comper = GuitarComper(math.Random(5));
    final riffs = [
      for (var index = 0; index < 4; index++)
        comper
            .comp(
              Chord.parse('Bbm7'),
              4,
              style: PianoStyle.straight,
              groove: Feel.funk,
              beatInBar: 0,
              bar: index,
              tempo: 110,
              swing: tripletSwing,
            )
            .map((h) => h.beat)
            .join(' '),
    ];
    expect(riffs.toSet(), hasLength(1));
  });

  test('held: one strum, left to ring', () {
    final hits = bar('Fmaj7', PianoStyle.held, Feel.swing);
    expect(hits, hasLength(1));
    expect(hits.single.length, greaterThan(3.5));
    expect(hits.single.notes, hasLength(4));
  });
}
