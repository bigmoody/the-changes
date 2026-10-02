// Recording a phrase and hearing it in another key.
//
// A fake recorder and a fake player, because there is no microphone in a
// widget test and no speaker either. What is being checked is the journey:
// what gets saved, and what the player is actually asked to do with it.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/audio/take_recorder.dart';
import 'package:play_along/music/phrase.dart';
import 'package:play_along/music/recorded_take.dart' show TakeShift;
import 'package:play_along/practice/phrase_store.dart';
import 'package:play_along/practice/recording_store.dart';
import 'package:play_along/screens/phrases_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/settings/progression_store.dart';

/// A recorder that writes nothing and says yes.
class FakeRecorder implements TakeRecorder {
  String? startedAt;
  var _running = false;
  @override
  Duration length = const Duration(seconds: 3);
  var allowed = true;

  @override
  bool get isRecording => _running;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(String path) async {
    startedAt = path;
    _running = true;
  }

  @override
  Future<Duration> stop() async {
    _running = false;
    return length;
  }

  @override
  Future<void> dispose() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A player that remembers what it was asked to play.
class FakePlayer implements PracticePlayer {
  Uint8List? played;
  TakeShift? withShift;

  @override
  Future<void> playSnippet(Uint8List wav, {TakeShift? shift}) async {
    played = wav;
    withShift = shift;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('recording one asks what key it was in, and keeps it', (
    tester,
  ) async {
    final files = NoRecordingFiles();
    final store = await PhraseStore.load(
      storage: MemoryStorage(),
      files: files,
    );
    final recorder = FakeRecorder();
    await tester.pumpWidget(
      MaterialApp(
        home: PhrasesScreen(
          phrases: store,
          player: FakePlayer(),
          settings: AppSettings.inMemory(),
          recorder: recorder,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('record-phrase')));
    await tester.pumpAndSettle();
    expect(recorder.isRecording, isTrue);
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('record-phrase')));
    await tester.pumpAndSettle();
    // The key is the one thing the app does not try to guess.
    expect(find.text('What key was that in?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('played-in-5')));
    await tester.pumpAndSettle();

    expect(store.all, hasLength(1));
    expect(store.all.single.key, 5);
    expect(store.all.single.seconds, 3);
  });

  testWidgets('without the microphone it says so rather than failing', (
    tester,
  ) async {
    final store = PhraseStore.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        home: PhrasesScreen(
          phrases: store,
          player: FakePlayer(),
          settings: AppSettings.inMemory(),
          recorder: FakeRecorder()..allowed = false,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('record-phrase')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phrase-problem')), findsOneWidget);
    expect(store.isEmpty, isTrue);
  });

  group('taking one round the keys', () {
    Future<FakePlayer> open(WidgetTester tester, {required int key}) async {
      final files = NoRecordingFiles();
      await files.save('one.wav', Uint8List.fromList([1, 2, 3]));
      final phrase = Phrase(
        id: '1',
        name: 'Four bars',
        fileName: 'one.wav',
        key: key,
        seconds: 3,
      );
      final store = await PhraseStore.load(
        storage: MemoryStorage(),
        files: files,
      );
      await store.add(phrase);
      final player = FakePlayer();
      await tester.pumpWidget(
        MaterialApp(
          home: PhraseKeysScreen(
            phrase: phrase,
            phrases: store,
            player: player,
          ),
        ),
      );
      return player;
    }

    testWidgets('it plays the audio, not a transcription of it', (
      tester,
    ) async {
      final player = await open(tester, key: 0);
      await tester.tap(find.byKey(const ValueKey('hear-phrase')));
      await tester.pumpAndSettle();
      expect(player.played, [1, 2, 3]);
    });

    testWidgets('in its own key nothing is shifted', (tester) async {
      final player = await open(tester, key: 0);
      await tester.tap(find.byKey(const ValueKey('hear-phrase')));
      await tester.pumpAndSettle();
      expect(player.withShift!.speed, 1);
      expect(player.withShift!.shift, 1);
    });

    testWidgets('moving a key shifts the pitch and keeps the tempo', (
      tester,
    ) async {
      final player = await open(tester, key: 0);
      // The cycle of fourths: the next one is five semitones up.
      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(player.withShift!.speed, 1);
      expect(player.withShift!.cents, closeTo(500, 1));
    });

    testWidgets('and Like Tape moves the speed instead', (tester) async {
      final player = await open(tester, key: 0);
      await tester.tap(find.text('Like Tape'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hear-phrase')));
      await tester.pumpAndSettle();
      expect(player.withShift!.shift, 1);
      expect(player.withShift!.speed, 1);

      await tester.tap(find.byKey(const ValueKey('next-key')));
      await tester.pumpAndSettle();
      expect(player.withShift!.shift, 1);
      expect(player.withShift!.speed, greaterThan(1));
    });

    testWidgets('a far key goes the short way round, not most of an octave', (
      tester,
    ) async {
      // Eleven semitones up is a semitone down, and dragging a recording
      // nearly an octave to reach it would sound far worse.
      final player = await open(tester, key: 0);
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(const ValueKey('next-key')));
        await tester.pumpAndSettle();
        expect(
          player.withShift!.cents.abs(),
          lessThanOrEqualTo(601),
          reason: 'step $i went the long way',
        );
      }
    });

    testWidgets('it says when the filter is being asked for too much', (
      tester,
    ) async {
      await open(tester, key: 0);
      expect(find.text('As you played it.'), findsOneWidget);
      // Three steps round the cycle is three fourths: half an octave.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('next-key')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Like Tape'), findsWidgets);
    });
  });
}
