// Upper structures: whether the triad really makes the chord it is said
// to make.
//
// Every claim here is checkable. An A♭ triad over C7 either contains the
// ♯9 and the ♭13 or it does not, and the name written beside it either
// matches the notes or it is wrong. So the tests check the arithmetic
// rather than that something plausible came back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/guitar_voicing.dart';
import 'package:play_along/music/tritone_subs.dart' show isDominant, subFor;
import 'package:play_along/music/upper_structures.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/upper_structures_screen.dart';
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

Chord get _c7 => Chord.parse('C7');
UpperStructure _at(String roman) =>
    upperStructures.firstWhere((s) => s.roman == roman);

void main() {
  group('the triads', () {
    test('every one of them is a plain major triad', () {
      // The whole point: three notes anybody can already play. If one of
      // these were a diminished or an altered shape it would defeat it.
      for (final structure in upperStructures) {
        final triad = triadOver(_c7, structure);
        expect(triad, hasLength(3));
        expect(triad[1] - triad[0], 4, reason: '${structure.roman} major 3rd');
        expect(triad[2] - triad[1], 3, reason: '${structure.roman} minor 3rd');
      }
    });

    test('they sit above the chord, not under it', () {
      for (final structure in upperStructures) {
        expect(structure.above, inInclusiveRange(1, 11));
      }
    });

    test('the one everybody knows is the flat III', () {
      // E♭ over C7 is the ♯9 chord, which is the one people play
      // without being told it has a name.
      expect(triadName(_c7, _at('♭III')), 'E♭');
      expect(symbolOver(_c7, _at('♭III')), 'C7♯9');
      expect(tensionsOf(_c7, _at('♭III')), ['♯9', '5th', '♭7']);
    });

    test('the sharp IV is the tritone sub, which is worth noticing', () {
      // G♭ over C7. The screen says so, and the app works out tritone
      // subs elsewhere, so the two had better agree.
      final triad = triadName(_c7, _at('♯IV'));
      expect(isDominant(_c7), isTrue);
      expect(subFor(_c7)!.rootName, triad);
    });

    test('the name and the notes cannot come apart', () {
      // symbol is written down; the tensions are worked out. Every
      // alteration in the name has to be a note that is actually there.
      for (final structure in upperStructures) {
        for (final symbol in ['C7', 'F7', 'G7', 'B♭7', 'E7']) {
          final chord = Chord.parse(symbol);
          final added = additionsOf(chord, structure);
          // Only the alterations, both ways. A natural 9 is not written
          // on a 13 chord because a 13 implies it, which is a naming
          // convention rather than a note going missing.
          const altered = ['♭9', '♯9', '♯11', '♭13'];
          for (final tension in added.where(altered.contains)) {
            expect(
              structure.symbol,
              contains(tension),
              reason: '${structure.roman} on $symbol adds $tension',
            );
          }
          for (final part in altered) {
            if (structure.symbol.contains(part)) {
              expect(added, contains(part), reason: structure.roman);
            }
          }
        }
      }
    });

    test('a 13 chord really has the 13 in it', () {
      for (final structure in upperStructures) {
        if (!structure.symbol.startsWith('13')) continue;
        expect(
          additionsOf(_c7, structure),
          contains('13'),
          reason: structure.roman,
        );
      }
    });

    test('it works the same over any dominant', () {
      // A fact about triads over dominants, not a fact about C.
      for (final symbol in ['C7', 'F7', 'G7', 'E♭7', 'A7']) {
        final chord = Chord.parse(symbol);
        for (final structure in upperStructures) {
          expect(
            tensionsOf(chord, structure),
            tensionsOf(_c7, structure),
            reason: '${structure.roman} on $symbol',
          );
        }
      }
    });

    test('none of them adds a plain 11, which would fight the 3rd', () {
      // The reason the ♭II triad is not on the list.
      for (final structure in upperStructures) {
        expect(
          additionsOf(_c7, structure),
          isNot(contains('11')),
          reason: structure.roman,
        );
      }
    });

    test('each one says what it is for', () {
      for (final structure in upperStructures) {
        expect(structure.roman, isNotEmpty);
        expect(
          structure.about.length,
          greaterThan(80),
          reason: structure.roman,
        );
      }
    });
  });

  group('naming the notes', () {
    test('an altered dominant is spelled with 9s, 11s and 13s', () {
      // Never a ♭5 or a ♯5: that is how the chord is written and half
      // the point is being able to read it back off the page.
      expect(tensionNames[6], '♯11');
      expect(tensionNames[8], '♭13');
      expect(tensionNames.values, isNot(contains('♭5')));
      expect(tensionNames.values, isNot(contains('♯5')));
    });

    test('the triad is named as a player would think it', () {
      expect(triadName(_c7, _at('♭VI')), 'A♭');
      expect(triadName(Chord.parse('G7'), _at('♯IV')), 'D♭');
    });
  });

  group('on the guitar', () {
    test('every structure has all three inversions on the top strings', () {
      // A guitarist plays whichever one is nearest, so all three have to
      // be there or the point of showing them is lost.
      for (final structure in upperStructures) {
        for (final symbol in ['C7', 'F7', 'G7']) {
          final triad = Chord.parse(triadName(Chord.parse(symbol), structure));
          final shapes = triadInversions(triad);
          expect(shapes, hasLength(3), reason: '${structure.roman} on $symbol');
          for (final (i, shape) in shapes.indexed) {
            expect(
              shape,
              isNotNull,
              reason: '${structure.roman} on $symbol, ${inversionNames[i]}',
            );
          }
        }
      }
    });

    test('they are on the top three strings and nowhere else', () {
      final shapes = triadInversions(Chord.parse('D'));
      for (final shape in shapes) {
        final played = [
          for (final (i, fret) in shape!.frets.indexed)
            if (fret != null) i,
        ];
        expect(played, [3, 4, 5], reason: 'G, B and the top E');
      }
    });

    test('each one really is that inversion', () {
      // Root position has the root at the bottom, the first has the 3rd
      // and the second has the 5th. If they were all the same shape in
      // three places there would be nothing to choose between them.
      final triad = Chord.parse('D');
      final shapes = triadInversions(triad);
      for (final (i, wanted) in [0, 4, 7].indexed) {
        expect(
          shapes[i]!.pitches.first % 12,
          (triad.root + wanted) % 12,
          reason: inversionNames[i],
        );
      }
    });

    test('all three sound the same three notes', () {
      final triad = Chord.parse('A♭');
      final wanted = {
        for (final shape in triadInversions(triad))
          ...shape!.pitches.map((p) => p % 12),
      };
      expect(wanted, hasLength(3));
      expect(wanted, {
        triad.root % 12,
        (triad.root + 4) % 12,
        (triad.root + 7) % 12,
      });
    });

    test('a hand can reach every one of them', () {
      for (final name in ['C', 'D', 'E♭', 'G♭', 'A', 'A♭', 'B']) {
        for (final shape in triadInversions(Chord.parse(name))) {
          final fretted = shape!.frets.whereType<int>().where((f) => f > 0);
          if (fretted.isEmpty) continue;
          expect(
            fretted.reduce(GuitarVoicing.max) -
                fretted.reduce(GuitarVoicing.min),
            lessThan(5),
            reason: name,
          );
        }
      }
    });

    test('asking for a string set that cannot hold it gets nothing', () {
      expect(
        shapeForPitches([60, 64, 67], onStrings: const [4, 5]),
        isNull,
        reason: 'three notes, two strings',
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
          home: UpperStructuresScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Brings something further down the page into view. The page is
    /// long enough now that a ListView has not built the bottom of it.
    Future<void> scrollTo(WidgetTester tester, Finder target) =>
        tester.scrollUntilVisible(
          target,
          140,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('upper-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        );

    testWidgets('the triad is the biggest thing on it, and on screen', (
      tester,
    ) async {
      // It is the thing to remember; the alterations are the footnote.
      await open(tester);
      final triad = find.byKey(const ValueKey('the-triad'));
      expect(triad, findsOneWidget);
      expect(tester.getRect(triad).bottom, lessThan(852));
      expect(find.text('D over C7'), findsOneWidget);
      expect(find.text('is C13♯11'), findsOneWidget);
    });

    testWidgets('it says what each note turns into', (tester) async {
      await open(tester);
      expect(find.text('the 9 of C7'), findsOneWidget);
      expect(find.text('the ♯11 of C7'), findsOneWidget);
      expect(find.text('the 13 of C7'), findsOneWidget);
    });

    testWidgets('picking another triad redraws the lot', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pick-♭VI')));
      await tester.pumpAndSettle();
      expect(find.text('A♭ over C7'), findsOneWidget);
      expect(find.text('is C7♯9♭13'), findsOneWidget);
      await scrollTo(tester, find.byKey(const ValueKey('about-structure')));
      expect(find.textContaining('The darkest of them'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both the plain chord and the loaded one can be played', (
      tester,
    ) async {
      await open(tester);
      await scrollTo(tester, find.byKey(const ValueKey('play-plain')));
      await tester.tap(find.byKey(const ValueKey('play-plain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-structure')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the dominant moves the triad with it', (
      tester,
    ) async {
      await open(tester);
      final chip = find.byKey(const ValueKey('pick-G7'));
      await tester.scrollUntilVisible(
        chip,
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('upper-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip, warnIfMissed: false);
      await tester.pumpAndSettle();
      // Back up to the top: the triad is off the screen by now, and a
      // ListView has thrown away what is not on it.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('the-triad')),
        -120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('upper-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('A over G7'), findsOneWidget);
      expect(find.text('is G13♯11'), findsOneWidget);
    });

    testWidgets('the three inversions are drawn for the guitar', (
      tester,
    ) async {
      await open(tester);
      final guitar = find.byKey(const ValueKey('on-the-guitar'));
      await scrollTo(tester, guitar);
      expect(guitar, findsOneWidget);
      for (final name in inversionNames) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.byKey(const ValueKey('inversion-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('inversion-2')), findsOneWidget);
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
      final card = find.byKey(const ValueKey('learn-upper-structures'));
      await tester.scrollUntilVisible(
        card,
        100,
        // The page's own list, not the search box's text field,
        // which is a scrollable too.
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(UpperStructuresScreen), findsOneWidget);
    });
  });
}
