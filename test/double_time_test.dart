// The count doubling itself on a quick tune: the beats and barlines
// Beat This! heard on real records (test/captures/beat-this-live.json,
// its live 20-second windows run on four microphone captures), fed to
// the count as the stage feeds it. Not the app's own band.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/tap_follower.dart';

void main() {
  final captures = jsonDecode(
    File('test/captures/beat-this-live.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  /// The count's bar at the end, in seconds, and whether it doubled.
  ({double bar, bool doubled}) follow(String name) {
    final capture = captures[name] as Map<String, dynamic>;
    // Named as the capture's file was: no quotes or capitals.
    String plain(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    final tune = standards.firstWhere(
      (t) => plain(t.title) == plain(capture['tune'] as String),
    );
    var now = Duration.zero;
    final taps = TapFollower(tune: tune, clock: () => now);
    addTearDown(taps.dispose);
    var doubled = false;
    taps.onDoubled = () => doubled = true;
    List<double> list(String key) => [
      for (final x in capture[key] as List) (x as num).toDouble(),
    ];
    final beats = list('beats');
    final downbeats = list('downbeats');
    Duration ago(double t, double at) =>
        Duration(milliseconds: ((t - at) * 1000).round());
    var next = 0;
    // A look every half second, as the stage has them: barlines a second
    // after they were played, and the beats of the last twenty seconds
    // every other look.
    for (var t = 0.0; t < beats.last + 2; t += 0.5) {
      now = Duration(milliseconds: (t * 1000).round());
      while (next < downbeats.length && downbeats[next] + 1 <= t) {
        taps.heardBarline(ago(t, downbeats[next++]));
      }
      if ((t * 2).round().isEven) {
        taps.heardBeats([
          for (final b in beats)
            if (b > t - 20 && b < t - 0.5) ago(t, b),
        ]);
      }
    }
    return (bar: 60 / taps.tempo! * tune.beatsPerBar, doubled: doubled);
  }

  test('Cherokee at 333: the count doubles itself', () {
    // Beat This! first heard every other barline, and the count started
    // at half; then it heard them all, and the beat at 333.
    final heard = follow('heard-Cherokee-2026-10-17T16-07-10');
    expect(heard.doubled, isTrue);
    expect(heard.bar, closeTo(0.72, 0.05));
  });

  test('tunes at the tempo heard are not doubled', () {
    for (final name in [
      // Half bars heard steadily for a while, the beat heard at the
      // count's: not doubled.
      'heard-Take-the-A-Train-2026-10-17T16-27-25',
      'heard-So-What-2026-10-17T16-19-01',
      'heard-St-Thomas-2026-10-17T13-58-31',
    ]) {
      expect(follow(name).doubled, isFalse, reason: name);
    }
  });
}
