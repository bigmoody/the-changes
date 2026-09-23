// A lick, and the book of them.
//
// The line and the changes it was played over have to stay together and
// have to move together. A line that ends up a key away from the chords
// underneath it is worse than no lick at all, because it looks right.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/transcribe.dart';
import 'package:play_along/music/lick.dart';
import 'package:play_along/music/midi_file.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/practice/lick_store.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/settings/progression_store.dart';

MidiNote note(int pitch, double beat) =>
    (pitch: pitch, beat: beat, beats: 0.5, velocity: 0.85);

/// A ii-V-I in C, two bars of it.
UserProgression iiVI({String key = 'C'}) => UserProgression(
  id: 'p1',
  title: 'ii V I',
  key: key,
  tempo: 160,
  bars: const ['Dm7 G7', 'CΔ7'],
  style: BandStyle.of(Feel.swing),
);

/// A line over it: D E F G, A B C, landing on the 3rd of C.
Lick lick({String id = 'l1', String name = 'The usual'}) => Lick(
  id: id,
  name: name,
  over: iiVI(),
  notes: [
    for (final (i, pitch) in const [62, 64, 65, 67, 69, 71, 72, 64].indexed)
      note(pitch, i * 0.5),
  ],
  at: DateTime(2026, 9, 23),
);

void main() {
  group('what a lick knows about itself', () {
    test('its shape', () {
      final one = lick();
      expect(one.bars, 2);
      expect(one.beatsPerBar, 4);
      expect(one.range, (62, 72));
      expect(one.lengthBeats, closeTo(4, 0.001));
      expect(one.isEmpty, isFalse);
    });

    test('the key it was played in, however it is spelled', () {
      expect(lick().key, 0, reason: 'C');
      final inFSharp = Lick(
        id: 'x',
        name: 'x',
        over: iiVI(key: 'G♭'),
        notes: const [],
        at: DateTime(2026),
      );
      expect(inFSharp.key, 6, reason: 'G flat and F sharp are one key');
    });

    test('which chord a note is over', () {
      final one = lick();
      expect(one.chordAt(0)?.display, 'Dm7');
      expect(one.chordAt(2.5)?.display, 'G7');
      expect(one.chordAt(4)?.display, 'CΔ7');
    });

    test('an empty lick is not a broken one', () {
      final empty = Lick(
        id: 'e',
        name: 'Nothing yet',
        over: iiVI(),
        notes: const [],
        at: DateTime(2026),
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.range, isNull);
      expect(empty.lengthBeats, 0);
    });
  });

  group('moving it to another key', () {
    test('the line moves', () {
      final up = lick().notesUp(2);
      expect(up.first.pitch, 64);
      expect(up.last.pitch, 66);
      expect(
        up.map((n) => n.beat).toList(),
        lick().notes.map((n) => n.beat).toList(),
        reason: 'the rhythm does not move',
      );
    });

    test('and the changes move with it, by the same number', () {
      // The thing that must never come apart.
      for (var move = 0; move < 12; move++) {
        final one = lick();
        final line = one.notesUp(move);
        final band = one.tuneUp(move);
        // The first note of this line is the root of the ii chord, so
        // the two agree only if both moved the same way.
        final rootOfTheTwo = band.slots.first.chord.root;
        expect(
          line.first.pitch % 12,
          rootOfTheTwo,
          reason: 'up $move the line and the chords disagree',
        );
      }
    });

    test('down as well as up', () {
      expect(lick().notesUp(-12).first.pitch, 50);
    });
  });

  group('the order the keys come round in', () {
    test('the cycle is fourths, and hits all twelve', () {
      final moves = KeyOrder.fourths.moves();
      expect(moves.first, 0, reason: 'where you already know it');
      expect(moves.toSet(), hasLength(12));
      expect(moves.take(4).toList(), [0, 5, 10, 3]);
    });

    test('chromatic is semitones', () {
      expect(KeyOrder.chromatic.moves().take(3).toList(), [0, 1, 2]);
      expect(KeyOrder.chromatic.moves().toSet(), hasLength(12));
    });

    test('shuffled still starts where you know it, and misses none', () {
      final moves = KeyOrder.random.moves(seed: 4);
      expect(moves.first, 0);
      expect(moves.toSet(), hasLength(12));
    });

    test('shuffled is actually shuffled', () {
      expect(
        KeyOrder.random.moves(seed: 1),
        isNot(KeyOrder.random.moves(seed: 2)),
      );
    });
  });

  group('keeping a book of them', () {
    test('what goes in comes back out', () async {
      final storage = MemoryStorage();
      final store = await LickStore.load(
        storage: storage,
        files: NoRecordingFiles(),
      );
      await store.add(lick());

      final later = await LickStore.load(
        storage: storage,
        files: NoRecordingFiles(),
      );
      final back = later.all.single;
      expect(back.name, 'The usual');
      expect(back.notes.length, 8);
      expect(back.notes.first.pitch, 62);
      expect(back.over.bars, ['Dm7 G7', 'CΔ7']);
      expect(back.grid, NoteGrid.swungEighths);
      expect(back.key, 0, reason: 'the changes came back too');
    });

    test('newest first, whatever order they went in', () async {
      final store = LickStore.inMemory();
      await store.add(lick(id: 'a', name: 'Older'));
      await store.add(
        Lick(
          id: 'b',
          name: 'Newer',
          over: iiVI(),
          notes: [note(60, 0)],
          at: DateTime(2026, 9, 24),
        ),
      );
      expect(store.all.map((one) => one.name).toList(), ['Newer', 'Older']);
      expect(store.byId('a')?.name, 'Older');
      expect(store.byId('nope'), isNull);
    });

    test('a lick can be changed without being added twice', () async {
      final store = LickStore.inMemory();
      await store.add(lick());
      await store.put(lick().renamed('Renamed'));
      expect(store.count, 1);
      expect(store.all.single.name, 'Renamed');
    });

    test('putting an unknown lick simply adds it', () async {
      final store = LickStore.inMemory();
      await store.put(lick());
      expect(store.count, 1);
    });

    test('taking one out takes its recording with it', () async {
      final store = LickStore.inMemory();
      final files = store.files as NoRecordingFiles;
      final name = await store.keep('l1', Uint8List(64));
      await store.add(
        Lick(
          id: 'l1',
          name: 'Recorded',
          over: iiVI(),
          notes: [note(60, 0)],
          at: DateTime(2026),
          recording: name,
        ),
      );
      expect(await store.pathOf(name), isNotNull);

      await store.remove('l1');
      expect(store.count, 0);
      expect(files.removed, [name]);
    });

    test('rubbish in storage loses the licks, not the app', () async {
      final store = await LickStore.load(
        storage: MemoryStorage('not json'),
        files: NoRecordingFiles(),
      );
      expect(store.count, 0);
    });

    test('one unreadable lick does not take the readable ones', () async {
      final good = jsonOf(lick());
      final store = await LickStore.load(
        storage: MemoryStorage('[{"name":"Broken"}, $good]'),
        files: NoRecordingFiles(),
      );
      expect(store.count, 1);
      expect(store.all.single.name, 'The usual');
    });

    test('it tells the screens when something changes', () async {
      final store = LickStore.inMemory();
      var told = 0;
      store.addListener(() => told++);
      await store.add(lick());
      await store.put(lick().renamed('x'));
      await store.remove('l1');
      expect(told, 3);
    });
  });
}

String jsonOf(Lick lick) => const JsonEncoder().convert(lick.toJson());
