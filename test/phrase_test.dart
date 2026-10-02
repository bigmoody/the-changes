// Keeping a phrase as audio, and moving it.
//
// The maths is the part worth testing hardest. Which of the two knobs is
// turned decides whether the tempo survives and whether the sound holds
// together, and getting it the wrong way round would be inaudible in a
// test that only checked a number came out.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/music/phrase.dart';
import 'package:play_along/music/recorded_take.dart' show TakeStrain;
import 'package:play_along/practice/phrase_store.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/settings/progression_store.dart';

Phrase phraseIn(int key) => Phrase(
  id: '1',
  name: 'Four bars',
  fileName: 'one.wav',
  key: key,
  seconds: 3.2,
);

void main() {
  group('moving it', () {
    final phrase = phraseIn(0);

    test('where it was played, nothing is touched at all', () {
      for (final move in PhraseMove.values) {
        final shift = phrase.shiftBy(0, move);
        expect(shift.speed, 1, reason: move.name);
        expect(shift.shift, 1, reason: move.name);
      }
    });

    test('keeping the tempo moves the pitch and only the pitch', () {
      // A fifth up: the filter does all of it, the speed does none.
      final shift = phrase.shiftBy(7, PhraseMove.inTime);
      expect(shift.speed, 1);
      expect(shift.shift, closeTo(1.4983, 0.001));
      expect(shift.cents, closeTo(700, 1));
      // Which is the whole point: it still takes as long to play.
      expect(shift.stretchPercent, 0);
    });

    test('like tape moves both, and invents nothing', () {
      final shift = phrase.shiftBy(7, PhraseMove.likeTape);
      expect(shift.shift, 1);
      expect(shift.speed, closeTo(1.4983, 0.001));
      // Nothing for the filter to do means nothing for it to get wrong.
      expect(shift.cents, 0);
      expect(shift.strain, TakeStrain.asRecorded);
      expect(shift.stretchPercent, closeTo(49.8, 0.2));
    });

    test('down is down, both ways', () {
      expect(phrase.shiftBy(-5, PhraseMove.inTime).shift, lessThan(1));
      expect(phrase.shiftBy(-5, PhraseMove.likeTape).speed, lessThan(1));
    });

    test('how hard the filter is working grows with the distance', () {
      // The honest measure, and why the screen warns past a point: a
      // semitone is nothing, half an octave is a lot of invention.
      expect(phrase.shiftBy(1, PhraseMove.inTime).strain, TakeStrain.close);
      expect(phrase.shiftBy(3, PhraseMove.inTime).strain, TakeStrain.stretched);
      expect(phrase.shiftBy(6, PhraseMove.inTime).strain, TakeStrain.tooFar);
    });

    test('and like tape never strains however far it goes', () {
      for (var semitones = -11; semitones <= 11; semitones++) {
        expect(
          phrase.shiftBy(semitones, PhraseMove.likeTape).strain,
          TakeStrain.asRecorded,
          reason: '$semitones semitones',
        );
      }
    });
  });

  group('keeping them', () {
    test('an empty book is the usual start', () {
      expect(PhraseStore.inMemory().isEmpty, isTrue);
    });

    test('a phrase is kept with its audio, and read back', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await PhraseStore.load(storage: saved, files: files);
      await store.add(phraseIn(5), audio: Uint8List.fromList([1, 2, 3, 4]));
      expect(store.all, hasLength(1));
      expect(await store.audioOf(store.all.single), [1, 2, 3, 4]);

      // And both come back after a restart.
      final again = await PhraseStore.load(storage: saved, files: files);
      expect(again.all.single.key, 5);
      expect(again.all.single.name, 'Four bars');
      expect(await again.audioOf(again.all.single), [1, 2, 3, 4]);
    });

    test('the newest is first, since that is the one just played', () async {
      final store = PhraseStore.inMemory();
      await store.add(phraseIn(0));
      await store.add(
        Phrase(id: '2', name: 'Later', fileName: 'two.wav', key: 7, seconds: 1),
      );
      expect(store.all.first.name, 'Later');
    });

    test('removing one takes its audio with it', () async {
      final files = NoRecordingFiles();
      final store = await PhraseStore.load(
        storage: MemoryStorage(),
        files: files,
      );
      await store.add(phraseIn(0), audio: Uint8List.fromList([9]));
      expect(files.saved, isNotEmpty);
      await store.remove(store.all.single);
      expect(store.isEmpty, isTrue);
      expect(files.saved, isEmpty);
    });

    test('renaming changes the name and nothing else', () async {
      final store = PhraseStore.inMemory([phraseIn(3)]);
      await store.rename(store.all.single, 'The good one');
      expect(store.all.single.name, 'The good one');
      expect(store.all.single.key, 3);
      expect(store.all.single.fileName, 'one.wav');
    });

    test('a saved phrase that will not read is dropped, not thrown', () async {
      // One bad entry should never cost somebody the rest of their book.
      final saved = MemoryStorage(
        '[{"id":"1","file":"one.wav","key":0,"seconds":1},{"name":"broken"}]',
      );
      final store = await PhraseStore.load(
        storage: saved,
        files: NoRecordingFiles(),
      );
      expect(store.all, hasLength(1));
    });
  });
}
