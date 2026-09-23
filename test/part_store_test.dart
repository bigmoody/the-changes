// Keeping an imported part between visits.
//
// The whole point is that a part outlives the screen. Choosing a file,
// picking a track out of it and nudging it into place is several minutes
// of work, and before this it was thrown away when the tune closed, which
// meant nobody would do it twice.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/imported_part.dart';
import 'package:play_along/music/midi_file.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/part_store.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';

class _FakePlayer extends PracticePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

MidiNote _note(int pitch, double beat) =>
    (pitch: pitch, beat: beat, beats: 1, velocity: 0.8);

ImportedPart _part({String name = 'Walking Bass', double offset = 0}) =>
    ImportedPart(
      name: name,
      notes: [
        for (var beat = 0; beat < 8; beat++) _note(40 + beat, beat + 0.0),
      ],
      lengthBeats: 8,
      voice: PartVoice.bass,
      offsetBeats: offset,
    );

final _blues = practiceProgressions.firstWhere(
  (tune) => tune.title == 'Jazz blues in F',
);
final _ref = TuneRef.standard('Jazz blues in F');

PracticeController _controllerWith(PartStore store) => PracticeController(
  tune: _blues,
  player: _FakePlayer(),
  settings: AppSettings.inMemory(),
  partStore: store,
  ref: _ref,
);

void main() {
  group('the store', () {
    test('what goes in comes back out', () async {
      final storage = MemoryStorage();
      final store = await PartStore.load(storage: storage);
      expect(store.forTune(_ref), isNull);
      await store.set(_ref, _part(offset: -4));

      // A second store reading the same storage is what the next launch of
      // the app does.
      final later = await PartStore.load(storage: storage);
      final back = later.forTune(_ref)!;
      expect(back.name, 'Walking Bass');
      expect(back.voice, PartVoice.bass);
      expect(back.offsetBeats, -4);
      expect(back.notes.length, 8);
    });

    test('parts are kept per tune, not shared', () async {
      final store = PartStore.inMemory();
      final other = TuneRef.standard('Rhythm changes in B♭');
      await store.set(_ref, _part(name: 'Blues line'));
      await store.set(other, _part(name: 'Rhythm line'));
      expect(store.forTune(_ref)?.name, 'Blues line');
      expect(store.forTune(other)?.name, 'Rhythm line');
      expect(store.count, 2);
    });

    test('taking one out forgets it', () async {
      final storage = MemoryStorage();
      final store = await PartStore.load(storage: storage);
      await store.set(_ref, _part());
      await store.set(_ref, null);
      expect(store.forTune(_ref), isNull);
      expect((await PartStore.load(storage: storage)).forTune(_ref), isNull);
    });

    test('a tune with nothing saved has nothing, and null asks nothing', () {
      final store = PartStore.inMemory();
      expect(store.forTune(_ref), isNull);
      expect(store.forTune(null), isNull);
    });

    test('rubbish in storage loses the parts, not the app', () async {
      final store = await PartStore.load(storage: MemoryStorage('not json'));
      expect(store.count, 0);
      // And one unreadable part does not take the readable ones with it.
      final mixed = await PartStore.load(
        storage: MemoryStorage(
          '{"s:Good": {"name":"Fine","lengthBeats":8,"notes":[60,0,1,0.8]},'
          ' "s:Bad": {"name":"Broken","lengthBeats":8,"notes":"nope"}}',
        ),
      );
      expect(mixed.forTune(TuneRef.standard('Good'))?.name, 'Fine');
      expect(mixed.forTune(TuneRef.standard('Bad')), isNull);
    });
  });

  group('the tune remembers it', () {
    test('a part put in is there when the tune is opened again', () async {
      final store = PartStore.inMemory();
      _controllerWith(store).setImportedPart(_part());
      // A fresh controller is what opening the tune again builds.
      expect(_controllerWith(store).importedPart?.name, 'Walking Bass');
    });

    test('nudging it into place is kept too, not just the file', () async {
      final store = PartStore.inMemory();
      final first = _controllerWith(store);
      first.setImportedPart(_part());
      first.setImportedPart(first.importedPart!.movedTo(-8));
      first.setImportedPart(
        first.importedPart!.repeatingEvery(16, beatsPerBar: 4),
      );

      final again = _controllerWith(store).importedPart!;
      expect(again.offsetBeats, -8, reason: 'the offset went');
      expect(again.lengthBeats, 16, reason: 'the repeat length went');
      expect(again.voice, PartVoice.bass);
    });

    test('taking it out is remembered as well', () {
      final store = PartStore.inMemory();
      _controllerWith(store).setImportedPart(_part());
      _controllerWith(store).setImportedPart(null);
      expect(_controllerWith(store).importedPart, isNull);
    });

    test('a controller without a store still works', () {
      // The Learn screens build one this way, and so do most tests.
      final controller = PracticeController(
        tune: _blues,
        player: _FakePlayer(),
        settings: AppSettings.inMemory(),
      );
      controller.setImportedPart(_part());
      expect(controller.importedPart?.name, 'Walking Bass');
    });
  });
}
