// Time signatures other than 4/4: a jazz waltz and a five, from the drums
// and bass up to a chart you write yourself.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart';
import 'package:play_along/audio/walking_bass.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/ireal_import.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

Tune _waltz({int beatsPerBar = 3}) => Tune.fromChart(
  title: 'Waltz',
  key: 'C',
  defaultTempo: 140,
  beatsPerBar: beatsPerBar,
  chart: '| CΔ7 | Am7 | Dm7 | G7 |',
);

void main() {
  group('the drums keep to the bar', () {
    for (final beatsPerBar in [2, 3, 4, 5, 7]) {
      test('nothing falls past the end of a $beatsPerBar-beat bar', () {
        for (final feel in Feel.values) {
          for (var bar = 0; bar < 16; bar++) {
            final hits = drumBar(
              feel: feel,
              bar: bar,
              beatsPerBar: beatsPerBar,
              random: math.Random(bar),
              swing: tripletSwing,
            );
            // Gypsy jazz has no drummer at all, which is the part
            // rather than a part missing.
            expect(
              hits,
              feel.hasDrums ? isNotEmpty : isEmpty,
              reason: '$feel, bar $bar',
            );
            for (final hit in hits) {
              expect(hit.beat, lessThan(beatsPerBar), reason: '$feel');
              expect(hit.beat, greaterThanOrEqualTo(0));
            }
          }
        }
      });
    }

    test('in a waltz the hi-hat closes on 2 and 3, not just 2', () {
      final pedals = {
        for (var bar = 0; bar < 8; bar++)
          for (final hit in drumBar(
            feel: Feel.swing,
            bar: bar,
            beatsPerBar: 3,
            random: math.Random(bar),
            swing: tripletSwing,
          ))
            if (hit.drum == Drum.hiHatPedal) hit.beat,
      };
      expect(pedals, {1.0, 2.0});
    });
  });

  test('the bass walks three to the bar', () {
    final line = walkingBassLine(
      [
        for (final chord in ['CΔ7', 'Am7', 'Dm7', 'G7'])
          (Chord.parse(chord), 3),
      ],
      choruses: 1,
      random: math.Random(1),
      beatsPerBar: 3,
      swing: tripletSwing,
    );
    // Three bars' worth of notes, nothing past the end, and every bar
    // played (a bassist may hold two beats rather than walk all three).
    expect(line.length, inInclusiveRange(8, 16));
    expect([for (final n in line) n.beat], everyElement(lessThan(12)));
    for (var bar = 0; bar < 4; bar++) {
      expect(
        line.where((n) => n.beat >= bar * 3 && n.beat < bar * 3 + 3),
        isNotEmpty,
        reason: 'bar $bar',
      );
    }
    for (final note in line) {
      expect(note.pitch, inInclusiveRange(bassLowest, bassHighest));
    }
  });

  test('a waltz renders, and lasts three beats a bar', () {
    final tune = _waltz();
    expect(tune.totalBeats, 12);
    const tempo = 120;
    final backing = renderBacking(
      BackingRequest(
        tune: tune,
        loop: LoopRange.wholeTune(tune),
        tempo: tempo,
        countInBars: 1,
      ),
    );
    // The count-in is a bar of three, and the band plays for a while.
    expect(backing.countInBeats, 3);
    expect(backing.batch.pcm, isNotEmpty);
    final beats =
        backing.batch.pcm.values.first.length / backing.samplesPerBeat;
    expect(beats, greaterThan(12), reason: 'more than one chorus');
  });

  test('five to the bar plays too', () {
    final five = Tune.fromChart(
      title: 'Five',
      key: 'C',
      defaultTempo: 160,
      beatsPerBar: 5,
      chart: '| Cm7 | Cm7 | Fm7 | G7 |',
    );
    expect(five.totalBeats, 20);
    final backing = renderBacking(
      BackingRequest(
        tune: five,
        loop: LoopRange.wholeTune(five),
        tempo: 160,
        countInBars: 0,
      ),
    );
    expect(backing.batch.pcm, isNotEmpty);
  });

  group('your own charts', () {
    test('the time signature is saved, and played', () {
      final waltz = UserProgression(
        id: 'w',
        title: 'My Waltz',
        key: 'C',
        tempo: 120,
        bars: ['CΔ7', 'Am7', 'Dm7', 'G7'],
        style: BandStyle.of(Feel.swing),
        beatsPerBar: 3,
      );
      expect(waltz.meter, '3/4');
      expect(waltz.toTune().beatsPerBar, 3);
      expect(waltz.toTune().totalBeats, 12);
      final again = UserProgression.fromJson(waltz.toJson());
      expect(again.beatsPerBar, 3);
      // Charts written before time signatures existed are in 4/4.
      final old = waltz.toJson()..remove('beats');
      expect(UserProgression.fromJson(old).beatsPerBar, 4);
    });

    test('an imported waltz keeps its 3/4; 6/8 says it plays in 4/4', () {
      String link(String music) =>
          'irealbook://${Uri.encodeComponent('T=Doe Jane=Jazz Waltz=C=n=$music')}';
      final waltz = parseIrealPro(link('[T34C^7 |A-7 |D-7 |G7 Z')).single;
      expect(waltz.progression.beatsPerBar, 3);
      expect(waltz.notes, isEmpty);
      final compound = parseIrealPro(link('[T68C^7 |A-7 |D-7 |G7 Z')).single;
      expect(compound.progression.beatsPerBar, 4);
      expect(compound.notes.single, contains('6/8'));
    });
  });
}
