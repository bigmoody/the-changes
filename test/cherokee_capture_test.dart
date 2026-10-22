// A real record, Cherokee at about 338, played in another app and heard
// by Beat This!: the barlines it heard and what was pressed, replayed
// from the log the stage kept (test/captures/). Not the app's own band.
//
// Around 82 seconds in, Beat This! heard half bars, and one barline at
// the edge of near enough took the count to 325. It fell most of a bar
// behind before bar 5 was tapped at 91.7.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/tap_follower.dart';

void main() {
  test('Cherokee: half bars heard do not pull the count behind', () {
    final tune = standards.firstWhere((t) => t.title == 'Cherokee');
    var now = Duration.zero;
    final taps = TapFollower(tune: tune, clock: () => now);
    addTearDown(taps.dispose);
    Duration seconds(String s) =>
        Duration(microseconds: (double.parse(s) * 1e6).round());

    double? atTheTap;
    final log = File('test/captures/broadcast-cherokee-2.txt');
    for (final line in log.readAsLinesSync()) {
      if (line.startsWith('#')) continue;
      final word = line.split(RegExp(r'\s+'));
      now = seconds(word[0]);
      final event = word.sublist(1).join(' ');
      if (event.startsWith('HEARD BARLINE')) {
        taps.heardBarline(now - seconds(word[3]));
      } else if (event.startsWith('DOUBLE TIME')) {
        // Pressed because it was at half. Two bars tapped a bar apart
        // now put that right before then, and it would not be pressed.
        if (taps.tempo! < 250) taps.doubleTime();
      } else if (event.startsWith('TAPPED BAR')) {
        if (word[0] == '91.720') {
          atTheTap = taps.beat! / tune.beatsPerBar;
          break;
        }
        taps.placeAtBar(int.parse(word[3]) - 1);
      }
    }
    // Bar 5 is bars 4.0 to 5.0 counted from nought: the tap came on its
    // first beat, so the count should be there or a beat either side.
    expect(atTheTap, closeTo(4, 0.3));
    expect(taps.tempo, closeTo(338, 6));
  });
}
