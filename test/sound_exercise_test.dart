// Sound: long tones, vibrato and a ballad's guide tones are notes to hold
// with the band under them, not a link to the tuner.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/sample_bank.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/practice/roadmap.dart';
import 'package:play_along/practice/sound_exercise.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/screens/sound_exercise_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

double _rms(Int16List pcm, double from, double to) {
  final a = math.max(0, (from * 44100).round());
  final b = math.min(pcm.length, (to * 44100).round());
  var sum = 0.0;
  for (var i = a; i < b; i++) {
    sum += pcm[i] * pcm[i].toDouble();
  }
  return math.sqrt(sum / math.max(1, b - a));
}

void main() {
  test('the band is still there at the end of every held note', () async {
    // A piano and a bass die away inside three beats; a drone that has
    // gone quiet halfway through a long tone is nothing to tune against.
    final bank = await SampleBank.load(
      (path) async => File('assets/sounds/$path').readAsBytes(),
    );
    final ballad = standards
        .firstWhere((t) => t.title == 'Body and Soul')
        .transposed(2);
    for (final way in [SoundWay.fan, SoundWay.vibrato, SoundWay.balladGuides]) {
      final notes = heldNotes(way, 'B♭', ballad: ballad);
      final band = soundBand(notes, tempo: 60, down: 2, guide: false);
      final wav = renderSnippet(bank, band.notes, drums: band.drums);
      final pcm = Int16List.sublistView(Uint8List.fromList(wav.sublist(44)));
      for (final (i, note) in notes.indexed) {
        for (var b = 0; b < note.beats; b++) {
          final at = soundCountIn + band.starts[i] + b;
          expect(
            _rms(pcm, at + 0.5, at + 0.95),
            greaterThan(120),
            reason: '${way.name}, note $i, beat ${b + 1}',
          );
        }
      }
    }
  });

  test('long tones fan out from the middle of the horn', () {
    final notes = heldNotes(SoundWay.fan, 'B♭');
    expect(notes, hasLength(7));
    final pitches = [for (final n in notes) n.pitch];
    // Each further from the middle G than the one before, or as far.
    for (var i = 1; i < pitches.length; i++) {
      expect(
        (pitches[i] - 67).abs(),
        greaterThanOrEqualTo((pitches[i - 1] - 67).abs()),
      );
    }
    for (final n in notes) {
      expect(n.under, isNotEmpty, reason: 'a drone under every note');
      expect(n.beats, 6);
    }
  });

  test('measured vibrato is one note, none to four pulses a beat', () {
    final notes = heldNotes(SoundWay.vibrato, 'F');
    expect([for (final n in notes) n.pulses], [0, 2, 3, 4]);
    expect({for (final n in notes) n.pitch}, hasLength(1));
  });

  test('every ballad has its first eight bars to hold', () {
    for (final title in soundBallads) {
      final tune = standards.firstWhere((t) => t.title == title);
      final notes = heldNotes(SoundWay.balladGuides, 'C', ballad: tune);
      expect(notes, isNotEmpty, reason: title);
      final beats = notes.fold(0, (sum, n) => sum + n.beats);
      expect(beats, 32, reason: '$title: eight bars of four');
      for (final n in notes) {
        expect(n.chord, isNotNull, reason: title);
        expect(n.under, hasLength(3), reason: '$title: root, 3rd and 7th');
        expect(n.pitch, inInclusiveRange(55, 81), reason: title);
      }
    }
  });

  test('the horn blocks that opened the tuner are exercises now', () {
    final horn = RoadmapInstrument.horn;
    for (final stage in stagesFor(horn)) {
      final longTones = stage.blocks.firstWhere((b) => b.title == 'Long Tones');
      expect(longTones.sound, isNotNull, reason: 'stage ${stage.number}');
    }
    final ballad = stagesFor(horn)
        .expand((s) => s.blocks)
        .firstWhere((b) => b.title == 'The Ballad Sound');
    expect(ballad.sound, balladSound);
  });

  testWidgets('the ballad sound plays its steps and opens the ballad', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(393, 852) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: SoundExerciseScreen(
          title: 'The Ballad Sound',
          exercise: balladSound,
          keyName: 'F',
          day: 0,
          player: PracticePlayer(),
          settings: AppSettings.inMemory(),
          onDone: () => done = true,
        ),
      ),
    );
    expect(find.text('Measured Vibrato'), findsOneWidget);
    expect(find.byKey(const ValueKey('sound-stave-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sound-next')));
    await tester.pump();
    expect(find.text('The Changes Under a Held Note'), findsOneWidget);
    expect(find.text('On Body and Soul'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sound-next')));
    await tester.pump();
    expect(find.text('The Melody, Straight'), findsOneWidget);
    expect(find.byKey(const ValueKey('sound-play')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sound-melody')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(done, isFalse);
    expect(tester.takeException(), isNull);
  });
}
