// Everything the player has made, written out as one piece of text and read
// back on the other phone.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/backup.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/user_progression.dart';

/// A progression with everything on it: a form, a repeat, a pair of endings,
/// a waltz's three beats to the bar.
UserProgression _everything() =>
    UserProgression(
        id: 'abc-1',
        title: 'Waltz for Nobody',
        composer: 'Y. Bridges',
        key: 'E♭ minor',
        tempo: 176,
        beatsPerBar: 3,
        bars: ['Fø7', 'Bb7b9', 'Ebm6', 'Ebm6', 'Cb^7', 'Bb7', 'Abm7', 'Db7'],
        tags: {Genre.ballad},
        style: const BandStyle(
          drums: Feel.bossa,
          bass: BassStyle.twoFeel,
          piano: PianoStyle.held,
        ),
      )
      ..setSection(4, 'B')
      ..setRepeats(0, 2)
      ..setEnding(6, 1)
      ..setEnding(7, 2);

UserProgression _plain(String id, String title) => UserProgression(
  id: id,
  title: title,
  key: 'C',
  tempo: 120,
  bars: const ['Dm7', 'G7', 'CΔ7', 'CΔ7'],
  style: BandStyle.of(Feel.swing),
);

Future<LibraryStore> _shelf() async {
  final library = LibraryStore.inMemory();
  await library.setFavourite(TuneRef.standard('Autumn Leaves'), true);
  await library.setFavourite(TuneRef.mine('abc-1'), true);
  await library.justPlayed(
    TuneRef.standard('Cherokee'),
    at: DateTime(2026, 9, 19, 20),
  );
  final gig = await library.addSetlist('Friday at the Vortex');
  await library.setInSetlist(gig.id, TuneRef.standard('Autumn Leaves'), true);
  await library.setInSetlist(gig.id, TuneRef.mine('abc-1'), true);
  return library;
}

