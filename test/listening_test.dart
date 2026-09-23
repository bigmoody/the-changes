// Listening: whether the records line up with the charts they claim to
// be about.
//
// This is the only data in the app that is neither written by the app
// nor derived from it: somebody typed it in from what they know, and
// what somebody knows can be wrong. So the tests lean on the one thing
// that can be checked mechanically, which is whether every tune named
// here is a tune the library actually holds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/library/listening.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/listening_screen.dart';
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

Set<String> get _titles => {for (final tune in standards) tune.title};

void main() {
  group('the records line up with the library', () {
    test('every tune named has a chart in this app', () {
      // The cross-reference is the whole feature. A title that does not
      // match is a promise the screen cannot keep, and a typo in a tune
      // name is the most likely mistake in the whole file.
      final missing = tunesListened.where((t) => !_titles.contains(t));
      expect(missing, isEmpty, reason: 'not in the library: $missing');
    });

    test('no record is listed with nothing on it', () {
      for (final record in listening) {
        expect(record.tunes, isNotEmpty, reason: titleOf(record));
      }
    });

    test('it covers a decent slice of the library', () {
      // Not all of it, and it does not claim to. But a listening list
      // that reached a handful of tunes would not be worth a screen.
      expect(tunesListened.length, greaterThan(50));
      expect(listening.length, greaterThan(20));
    });
  });

  group('what is stored', () {
    test('artist, year and a reason, on every one', () {
      for (final record in listening) {
        expect(record.artist, isNotEmpty);
        expect(record.year, isNotEmpty);
        expect(record.about.length, greaterThan(60), reason: titleOf(record));
      }
    });

    test('a year is a year, or a stretch of them', () {
      final years = RegExp(r'^\d{4}(–\d{2,4})?$');
      for (final record in listening) {
        expect(
          years.hasMatch(record.year),
          isTrue,
          reason: '${record.artist}: "${record.year}"',
        );
      }
    });

    test('the sides too early to have an album do not pretend to one', () {
      // Naming an album for a 1939 seventy-eight would be worse than
      // saying less, so those carry a player and a stretch of years.
      final early = listening.where((r) => r.album == null);
      expect(early, isNotEmpty);
      for (final record in early) {
        expect(int.parse(record.year.substring(0, 4)), lessThan(1955));
        expect(titleOf(record), '${record.artist}, ${record.year}');
      }
    });

    test('an album is written out with its year beside it', () {
      final withAlbum = listening.firstWhere((r) => r.album != null);
      expect(
        titleOf(withAlbum),
        '${withAlbum.artist}, ${withAlbum.album} (${withAlbum.year})',
      );
    });

    test('they are in order, oldest first', () {
      // Read down the list and it is also the story of how the music got
      // from one place to the next, which only works if it is sorted.
      var last = 0;
      for (final record in listening) {
        final year = int.parse(record.year.substring(0, 4));
        expect(year, greaterThanOrEqualTo(last), reason: titleOf(record));
        last = year;
      }
    });

    test('nothing is stored but facts about the record', () {
      // No lyrics, no melodies, no transcriptions. The fields are the
      // fields, and this is the test that says so if anybody adds one.
      final record = listening.first;
      expect(record, isA<Listening>());
      expect(
        (
          artist: record.artist,
          album: record.album,
          year: record.year,
          about: record.about,
          tunes: record.tunes,
        ),
        record,
        reason: 'a record is who, what, when, why and which tunes',
      );
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: const ListeningScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it says why before it says what', (tester) async {
      await open(tester);
      expect(
        find.textContaining('passed on by recordings, not by paper'),
        findsOneWidget,
      );
    });

    testWidgets('it counts what it covers rather than claiming a number', (
      tester,
    ) async {
      await open(tester);
      expect(
        find.textContaining(
          '${listening.length} records, and ${tunesListened.length} of the '
          'tunes',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the oldest is at the top and carries its tunes', (
      tester,
    ) async {
      await open(tester);
      final first = listening.first;
      expect(find.text(first.artist), findsOneWidget);
      for (final tune in first.tunes.take(2)) {
        expect(find.text(tune), findsOneWidget, reason: tune);
      }
    });

    testWidgets('a record further down is built when it is scrolled to', (
      tester,
    ) async {
      await open(tester);
      final kindOfBlue = listening.firstWhere((r) => r.album == 'Kind of Blue');
      final card = find.byKey(ValueKey('record-${titleOf(kindOfBlue)}'));
      await tester.scrollUntilVisible(card, 200);
      expect(card, findsOneWidget);
      expect(find.text('So What'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it opens from Learn', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: LearnPage(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      final card = find.byKey(const ValueKey('learn-listening'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(ListeningScreen), findsOneWidget);
    });
  });
}
