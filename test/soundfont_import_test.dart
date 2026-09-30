// Importing a sound, keeping it, and the band playing it.
//
// The parser has its own tests; these are about the rest of the journey:
// choosing a file, choosing one sound out of it, what is written down,
// what survives a restart, and whether the band actually plays it.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/drum_patterns.dart' show Drum;
import 'package:play_along/audio/instrument_file.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/audio/soundfont.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/settings/progression_store.dart';
import 'package:play_along/practice/soundfont_store.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/screens/import_soundfont_screen.dart';
import 'package:play_along/screens/settings_page.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/audio/practice_player.dart';

import 'soundfont_test.dart' show buildFont, sample, zone, emptyDrum;

SampledInstrument instrumentIn(Uint8List font) {
  final read = SoundFont.read(font);
  return read.instrumentFor(read.presets.single);
}

/// A window tall enough for the whole screen: two parts, ten drums and a
/// file's worth of presets do not fit in the default one, and none of
/// these tests is about scrolling.
void tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A bank whose every melodic instrument is [instrument], so a render can
/// be asked what it played without any of the real samples being loaded.
SampleBank bankOf(
  SampledInstrument instrument, {
  SampledInstrument? importedChords,
  SampledInstrument? importedBass,
}) => SampleBank(
  bass: instrument,
  piano: instrument,
  guitar: instrument,
  ride: emptyDrum,
  hiHatPedal: emptyDrum,
  hiHatClosed: emptyDrum,
  hiHatOpen: emptyDrum,
  kick: emptyDrum,
  snare: emptyDrum,
  crossStick: emptyDrum,
  cowbell: emptyDrum,
  tomHigh: emptyDrum,
  tomLow: emptyDrum,
  importedChords: importedChords,
  importedBass: importedBass,
);

