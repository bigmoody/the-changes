// The sheet where an imported part is put in place.
//
// The file picker cannot be driven from a test, so what is checked here is
// everything after it: that the two controls move the part the way their
// labels say, that the picture is drawn from the same numbers the band
// plays, and that a part can be taken out again.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/imported_part.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/practice_controller.dart';
import 'package:play_along/screens/import_part_sheet.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// A two-bar riff, so the repeat and the offset both have something to do.
ImportedPart _riff() => ImportedPart(
  name: 'Walking Bass',
  notes: [
    for (var beat = 0; beat < 8; beat++)
      (pitch: 40 + beat, beat: beat + 0.0, beats: 1, velocity: 0.8),
  ],
  lengthBeats: 8,
);

void main() {
  late PracticeController controller;

  Future<void> open(WidgetTester tester, {ImportedPart? part}) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    controller = PracticeController(
      // The blues, so the form is a round twelve bars.
      tune: practiceProgressions.firstWhere(
        (tune) => tune.title == 'Jazz blues in F',
      ),
      player: _FakePlayer(),
      settings: AppSettings.inMemory(),
    );
    if (part != null) controller.setImportedPart(part);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showImportPart(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('with no part it just offers the picker', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('choose-midi')), findsOneWidget);
    expect(find.byKey(const ValueKey('over-the-form')), findsNothing);
  });

  testWidgets('a part in shows its controls and where it lands', (
    tester,
  ) async {
    await open(tester, part: _riff());
    expect(find.text('Walking Bass'), findsOneWidget);
    expect(find.text('8 notes'), findsOneWidget);
    expect(find.byKey(const ValueKey('over-the-form')), findsOneWidget);
    expect(find.text('As written'), findsOneWidget);
    expect(find.text('2 bars'), findsOneWidget);
  });

  testWidgets('moving the start says so in bars once it is a whole one', (
    tester,
  ) async {
    await open(tester, part: _riff());
    final earlier = find.byKey(const ValueKey('start-earlier'));
    await tester.tap(earlier);
    await tester.pumpAndSettle();
    expect(find.text('1 beat earlier'), findsOneWidget);
    expect(controller.importedPart!.offsetBeats, -1);

    for (var i = 0; i < 3; i++) {
      await tester.tap(earlier);
      await tester.pumpAndSettle();
    }
    expect(find.text('1 bar earlier'), findsOneWidget);
    expect(controller.importedPart!.offsetBeats, -4);
  });

  testWidgets('the repeat length changes a bar at a time, never below one', (
    tester,
  ) async {
    await open(tester, part: _riff());
    await tester.tap(find.byKey(const ValueKey('repeat-longer')));
    await tester.pumpAndSettle();
    expect(find.text('3 bars'), findsOneWidget);

    final shorter = find.byKey(const ValueKey('repeat-shorter'));
    for (var i = 0; i < 4; i++) {
      await tester.tap(shorter);
      await tester.pumpAndSettle();
    }
    expect(find.text('1 bar'), findsOneWidget);
    // At one bar it stops offering to go shorter.
    expect(tester.widget<IconButton>(shorter).onPressed, isNull);
  });

  testWidgets('changing the instrument keeps everything else', (tester) async {
    await open(tester, part: _riff().movedTo(-4));
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('imported-voice')),
        matching: find.text('Bass'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.importedPart!.voice, PartVoice.bass);
    expect(controller.importedPart!.offsetBeats, -4, reason: 'still moved');
  });

  testWidgets('removing it takes it out and closes the sheet', (tester) async {
    await open(tester, part: _riff());
    await tester.tap(find.byKey(const ValueKey('remove-part')));
    await tester.pumpAndSettle();
    expect(controller.importedPart, isNull);
    expect(find.byKey(const ValueKey('over-the-form')), findsNothing);
  });

  testWidgets('the picture is drawn from what the band would play', (
    tester,
  ) async {
    // The riff is two bars long, so over twelve bars it plays in every one
    // and starts again on the odd-numbered ones.
    await open(tester, part: _riff());
    final part = controller.importedPart!;
    expect(part.notesByBar(bars: 12, beatsPerBar: 4).every((n) => n > 0), true);
    expect(part.repeatsAt(bars: 12, beatsPerBar: 4), {0, 2, 4, 6, 8, 10});

    // Moved a bar early, the first bar of each repeat falls silent.
    controller.setImportedPart(part.movedTo(4));
    await tester.pumpAndSettle();
    expect(controller.importedPart!.notesByBar(bars: 4, beatsPerBar: 4), [
      0,
      4,
      0,
      4,
    ]);
  });
}
