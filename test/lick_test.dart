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

  group('following somebody through a lick', () {
    List<MidiNote> line(List<int> pitches) => [
      for (final (i, pitch) in pitches.indexed) note(pitch, i * 0.5),
    ];

    test('playing it through fills it in, note by note', () {
      final follow = LickFollower(line(const [62, 64, 65, 67]));
      expect(follow.done, isFalse);
      expect(follow.got, [false, false, false, false]);
      for (final pitch in [62.0, 64.0, 65.0, 67.0]) {
        expect(follow.heard(pitch), isTrue, reason: '$pitch');
      }
      expect(follow.done, isTrue);
      expect(follow.got, everyElement(isTrue));
    });

    test('a note held for a while does not run through the lick', () {
      // The microphone reports the same pitch many times a second.
      final follow = LickFollower(line(const [62, 64, 65]));
      for (var i = 0; i < 20; i++) {
        follow.heard(62);
      }
      expect(follow.at, 1, reason: 'one note played, not twenty');
    });

    test('a wrong note is simply not the next one', () {
      final follow = LickFollower(line(const [62, 64, 65]));
      expect(follow.heard(62), isTrue);
      expect(follow.heard(70), isFalse, reason: 'not in the lick here');
      expect(follow.at, 1, reason: 'still waiting for the 64');
      expect(follow.heard(64), isTrue);
    });

    test('a note the lick plays twice has to be played twice', () {
      final follow = LickFollower(line(const [67, 67, 65]));
      expect(follow.heard(67), isTrue);
      expect(follow.heard(67), isFalse, reason: 'still the same note held');
      // Let it stop, then play it again.
      follow.heard(null);
      expect(follow.heard(67), isTrue);
      expect(follow.at, 2);
    });

    test('and another note in between counts as letting go too', () {
      final follow = LickFollower(line(const [67, 67]));
      expect(follow.heard(67), isTrue);
      follow.heard(60);
      expect(follow.heard(67), isTrue);
      expect(follow.done, isTrue);
    });

    test('being a little off pitch still counts', () {
      final follow = LickFollower(line(const [62, 64]));
      expect(follow.heard(62.3), isTrue, reason: 'thirty cents sharp');
      expect(follow.heard(63.8), isTrue, reason: 'twenty cents flat');
    });

    test('being a long way off does not', () {
      final follow = LickFollower(line(const [62]));
      expect(follow.heard(62.7), isFalse);
      expect(follow.at, 0);
    });

    test('silence is not a note', () {
      final follow = LickFollower(line(const [62]));
      expect(follow.heard(null), isFalse);
      expect(follow.at, 0);
    });

    test('an octave out is wrong, unless the drill says otherwise', () {
      expect(LickFollower(line(const [62])).heard(74), isFalse);
      expect(LickFollower(line(const [62]), anyOctave: true).heard(74), isTrue);
    });

    test('nothing more is heard once it is done', () {
      final follow = LickFollower(line(const [62]));
      expect(follow.heard(62), isTrue);
      expect(follow.heard(62), isFalse);
      expect(follow.done, isTrue);
    });

    test('starting again starts again', () {
      final follow = LickFollower(line(const [62, 64]));
      follow.heard(62);
      follow.restart();
      expect(follow.at, 0);
      expect(follow.heard(62), isTrue, reason: 'the same note is fine again');
    });
  });

  group('marking an attempt', () {
    List<MidiNote> line(List<int> pitches) => [
      for (final (i, pitch) in pitches.indexed) note(pitch, i * 0.5),
    ];
    const want = [62, 64, 65, 67, 69];

    test('playing it right is all of it right', () {
      final attempt = compareLick(line(want), line(want));
      expect(attempt.right, 5);
      expect(attempt.wanted, 5);
      expect(attempt.extra, 0);
      expect(attempt.score, 1);
      expect(attempt.clean, isTrue);
      expect(attempt.firstMissed, isNull);
    });

    test('one note wrong is one note wrong, not everything after it', () {
      final attempt = compareLick(line(const [62, 64, 66, 67, 69]), line(want));
      expect(attempt.right, 4);
      expect(attempt.got, [true, true, false, true, true]);
      expect(attempt.firstMissed, 2);
      expect(attempt.clean, isFalse);
    });

    test('a note left out is one missing and nothing else', () {
      final attempt = compareLick(line(const [62, 64, 67, 69]), line(want));
      expect(attempt.got, [true, true, false, true, true]);
      expect(attempt.extra, 0);
    });

    test('notes put in are counted apart from notes missed', () {
      final attempt = compareLick(
        line(const [62, 64, 63, 65, 67, 69]),
        line(want),
      );
      expect(attempt.right, 5, reason: 'the lick is all there');
      expect(attempt.extra, 1, reason: 'and one note that is not in it');
      expect(attempt.clean, isFalse, reason: 'right notes, plus a spare');
    });

    test('the right notes in the wrong order is not the lick', () {
      final attempt = compareLick(line(want.reversed.toList()), line(want));
      expect(attempt.right, lessThan(3));
    });

    test('playing nothing is nothing right', () {
      final attempt = compareLick(const [], line(want));
      expect(attempt.right, 0);
      expect(attempt.score, 0);
      expect(attempt.firstMissed, 0);
    });

    test('an octave out is wrong, unless the drill says otherwise', () {
      final octaveUp = line([for (final p in want) p + 12]);
      expect(compareLick(octaveUp, line(want)).right, 0);
      expect(compareLick(octaveUp, line(want), anyOctave: true).right, 5);
    });

    test('a lick with no notes cannot be got wrong', () {
      final attempt = compareLick(line(const [60]), const []);
      expect(attempt.wanted, 0);
      expect(attempt.clean, isFalse);
      expect(attempt.extra, 1);
    });
  });

  group('how the notes are spelled', () {
    test('flat keys take flats and sharp keys take sharps', () {
      // The same sound, twice, and only one of them is readable.
      expect(nameInKey(63, key: 3), 'E♭', reason: 'in E flat');
      expect(nameInKey(63, key: 2), 'D♯', reason: 'in D');
      expect(nameInKey(66, key: 10), 'G♭', reason: 'in B flat');
      expect(nameInKey(66, key: 7), 'F♯', reason: 'in G');
    });

    test('the flat side of the circle is the flat side', () {
      for (final key in [5, 10, 3, 8, 1, 6]) {
        expect(nameInKey(61, key: key), 'D♭', reason: 'key $key');
      }
      for (final key in [0, 7, 2, 9, 4, 11]) {
        expect(nameInKey(61, key: key), 'C♯', reason: 'key $key');
      }
    });

    test('a white note is a white note whatever the key', () {
      for (var key = 0; key < 12; key++) {
        expect(nameInKey(60, key: key), 'C');
        expect(nameInKey(65, key: key), 'F');
      }
    });

    test('octaves do not change the name', () {
      expect(nameInKey(70, key: 3), nameInKey(58, key: 3));
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
