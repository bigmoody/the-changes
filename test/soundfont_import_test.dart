// Importing a sound, keeping it, and the band playing it.
//
// The parser has its own tests; these are about the rest of the journey:
// choosing a file, choosing one sound out of it, what is written down,
// what survives a restart, and whether the band actually plays it.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
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

import 'soundfont_test.dart' show buildFont, sample, zone, emptyDrum;

SampledInstrument instrumentIn(Uint8List font) {
  final read = SoundFont.read(font);
  return read.instrumentFor(read.presets.single);
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
      expect(store.nameFor(SoundFontRole.chords), "Preset");

      // The same files and the same preferences, opened again.
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.has(SoundFontRole.chords), isTrue);
      expect(again.nameFor(SoundFontRole.chords), 'Preset');
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

    testWidgets('a drum kit is offered but cannot be chosen', (tester) async {
      final store = SoundFontStore.inMemory();
      await tester.pumpWidget(
        MaterialApp(
          home: ImportSoundFontScreen(
            store: store,
            pick: () async => (
              name: 'gm.sf2',
              bytes: buildFont(
                bank: 128,
                samples: [sample()],
                zones: [zone(0)],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('choose-soundfont')));
      await tester.pumpAndSettle();
      expect(find.textContaining('plays its own drums'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('preset-0')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isFalse);
    });

    testWidgets('shows what is already in, and lets it go', (tester) async {
      final store = SoundFontStore.inMemory(chords: instrumentIn(font));
      await tester.pumpWidget(
        MaterialApp(home: ImportSoundFontScreen(store: store)),
      );
      expect(find.byKey(const ValueKey('kept-soundfont')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forget-soundfont')));
      await tester.pumpAndSettle();
      expect(store.has(SoundFontRole.chords), isFalse);
    });
  });
}
