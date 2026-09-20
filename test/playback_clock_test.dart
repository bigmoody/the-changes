import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune_library.dart';

void main() {
  final tune = standards.first;
  final backing = renderBacking(
    BackingRequest(tune: tune, loop: LoopRange.bars(tune, 0, 0), tempo: 120),
  );
  // 120 BPM: one beat = 0.5 s; count-in = 4 beats = 2 s; loop = bar 1.
  Duration seconds(double s) => Duration(microseconds: (s * 1e6).round());

  test('counts in, then follows the loop', () {
    final clock = PlaybackClock(
      backing: backing,
      loop: LoopRange.bars(tune, 0, 0),
    );
    expect(clock.positionAt(seconds(0.1)).countInBeat, 1);
    expect(clock.positionAt(seconds(1.6)).countInBeat, 4);
    expect(clock.positionAt(seconds(2.1)).tuneBeat, 0);
    expect(clock.positionAt(seconds(3.6)).tuneBeat, 3);
  });

  test('no count-in flash when the loop jumps back a hair early', () {
    final clock = PlaybackClock(
      backing: backing,
      loop: LoopRange.bars(tune, 0, 0),
    );
    clock.positionAt(seconds(0.5)); // counting in
    clock.positionAt(seconds(3.9)); // playing the loop
    // Engine reports just under the loop point (2 s) after wrapping.
    final wrapped = clock.positionAt(const Duration(microseconds: 1999977));
    expect(wrapped.countInBeat, isNull);
    expect(wrapped.tuneBeat, 0);
  });

  test('a position a rounding error short of the loop start is not beat 4', () {
    final clock = PlaybackClock(
      backing: backing,
      loop: LoopRange.bars(tune, 0, 0),
    );
    final atLoopPoint = clock.positionAt(const Duration(microseconds: 1999999));
    expect(atLoopPoint.countInBeat, isNull);
  });
}
