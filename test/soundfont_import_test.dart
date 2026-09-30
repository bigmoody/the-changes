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
  SampledInstrument? imported,
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
  imported: imported,
);

void main() {
  final font = buildFont(
    name: 'Someone Else\'s Piano',
    samples: [sample(name: 'note', root: 60, length: 400)],
    zones: [zone(0)],
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
      expect(store.hasOne, isFalse);
      expect(store.name, isNull);
    });

    test('keeps one, and finds it again after a restart', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      await store.keep(instrumentIn(font));
      expect(store.name, "Preset");

      // The same files and the same preferences, opened again.
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.hasOne, isTrue);
      expect(again.name, 'Preset');
      expect(again.instrument!.pitches, [60]);
    });

    test('forgetting one leaves nothing behind', () async {
      final files = NoRecordingFiles();
      final saved = MemoryStorage();
      final store = await SoundFontStore.load(storage: saved, files: files);
      await store.keep(instrumentIn(font));
      await store.forget();
      expect(store.hasOne, isFalse);
      expect(store.name, isNull);
      final again = await SoundFontStore.load(storage: saved, files: files);
      expect(again.hasOne, isFalse);
    });
  });

  group('the band playing it', () {
    Tune tune() => Tune.fromChart(
      title: 'Test',
      key: 'C',
      chart: 'Cmaj7 | Dm7 | G7 | Cmaj7 |',
      defaultTempo: 120,
    );

    Uint8List chordsWith(Comping comping, {SampledInstrument? imported}) {
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
          samples: bankOf(ours, imported: imported),
        ),
      ).stems[Instrument.chords]!;
    }

    test('the imported sound is what comes out, not the piano', () {
      // Two recognisably different instruments: one a long note, one short.
      final other = instrumentIn(
        buildFont(samples: [sample(length: 40)], zones: [zone(0)]),
      );
      expect(
        chordsWith(Comping.imported, imported: other),
        isNot(chordsWith(Comping.piano)),
      );
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
      expect(store.hasOne, isTrue);
      expect(store.instrument!.pitches, [60]);
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
      expect(store.hasOne, isFalse);
    });

    testWidgets('shows what is already in, and lets it go', (tester) async {
      final store = SoundFontStore.inMemory(instrument: instrumentIn(font));
      await tester.pumpWidget(
        MaterialApp(home: ImportSoundFontScreen(store: store)),
      );
      expect(find.byKey(const ValueKey('kept-soundfont')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('forget-soundfont')));
      await tester.pumpAndSettle();
      expect(store.hasOne, isFalse);
    });
  });
}
