// The shelf: a SoundFont brought in once, and every sound in it there to
// choose from afterwards.
//
// Asked for because the old way started every change with the file
// picker: one file, one sound out of it, and the whole trip again for the
// next. "Extremely tedious." These are about never having to do that.


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart' show Drum;
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/practice/soundfont_store.dart';
import 'package:play_along/screens/imported_sounds_screen.dart';
import 'package:play_along/screens/practice_sheets.dart';
import 'package:play_along/screens/sound_shelf.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';

import 'soundfont_test.dart' show buildFont, sample, zone;

void main() {
  // Two pitched sounds and a kit, the way a General MIDI font has a
  // hundred and twenty-eight of the one and a few of the other.
  final band = buildFont(
    name: 'A Band',
    moreBanks: [1, 128],
    samples: [
      sample(name: 'piano', root: 60),
      sample(name: 'organ', root: 60),
      sample(name: 'kick'),
    ],
    zones: [
      zone(0, keyLow: 60, keyHigh: 60),
      zone(1, keyLow: 60, keyHigh: 60),
      zone(2, keyLow: 36, keyHigh: 36),
    ],
  );

  group('the store', () {
    test('lists what is in a file, and keeps it across a restart', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      final font = await store.add('band.sf2', band);
      expect(font.instruments, hasLength(2));
      expect(font.kits.single.drums, [Drum.kick]);
      expect(files.saved.keys, contains(font.fileName));

      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.shelf.single.name, font.name);
      expect(again.shelf.single.instruments, hasLength(2));
      // And it can still be chosen from, which needs the file itself.
      await again.choose(
        SoundFontRole.chords,
        again.shelf.single,
        again.shelf.single.instruments.first,
      );
      expect(again.has(SoundFontRole.chords), isTrue);
    });

    test('one sound after another, without the file again', () async {
      final store = SoundFontStore.inMemory();
      final font = await store.add('band.sf2', band);
      final [first, second] = font.instruments.toList();
      await store.choose(SoundFontRole.chords, font, first);
      expect(store.isPlaying(SoundFontRole.chords, font, first), isTrue);
      await store.choose(SoundFontRole.chords, font, second);
      expect(store.isPlaying(SoundFontRole.chords, font, first), isFalse);
      expect(store.isPlaying(SoundFontRole.chords, font, second), isTrue);
      // And a different part out of the same file.
      await store.choose(SoundFontRole.bass, font, first);
      expect(store.has(SoundFontRole.bass), isTrue);
      await store.chooseKit(font, font.kits.single);
      expect(store.hasDrum(Drum.kick), isTrue);
      expect(store.isPlayingKit(font, font.kits.single), isTrue);
    });

    test('the same file twice is the one already there', () async {
      final store = SoundFontStore.inMemory();
      final first = await store.add('band.sf2', band);
      final second = await store.add('band.sf2', band);
      expect(second.id, first.id);
      expect(store.shelf, hasLength(1));
    });

    test('removing a font leaves what it is playing playing', () async {
      final files = NoRecordingFiles();
      final store = await SoundFontStore.load(
        storage: MemoryStorage(),
        files: files,
      );
      final font = await store.add('band.sf2', band);
      await store.choose(SoundFontRole.chords, font, font.instruments.first);
      await store.remove(font);
      expect(store.shelf, isEmpty);
      expect(files.saved.keys, isNot(contains(font.fileName)));
      expect(store.has(SoundFontRole.chords), isTrue);
    });
  });

  group('the screen', () {
    void tallWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('a part offers the shelf, and the picker stays shut', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory();
      await store.add('band.sf2', band);
      final settings = AppSettings.inMemory();
      var picked = 0;
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ImportedSoundsScreen(
            store: store,
            settings: settings,
            pick: () async {
              picked++;
              return (name: 'band.sf2', bytes: band);
            },
          ),
        ),
      );
      expect(find.byKey(const ValueKey('font-0')), findsOneWidget);

      // Two goes on the chords, two different sounds, no file either time.
      for (final index in [0, 1]) {
        await tester.tap(find.byKey(const ValueKey('playing-chords')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('shelf-0-$index')));
        await tester.pumpAndSettle();
        expect(
          store.isPlaying(
            SoundFontRole.chords,
            store.shelf.single,
            store.shelf.single.sounds[index],
          ),
          isTrue,
        );
      }
      expect(picked, 0);
      expect(settings.comping, Comping.imported);

      // The kit is only offered for the drums.
      await tester.tap(find.byKey(const ValueKey('playing-bass')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('shelf-0-2')), findsNothing);
      // And the band's own is there to go back to.
      await tester.tap(find.byKey(const ValueKey('shelf-ours')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.bass), isFalse);
    });

    testWidgets('a font can be taken off the shelf', (tester) async {
      final store = SoundFontStore.inMemory();
      await store.add('band.sf2', band);
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(home: ImportedSoundsScreen(store: store)),
      );
      await tester.tap(find.byKey(const ValueKey('remove-font-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('really-remove-font')));
      await tester.pumpAndSettle();
      expect(store.shelf, isEmpty);
      expect(find.byKey(const ValueKey('font-0')), findsNothing);
    });
  });

  group('the mixer', () {
    Future<PracticeController> openTheMixer(
      WidgetTester tester,
      SoundFontStore store,
      AppSettings settings,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = PracticeController(
        tune: standards.first,
        player: PracticePlayer(),
        settings: settings,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => SoundFonts(store: store, child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMixer(context, controller),
                child: const Text('Mixer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mixer'));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('says nothing about a shelf with nothing on it', (
      tester,
    ) async {
      await openTheMixer(
        tester,
        SoundFontStore.inMemory(),
        AppSettings.inMemory(),
      );
      expect(find.byKey(const ValueKey('shelf-chords')), findsNothing);
      expect(find.byKey(const ValueKey('shelf-drums')), findsNothing);
    });

    testWidgets('chooses a sound off the shelf and puts it on', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory();
      final settings = AppSettings.inMemory();
      await tester.runAsync(() => store.add('band.sf2', band));
      await openTheMixer(tester, store, settings);

      await tester.ensureVisible(find.byKey(const ValueKey('shelf-chords')));
      await tester.tap(find.byKey(const ValueKey('shelf-chords')));
      await tester.pumpAndSettle();
      // Not the band's own: the segments above are for that.
      expect(find.byKey(const ValueKey('shelf-ours')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shelf-0-1')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isTrue);
      expect(settings.comping, Comping.imported);
      expect(find.textContaining('Imported: '), findsOneWidget);

      // The bass row is there now there is something to play it on.
      expect(find.byKey(const ValueKey('bass-sound')), findsOneWidget);

      // And a whole kit, for the drums.
      await tester.ensureVisible(find.byKey(const ValueKey('shelf-drums')));
      await tester.tap(find.byKey(const ValueKey('shelf-drums')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shelf-0-2')));
      await tester.pumpAndSettle();
      expect(store.hasDrum(Drum.kick), isTrue);
      expect(settings.drumSound, DrumSound.imported);
    });
  });
}
