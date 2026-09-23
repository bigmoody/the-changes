// Keeping imported recordings between visits.
//
// A take costs several minutes to set up and tens of megabytes to hold,
// so losing one matters more than losing almost anything else the app
// keeps. The audio stays out of the JSON and out of the backup file; what
// is written down is the file's name and the facts no audio file carries.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/recorded_take.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/settings/progression_store.dart';

final ref = TuneRef.standard('Jazz blues in F');
final other = TuneRef.standard('Rhythm changes in B♭');

RecordedTake take({
  String name = 'F 120',
  double bpm = 120,
  int key = 5,
  Map<TakeStem, String>? files,
}) => RecordedTake(
  name: name,
  files:
      files ??
      const {
        TakeStem.bass: 'a-bass.wav',
        TakeStem.drums: 'a-drums.wav',
        TakeStem.comp: 'a-comp.wav',
      },
  bpm: bpm,
  key: key,
  bars: 12,
  choruses: 6,
);

void main() {
  group('what goes in comes back out', () {
    test('a take survives the next launch', () async {
      final storage = MemoryStorage();
      final store = await RecordingStore.load(
        storage: storage,
        files: NoRecordingFiles(),
      );
      expect(store.forTune(ref).isEmpty, isTrue);
      await store.add(ref, take().atTempo(176.5).startingAt(0.02));

      // A second store reading the same storage is the next launch.
      final later = await RecordingStore.load(
        storage: storage,
        files: NoRecordingFiles(),
      );
      final back = later.forTune(ref).takes.single;
      expect(back.name, 'F 120');
      expect(back.bpm, 176.5);
      expect(back.startSeconds, 0.02);
      expect(back.files[TakeStem.drums], 'a-drums.wav');
    });

    test('the four the template asks for sit together', () async {
      final store = RecordingStore.inMemory();
      for (final (name, bpm, key) in [
        ('F 120', 120.0, 5),
        ('F 180', 180.0, 5),
        ('B flat 120', 120.0, 10),
        ('B flat 180', 180.0, 10),
      ]) {
        await store.add(ref, take(name: name, bpm: bpm, key: key));
      }
      expect(store.forTune(ref).length, 4);
      // And the set is what does the choosing, as it does everywhere else.
      expect(
        store.forTune(ref).bestFor(tempo: 150, soundingKey: 7)?.name,
        'B flat 180',
      );
    });

    test('takes are kept per tune, not shared', () async {
      final store = RecordingStore.inMemory();
      await store.add(ref, take(name: 'Blues take'));
      await store.add(other, take(name: 'Rhythm take'));
      expect(store.forTune(ref).takes.single.name, 'Blues take');
      expect(store.forTune(other).takes.single.name, 'Rhythm take');
      expect(store.count, 2);
    });

    test('a tune with nothing has nothing, and null asks nothing', () {
      final store = RecordingStore.inMemory();
      expect(store.forTune(ref).isEmpty, isTrue);
      expect(store.forTune(null).isEmpty, isTrue);
    });
  });

  group('the audio itself', () {
    test('is kept beside the facts, not inside them', () async {
      final store = RecordingStore.inMemory();
      final name = await store.keep(
        'abc',
        TakeStem.bass,
        Uint8List.fromList(List.filled(4096, 7)),
      );
      expect(name, 'abc-bass.wav', reason: 'the stem is readable by eye');
      expect(await store.pathOf(name), isNotNull);
      await store.add(ref, take(files: {TakeStem.bass: name}));

      // Nothing that large went into the JSON.
      expect(jsonEncode(store.toJson()).length, lessThan(500));
      expect(jsonEncode(store.toJson()), contains('abc-bass.wav'));
    });

    test('a file the app has never kept has no path', () async {
      final store = RecordingStore.inMemory();
      expect(await store.pathOf('never-heard-of-it.wav'), isNull);
    });

    test('forgetting a take takes its audio with it', () async {
      final store = RecordingStore.inMemory();
      final files = store.files as NoRecordingFiles;
      for (final stem in TakeStem.values) {
        await store.keep('abc', stem, Uint8List(16));
      }
      await store.add(
        ref,
        take(
          files: {
            for (final stem in TakeStem.values) stem: 'abc-${stem.name}.wav',
          },
        ),
      );

      await store.forget(ref, 'F 120');
      expect(store.forTune(ref).isEmpty, isTrue);
      expect(files.removed, hasLength(3));
      expect(files.saved, isEmpty, reason: 'all three went, not just one');
    });

    test('forgetting one of four leaves the other three alone', () async {
      final store = RecordingStore.inMemory();
      final files = store.files as NoRecordingFiles;
      for (final name in ['one', 'two', 'three']) {
        await store.keep(name, TakeStem.bass, Uint8List(16));
        await store.add(
          ref,
          take(name: name, files: {TakeStem.bass: '$name-bass.wav'}),
        );
      }
      await store.forget(ref, 'two');
      expect(store.forTune(ref).takes.map((t) => t.name), ['one', 'three']);
      expect(files.removed, ['two-bass.wav']);
      expect(files.saved.keys, ['one-bass.wav', 'three-bass.wav']);
    });
  });

  group('changing one', () {
    test('a corrected tempo replaces it rather than adding another', () async {
      final store = RecordingStore.inMemory();
      await store.add(ref, take());
      await store.replace(ref, 'F 120', take().atTempo(124));
      expect(store.forTune(ref).length, 1);
      expect(store.forTune(ref).takes.single.bpm, 124);
    });

    test('and it is still there next launch', () async {
      final storage = MemoryStorage();
      final store = await RecordingStore.load(
        storage: storage,
        files: NoRecordingFiles(),
      );
      await store.add(ref, take());
      await store.replace(ref, 'F 120', take().inKey(10));
      final later = await RecordingStore.load(
        storage: storage,
        files: NoRecordingFiles(),
      );
      expect(later.forTune(ref).takes.single.key, 10);
    });
  });

  group('when the stored text is not what this version writes', () {
    test('rubbish loses the recordings, not the app', () async {
      final store = await RecordingStore.load(
        storage: MemoryStorage('not json'),
        files: NoRecordingFiles(),
      );
      expect(store.count, 0);
    });

    test(
      'one unreadable take does not take the readable ones with it',
      () async {
        final store = await RecordingStore.load(
          storage: MemoryStorage(
            '{"s:Good": [{"name":"Fine","files":{"bass":"b.wav"},'
            '"bpm":120,"bars":12,"choruses":6}],'
            ' "s:Bad": [{"name":"Broken","bpm":"fast"}]}',
          ),
          files: NoRecordingFiles(),
        );
        expect(
          store.forTune(TuneRef.standard('Good')).takes.single.name,
          'Fine',
        );
        expect(store.forTune(TuneRef.standard('Bad')).isEmpty, isTrue);
      },
    );
  });

  group('it tells the screens when something changes', () {
    test('adding, replacing and forgetting all notify', () async {
      final store = RecordingStore.inMemory();
      var told = 0;
      store.addListener(() => told++);
      await store.add(ref, take());
      await store.replace(ref, 'F 120', take().atTempo(124));
      await store.forget(ref, 'F 120');
      expect(told, 3);
    });
  });
}
