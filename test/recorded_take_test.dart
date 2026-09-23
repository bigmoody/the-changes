// Playing a recording somewhere other than where it was recorded.
//
// The numbers here are the whole feature. If they are wrong the chart
// drifts against real players and the band comes out in the wrong key,
// and neither would be obvious from looking at the screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/recorded_take.dart';

const f = 5;
const bFlat = 10;
const g = 7;

RecordedTake take({
  String name = 'Blues in F, 120',
  double bpm = 120,
  int key = f,
  int choruses = 6,
}) => RecordedTake(
  name: name,
  files: const {TakeStem.bass: 'bass.wav', TakeStem.drums: 'drums.wav'},
  bpm: bpm,
  key: key,
  bars: 12,
  choruses: choruses,
);

/// The four the template asks for.
final template = TakeSet([
  take(name: 'F 120', bpm: 120, key: f),
  take(name: 'F 180', bpm: 180, key: f),
  take(name: 'B flat 120', bpm: 120, key: bFlat),
  take(name: 'B flat 180', bpm: 180, key: bFlat),
]);

void main() {
  group('where it was recorded', () {
    test('asked for its own tempo and key, nothing is done to it', () {
      final shift = take().shiftTo(tempo: 120, soundingKey: f);
      expect(shift.speed, 1);
      expect(shift.shift, 1);
      expect(shift.cents, 0);
      expect(shift.stretchPercent, 0);
      expect(shift.strain, TakeStrain.asRecorded);
      expect(shift.worthSaying, isFalse);
    });
  });

  group('the two knobs', () {
    test('faster in the same key: the filter has to pull the pitch down', () {
      // Resampling 120 up to 180 raises everything by a fifth, so the
      // filter has to put a fifth back.
      final shift = take().shiftTo(tempo: 180, soundingKey: f);
      expect(shift.speed, closeTo(1.5, 0.0001));
      expect(shift.shift, closeTo(1 / 1.5, 0.0001));
      expect(shift.cents, closeTo(-701.955, 0.01), reason: 'a fifth, down');
      expect(shift.stretchPercent, closeTo(50, 0.0001));
    });

    test('a higher key at the same tempo is the filter on its own', () {
      final shift = take().shiftTo(tempo: 120, soundingKey: f + 1);
      expect(shift.speed, 1, reason: 'the tempo did not move');
      expect(shift.cents, closeTo(100, 0.0001));
    });

    test('slower in the same key pushes the filter up', () {
      final shift = take(bpm: 180).shiftTo(tempo: 120, soundingKey: f);
      expect(shift.speed, closeTo(2 / 3, 0.0001));
      expect(shift.cents, closeTo(701.955, 0.01));
    });
  });

  group('faster and higher cancel, which is the point of four takes', () {
    test('a semitone up and the tempo up to match is free', () {
      // Resampling a semitone faster is 1.0595 times the tempo, and it
      // brings the key up a semitone with it. The filter does nothing.
      final shift = take().shiftTo(tempo: 120 * 1.059463, soundingKey: f + 1);
      expect(shift.cents, closeTo(0, 0.1));
      expect(shift.strain, TakeStrain.asRecorded);
    });

    test('the awkward key at the awkward tempo still finds an easy take', () {
      // G at 150 is in neither recorded key and at neither recorded
      // tempo, and one of the four still lands within a fifth of a
      // semitone of it: B flat at 180, slowed down, drops almost exactly
      // the three semitones to G on its own.
      final best = template.bestFor(tempo: 150, soundingKey: g)!;
      expect(best.name, 'B flat 180');
      final shift = best.shiftTo(tempo: 150, soundingKey: g);
      expect(shift.cents.abs(), lessThan(20));
      expect(shift.strain, TakeStrain.asRecorded);
    });

    test('the nearest take by key alone would have been far worse', () {
      // Proving the choice is worth making: the take in the key the
      // player asked around is the wrong one to reach for.
      final byKeyOnly = template.takes.firstWhere((t) => t.name == 'F 120');
      final shift = byKeyOnly.shiftTo(tempo: 150, soundingKey: g);
      expect(shift.cents.abs(), greaterThan(150));
      expect(shift.strain, isNot(TakeStrain.asRecorded));
    });
  });

  group('choosing a take', () {
    test('its own key and tempo wins outright', () {
      expect(template.bestFor(tempo: 120, soundingKey: f)?.name, 'F 120');
      expect(
        template.bestFor(tempo: 180, soundingKey: bFlat)?.name,
        'B flat 180',
      );
    });

    test('nothing imported, nothing chosen', () {
      expect(TakeSet.empty.bestFor(tempo: 120, soundingKey: f), isNull);
      expect(TakeSet.empty.isEmpty, isTrue);
    });

    test('one take is always the answer, however far it has to go', () {
      final only = TakeSet([take()]);
      expect(
        only.bestFor(tempo: 240, soundingKey: f + 6)?.name,
        'Blues in F, 120',
      );
    });
  });

  group('how far is too far', () {
    test('the bands, in order', () {
      final it = take();
      TakeStrain at(num tempo, int key) =>
          it.shiftTo(tempo: tempo, soundingKey: key).strain;
      expect(at(120, f), TakeStrain.asRecorded);
      expect(at(120, f + 1), TakeStrain.close, reason: '100 cents');
      expect(at(120, f + 3), TakeStrain.stretched, reason: '300 cents');
      expect(at(120, f + 5), TakeStrain.tooFar, reason: '500 cents');
    });

    test('up and down are as bad as each other', () {
      // Away from a boundary on purpose. Three semitones up lands on
      // 300.00000000000006 cents and three down on 299.99999999999994, so
      // a band edge chosen at either would sort them differently for
      // reasons that have nothing to do with how it sounds.
      final up = take().shiftTo(tempo: 120, soundingKey: f + 3);
      final down = take().shiftTo(tempo: 120, soundingKey: f - 3);
      expect(up.cents, closeTo(300, 0.001));
      expect(down.cents, closeTo(-300, 0.001));
      expect(up.strain, down.strain);
      expect(up.strain, TakeStrain.stretched);
    });

    test('only the stretched ones are worth saying out loud', () {
      expect(take().shiftTo(tempo: 126, soundingKey: f).worthSaying, isFalse);
      expect(take().shiftTo(tempo: 180, soundingKey: f).worthSaying, isTrue);
    });
  });

  group('the shorter way round', () {
    test('never further than six semitones', () {
      final it = take(key: f);
      expect(it.moveTo(f), 0);
      expect(it.moveTo(f + 5), 5);
      expect(it.moveTo(f + 7), -5, reason: 'down five, not up seven');
      expect(it.moveTo(f - 1), -1);
      for (var key = 0; key < 12; key++) {
        expect(it.moveTo(key).abs(), lessThanOrEqualTo(6));
      }
    });

    test('it wraps round the top of the octave', () {
      // B to C is one semitone up, not eleven down.
      expect(take(key: 11).moveTo(0), 1);
      expect(take(key: 0).moveTo(11), -1);
    });
  });

  group('checking the stated tempo against the file', () {
    test('how long six choruses of a blues at 120 should be', () {
      // 12 bars, four beats, six times round: 288 beats, so 144 seconds.
      expect(take().beats, 288);
      expect(take().seconds, closeTo(144, 0.0001));
    });

    test('a take labelled 120 that is really 124', () {
      final it = take();
      final reallySeconds = 288 * 60 / 124;
      expect(it.bpmFrom(reallySeconds), closeTo(124, 0.0001));
      expect(it.tempoErrorFrom(reallySeconds), closeTo(3.33, 0.01));
    });

    test('a file exactly as long as it claims reports no error', () {
      expect(take().tempoErrorFrom(144), closeTo(0, 0.0001));
    });

    test('an empty or missing file does not divide by zero', () {
      expect(take().bpmFrom(0), 0);
      expect(take().tempoErrorFrom(0), 0);
      expect(take(bpm: 0).seconds, 0);
      expect(take(bpm: 0).shiftTo(tempo: 120, soundingKey: f).speed, 1);
    });
  });

  group('keeping it', () {
    test('what goes in comes back out', () {
      final it = take().startingAt(0.02).inKey(bFlat).atTempo(176.5);
      final back = RecordedTake.fromJson(it.toJson())!;
      expect(back.name, it.name);
      expect(back.bpm, 176.5);
      expect(back.key, bFlat);
      expect(back.bars, 12);
      expect(back.choruses, 6);
      expect(back.startSeconds, 0.02);
      expect(back.files[TakeStem.bass], 'bass.wav');
    });

    test('a set round trips, and rubbish in it is dropped not thrown', () {
      final back = TakeSet.fromJson(template.toJson());
      expect(back.length, 4);
      expect(TakeSet.fromJson('not a list').isEmpty, isTrue);
      expect(
        TakeSet.fromJson([
          {'name': 'Broken'},
          ...template.toJson(),
        ]).length,
        4,
      );
    });

    test('a take with no files at all is not a take', () {
      expect(
        RecordedTake.fromJson({
          'files': <String, Object?>{},
          'bpm': 120,
          'bars': 12,
        }),
        isNull,
      );
    });
  });
}
