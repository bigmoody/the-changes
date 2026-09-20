// The player's own shelf: what they've starred, what they've played lately,
// the setlists they've put together, and the order a list comes out in.

import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/library/library_store.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/music/user_progression.dart';
import 'package:play_along/settings/progression_store.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

Tune _practice(String title) =>
    practiceProgressions.firstWhere((tune) => tune.title == title);

UserProgression _mine({
  required String id,
  required String title,
  String key = 'C',
  int tempo = 120,
  String? composer,
}) => UserProgression(
  id: id,
  title: title,
  key: key,
  tempo: tempo,
  composer: composer,
  bars: const ['Dm7', 'G7'],
  style: BandStyle.of(Feel.swing),
);

void main() {
  final autumn = TuneRef.standard('Autumn Leaves');
  final cherokee = TuneRef.standard('Cherokee');
  final solar = TuneRef.standard('Solar');
  final ownTune = TuneRef.mine('1758-0');

  group('pointing at a tune', () {
    test('one of the book\'s is named by its title, one of the player\'s by '
        'its id', () {
      expect(autumn.value, 's:Autumn Leaves');
      expect(autumn.name, 'Autumn Leaves');
      expect(autumn.isMine, isFalse);

      expect(ownTune.value, 'p:1758-0');
      expect(ownTune.name, '1758-0');
      expect(ownTune.isMine, isTrue);
    });

    test('a tune off the shelf points at the same thing as its title', () {
      expect(TuneRef.of(_standard('Autumn Leaves')), autumn);
      expect(TuneRef.of(_standard('Autumn Leaves')).isMine, isFalse);
    });

    test('two references to the same tune are the same reference', () {
      expect(TuneRef.standard('Cherokee'), cherokee);
      expect(TuneRef.standard('Cherokee').hashCode, cherokee.hashCode);
      expect({cherokee, TuneRef.standard('Cherokee')}, hasLength(1));
      expect(TuneRef.standard('Cherokee'), isNot(TuneRef.mine('Cherokee')));
      expect('$autumn', 's:Autumn Leaves');
    });
  });

  group('starring a tune', () {
    test('star it, unstar it, and tap the star to flip it', () async {
      final library = LibraryStore.inMemory();
      expect(library.isFavourite(autumn), isFalse);

      await library.setFavourite(autumn, true);
      expect(library.isFavourite(autumn), isTrue);
      expect(library.favourites, {autumn});

      await library.setFavourite(autumn, false);
      expect(library.favourites, isEmpty);

      await library.toggleFavourite(autumn);
      expect(library.isFavourite(autumn), isTrue);
      await library.toggleFavourite(autumn);
      expect(library.isFavourite(autumn), isFalse);
    });

    test('the stars are still there next time the app opens', () async {
      final storage = MemoryStorage();
      final library = await LibraryStore.load(storage);
      await library.setFavourite(autumn, true);
      await library.setFavourite(ownTune, true);

      final reopened = await LibraryStore.load(storage);
      expect(reopened.favourites, {autumn, ownTune});
    });

    test('unreadable saved data opens an empty shelf rather than '
        'crashing', () async {
      final library = await LibraryStore.load(MemoryStorage('not json'));
      expect(library.favourites, isEmpty);
      expect(library.played, isEmpty);
      expect(library.setlists, isEmpty);
    });
  });

  group('what was played lately', () {
    test('newest first', () async {
      final library = LibraryStore.inMemory();
      await library.justPlayed(autumn);
      await library.justPlayed(cherokee);
      expect(
        [for (final entry in library.played) entry.tune],
        [cherokee, autumn],
      );
    });

    test('playing a tune again moves it up rather than listing it '
        'twice', () async {
      final library = LibraryStore.inMemory();
      await library.justPlayed(autumn);
      await library.justPlayed(cherokee);
      await library.justPlayed(autumn);
      expect(
        [for (final entry in library.played) entry.tune],
        [autumn, cherokee],
      );
    });

    test('it remembers the last handful and lets the rest go', () async {
      final library = LibraryStore.inMemory();
      for (var i = 0; i < LibraryStore.remembers + 5; i++) {
        await library.justPlayed(TuneRef.standard('Tune $i'));
      }
      expect(library.played, hasLength(LibraryStore.remembers));
      expect(library.played.first.tune.name, 'Tune 24');
      expect(library.played.last.tune.name, 'Tune 5');
    });

    test('clearing it empties the list, and the list survives a '
        'restart', () async {
      final storage = MemoryStorage();
      final library = await LibraryStore.load(storage);
      final when = DateTime(2026, 3, 4, 5, 6);
      await library.justPlayed(autumn, at: when);

      final reopened = await LibraryStore.load(storage);
      expect(reopened.played.single.tune, autumn);
      expect(reopened.played.single.at, when);

      await reopened.clearPlayed();
      expect(reopened.played, isEmpty);
      expect((await LibraryStore.load(storage)).played, isEmpty);
    });
  });

  group('setlists', () {
    test('add one, rename it, delete it', () async {
      final library = LibraryStore.inMemory();
      final gig = await library.addSetlist('Friday at the Vortex');
      expect(library.setlists.single.name, 'Friday at the Vortex');
      expect(library.setlistById(gig.id), same(gig));

      await library.renameSetlist(gig.id, 'Saturday instead');
      expect(library.setlists.single.name, 'Saturday instead');

      await library.deleteSetlist(gig.id);
      expect(library.setlists, isEmpty);
      expect(library.setlistById(gig.id), isNull);
    });

    test('a setlist with no name still has something to call it', () async {
      final library = LibraryStore.inMemory();
      final list = await library.addSetlist('  ');
      expect(list.displayName, 'Untitled Setlist');
    });

    test('tunes go in at the end and come back out', () async {
      final library = LibraryStore.inMemory();
      final gig = await library.addSetlist('Gig');

      await library.setInSetlist(gig.id, autumn, true);
      await library.setInSetlist(gig.id, cherokee, true);
      expect(gig.tunes, [autumn, cherokee]);

      await library.setInSetlist(gig.id, autumn, false);
      expect(gig.tunes, [cherokee]);
      // Taking out a tune that isn't in it changes nothing.
      await library.setInSetlist(gig.id, autumn, false);
      expect(gig.tunes, [cherokee]);
    });

    test('the same tune can only be in a setlist once', () async {
      final library = LibraryStore.inMemory();
      final gig = await library.addSetlist('Gig');
      await library.setInSetlist(gig.id, autumn, true);
      await library.setInSetlist(gig.id, cherokee, true);
      await library.setInSetlist(gig.id, autumn, true);
      expect(gig.tunes, [autumn, cherokee]);
    });

    test('a tune is dragged up and down the running order', () async {
      final library = LibraryStore.inMemory();
      final gig = await library.addSetlist('Gig');
      for (final tune in [autumn, cherokee, solar]) {
        await library.setInSetlist(gig.id, tune, true);
      }

      // The closer up the list, the earlier in the set.
      await library.moveInSetlist(gig.id, 2, 0);
      expect(gig.tunes, [solar, autumn, cherokee]);
      await library.moveInSetlist(gig.id, 0, 2);
      expect(gig.tunes, [autumn, cherokee, solar]);
    });

    test('dragging past either end leaves the set playable', () async {
      final library = LibraryStore.inMemory();
      final gig = await library.addSetlist('Gig');
      for (final tune in [autumn, cherokee, solar]) {
        await library.setInSetlist(gig.id, tune, true);
      }

      // Nothing at that position to pick up.
      await library.moveInSetlist(gig.id, 7, 0);
      await library.moveInSetlist(gig.id, -1, 0);
      expect(gig.tunes, [autumn, cherokee, solar]);

      // Dropped past the bottom: it goes last. Past the top: it goes first.
      await library.moveInSetlist(gig.id, 0, 9);
      expect(gig.tunes, [cherokee, solar, autumn]);
      await library.moveInSetlist(gig.id, 2, -3);
      expect(gig.tunes, [autumn, cherokee, solar]);

      // Dropping a tune where it already was leaves it there.
      await library.moveInSetlist(gig.id, 1, 1);
      expect(gig.tunes, [autumn, cherokee, solar]);
      // No such setlist.
      await library.moveInSetlist('nowhere', 0, 1);
      expect(gig.tunes, [autumn, cherokee, solar]);
    });

    test('a tune knows which sets it is in', () async {
      final library = LibraryStore.inMemory();
      final friday = await library.addSetlist('Friday');
      final lesson = await library.addSetlist('Lesson');
      await library.setInSetlist(friday.id, autumn, true);
      await library.setInSetlist(lesson.id, autumn, true);
      await library.setInSetlist(lesson.id, cherokee, true);

      expect(
        [for (final list in library.setlistsWith(autumn)) list.name],
        ['Friday', 'Lesson'],
      );
      expect(
        [for (final list in library.setlistsWith(cherokee)) list.name],
        ['Lesson'],
      );
      expect(library.setlistsWith(solar), isEmpty);
    });

    test('setlists are still there next time the app opens', () async {
      final storage = MemoryStorage();
      final library = await LibraryStore.load(storage);
      final gig = await library.addSetlist('Friday');
      await library.setInSetlist(gig.id, autumn, true);
      await library.setInSetlist(gig.id, ownTune, true);

      final reopened = await LibraryStore.load(storage);
      final saved = reopened.setlists.single;
      expect(saved.id, gig.id);
      expect(saved.name, 'Friday');
      expect(saved.tunes, [autumn, ownTune]);
    });
  });

  group('a progression the player has deleted', () {
    test('goes out of the stars, the recents and every setlist', () async {
      final library = LibraryStore.inMemory();
      await library.setFavourite(ownTune, true);
      await library.setFavourite(autumn, true);
      await library.justPlayed(ownTune);
      await library.justPlayed(autumn);
      final friday = await library.addSetlist('Friday');
      final lesson = await library.addSetlist('Lesson');
      for (final list in [friday, lesson]) {
        await library.setInSetlist(list.id, ownTune, true);
        await library.setInSetlist(list.id, autumn, true);
      }

      await library.forget([ownTune]);

      expect(library.favourites, {autumn});
      expect([for (final entry in library.played) entry.tune], [autumn]);
      expect(friday.tunes, [autumn]);
      expect(lesson.tunes, [autumn]);
      expect(library.setlistsWith(ownTune), isEmpty);
    });

    test('forgetting nothing leaves everything alone', () async {
      final library = LibraryStore.inMemory();
      await library.setFavourite(autumn, true);
      await library.forget(const []);
      expect(library.favourites, {autumn});
    });
  });

  group('saving the whole shelf', () {
    test('it comes back exactly as it went in', () async {
      final library = LibraryStore.inMemory();
      final when = DateTime(2026, 9, 20, 11, 30);
      await library.setFavourite(autumn, true);
      await library.justPlayed(cherokee, at: when);
      final gig = await library.addSetlist('Friday');
      await library.setInSetlist(gig.id, autumn, true);
      final saved = library.toJson();

      final other = LibraryStore.inMemory();
      await other.replaceWith(saved);

      expect(other.favourites, {autumn});
      expect(other.played.single.tune, cherokee);
      expect(other.played.single.at, when);
      expect(other.setlists.single.name, 'Friday');
      expect(other.setlists.single.tunes, [autumn]);
      expect(other.toJson(), saved);
    });

    test('restoring over a full shelf replaces it rather than adding '
        'to it', () async {
      final library = LibraryStore.inMemory();
      await library.setFavourite(solar, true);
      await library.justPlayed(solar);
      await library.addSetlist('Old');

      await library.replaceWith(const {});

      expect(library.favourites, isEmpty);
      expect(library.played, isEmpty);
      expect(library.setlists, isEmpty);
    });
  });

  group('putting a list in order', () {
    test('keys go round the circle of fifths, not down the alphabet', () {
      final keys = ['A♭', 'E♭', 'C', 'B♭', 'F']
        ..sort((a, b) => keyRank(a).compareTo(keyRank(b)));
      expect(keys, ['C', 'F', 'B♭', 'E♭', 'A♭']);
      // Alphabetically A♭ would sit next to A; on the circle it's nowhere
      // near it.
      expect(keyRank('A♭'), lessThan(keyRank('A')));
    });

    test('the minor keys come after all the major ones', () {
      expect(keyRank('C minor'), greaterThan(keyRank('G')));
      expect(keyRank('G minor'), greaterThan(keyRank('C minor')));
      // Flats written either way round mean the same key.
      expect(keyRank('Bb'), keyRank('B♭'));
      expect(keyRank('Bb minor'), keyRank('B♭ minor'));
    });

    test('by title, ignoring capitals', () {
      final sorted = sortedTunes([
        _standard('Solar'),
        _standard('Autumn Leaves'),
        _standard('Cherokee'),
      ], TuneOrder.title);
      expect(
        [for (final tune in sorted) tune.title],
        ['Autumn Leaves', 'Cherokee', 'Solar'],
      );
    });

    test('by key: majors round the circle, then the minors', () {
      final sorted = sortedTunes([
        _standard('Autumn Leaves'), // G minor
        _standard('Blue Bossa'), // C minor
        _standard('Cherokee'), // B♭
        _standard('All of Me'), // C
      ], TuneOrder.key);
      expect(
        [for (final tune in sorted) tune.key],
        ['C', 'B♭', 'C minor', 'G minor'],
      );
    });

    test('by tempo, slowest first, and two at the same tempo fall back to '
        'the title', () {
      final sorted = sortedTunes([
        _standard('Cherokee'), // 200
        _standard('Blue Bossa'), // 140
        _standard('All of Me'), // 140
        _standard('Autumn Leaves'), // 130
      ], TuneOrder.tempo);
      expect(
        [for (final tune in sorted) tune.title],
        ['Autumn Leaves', 'All of Me', 'Blue Bossa', 'Cherokee'],
      );
    });

    test('by composer, with the tunes nobody is credited with last', () {
      final sorted = sortedTunes([
        _practice('Jazz blues in F'), // nobody
        _standard('Cherokee'), // Ray Noble
        _standard('Autumn Leaves'), // Joseph Kosma
      ], TuneOrder.composer);
      expect(
        [for (final tune in sorted) tune.title],
        ['Autumn Leaves', 'Cherokee', 'Jazz blues in F'],
      );
    });

    test('two tunes by the same writer go in title order', () {
      final sorted = sortedTunes([
        _standard('So What'),
        _standard('Solar'),
        _standard('Freddie Freeloader'),
      ], TuneOrder.composer);
      expect(
        [for (final tune in sorted) tune.title],
        ['Freddie Freeloader', 'So What', 'Solar'],
      );
    });

    test('sorting leaves the list it was handed alone', () {
      final tunes = [_standard('Solar'), _standard('All of Me')];
      sortedTunes(tunes, TuneOrder.title);
      expect([for (final tune in tunes) tune.title], ['Solar', 'All of Me']);
    });

    test('the player\'s own progressions go in the same orders', () {
      final own = [
        _mine(id: '1', title: 'Walk', key: 'G minor', tempo: 90),
        _mine(id: '2', title: 'amble', key: 'F', tempo: 200, composer: 'Zoe'),
        _mine(id: '3', title: 'Run', key: 'C', tempo: 90, composer: 'Ada'),
      ];
      List<String> titles(TuneOrder order) => [
        for (final p in sortedProgressions(own, order)) p.displayTitle,
      ];

      expect(titles(TuneOrder.title), ['amble', 'Run', 'Walk']);
      expect(titles(TuneOrder.key), ['Run', 'amble', 'Walk']);
      // Two at 90: the title breaks the tie.
      expect(titles(TuneOrder.tempo), ['Run', 'Walk', 'amble']);
      // Walk has nobody credited, so it goes last.
      expect(titles(TuneOrder.composer), ['Run', 'amble', 'Walk']);
    });

    test('an untitled progression sorts under the name it shows', () {
      final own = [
        _mine(id: '1', title: 'Zebra'),
        _mine(id: '2', title: '   '),
        _mine(id: '3', title: 'Apple'),
      ];
      expect(
        [for (final p in sortedProgressions(own, TuneOrder.title)) p.id],
        ['3', '2', '1'],
      );
    });
  });
}
