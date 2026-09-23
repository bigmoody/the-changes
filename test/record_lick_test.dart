// Catching a lick.
//
// There is no microphone in a simulator and none in a test, so the tape
// is stood in for and hands over playing that was made here: known
// pitches, at known moments, over known changes. What is being checked is
// everything between that and a lick in the book.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/lick_contexts.dart';
import 'package:play_along/music/tuning.dart';
import 'package:play_along/practice/lick_store.dart';
import 'package:play_along/practice/lick_tape.dart';
import 'package:play_along/screens/record_lick_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
    PlayableRecording? recording,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

/// Hands back playing the test made, instead of listening to a room.
class _FakeTape implements LickTape {
  _FakeTape(this.recorded, {this.allowed = true});

  Uint8List? recorded;
  final bool allowed;
  var started = false;

  @override
  bool get isRecording => started;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start() async => started = true;

  @override
  Future<Uint8List?> stop() async {
    started = false;
    return recorded;
  }
}

const _rate = 44100;

/// A line of [pitches], an eighth note apart at [bpm], beginning [from]
/// seconds into the recording.
Uint8List playing(
  List<int> pitches, {
  double bpm = 140,
  required double from,
  double swing = 1 / 6,
}) {
  final perBeat = 60 / bpm;
  final seconds = from + pitches.length * perBeat + 1;
  final samples = Float32List((seconds * _rate).round());
  for (final (i, pitch) in pitches.indexed) {
    // Off-beats late, as anybody playing this would.
    final late = i.isOdd ? swing * perBeat : 0.0;
    final at = from + i * perBeat / 2 + late;
    final length = (perBeat / 2 * _rate).round();
    final start = (at * _rate).round();
    final hz = midiToHz(pitch);
    for (var s = 0; s < length && start + s < samples.length; s++) {
      final t = s / _rate;
      final left = (length - s) / _rate;
      final fade = math.exp(-t * 3) * (left < 0.02 ? left / 0.02 : 1);
      samples[start + s] +=
          (math.sin(2 * math.pi * hz * t) * 0.6 +
              math.sin(4 * math.pi * hz * t) * 0.25 +
              math.sin(6 * math.pi * hz * t) * 0.1) *
          fade *
          0.6;
    }
  }
  final body = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(body);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(
      i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  final out = BytesBuilder();
  void u32(int v) =>
      out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      out.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  out.add('RIFF'.codeUnits);
  u32(36 + body.length);
  out.add('WAVE'.codeUnits);
  out.add('fmt '.codeUnits);
  u32(16);
  u16(1);
  u16(1);
  u32(_rate);
  u32(_rate * 2);
  u16(2);
  u16(16);
  out.add('data'.codeUnits);
  u32(body.length);
  out.add(body);
  return out.toBytes();
}

/// The count-in the first context gets: one bar of four at its tempo.
double get countIn => 4 * 60 / lickContexts.first.tempo;

/// D E F G A B, over the ii-V-I.
const aLine = [62, 64, 65, 67, 69, 71];

void main() {
  late LickStore licks;
  late _FakeTape tape;

  Future<void> open(
    WidgetTester tester, {
    Uint8List? recorded,
    bool mic = true,
  }) async {
    tester.view
      ..physicalSize = const Size(393, 1400) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    licks = LickStore.inMemory();
    tape = _FakeTape(recorded, allowed: mic);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light, fontFamily: 'Roboto'),
        home: RecordLickScreen(
          licks: licks,
          player: _FakePlayer(),
          settings: AppSettings.inMemory(),
          tape: tape,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> record(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('lick-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lick-record')));
    await tester.pumpAndSettle();
  }

  String textOf(Key key) =>
      (find.byKey(key).evaluate().single.widget as Text).data!;

  group('before anything is played', () {
    testWidgets('it offers changes to play over and nothing to save', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const ValueKey('lick-context')), findsOneWidget);
      expect(find.byKey(const ValueKey('lick-record')), findsOneWidget);
      expect(find.byKey(const ValueKey('lick-save')), findsNothing);
      expect(find.byKey(const ValueKey('heard-line')), findsNothing);
    });

    testWidgets('the button says what pressing it does', (tester) async {
      await open(tester);
      expect(find.text('Record'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lick-record')));
      await tester.pumpAndSettle();
      expect(find.text('Stop and Write It Down'), findsOneWidget);
      expect(tape.started, isTrue);
    });
  });

  group('what it heard', () {
    testWidgets('the line comes back, written on a stave', (tester) async {
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      expect(find.byKey(const ValueKey('heard-line')), findsOneWidget);
      expect(find.byKey(const ValueKey('lick-save')), findsOneWidget);
      expect(find.text('Save These 6 Notes'), findsOneWidget);
    });

    testWidgets('it works out that the line was swung', (tester) async {
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      final grid = tester.widget<DropdownButtonFormField<Object?>>(
        find.byKey(const ValueKey('lick-grid')),
      );
      expect(grid.initialValue.toString(), contains('swungEighths'));
    });

    testWidgets('a silent recording says so rather than saving nothing', (
      tester,
    ) async {
      await open(tester, recorded: playing(const [], from: countIn));
      await record(tester);
      expect(
        textOf(const ValueKey('lick-problem')),
        contains('Nothing was heard'),
      );
      expect(find.byKey(const ValueKey('lick-save')), findsNothing);
    });

    testWidgets('a recording that will not read says which trouble', (
      tester,
    ) async {
      await open(tester, recorded: Uint8List.fromList(List.filled(64, 3)));
      await record(tester);
      expect(textOf(const ValueKey('lick-problem')), contains('not a WAV'));
    });

    testWidgets('without a microphone it says so and keeps the band', (
      tester,
    ) async {
      await open(tester, mic: false);
      await tester.tap(find.byKey(const ValueKey('lick-record')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('lick-problem')), contains('microphone'));
      expect(tape.started, isFalse);
    });
  });

  group('putting it right before it is kept', () {
    testWidgets('the start can be nudged when it sits over wrong chords', (
      tester,
    ) async {
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      expect(textOf(const ValueKey('lick-nudge')), 'Where it was played');

      await tester.tap(find.byKey(const ValueKey('lick-later')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('lick-nudge')), '1 beat later');

      await tester.tap(find.byKey(const ValueKey('lick-earlier')));
      await tester.tap(find.byKey(const ValueKey('lick-earlier')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('lick-nudge')), '1 beat earlier');
    });

    testWidgets('nudging moves the notes, the way the words say', (
      tester,
    ) async {
      // Played on beat 1, so without a nudge the line starts at beat
      // nought. Told it sits a beat later, it starts at beat one.
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      await tester.tap(find.byKey(const ValueKey('lick-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lick-save')));
      await tester.pumpAndSettle();
      expect(licks.all.single.notes.first.beat, closeTo(1, 0.001));
    });
  });

  group('a line with no changes under it', () {
    Future<void> pickNoChanges(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('lick-context')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nothing, just a click').last);
      await tester.pumpAndSettle();
    }

    testWidgets('is offered, and swaps the band for a click', (tester) async {
      await open(tester);
      expect(find.text('Play'), findsOneWidget);
      await pickNoChanges(tester);
      expect(find.byKey(const ValueKey('click-play')), findsOneWidget);
      expect(find.text('Play'), findsNothing);
      expect(textOf(const ValueKey('click-tempo')), '120 BPM');
    });

    testWidgets('the tempo can be set before playing', (tester) async {
      await open(tester);
      await pickNoChanges(tester);
      await tester.tap(find.byKey(const ValueKey('click-faster')));
      await tester.tap(find.byKey(const ValueKey('click-faster')));
      await tester.pumpAndSettle();
      expect(textOf(const ValueKey('click-tempo')), '130 BPM');
    });

    testWidgets('the line starts where it starts, whenever that was', (
      tester,
    ) async {
      // No bar 1 to come in on, so coming in late is not coming in late.
      await open(tester, recorded: playing(aLine, bpm: 120, from: 3.7));
      await pickNoChanges(tester);
      await record(tester);
      expect(find.byKey(const ValueKey('heard-line')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lick-save')));
      await tester.pumpAndSettle();
      expect(licks.all.single.notes.first.beat, 0);
    });

    testWidgets('and there is nothing to move it against', (tester) async {
      await open(tester, recorded: playing(aLine, bpm: 120, from: 3.7));
      await pickNoChanges(tester);
      await record(tester);
      expect(find.byKey(const ValueKey('lick-nudge')), findsNothing);
      expect(
        find.byKey(const ValueKey('lick-grid')),
        findsOneWidget,
        reason: 'the rhythm is still worth getting right',
      );
    });

    testWidgets('it saves with no changes and the tempo it was caught at', (
      tester,
    ) async {
      await open(tester, recorded: playing(aLine, bpm: 120, from: 3.7));
      await pickNoChanges(tester);
      await record(tester);
      await tester.tap(find.byKey(const ValueKey('lick-save')));
      await tester.pumpAndSettle();

      final lick = licks.all.single;
      expect(lick.over, isNull);
      expect(lick.hasChanges, isFalse);
      expect(lick.tempo, 120);
      expect(lick.notes.map((n) => n.pitch).toList(), aLine);
      expect(lick.name, 'Just a line');
      expect(lick.key, aLine.first % 12, reason: 'known by what it starts on');
    });
  });

  group('keeping it', () {
    testWidgets('the lick lands in the book with its changes', (tester) async {
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      await tester.enterText(
        find.byKey(const ValueKey('lick-name')),
        'The one off the record',
      );
      await tester.tap(find.byKey(const ValueKey('lick-save')));
      await tester.pumpAndSettle();

      final lick = licks.all.single;
      expect(lick.name, 'The one off the record');
      expect(lick.notes.map((n) => n.pitch).toList(), aLine);
      expect(lick.over!.bars, lickContexts.first.bars);
      expect(lick.key, 0, reason: 'the contexts are in C');
      expect(lick.notes.first.beat, closeTo(0, 0.001));
    });

    testWidgets('unnamed, it is called after the changes', (tester) async {
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      await tester.tap(find.byKey(const ValueKey('lick-save')));
      await tester.pumpAndSettle();
      expect(licks.all.single.name, lickContexts.first.title);
    });

    testWidgets('the changes it is saved over are its own copy', (
      tester,
    ) async {
      // Editing the context later must not change what the lick is about.
      await open(tester, recorded: playing(aLine, from: countIn));
      await record(tester);
      await tester.tap(find.byKey(const ValueKey('lick-save')));
      await tester.pumpAndSettle();
      expect(identical(licks.all.single.over!, lickContexts.first), isFalse);
    });
  });
}
