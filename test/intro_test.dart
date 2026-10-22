// A tune's intro, played once and never again.
//
// iReal Pro plays a chart that opens with an intro (marked "in" on its
// chart) that way: the intro once, then the rest round and round for as
// long as the band plays. Valse Hot is eight bars of intro and a sixteen
// bar A section, and its A section is what the band goes round. The app
// played the intro again at the top of every chorus.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/arrangement.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';

/// Shaped like Valse Hot: eight bars of intro, then a sixteen bar A.
final _valse = Tune.fromChart(
  title: 'A Waltz With an Intro',
  key: 'Ab',
  defaultTempo: 120,
  chart:
      '| [Intro] Bbm7 | Eb7 | AbΔ7 | AbΔ7 | Ebm7 | Ab7 | DbΔ7 | DbΔ7 '
      '| [A] AbΔ7 | DbΔ7 | Cm7 | F7 | Bbm7 | Eb7 | AbΔ7 | F7 '
      '| Bbm7 | Dbm6 | Cm7 | F7 | Bbm7 | Eb7 | AbΔ7 | Eb7 |',
);

void main() {
  test('a tune that opens with an intro says where it is', () {
    final intro = introOf(_valse)!;
    expect(intro.firstBar(_valse), 0);
    expect(intro.lastBar(_valse), 7);
    // And one that does not, has none.
    final plain = Tune.fromChart(
      title: 'No Intro',
      key: 'C',
      defaultTempo: 120,
      chart: '| [A] C | F | G7 | C |',
    );
    expect(introOf(plain), isNull);
  });

  test('the intro is played once, after the count-in, before the loop', () {
    final intro = introOf(_valse)!;
    final loop = LoopRange(
      startBeat: intro.endBeat,
      lengthBeats: _valse.totalBeats - intro.endBeat,
    );
    final request = BackingRequest(
      tune: _valse,
      loop: loop,
      intro: intro,
      tempo: 120,
      arrangement: const Arrangement(choruses: 2),
    );
    final backing = renderBacking(request);
    expect(backing.introBeats, intro.lengthBeats);
    // The count-in, the intro once, and two times round the A section:
    // not two times round the intro and the A.
    final beats =
        backing.countInBeats + intro.lengthBeats + 2 * loop.lengthBeats;
    final samples = backing.batch.pcm[Instrument.bass]!.length ~/ 2;
    expect(samples, beats * backing.samplesPerBeat);
  });

  test('the clock walks through the intro, then round the A section', () {
    final intro = introOf(_valse)!;
    final loop = LoopRange(
      startBeat: intro.endBeat,
      lengthBeats: _valse.totalBeats - intro.endBeat,
    );
    final backing = renderBacking(
      BackingRequest(tune: _valse, loop: loop, intro: intro, tempo: 120),
    );
    final clock = PlaybackClock(backing: backing, loop: loop);
    // At 120, half a second a beat; a bar of four beats counted in.
    Duration atBeat(double beat) =>
        Duration(microseconds: (beat * 500000).round());
    expect(clock.positionAt(atBeat(1)).countInBeat, 2);
    // The first beat after the count-in is the intro's first.
    expect(clock.positionAt(atBeat(4.1)).tuneBeat, 0);
    // The intro's last bar.
    expect(clock.positionAt(atBeat(4 + 29.1)).tuneBeat, 29);
    // Then the A section, from its top.
    expect(clock.positionAt(atBeat(4 + 32.1)).tuneBeat, loop.startBeat);
    // And round the A again, not back to the intro.
    final second = 4 + 32 + loop.lengthBeats + 0.1;
    expect(clock.positionAt(atBeat(second)).tuneBeat, loop.startBeat);
    expect(clock.positionAt(atBeat(second)).chorus, 1);
  });
}
