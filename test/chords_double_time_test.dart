// The chords telling a count at half the band's tempo: Cherokee at 338,
// broadcast from another app and heard by Beat This!, which heard every
// other barline for its first minute and counted at 169. The bars it
// heard, and what sounded in them, replayed from the stage's logs
// (test/captures/). Real records, not the app's own band.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/form_finder.dart';
import 'package:play_along/practice/tap_follower.dart';

void main() {
  final tune = standards.firstWhere((t) => t.title == 'Cherokee');
  Duration seconds(String s) =>
      Duration(microseconds: (double.parse(s) * 1e6).round());

  test('Cherokee at half: the chords double it, nothing pressed', () {
    // The fourth broadcast, which the figure was not chosen on. Double
    // Time was pressed at 36.8; here nothing is pressed or tapped.
    var now = Duration.zero;
    final taps = TapFollower(tune: tune, clock: () => now);
    addTearDown(taps.dispose);
    final form = FormFinder(tune: tune);
    double? doubledAt;
    double? at150;
    final log = File('test/captures/broadcast-cherokee-4.txt');
    for (final line in log.readAsLinesSync()) {
      if (line.startsWith('#')) continue;
      final word = line.split(RegExp(r'\s+'));
      now = seconds(word[0]);
      if (at150 == null && now >= const Duration(seconds: 150)) {
        at150 = taps.tempo;
      }
      if (word[1] != 'HEARD') continue;
      if (word[2] == 'BARLINE') {
        taps.heardBarline(now - seconds(word[3]));
      } else if (word[2] == 'BAR' && taps.counting) {
        form.heard(seconds(word[3]), [
          for (final x in word.sublist(4)) double.parse(x),
        ]);
        // As the stage does it.
        final bar = Duration(
          microseconds: (60e6 / taps.tempo! * tune.beatsPerBar).round(),
        );
        if (doubledAt == null && form.twiceAsLong(bar)) {
          taps.doubleTime();
          form.clear();
          doubledAt = now.inMilliseconds / 1000;
        }
      }
    }
    // At 31.3 seconds: five before Double Time was pressed.
    expect(doubledAt, isNotNull);
    expect(doubledAt, lessThan(36));
    // Two minutes on, still at the band's tempo.
    expect(at150, closeTo(338, 10));
  });

  test('Cherokee counted right: the chords leave it alone', () {
    // The third broadcast after a minute in, at 338 with every barline
    // heard.
    final form = FormFinder(tune: tune);
    const bar = Duration(microseconds: 710000);
    final log = File('test/captures/broadcast-cherokee-3.txt');
    for (final line in log.readAsLinesSync()) {
      final word = line.split(RegExp(r'\s+'));
      if (word.length < 4 || word[1] != 'HEARD' || word[2] != 'BAR') continue;
      if (double.parse(word[3]) < 58) continue;
      form.heard(seconds(word[3]), [
        for (final x in word.sublist(4)) double.parse(x),
      ]);
      expect(form.twiceAsLong(bar), isFalse, reason: 'at ${word[3]} s');
    }
  });
}
