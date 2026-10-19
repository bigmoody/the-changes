// Finding the bar of the tune from what sounded in the bars heard. On
// pitches made from the chart itself, so these say the matching and the
// moving work, not how well it hears a record.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/form_finder.dart';
import 'package:play_along/practice/tap_follower.dart';

void main() {
  final tune = standards.firstWhere((t) => t.title == 'St. Thomas');

  /// What would sound in bar [index] of the chart: its chords' notes, and
  /// their lowest note in the bass.
  List<double> soundOf(int index) {
    final out = <double>[];
    for (var half = 0; half < 2; half++) {
      final chord = tune.slotAtBeat(index * tune.beatsPerBar + half * 2).chord;
      final harmony = List<double>.filled(12, 0.1);
      for (final pc in chord.pitchClasses) {
        harmony[pc] = 1;
      }
      final bass = List<double>.filled(12, 0.1)..[chord.bass] = 1;
      out
        ..addAll(harmony)
        ..addAll(bass);
    }
    return out;
  }

  const bar = Duration(seconds: 1);

  test('finds how far the count is from the band', () {
    final form = FormFinder(tune: tune);
    // The band is on bars 9 to 18; the count calls them 1 to 10.
    for (var i = 0; i < 10; i++) {
      form.heard(bar * i, soundOf((8 + i) % 16));
    }
    expect(form.shift((at) => at.inSeconds % 16), 8);
  });

  test('waits for eight bars', () {
    final form = FormFinder(tune: tune);
    for (var i = 0; i < 7; i++) {
      form.heard(bar * i, soundOf(8 + i));
    }
    expect(form.shift((at) => at.inSeconds % 16), isNull);
  });

  test('says nought when sure the count is already right', () {
    final form = FormFinder(tune: tune);
    for (var i = 0; i < 12; i++) {
      form.heard(bar * i, soundOf(i));
    }
    expect(form.shift((at) => at.inSeconds % 16), 0);
  });

  test('says nothing when nothing tells the places apart', () {
    final form = FormFinder(tune: tune);
    for (var i = 0; i < 12; i++) {
      form.heard(bar * i, List<double>.filled(48, 1));
    }
    expect(form.shift((at) => at.inSeconds % 16), isNull);
  });

  test('the count moves by whole bars and keeps its time', () {
    var now = Duration.zero;
    final taps = TapFollower(tune: tune, clock: () => now);
    addTearDown(taps.dispose);
    for (var i = 0; i < 5; i++) {
      now = bar * 2 * i;
      taps.heardBarline(Duration.zero);
    }
    // Started by the barlines alone: where, not which bar.
    expect(taps.placeKnown, isFalse);
    // Bar 1 at 8 s; half a bar on, still bar 1.
    now = const Duration(seconds: 9);
    expect(taps.barAt(now), 0);
    taps.moveBars(8);
    expect(taps.barAt(now), 8);
    expect(taps.beat, 8 * tune.beatsPerBar + 2);
    // A bar before the count started is a whole bar back.
    expect(taps.barAt(const Duration(seconds: 7)), 7);
    expect(taps.placedByHand, isFalse);
    expect(taps.placeKnown, isTrue, reason: 'moved to the bar heard');
    taps.placeAtBar(3);
    expect(taps.placedByHand, isTrue);
    taps.stop();
    expect(taps.placedByHand, isFalse);
  });
}