void main() {
  // A General MIDI kit: a kick, a snare, a closed hi-hat and a ride,
  // where the map puts them.
  final generalMidiKit = buildFont(
    name: 'A Kit',
    bank: 128,
    samples: [
      sample(name: 'kick'),
      sample(name: 'snare'),
      sample(name: 'hat'),
      sample(name: 'ride'),
    ],
    zones: [
      zone(0, keyLow: 36, keyHigh: 36),
      zone(1, keyLow: 38, keyHigh: 38),
      zone(2, keyLow: 42, keyHigh: 42),
      zone(3, keyLow: 51, keyHigh: 51),
    ],
  );

  // A second kit, with a different kick in it, for mixing.
  final otherKit = buildFont(
    name: 'Another Kit',
    bank: 128,
    samples: [sample(name: 'other kick', length: 120)],
    zones: [zone(0, keyLow: 36, keyHigh: 36)],
  );

  // A file with an instrument and a kit in it, which is what a General
  // MIDI font is.
  final wholeBand = buildFont(
    name: 'A Whole Band',
    moreBanks: [128],
    samples: [
      sample(name: 'piano'),
      sample(name: 'kick'),
    ],
    zones: [zone(0, keyLow: 60, keyHigh: 60), zone(1, keyLow: 36, keyHigh: 36)],
  );

  // One key, so a test can say exactly which notes came out.
  final font = buildFont(
    name: 'Someone Else\'s Piano',
    samples: [sample(name: 'note', root: 60, length: 400)],
    zones: [zone(0, keyLow: 60, keyHigh: 60)],
  );

  group('keeping one', () {
    test('writes the sound out and reads it back the same', () {
      final instrument = instrumentIn(font);
      final read = readInstrument(writeInstrument(instrument));
      expect(read.name, instrument.name);
      expect(read.pitches, instrument.pitches);
      expect(read.takesAre, instrument.takesAre);
      final was = instrument.notes[60]!.single;
      final now = read.notes[60]!.single;
      expect(now.samples, was.samples);
      expect(now.rate, closeTo(was.rate, 1e-9));
      expect(now.loop, was.loop);
    });

    test('a shared recording is written once, not once per key', () {
      // Sixty keys off one zone. Written naively a real piano preset came
      // to 115 MB where 23 would do, and the file is what goes on a phone.
      final wide = instrumentIn(
        buildFont(
          samples: [sample(length: 4000)],
          zones: [zone(0, keyLow: 36, keyHigh: 96)],
        ),
      );
      final written = writeInstrument(wide);
      expect(wide.pitches, hasLength(61));
      // One recording's worth of samples, plus a header, rather than 61.
      expect(written.length, lessThan(4000 * 2 * 3));

      // And shared again on the way back in, so opening the app does not
      // undo it.
      final read = readInstrument(written);
      final distinct = <Object>{
        for (final takes in read.notes.values)
          for (final take in takes) take.samples,
      };
      expect(read.pitches, hasLength(61));
      expect(distinct, hasLength(1));
    });

    test('a looping note keeps its loop across the write', () {
      final looping = instrumentIn(
        buildFont(
          samples: [sample(length: 400, loops: true)],
          zones: [zone(0)],
        ),
      );
      final read = readInstrument(writeInstrument(looping));
      expect(read.notes[60]!.single.loop, isNotNull);
      expect(read.notes[60]!.single.loop, looping.notes[60]!.single.loop);
    });

    test('a file from an older version is refused rather than misread', () {
      final bytes = writeInstrument(instrumentIn(font));
      // The version sits in the four bytes after the magic.
      bytes[4] = 99;
      expect(
        () => readInstrument(bytes),
        throwsA(isA<InstrumentFileException>()),
      );
    });

    test('something that is not a saved instrument is refused', () {
      expect(
        () => readInstrument(Uint8List.fromList(List.filled(64, 7))),
        throwsA(isA<InstrumentFileException>()),
      );
    });
  });

  group('the store', () {
    test('has nothing in it to begin with', () {
      final store = SoundFontStore.inMemory();
      expect(store.has(SoundFontRole.chords), isFalse);
      expect(store.nameFor(SoundFontRole.chords), isNull);
    });

    test('keeps one, and finds it again after a restart', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      await store.keep(SoundFontRole.chords, instrumentIn(font));
      expect(store.nameFor(SoundFontRole.chords), "Preset 0");

      // The same files and the same preferences, opened again.
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.has(SoundFontRole.chords), isTrue);
      expect(again.nameFor(SoundFontRole.chords), 'Preset 0');
      expect(again.chords!.pitches, [60]);
    });

    test('a bass and a chord sound live side by side', () async {
      // The whole reason they are two files: choosing a bass must not
      // throw away the piano chosen last week.
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      final piano = instrumentIn(font);
      final bass = instrumentIn(
        buildFont(
          name: 'A Bass',
          samples: [sample(name: 'low', root: 40, length: 200)],
          zones: [zone(0, keyLow: 28, keyHigh: 52)],
        ),
      );
      await store.keep(SoundFontRole.chords, piano);
      await store.keep(SoundFontRole.bass, bass);
      expect(store.chords!.pitches, [60]);
      expect(store.bass!.lowest, 28);

      // And both come back.
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.chords!.pitches, [60]);
      expect(again.bass!.lowest, 28);

      // Letting the bass go leaves the chords where they were.
      await again.forget(SoundFontRole.bass);
      expect(again.has(SoundFontRole.bass), isFalse);
      expect(again.has(SoundFontRole.chords), isTrue);
    });

    test('forgetting everything takes the files with it', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      await store.keep(SoundFontRole.chords, instrumentIn(font));
      await store.keepKit('A Kit', {Drum.kick: emptyDrum});
      expect(files.saved, isNotEmpty);

      await store.forgetEverything();
      expect(store.anything, isFalse);
      expect(files.saved, isEmpty);

      // And it stays gone across a restart.
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.anything, isFalse);
    });

    test('forgetting one leaves nothing behind', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      await store.keep(SoundFontRole.chords, instrumentIn(font));
      await store.forget(SoundFontRole.chords);
      expect(store.has(SoundFontRole.chords), isFalse);
      expect(store.nameFor(SoundFontRole.chords), isNull);
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.has(SoundFontRole.chords), isFalse);
    });
  });

  group('the band playing it', () {
    Tune tune() => Tune.fromChart(
      title: 'Test',
      key: 'C',
      chart: 'Cmaj7 | Dm7 | G7 | Cmaj7 |',
      defaultTempo: 120,
    );

    Uint8List chordsWith(Comping comping, {SampledInstrument? importedChords}) {
      final ours = instrumentIn(
        buildFont(samples: [sample(length: 400)], zones: [zone(0)]),
      );
      final t = tune();
      return renderBacking(
        BackingRequest(
          tune: t,
          loop: LoopRange.wholeTune(t),
          tempo: 120,
          countInBars: 0,
          comping: comping,
          samples: bankOf(ours, importedChords: importedChords),
        ),
      ).stems[Instrument.chords]!;
    }

    test('the imported sound is what comes out, not the piano', () {
      // Two recognisably different instruments: one a long note, one short.
      final other = instrumentIn(
        buildFont(samples: [sample(length: 40)], zones: [zone(0)]),
      );
      expect(
        chordsWith(Comping.imported, importedChords: other),
        isNot(chordsWith(Comping.piano)),
      );
    });

    Uint8List bassWith(BassSound sound, {SampledInstrument? importedBass}) {
      final ours = instrumentIn(
        buildFont(samples: [sample(length: 400)], zones: [zone(0)]),
      );
      final t = tune();
      return renderBacking(
        BackingRequest(
          tune: t,
          loop: LoopRange.wholeTune(t),
          tempo: 120,
          countInBars: 0,
          bassSound: sound,
          samples: bankOf(ours, importedBass: importedBass),
        ),
      ).stems[Instrument.bass]!;
    }

    test('an imported bass is what the bass player uses', () {
      final other = instrumentIn(
        buildFont(samples: [sample(length: 40)], zones: [zone(0)]),
      );
      expect(
        bassWith(BassSound.imported, importedBass: other),
        isNot(bassWith(BassSound.upright)),
      );
    });

    test('with no bass imported it falls back to the upright', () {
      expect(bassWith(BassSound.imported), bassWith(BassSound.upright));
    });

    test('with nothing imported it falls back to the piano', () {
      // A setting saved on a phone that has since lost the file still
      // plays, rather than going silent.
      expect(chordsWith(Comping.imported), chordsWith(Comping.piano));
    });
  });

  group('the import screen', () {
    testWidgets('lists what is in a file and keeps the one chosen', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            pick: () async => (name: 'piano.sf2', bytes: font),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      expect(find.text("Someone Else's Piano"), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-as-chords')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isTrue);
      expect(store.chords!.pitches, [60]);
    });

    testWidgets('choosing a sound also puts it on', (tester) async {
      // Otherwise the sound is kept, nothing plays it, and the app looks
      // broken to everybody who does not make a second trip to Settings.
      final store = SoundFontStore.inMemory();
      final settings = AppSettings.inMemory();
      expect(settings.comping, Comping.piano);
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: settings,
            pick: () async => (name: 'piano.sf2', bytes: font),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-as-chords')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isTrue);
      expect(settings.comping, Comping.imported);
    });

    testWidgets('says what is wrong with a file it cannot read', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: SoundFontStore.inMemory(),
            pick: () async => (
              name: 'holiday.jpg',
              bytes: Uint8List.fromList(List.filled(64, 3)),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('soundfont-problem')), findsOneWidget);
      expect(find.textContaining('not a SoundFont'), findsOneWidget);
    });

    testWidgets('a pitched preset asks which part it is for', (tester) async {
      // The whole point of one screen instead of three: a piano could comp
      // or it could walk, so it is asked rather than assumed.
      final store = SoundFontStore.inMemory();
      final settings = AppSettings.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: settings,
            pick: () async => (name: 'piano.sf2', bytes: font),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play-as-chords')), findsOneWidget);
      expect(find.byKey(const ValueKey('play-as-bass')), findsOneWidget);
      // And never the drums: it has pitch and no idea where a kick is.
      expect(find.byKey(const ValueKey('play-as-drums')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('play-as-bass')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.bass), isTrue);
      expect(store.has(SoundFontRole.chords), isFalse);
      expect(settings.bassSound, BassSound.imported);
    });

    testWidgets('a kit is not asked, because it can only be the drums', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory();
      final settings = AppSettings.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: settings,
            pick: () async => (name: 'gm.sf2', bytes: generalMidiKit),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      // It is never asked whether it is the chords: it has no pitch.
      expect(find.byKey(const ValueKey('play-as-drums')), findsNothing);
      expect(find.byKey(const ValueKey('play-as-chords')), findsNothing);
      // It is asked how much of it to take.
      await tester.tap(find.byKey(const ValueKey('take-whole-kit')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.drums), isTrue);
      expect(settings.drumSound, DrumSound.imported);
      expect(store.drums.keys, contains(Drum.kick));
    });

    testWidgets('one file can give the band more than one of its players', (
      tester,
    ) async {
      // The thing three separate screens made you choose the same file
      // three times to do.
      final store = SoundFontStore.inMemory();
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: AppSettings.inMemory(),
            pick: () async => (name: 'band.sf2', bytes: wholeBand),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();

      // The pitched one on the chords.
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-as-chords')));
      await tester.pumpAndSettle();
      // The list is still there: choosing did not close the screen.
      expect(find.byKey(const ValueKey('preset-1')), findsOneWidget);
      expect(store.has(SoundFontRole.chords), isTrue);

      // Once the message about the first one has gone, since it sits over
      // the bottom of the list.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // And the kit on the drums, without choosing the file again. It has
      // moved down the page, because assigning the first one added the
      // section that says who is playing what.
      await tester.ensureVisible(find.byKey(const ValueKey('preset-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('take-whole-kit')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isTrue);
      expect(store.has(SoundFontRole.drums), isTrue);
    });

    testWidgets('one drum can be taken out of a kit, and only that one', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: AppSettings.inMemory(),
            pick: () async => (name: 'gm.sf2', bytes: generalMidiKit),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      // Every drum the kit actually has is offered, and nothing it does
      // not: this one has no cowbell.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('take-snare')),
        100,
        // The sheet's own list, which is the last one on screen.
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const ValueKey('take-snare')), findsOneWidget);
      expect(find.byKey(const ValueKey('take-cowbell')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('take-snare')));
      await tester.pumpAndSettle();
      expect(store.hasDrum(Drum.snare), isTrue);
      // And the kick, which that kit also has, is untouched.
      expect(store.hasDrum(Drum.kick), isFalse);
      expect(store.drums.keys, [Drum.snare]);
    });

    testWidgets('drums can come from two different kits', (tester) async {
      // The point of the whole change: a snare out of one kit and cymbals
      // out of another is how people build a kit.
      final store = SoundFontStore.inMemory();
      var file = generalMidiKit;
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: AppSettings.inMemory(),
            pick: () async => (name: 'kit.sf2', bytes: file),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('take-snare')),
        100,
        // The sheet's own list, which is the last one on screen.
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('take-snare')));
      await tester.pumpAndSettle();
      final snare = store.drums[Drum.snare];

      // A second file, and the kick out of that one.
      file = otherKit;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('take-kick')),
        100,
        // The sheet's own list, which is the last one on screen.
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('take-kick')));
      await tester.pumpAndSettle();

      expect(store.drums.keys, containsAll([Drum.snare, Drum.kick]));
      // The snare is still the one from the first kit.
      expect(identical(store.drums[Drum.snare], snare), isTrue);
      expect(
        store.nameForDrum(Drum.snare),
        isNot(store.nameForDrum(Drum.kick)),
      );
    });

    testWidgets('taking a whole kit leaves alone what it has not got', (
      tester,
    ) async {
      // Somebody who found a cowbell they like and then imports a kit for
      // the cymbals should keep the cowbell.
      final store = SoundFontStore.inMemory(
        drums: {Drum.cowbell: emptyDrum},
        drumsName: 'An Old Kit',
      );
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            settings: AppSettings.inMemory(),
            pick: () async => (name: 'gm.sf2', bytes: generalMidiKit),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('take-whole-kit')));
      await tester.pumpAndSettle();
      expect(store.hasDrum(Drum.kick), isTrue);
      expect(store.nameForDrum(Drum.cowbell), 'An Old Kit');
    });

    testWidgets('a drum can be sent back to the band on its own', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory(
        drums: {Drum.kick: emptyDrum, Drum.snare: emptyDrum},
      );
      await tester.pumpWidget(
        MaterialApp(home: ImportSoundFontScreen(store: store)),
      );
      tallWindow(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forget-kick')));
      await tester.pumpAndSettle();
      expect(store.hasDrum(Drum.kick), isFalse);
      expect(store.hasDrum(Drum.snare), isTrue);
    });

    testWidgets('everything can go at once, once it is confirmed', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory(
        chords: instrumentIn(font),
        bass: instrumentIn(font),
        drums: {Drum.kick: emptyDrum, Drum.snare: emptyDrum},
      );
      final settings = AppSettings.inMemory();
      await settings.setComping(Comping.imported);
      await settings.setBassSound(BassSound.imported);
      await settings.setDrumSound(DrumSound.imported);
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(store: store, settings: settings),
        ),
      );

      // Asked first, and backing out keeps everything.
      await tester.tap(find.byKey(const ValueKey('forget-everything')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Them'));
      await tester.pumpAndSettle();
      expect(store.anything, isTrue);

      await tester.tap(find.byKey(const ValueKey('forget-everything')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('really-forget-everything')));
      await tester.pumpAndSettle();
      expect(store.anything, isFalse);
      expect(store.drums, isEmpty);

      // And nothing left claiming to play a sound that has gone.
      expect(settings.comping, Comping.piano);
      expect(settings.arpeggioSound, Comping.piano);
      expect(settings.bassSound, BassSound.upright);
      expect(settings.drumSound, DrumSound.kit);
    });

    testWidgets('and is not offered when there is nothing to remove', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(store: SoundFontStore.inMemory()),
        ),
      );
      expect(find.byKey(const ValueKey('forget-everything')), findsNothing);
    });

    testWidgets('a kit with nothing where the map says is refused', (
      tester,
    ) async {
      // Its hits are up at 90, where General MIDI has nothing, so the band
      // would not know what to hit.
      final store = SoundFontStore.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            pick: () async => (
              name: 'odd.sf2',
              bytes: buildFont(
                bank: 128,
                samples: [sample()],
                zones: [zone(0, keyLow: 90, keyHigh: 92)],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-0')));
      await tester.pumpAndSettle();
      // Refused before it ever asks which drum, because there are none.
      expect(find.byKey(const ValueKey('take-whole-kit')), findsNothing);
      expect(find.byKey(const ValueKey('soundfont-problem')), findsOneWidget);
      expect(store.has(SoundFontRole.drums), isFalse);
    });

    testWidgets('it says who is playing each part, and lets one go', (
      tester,
    ) async {
      final store = SoundFontStore.inMemory(chords: instrumentIn(font));
      tallWindow(tester);
      await tester.pumpWidget(
        MaterialApp(home: ImportSoundFontScreen(store: store)),
      );
      // The chords and the bass as parts, and then every drum on its own,
      // with the band's own named where nothing has been imported.
      expect(find.byKey(const ValueKey('playing-chords')), findsOneWidget);
      expect(find.byKey(const ValueKey('playing-bass')), findsOneWidget);
      expect(find.byKey(const ValueKey('playing-kick')), findsOneWidget);
      expect(find.byKey(const ValueKey('playing-ride')), findsOneWidget);
      expect(find.text("The band's upright"), findsOneWidget);
      expect(find.text("The band's own"), findsNWidgets(Drum.values.length));
      // Only the imported one can be let go.
      expect(find.byKey(const ValueKey('forget-bass')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('forget-chords')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isFalse);
    });
  });

  group('the rows in Settings', () {
    Future<void> openSettings(WidgetTester tester, SoundFontStore store) =>
        tester.pumpWidget(
          MaterialApp(
            home: SettingsPage(
              player: PracticePlayer(),
              settings: AppSettings.inMemory(),
              progressions: ProgressionStore.inMemory(),
              library: LibraryStore.inMemory(),
              soundFont: store,
            ),
          ),
        );

    testWidgets('one row, saying nothing is imported yet', (tester) async {
      await openSettings(tester, SoundFontStore.inMemory());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('import-soundfont')),
        200,
      );
      expect(
        find.text('Play any of the band from a SoundFont of your own'),
        findsOneWidget,
      );
    });

    testWidgets('and naming each part once there is something', (tester) async {
      // The bug a per-role subtitle once had: the drums row read "Play the
      // chords...", because a catch-all case caught it. One row now, and
      // it names the parts it actually has.
      final store = SoundFontStore.inMemory(
        chords: instrumentIn(font),
        drums: {Drum.kick: emptyDrum},
        drumsName: 'A Kit',
      );
      await openSettings(tester, store);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('import-soundfont')),
        200,
      );
      expect(find.textContaining('Chords: Preset 0'), findsOneWidget);
      expect(find.textContaining('Drums:'), findsOneWidget);
      // And nothing about the bass, because nothing was imported for it.
      expect(find.textContaining('Bass:'), findsNothing);
    });
  });
}
