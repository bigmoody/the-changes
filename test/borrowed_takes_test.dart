// A recording offered to a chart its players never saw.
//
// The feature in one sentence: three files of people playing a blues in
// one key are a blues, and should back every blues in the book. What is
// tested here is that they are offered where they fit, refused where they
// do not, and never offered quietly.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/recorded_take.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/recording_store.dart';

RecordedTake take({
  String name = 'Take 1',
  double bpm = 120,
  int key = 0,
  int bars = 12,
}) => RecordedTake(
  name: name,
  files: const {TakeStem.bass: 'bass.wav', TakeStem.drums: 'drums.wav'},
  bpm: bpm,
  key: key,
  bars: bars,
  choruses: 6,
);

void main() {
  group('offering a take to another chart', () {
    test('a blues imported for one tune is offered to every other blues', () {
      // After Hours is a blues in C. Imported there, the recording should
      // turn up under Billie's Bounce, which is a blues in F.
      final store = RecordingStore.inMemory({
        TuneRef.standard('After Hours'): TakeSet([take()]),
      });
      final billie = standards.firstWhere((t) => t.title == "Billie's Bounce");
      final fits = store.fitting(billie, TuneRef.of(billie));
      expect(fits, hasLength(1));
      expect(fits.first.from, 'After Hours');
      expect(fits.first.semitones, 5, reason: 'C up to F');
    });

    test('and not to a tune with different changes', () {
      final store = RecordingStore.inMemory({
        TuneRef.standard('After Hours'): TakeSet([take()]),
      });
      final oleo = standards.firstWhere((t) => t.title == 'Oleo');
      expect(store.fitting(oleo, TuneRef.of(oleo)), isEmpty);
    });

    test('a tune is not offered its own takes twice', () {
      // They are already there as the tune's own, and listing them again
      // as borrowed would have the mixer counting them twice.
      final store = RecordingStore.inMemory({
        TuneRef.standard('After Hours'): TakeSet([take()]),
      });
      final after = standards.firstWhere((t) => t.title == 'After Hours');
      expect(store.fitting(after, TuneRef.of(after)), isEmpty);
    });

    test('every take of a fitting tune is offered, not just one', () {
      final store = RecordingStore.inMemory({
        TuneRef.standard('After Hours'): TakeSet([
          take(name: 'Slow in C', bpm: 120),
          take(name: 'Fast in C', bpm: 200),
        ]),
      });
      final billie = standards.firstWhere((t) => t.title == "Billie's Bounce");
      expect(store.fitting(billie, TuneRef.of(billie)), hasLength(2));
    });

    test('it says which tune the players were playing', () {
      // The one thing nobody should ever work out by ear.
      final store = RecordingStore.inMemory({
        TuneRef.standard('After Hours'): TakeSet([take()]),
      });
      final billie = standards.firstWhere((t) => t.title == "Billie's Bounce");
      expect(store.fitting(billie, TuneRef.of(billie)).single.from, isNotEmpty);
    });

    test('nothing imported anywhere is nothing offered', () {
      final store = RecordingStore.inMemory();
      final billie = standards.firstWhere((t) => t.title == "Billie's Bounce");
      expect(store.fitting(billie, TuneRef.of(billie)), isEmpty);
    });
  });
}
