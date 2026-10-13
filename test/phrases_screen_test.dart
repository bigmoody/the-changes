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

  /// Where the last play was asked to start.
  Duration? playedFrom;

  /// Every place it was asked to move to mid-play, in order.
  final movedTo = <Duration>[];

  /// What a position read gives back, so a test can put the play part
  /// way through or say it is over.
  Duration? at;

  var stopped = false;

  @override
  Future<void> playSnippet(
    Uint8List wav, {
    TakeShift? shift,
    Duration from = Duration.zero,
  }) async {
    played = wav;
    withShift = shift;
    playedFrom = from;
  }

  @override
  Duration? snippetPosition() => at;

  @override
  Future<void> seekSnippet(Duration to) async => movedTo.add(to);

  @override
  Future<void> stopSnippet() async => stopped = true;

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

    testWidgets('it plays from the start until the bar is moved', (
      tester,
    ) async {
      final player = await open(tester, key: 0);
      await tester.tap(find.byKey(const ValueKey('hear-phrase')));
      await tester.pump();
      expect(player.playedFrom, Duration.zero);
      expect(find.text('Hear It'), findsOneWidget);
    });

    testWidgets('dragging the bar is where the next play begins', (
      tester,
    ) async {
      // The whole of it: a lick is four bars and the bit you need is
      // usually not the start, so the point you drag to is the point it
      // plays from.
      final player = await open(tester, key: 0);
      await tester.drag(
        find.byKey(const ValueKey('scrub')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      final from = player.movedTo.isEmpty ? null : player.movedTo.last;
      expect(from, isNotNull);
      expect(from!, greaterThan(Duration.zero));

      await tester.tap(find.byKey(const ValueKey('hear-phrase')));
      await tester.pump();
      expect(player.playedFrom, from);
    });

    testWidgets('the button says what it will do once it has been moved', (
      tester,
    ) async {
      await open(tester, key: 0);
      expect(find.text('Hear It'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('scrub')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Play From'), findsOneWidget);
    });

    testWidgets('and it can be put back to the start', (tester) async {
      await open(tester, key: 0);
      expect(find.byKey(const ValueKey('scrub-to-start')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('scrub')),
        const Offset(60, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scrub-to-start')));
      await tester.pumpAndSettle();
      expect(find.text('Hear It'), findsOneWidget);
      expect(find.byKey(const ValueKey('scrub-to-start')), findsNothing);
    });

    testWidgets('dragging while it plays moves the sound with the thumb', (
      tester,
    ) async {
      final player = await open(tester, key: 0);
      player.at = const Duration(milliseconds: 500);
      await tester.tap(find.byKey(const ValueKey('hear-phrase')));
      await tester.pump();
      player.movedTo.clear();
      await tester.drag(
        find.byKey(const ValueKey('scrub')),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();
      expect(
        player.movedTo,
        isNotEmpty,
        reason: 'the sound should follow the thumb, not wait for it',
      );
    });

    testWidgets('the length of the recording is on the bar', (tester) async {
      await open(tester, key: 0);
      expect(find.byKey(const ValueKey('scrub-length')), findsOneWidget);
      expect(find.text('3.0s'), findsOneWidget);
    });

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

  group('keeping the book tidy', () {
    Future<PhraseStore> openWith(WidgetTester tester) async {
      final store = PhraseStore.inMemory([
        Phrase(
          id: '1',
          name: 'Phrase 1',
          fileName: 'one.wav',
          key: 0,
          seconds: 3,
        ),
        Phrase(
          id: '2',
          name: 'Phrase 2',
          fileName: 'two.wav',
          key: 5,
          seconds: 2,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: PhrasesScreen(
            phrases: store,
            player: FakePlayer(),
            settings: AppSettings.inMemory(),
            recorder: FakeRecorder(),
          ),
        ),
      );
      return store;
    }

    testWidgets('one can be given a name worth finding it by', (tester) async {
      final store = await openWith(tester);
      await tester.tap(find.byKey(const ValueKey('more-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rename-1')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('phrase-name')),
        'The one over the bridge',
      );
      await tester.tap(find.byKey(const ValueKey('keep-name')));
      await tester.pumpAndSettle();
      expect(store.all.first.name, 'The one over the bridge');
      // And the other is untouched.
      expect(store.all.last.name, 'Phrase 2');
    });

    testWidgets('an empty name is not a name, and is refused', (tester) async {
      final store = await openWith(tester);
      await tester.tap(find.byKey(const ValueKey('more-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rename-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('phrase-name')), '   ');
      await tester.tap(find.byKey(const ValueKey('keep-name')));
      await tester.pumpAndSettle();
      expect(store.all.first.name, 'Phrase 1');
    });

    testWidgets('deleting asks first, and backing out keeps it', (
      tester,
    ) async {
      final store = await openWith(tester);
      await tester.tap(find.byKey(const ValueKey('more-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('no other copy'), findsOneWidget);

      await tester.tap(find.text('Keep It'));
      await tester.pumpAndSettle();
      expect(store.all, hasLength(2));
    });

    testWidgets('and goes through with it when confirmed', (tester) async {
      final store = await openWith(tester);
      await tester.tap(find.byKey(const ValueKey('more-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('really-delete')));
      await tester.pumpAndSettle();
      expect(store.all, hasLength(1));
      // The right one went.
      expect(store.all.single.id, '2');
    });
  });
}
