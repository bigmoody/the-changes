// Building a kit drum by drum, starting from the drum.
//
// The screen exists because the other way round was too much work: to
// change the snare you chose a file, scrolled past forty instruments to
// the kit at the bottom, opened it and picked the snare out of ten. These
// are about the short way: tap the drum, choose a file, done.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/drum_patterns.dart' show Drum;
import 'package:play_along/music/tune.dart' show DrumSound;
import 'package:play_along/practice/soundfont_store.dart';
import 'package:play_along/screens/drum_kit_screen.dart';
import 'package:play_along/settings/app_settings.dart';

import 'soundfont_test.dart' show buildFont, sample, zone, emptyDrum;

/// A kit with a kick, a snare, a closed hi-hat and a ride on the notes
/// General MIDI puts them.
final aKit = buildFont(
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

/// A file with two kits in it, so the screen has to ask which.
final twoKits = buildFont(
  name: 'Two Kits',
  bank: 128,
  moreBanks: [128],
  samples: [
    sample(name: 'kick'),
    sample(name: 'snare'),
  ],
  zones: [zone(0, keyLow: 36, keyHigh: 36), zone(1, keyLow: 38, keyHigh: 38)],
);

/// A tall window: ten drums and a button do not fit the default one, and
/// none of these is about scrolling.
void tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> openWith(
  WidgetTester tester, {
  required SoundFontStore store,
  AppSettings? settings,
  Uint8List? file,
}) async {
  tallWindow(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: DrumKitScreen(
        store: store,
        settings: settings,
        pick: file == null
            ? () async => null
            : () async => (name: 'kit.sf2', bytes: file),
      ),
    ),
  );
}

void main() {
  testWidgets('every drum is listed, as the band\'s own to begin with', (
    tester,
  ) async {
    await openWith(tester, store: SoundFontStore.inMemory());
    for (final drum in Drum.values) {
      expect(find.byKey(ValueKey('drum-${drum.name}')), findsOneWidget);
    }
    expect(find.text("The band's own"), findsNWidgets(Drum.values.length));
  });

  testWidgets('tapping a drum takes that one and no other', (tester) async {
    // The whole point: one tap on the drum, one file, done. No scrolling
    // past the instruments and no second list of ten.
    final store = SoundFontStore.inMemory();
    final settings = AppSettings.inMemory();
    await openWith(tester, store: store, settings: settings, file: aKit);
    await tester.tap(find.byKey(const ValueKey('drum-snare')));
    await tester.pumpAndSettle();
    expect(store.hasDrum(Drum.snare), isTrue);
    expect(store.hasDrum(Drum.kick), isFalse);
    // And it is switched on, so the band actually plays it.
    expect(settings.drumSound, DrumSound.imported);
  });

  testWidgets('with one kit in the file it does not ask which', (tester) async {
    final store = SoundFontStore.inMemory();
    await openWith(tester, store: store, file: aKit);
    await tester.tap(find.byKey(const ValueKey('drum-ride')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-0')), findsNothing);
    expect(store.hasDrum(Drum.ride), isTrue);
  });

  testWidgets('with two it asks, and names the drum it is asking about', (
    tester,
  ) async {
    final store = SoundFontStore.inMemory();
    await openWith(tester, store: store, file: twoKits);
    await tester.tap(find.byKey(const ValueKey('drum-kick')));
    await tester.pumpAndSettle();
    expect(find.textContaining('kick'), findsWidgets);
    expect(find.byKey(const ValueKey('kit-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kit-1')));
    await tester.pumpAndSettle();
    expect(store.hasDrum(Drum.kick), isTrue);
  });

  testWidgets('a drum no kit in the file has says so', (tester) async {
    // Plenty of General MIDI kits have no cowbell, and the honest answer
    // is to say so rather than to offer a kit that cannot supply it.
    final store = SoundFontStore.inMemory();
    await openWith(tester, store: store, file: aKit);
    await tester.tap(find.byKey(const ValueKey('drum-cowbell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drum-problem')), findsOneWidget);
    expect(find.textContaining('cowbell'), findsWidgets);
    expect(store.hasDrum(Drum.cowbell), isFalse);
  });

  testWidgets('a file with no kits in it says that instead', (tester) async {
    final store = SoundFontStore.inMemory();
    await openWith(
      tester,
      store: store,
      file: buildFont(samples: [sample()], zones: [zone(0)]),
    );
    await tester.tap(find.byKey(const ValueKey('drum-snare')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no drum kits'), findsOneWidget);
  });

  testWidgets('a whole kit fills in what it has and leaves the rest', (
    tester,
  ) async {
    final store = SoundFontStore.inMemory(
      drums: {Drum.cowbell: emptyDrum},
      drumsName: 'An Old Kit',
    );
    await openWith(
      tester,
      store: store,
      settings: AppSettings.inMemory(),
      file: aKit,
    );
    await tester.tap(find.byKey(const ValueKey('whole-kit')));
    await tester.pumpAndSettle();
    expect(store.hasDrum(Drum.kick), isTrue);
    expect(store.hasDrum(Drum.snare), isTrue);
    // The cowbell was not in that kit, so it is still the old one.
    expect(store.nameForDrum(Drum.cowbell), 'An Old Kit');
  });

  testWidgets('one drum can be cleared on its own', (tester) async {
    final store = SoundFontStore.inMemory(
      drums: {Drum.kick: emptyDrum, Drum.snare: emptyDrum},
    );
    await openWith(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('clear-kick')));
    await tester.pumpAndSettle();
    expect(store.hasDrum(Drum.kick), isFalse);
    expect(store.hasDrum(Drum.snare), isTrue);
  });

  testWidgets('and the whole kit goes back to the band in one tap', (
    tester,
  ) async {
    final store = SoundFontStore.inMemory(
      drums: {Drum.kick: emptyDrum, Drum.snare: emptyDrum},
    );
    final settings = AppSettings.inMemory();
    await settings.setDrumSound(DrumSound.imported);
    await openWith(tester, store: store, settings: settings);
    await tester.tap(find.byKey(const ValueKey('bands-own-kit')));
    await tester.pumpAndSettle();
    expect(store.drums, isEmpty);
    expect(settings.drumSound, DrumSound.kit);
  });

  testWidgets('that button is not there when there is nothing to undo', (
    tester,
  ) async {
    await openWith(tester, store: SoundFontStore.inMemory());
    expect(find.byKey(const ValueKey('bands-own-kit')), findsNothing);
  });
}
