import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';

void main() {
  final tune = Tune.fromChart(
    title: 'Test',
    key: 'B♭',
    defaultTempo: 120,
    chart: '| Dm7 | G7 | Cm7 F7 | BbΔ7 Bb6 Bb7 |',
  );

  test('chords in a bar share its beats', () {
    expect(tune.bars[2].map((s) => s.beats), [2, 2]);
    expect(tune.bars[3].map((s) => s.beats), [2, 1, 1]);
    expect(tune.slotAtBeat(10).chord.display, 'F7');
  });

  test('loops a single bar, a single chord, or a range', () {
    expect(LoopRange.bars(tune, 1, 1).describe(tune), 'Bar 2');
    expect(LoopRange.slot(tune.bars[2][0]).describe(tune), 'Bar 3: Cm7 only');
    expect(
      LoopRange.bars(tune, 1, 1).extendedToBar(tune, 3).describe(tune),
      'Bars 2–4',
    );
    expect(LoopRange.bars(tune, 3, 0).isWholeTune(tune), isTrue);
  });

  test('renders a count-in plus exactly the looped beats', () {
    final backing = renderBacking(
      BackingRequest(
        tune: tune,
        loop: LoopRange.slot(tune.bars[2][1]), // just F7: 2 beats
        tempo: 120,
      ),
    );
    expect(backing.samplesPerBeat, 22050);
    expect(backing.loopStart, const Duration(seconds: 2));
    // The band; the arpeggios only play when asked for.
    expect(backing.stems.keys, [
      Instrument.chords,
      Instrument.bass,
      Instrument.drums,
    ]);
    // The count-in clicks loop under everything, so they're the same length
    // as the instruments and stay perfectly in sync.
    expect(backing.countIn.length, backing.stems[Instrument.bass]!.length);
    // Every instrument holds about a minute of different playing (at most
    // 32 passes): count-in + 32 × 2 beats.
    for (final instrument in backing.stems.keys) {
      expect(
        backing.stems[instrument]!.length,
        44 + (4 + 32 * 2) * 22050 * 2,
        reason: instrument.label,
      );
    }

    for (final wav in backing.stems.values) {
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    }
  });
}
