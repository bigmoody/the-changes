// Arpeggios: every chord as a broken chord, root first, in time.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/arpeggios.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/chord_drill.dart';
import 'package:play_along/music/loop_range.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

List<ArpeggioNote> line(
  List<(String, int)> chords, {
  double swing = straight,
  ArpeggioStart from = ArpeggioStart.root,
}) => arpeggioLine(
  [for (final (symbol, beats) in chords) (Chord.parse(symbol), beats)],
  choruses: 1,
  swing: swing,
  from: from,
).notes;

void main() {
  test('up to the octave and back down, root first', () {
    final notes = line([('G7', 4)]);
    final pitches = notes.map((n) => n.pitch).toList();
    // G B D F G F D B.
    expect(pitches.map((p) => p % 12), [7, 11, 2, 5, 7, 5, 2, 11]);
    expect(pitches, [...pitches.take(5).toList()..sort(), ...pitches.skip(5)]);
    expect(notes.map((n) => n.beat), [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]);
  });

  test('from the 3rd, 5th or 7th: an inversion, up to the octave and back', () {
    List<int> classes(ArpeggioStart from) => [
      for (final note in line([('G7', 4)], from: from)) note.pitch % 12,
    ];
    // G7 is G B D F.
    expect(classes(ArpeggioStart.third), [11, 2, 5, 7, 11, 7, 5, 2]);
    expect(classes(ArpeggioStart.fifth), [2, 5, 7, 11, 2, 11, 7, 5]);
    expect(classes(ArpeggioStart.seventh), [5, 7, 11, 2, 5, 2, 11, 7]);
    // Always climbing to the top, then falling.
    for (final from in ArpeggioStart.values) {
      final pitches = [
        for (final n in line([('G7', 4)], from: from)) n.pitch,
      ];
      for (var i = 1; i <= 4; i++) {
        expect(pitches[i], greaterThan(pitches[i - 1]), reason: '$from');
      }
      expect(pitches[4], pitches[0] + 12, reason: '$from');
    }
  });

  test('says which note each chord starts on, and what it is', () {
    String startOf(String symbol, ArpeggioStart from) {
      final start = arpeggioStartOf(Chord.parse(symbol), from);
      return '${start.note} (${start.degree})';
    }

    // A 6th chord has no 7th: its 6th takes the place.
    expect(startOf('C6', ArpeggioStart.seventh), 'A (6th)');
    expect(startOf('G7', ArpeggioStart.seventh), 'F (♭7th)');
    expect(startOf('C^7', ArpeggioStart.seventh), 'B (7th)');
    expect(startOf('Cm7', ArpeggioStart.third), 'E♭ (♭3rd)');
    expect(startOf('Bo7', ArpeggioStart.seventh), 'A♭ (𝄫7th)');
    expect(startOf('F#m7b5', ArpeggioStart.fifth), 'C (♭5th)');
    // A triad has no 4th tone: from the 7th is the root, an octave up.
    expect(startOf('C', ArpeggioStart.seventh), 'C (root)');
    // Extensions don't count: G13 starts from its ♭7 like G7.
    expect(startOf('G13', ArpeggioStart.seventh), 'F (♭7th)');
    // And the line really does start there.
    final c6 = line([('C6', 2)], from: ArpeggioStart.seventh);
    expect(c6.first.pitch % 12, 9);
  });

  testWidgets('the readout shows where the arpeggio starts', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: PracticeScreen(
          tune: standards.firstWhere((t) => t.title.contains('A" Train')),
          player: PracticePlayer(),
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Arpeggio from'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('arpeggio-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arpeggio-seventh')));
    await tester.pumpAndSettle();
    // The tune opens on C6.
    expect(find.text('Arpeggio from A (6th)'), findsOneWidget);
    // Alongside the notes and the extensions, not instead of them.
    expect(find.text('C E G A'), findsOneWidget);
    expect(find.textContaining('ext '), findsOneWidget);
    expect(tester.takeException(), isNull);

    // And with "Aim for" on too, the next chord is still shown.
    settings.setAimFor(DrillTarget.third);
    await tester.pumpAndSettle();
    expect(find.text('Arpeggio from A (6th)'), findsOneWidget);
    expect(find.textContaining('Then '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('on a triad the "7th" is the root an octave up', () {
    expect(
      [
        for (final n in line([('C', 2)], from: ArpeggioStart.seventh))
          n.pitch % 12,
      ],
      [0, 4, 7, 0],
    );
  });

  test('two-beat chords get 1 3 5 7; only chord tones, never extensions', () {
    final notes = line([('Dm9', 2), ('G13', 2)]);
    expect(notes.take(4).map((n) => n.pitch % 12), [2, 5, 9, 0]); // D F A C
    expect(notes.skip(4).map((n) => n.pitch % 12), [7, 11, 2, 5]); // G B D F
  });

  test('swung eighths land late', () {
    final notes = line([('C^7', 2)], swing: tripletSwing);
    expect(notes[1].beat, closeTo(2 / 3, 1e-9));
  });

  test('the line stays in one place on the keyboard', () {
    final notes = line([
      for (final symbol in ['Cm7', 'F7', 'Bb^7', 'Eb^7', 'Am7b5', 'D7', 'Gm6'])
        (symbol, 4),
    ]);
    for (final note in notes) {
      expect(note.pitch, inInclusiveRange(55, 79));
    }
  });

  test('only rendered when asked for, and then in its own part', () async {
    // With the recorded piano, as in the app (the synthesised fallback once
    // hid the arpeggios going into the chords part instead).
    final bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
    final tune = standards.firstWhere((t) => t.title == 'Autumn Leaves');
    BackingRequest request({
      required bool arpeggios,
      Comping sound = Comping.piano,
    }) => BackingRequest(
      tune: tune,
      loop: LoopRange.bars(tune, 0, 3),
      tempo: 140,
      seed: 3,
      samples: bank,
      arpeggios: arpeggios,
      arpeggioSound: sound,
    );
    double rms(Uint8List wav) {
      final samples = decodeWav(wav);
      var sum = 0.0;
      for (final s in samples) {
        sum += s * s.toDouble();
      }
      return math.sqrt(sum / samples.length);
    }

    final off = renderBacking(request(arpeggios: false));
    expect(off.stems.keys, isNot(contains(Instrument.arpeggio)));
    final on = renderBacking(request(arpeggios: true));
    expect(rms(on.stems[Instrument.arpeggio]!), greaterThan(200));
    // The chords part is just the chords, arpeggios or not.
    expect(
      rms(on.stems[Instrument.chords]!) / rms(off.stems[Instrument.chords]!),
      closeTo(1, 0.1),
    );

    // On guitar: its own part too, about as present as on piano.
    final guitar = renderBacking(
      request(arpeggios: true, sound: Comping.guitar),
    );
    final onGuitar = rms(guitar.stems[Instrument.arpeggio]!);
    expect(onGuitar, greaterThan(200));
    expect(
      onGuitar / rms(on.stems[Instrument.arpeggio]!),
      inInclusiveRange(0.7, 1.4),
    );
    expect(
      rms(guitar.stems[Instrument.chords]!) /
          rms(off.stems[Instrument.chords]!),
      closeTo(1, 0.1),
    );
  });

  testWidgets('the Arpeggios button: off when a tune opens; a tap offers '
      'where to start', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings.inMemory();
    Future<void> open(String title) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            key: ValueKey(title),
            tune: standards.firstWhere((t) => t.title == title),
            player: PracticePlayer(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    FilterChip chip() =>
        tester.widget<FilterChip>(find.byKey(const ValueKey('arpeggio-chip')));
    Future<void> choose(String key) async {
      await tester.tap(find.byKey(const ValueKey('arpeggio-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }

    await open('Autumn Leaves');
    expect(find.text('Arpeggios'), findsOneWidget);
    expect(chip().selected, isFalse);

    // A tap offers the choices; picking one turns them on.
    await tester.tap(find.byKey(const ValueKey('arpeggio-chip')));
    await tester.pumpAndSettle();
    for (final label in [
      'Off',
      'From the root',
      'From the 3rd',
      'From the 5th',
      'From the 7th (6th on a 6 chord)',
      'On piano',
      'On guitar',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.byKey(const ValueKey('arpeggio-third')));
    await tester.pumpAndSettle();
    expect(chip().selected, isTrue);
    expect(settings.arpeggioStart, ArpeggioStart.third);

    // The mixer shows them on, with their own channel and the same choices.
    await tester.tap(find.byTooltip('Mixer'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mute arpeggios'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('arpeggio-start')),
        matching: find.text('7th/6th'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.arpeggioStart, ArpeggioStart.seventh);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('arpeggio-sound')),
        matching: find.text('Guitar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.arpeggioSound, Comping.guitar);
    // Close the mixer.
    Navigator.of(tester.element(find.byKey(const ValueKey('arpeggios')))).pop();
    await tester.pumpAndSettle();

    // Off again from the menu.
    await choose('arpeggio-off');
    expect(chip().selected, isFalse);
    await choose('arpeggio-fifth');
    expect(chip().selected, isTrue);

    // The next tune starts with them off; the choices are kept.
    await open('Blue Bossa');
    expect(chip().selected, isFalse);
    expect(settings.arpeggioStart, ArpeggioStart.fifth);
    expect(settings.arpeggioSound, Comping.guitar);
  });
}
