// Each instrument follows its own style when a progression mixes them.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/piano_comping.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';

void main() {
  final changes = [
    for (final symbol in ['Dm7', 'G7', 'C^7', 'A7']) (Chord.parse(symbol), 4),
  ];

  test('two-feel bass plays half notes, walking plays quarters', () {
    int notesPerBar(List<BassNote> line) => (line.length / 16).round();
    final walking = walkingBassLine(
      changes,
      choruses: 4,
      random: math.Random(1),
    );
    final twoFeel = twoFeelBassLine(
      changes,
      choruses: 4,
      random: math.Random(1),
    );
    expect(notesPerBar(walking), greaterThanOrEqualTo(4));
    expect(notesPerBar(twoFeel), lessThanOrEqualTo(3));
    expect(twoFeel.length, lessThan(walking.length * 0.75));
  });

  test('held piano plays each chord once, for its whole length', () {
    final comper = Comper(math.Random(2));
    for (final (chord, beats) in changes) {
      final hits = comper.comp(chord, beats, Feel.swing, held: true);
      expect(hits, hasLength(1));
      expect(hits.single.beat, 0);
      expect(hits.single.length, closeTo(beats, 0.1));
    }
    // A chord held into a second bar is struck again, more gently.
    final c = Chord.parse('C^7');
    final first = comper.comp(c, 4, Feel.swing, held: true).single;
    final again = comper.comp(c, 4, Feel.swing, held: true).single;
    expect(again.velocity, lessThan(first.velocity));
  });

  test('a mixed band renders: bossa drums, walking bass, held piano', () {
    final tune = Tune.fromChart(
      title: 'Mixed',
      key: 'C',
      defaultTempo: 120,
      chart: '| Dm7 | G7 | C^7 | A7 |',
      style: const BandStyle(
        drums: Feel.bossa,
        bass: BassStyle.walking,
        piano: PianoStyle.held,
      ),
    );
    final backing = renderBacking(
      BackingRequest(tune: tune, loop: LoopRange.wholeTune(tune), tempo: 120),
    );
    expect(backing.stems, hasLength(3));
  });

  test('a standard is played by its own feel, as before', () {
    expect(
      Tune.fromChart(
        title: 'T',
        key: 'C',
        defaultTempo: 120,
        feel: Feel.bossa,
        chart: '| C |',
      ).style,
      const BandStyle(
        drums: Feel.bossa,
        bass: BassStyle.bossa,
        piano: PianoStyle.straight,
      ),
    );
  });
}
