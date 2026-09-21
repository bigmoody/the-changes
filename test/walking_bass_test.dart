import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';

void main() {
  final autumnLeaves = standards.firstWhere((t) => t.title == 'Autumn Leaves');
  final chords = [for (final s in autumnLeaves.slots) (s.chord, s.beats)];

  List<BassNote> line(int seed, {int choruses = 4}) => walkingBassLine(
    chords,
    choruses: choruses,
    random: math.Random(seed),
    swing: tripletSwing,
  );

  test('chord changes land on chord tones, mostly the root', () {
    var changes = 0, roots = 0;
    for (var seed = 0; seed < 20; seed++) {
      final notes = line(seed);
      var beat = 0;
      for (var chorus = 0; chorus < 4; chorus++) {
        for (final slot in autumnLeaves.slots) {
          // The note sounding at the change (it may have been anticipated
          // by a swung eighth).
          final landing = notes.lastWhere((n) => n.beat <= beat + 0.01);
          expect(beat - landing.beat, lessThan(0.4), reason: 'seed $seed');
          final pitchClass = landing.pitch % 12;
          expect(
            [...slot.chord.pitchClasses, slot.chord.bass],
            contains(pitchClass),
            reason: 'seed $seed beat $beat',
          );
          changes++;
          if (pitchClass == slot.chord.bass) roots++;
          beat += slot.beats;
        }
      }
    }
    expect(roots / changes, greaterThan(0.75));
    expect(roots / changes, lessThan(0.99)); // sometimes the 3rd or 5th
  });

  test('stays in range with no leaps bigger than an octave', () {
    for (var seed = 0; seed < 20; seed++) {
      final notes = line(seed);
      for (var i = 0; i < notes.length; i++) {
        expect(notes[i].pitch, inInclusiveRange(bassLowest, bassHighest));
        if (i > 0) {
          expect(
            (notes[i].pitch - notes[i - 1].pitch).abs(),
            lessThanOrEqualTo(12),
            reason: 'seed $seed note $i',
          );
        }
      }
    }
  });

  test('lots of variety: bars, rhythms and feels all change', () {
    final oneBar = [(autumnLeaves.slots.first.chord, 4)];
    final notes = walkingBassLine(
      oneBar,
      choruses: 32,
      random: math.Random(11),
      swing: tripletSwing,
    );
    final bars = <String>{};
    final rhythms = <String>{};
    for (var bar = 0; bar < 32; bar++) {
      final inBar = notes.where(
        (n) => n.beat >= bar * 4 - 0.01 && n.beat < bar * 4 + 3.99,
      );
      bars.add(inBar.map((n) => n.pitch).join(','));
      rhythms.add(
        inBar.map((n) => (n.beat - bar * 4).toStringAsFixed(1)).join(','),
      );
    }
    expect(bars.length, greaterThan(20), reason: 'distinct pitch patterns');
    expect(rhythms.length, greaterThan(3), reason: 'distinct rhythms');
    expect(notes.where((n) => n.velocity < 0.55), isNotEmpty, reason: 'ghosts');
    expect(notes.where((n) => n.length > 1.5), isNotEmpty, reason: 'two-feel');
  });

  test('choruses differ from each other, but a seed is repeatable', () {
    final notes = line(3, choruses: 2);
    final beatsPerChorus = autumnLeaves.totalBeats;
    final first = [
      for (final n in notes)
        if (n.beat < beatsPerChorus) n.pitch,
    ];
    final second = [
      for (final n in notes)
        if (n.beat >= beatsPerChorus) n.pitch,
    ];
    expect(first, isNot(equals(second)));
    List<int> pitches(int seed) => [for (final n in line(seed)) n.pitch];
    expect(pitches(3), pitches(3));
    expect(pitches(3), isNot(equals(pitches(4))));
  });

  test('a one-bar loop gets a minute of different playing, in sync', () {
    final request = BackingRequest(
      tune: autumnLeaves,
      loop: LoopRange.bars(autumnLeaves, 0, 0),
      tempo: 120,
      countInBars: 0,
    );
    final backing = renderBacking(request);
    expect(chorusesPerBatch(request), 30); // 60 s of 2-second bars

    // Every instrument covers the same 30 bars, and no instrument plays the
    // first two bars identically.
    final bar = 4 * 22050 * 2; // bytes in one bar (4 beats at 120 BPM)
    for (final instrument in backing.stems.keys) {
      final wav = backing.stems[instrument]!;
      expect(wav.length - 44, 30 * bar, reason: instrument.label);
      final samples = wav.buffer.asInt16List(44);
      final bar1 = Int16List.sublistView(samples, 0, bar ~/ 2);
      final bar2 = Int16List.sublistView(samples, bar ~/ 2, bar);
      expect(bar1, isNot(equals(bar2)), reason: '${instrument.label} repeats');
    }
  });

  test('batches differ, continue the line, and join without a click', () {
    final request = BackingRequest(
      tune: autumnLeaves,
      loop: LoopRange.bars(autumnLeaves, 0, 3),
      tempo: 160,
      countInBars: 1,
      seed: 4,
    );
    final first = renderBacking(request);
    final second = renderBatch(
      request,
      batch: 1,
      gain: first.gain,
      state: first.batch.state,
      carryIn: first.batch.tails,
    );
    final countIn = first.countInBeats * first.samplesPerBeat;
    for (final instrument in first.batch.pcm.keys) {
      final a = Int16List.sublistView(
        Uint8List.fromList(first.batch.pcm[instrument]!).buffer.asInt16List(),
        countIn,
      );
      final b = Uint8List.fromList(second.pcm[instrument]!).buffer
          .asInt16List();
      expect(b.length, a.length, reason: instrument.label);
      expect(b, isNot(equals(a)), reason: '${instrument.label} repeats');

      // The join: the jump between batches is no bigger than jumps within.
      var biggestJump = 0;
      for (var i = 1; i < a.length; i++) {
        biggestJump = math.max(biggestJump, (a[i] - a[i - 1]).abs());
      }
      expect(
        (b.first - a.last).abs(),
        lessThanOrEqualTo(biggestJump),
        reason: '${instrument.label} clicks at the join',
      );
    }
  });

  test('bossa bass varies too, while staying a bossa figure', () {
    final blueBossa = standards.firstWhere((t) => t.title == 'Blue Bossa');
    final oneBar = [(blueBossa.slots.first.chord, 4)];
    final notes = bossaBassLine(
      oneBar,
      choruses: 32,
      random: math.Random(5),
      swing: tripletSwing,
    );
    final bars = <String>{};
    var roots = 0;
    for (var bar = 0; bar < 32; bar++) {
      final inBar = notes
          .where((n) => n.beat >= bar * 4 - 0.01 && n.beat < bar * 4 + 3.99)
          .toList();
      bars.add(
        inBar
            .map((n) => '${n.pitch}@${(n.beat - bar * 4).toStringAsFixed(1)}')
            .join(','),
      );
      if (inBar.isNotEmpty &&
          inBar.first.beat - bar * 4 < 0.01 &&
          inBar.first.pitch % 12 == blueBossa.slots.first.chord.bass) {
        roots++;
      }
      // Bossa rhythm: notes on beats or the "and" of a beat, no triplets.
      for (final n in inBar) {
        final position = (n.beat - bar * 4) * 2;
        expect((position - position.round()).abs(), lessThan(0.05));
      }
    }
    expect(bars.length, greaterThan(8), reason: 'distinct bars');
    expect(roots, greaterThan(20), reason: 'mostly starts on the root');
  });
}