void main() {
  group('writing a backup and reading it back', () {
    test('the progressions and the shelf come back as they went out', () async {
      final library = await _shelf();
      final progressions = [_everything(), _plain('abc-2', 'Simple')];

      final backup = readBackup(
        backupText(
          progressions: progressions,
          library: library,
          at: DateTime(2026, 9, 20, 10, 30),
        ),
      );

      expect(backup.made, DateTime(2026, 9, 20, 10, 30));
      expect(
        [for (final p in backup.progressions) p.toJson()],
        [for (final p in progressions) p.toJson()],
      );
      expect(backup.library, library.toJson());

      // And put back on a fresh phone it reads as the same shelf.
      final restored = LibraryStore.inMemory();
      await restored.replaceWith(backup.library);
      expect(restored.favourites, library.favourites);
      expect(restored.setlists.single.tunes, library.setlists.single.tunes);
      expect(restored.played.single.at, DateTime(2026, 9, 19, 20));
    });

    test('a progression keeps its bars, form, repeats, endings, key, tempo '
        'and metre', () async {
      final original = _everything();
      final backup = readBackup(
        backupText(progressions: [original], library: LibraryStore.inMemory()),
      );

      final copy = backup.progressions.single;
      expect(copy.id, 'abc-1');
      expect(copy.title, 'Waltz for Nobody');
      expect(copy.composer, 'Y. Bridges');
      expect(copy.bars, original.bars);
      expect(copy.key, 'E♭ minor');
      expect(copy.tempo, 176);
      expect(copy.beatsPerBar, 3);
      expect(copy.meter, '3/4');
      expect(copy.sections, {0: 'A', 4: 'B'});
      expect(copy.repeats, {0: 2});
      expect(copy.endings, {6: 1, 7: 2});
      expect(copy.tags, {Genre.ballad});
      expect(copy.style, original.style);
      // Still plays the same: the A twice, then the B.
      expect(copy.toTune().form, original.toTune().form);
      expect(copy.toTune().barCount, original.toTune().barCount);
    });

    test('an empty shelf backs up and comes back empty', () async {
      final backup = readBackup(
        backupText(progressions: const [], library: LibraryStore.inMemory()),
      );
      expect(backup.progressions, isEmpty);
      expect(backup.favourites, 0);
      expect(backup.setlists, 0);
    });

    test('takes are left behind, and the file says how many', () async {
      final text = backupText(
        progressions: const [],
        library: LibraryStore.inMemory(),
        takesLeftBehind: 3,
      );
      expect(jsonDecode(text), containsPair('takesNotIncluded', 3));
      // Nothing to say when there were none.
      expect(
        jsonDecode(
          backupText(progressions: const [], library: LibraryStore.inMemory()),
        ),
        isNot(contains('takesNotIncluded')),
      );
    });
  });

  group('a file that is not a backup', () {
    test('something that isn\'t JSON at all', () {
      expect(
        () => readBackup('my holiday photos'),
        throwsA(
          isA<NotABackup>().having(
            (e) => e.message,
            'message',
            contains('Paste the whole thing'),
          ),
        ),
      );
    });

    test('JSON from some other app', () {
      expect(
        () => readBackup('{"app": "some-other-thing", "version": 1}'),
        throwsA(
          isA<NotABackup>().having(
            (e) => '$e',
            'says so',
            contains('The Changes'),
          ),
        ),
      );
      // A bare list or a bare number isn't one either.
      expect(() => readBackup('[1, 2, 3]'), throwsA(isA<NotABackup>()));
      expect(() => readBackup('42'), throwsA(isA<NotABackup>()));
    });

    test('one made by a newer version of the app', () {
      expect(
        () => readBackup('{"app": "the-changes-backup", "version": 99}'),
        throwsA(
          isA<NotABackup>().having(
            (e) => '$e',
            'says so',
            contains('newer version'),
          ),
        ),
      );
    });

    test('one whose progressions are gibberish', () {
      expect(
        () => readBackup(
          '{"app": "the-changes-backup", "version": 1, '
          '"progressions": [{"nonsense": true}]}',
        ),
        throwsA(isA<NotABackup>()),
      );
    });

    test('a backup with spare whitespace round it still reads', () async {
      final text = backupText(
        progressions: [_plain('abc-2', 'Simple')],
        library: LibraryStore.inMemory(),
      );
      expect(readBackup('\n\n  $text  \n').progressions, hasLength(1));
    });
  });

  group('what the player is told a file holds', () {
    test('one progression on its own', () {
      final backup = readBackup(
        backupText(
          progressions: [_plain('a', 'One')],
          library: LibraryStore.inMemory(),
        ),
      );
      expect(backup.describe, '1 progression');
    });

    test('several of them', () {
      final backup = readBackup(
        backupText(
          progressions: [_plain('a', 'One'), _plain('b', 'Two')],
          library: LibraryStore.inMemory(),
        ),
      );
      expect(backup.describe, '2 progressions');
    });

    test('with setlists and stars counted too', () async {
      final backup = readBackup(
        backupText(
          progressions: [_plain('a', 'One'), _plain('b', 'Two')],
          library: await _shelf(),
        ),
      );
      expect(backup.favourites, 2);
      expect(backup.setlists, 1);
      expect(backup.describe, '2 progressions · 1 setlist · 2 starred');
    });

    test('two setlists read as setlists', () async {
      final library = await _shelf();
      await library.addSetlist('Lesson');
      final backup = readBackup(
        backupText(progressions: const [], library: library),
      );
      expect(backup.describe, '0 progressions · 2 setlists · 2 starred');
    });
  });

  test('the file is named with the day it was made', () {
    expect(
      backupFileName(DateTime(2026, 9, 20, 14, 5)),
      'The Changes backup 2026-09-20.json',
    );
    expect(backupFileName(DateTime(2026, 1, 2)), contains('2026-01-02'));
    // Nothing in it that a file system would object to.
    expect(backupFileName(DateTime(2026, 9, 20)), isNot(contains('/')));
    expect(backupFileName(), endsWith('.json'));
  });
}
