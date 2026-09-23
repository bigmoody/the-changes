// Number patterns: the same shape coming out different over every chord.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord.dart';
import 'package:play_along/music/number_patterns.dart';
import 'package:play_along/music/enclosures.dart';
import 'package:play_along/screens/number_patterns_screen.dart';
import 'package:play_along/screens/learn_page.dart';
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

List<String> _names(List<int> degrees, String chord) => [
  for (final note in patternOn(degrees, Chord.parse(chord))) note.name,
];

void main() {
  group('the numbers', () {
    test('1-2-3-5 over a ii–V–I is three different sets of notes', () {
      // The whole idea: the hand does the same thing, the notes move.
      expect(_names([1, 2, 3, 5], 'Dm7'), ['D', 'E', 'F', 'A']);
      expect(_names([1, 2, 3, 5], 'G7'), ['G', 'A', 'B', 'D']);
      expect(_names([1, 2, 3, 5], 'C^7'), ['C', 'D', 'E', 'G']);
    });

    test('a 3 is the ♭3 over a minor chord, with no special case', () {
      // The numbers index the chord's own scale, so this falls out.
      expect(_names([1, 3, 5, 7], 'Dm7'), ['D', 'F', 'A', 'C']);
      expect(_names([1, 3, 5, 7], 'D7'), ['D', 'F♯', 'A', 'C']);
      expect(_names([1, 3, 5, 7], 'D^7'), ['D', 'F♯', 'A', 'C♯']);
    });

    test('a 9 is the 2nd up an octave, not the 2nd again', () {
      final run = patternOn([3, 5, 7, 9], Chord.parse('Dm7'));
      expect([for (final n in run) n.name], ['F', 'A', 'C', 'E']);
      // And it really is up there: the last note is above the first.
      expect(run.last.pitch - run.first.pitch, 11);
    });

    test('a 0 is the 7th below the root, not above it', () {
      // Dart truncates towards zero, so this is the one that goes wrong
      // if the octave is worked out by dividing.
      final run = patternOn([3, 2, 1, 0], Chord.parse('Dm7'));
      expect([for (final n in run) n.name], ['F', 'E', 'D', 'C']);
      expect(run.last.pitch, lessThan(run[2].pitch), reason: 'below the D');
      expect(run[2].pitch - run.last.pitch, 2);
    });

    test('the octave turns over when the letters pass B', () {
      // A B C E: the C and the E are in the octave above the A.
      final run = patternOn([1, 2, 3, 5], Chord.parse('Am7'));
      expect([for (final n in run) n.name], ['A', 'B', 'C', 'E']);
      expect(run[2].octave, run[1].octave + 1);
      for (var i = 1; i < run.length; i++) {
        expect(run[i].pitch, greaterThan(run[i - 1].pitch), reason: 'climbs');
      }
    });

    test('every pattern works over every chord in every progression', () {
      // A blank bar in the middle of the exercise would be worse than the
      // exercise not being there.
      for (final changes in patternChanges) {
        for (final (step, quality) in changes.chords) {
          for (final root in ['C', 'F', 'B♭', 'E♭', 'G', 'D', 'A']) {
            final at = (pitchClassOf(parseNoteName(root)!) + step) % 12;
            final name = [
              'C',
              'D♭',
              'D',
              'E♭',
              'E',
              'F',
              'G♭',
              'G',
              'A♭',
              'A',
              'B♭',
              'B',
            ][at];
            final chord = Chord.parse('$name$quality');
            for (final pattern in numberPatterns) {
              expect(
                fits(pattern.degrees, chord),
                isTrue,
                reason: '${pattern.written} over ${chord.display}',
              );
            }
          }
        }
      }
    });
  });

  group('the patterns themselves', () {
    test('each is four numbers and no two are the same pattern', () {
      final seen = <String>{};
      for (final pattern in numberPatterns) {
        expect(pattern.degrees, hasLength(4), reason: pattern.name);
        expect(pattern.about, isNotEmpty, reason: pattern.name);
        expect(seen.add(pattern.written), isTrue, reason: pattern.written);
      }
    });

    test('there are ascending ones and descending ones', () {
      bool climbs(List<int> d) => d.last > d.first;
      expect(numberPatterns.any((p) => climbs(p.degrees)), isTrue);
      expect(numberPatterns.any((p) => !climbs(p.degrees)), isTrue);
    });

    test('written out, it reads as the numbers you would say', () {
      expect(numberPatterns.first.written, '1 2 3 5');
    });
  });

  group('chords the book had no scale for', () {
    test('a 6 chord takes the major scale rather than nothing', () {
      // It used to come back empty, which left the turnaround with a
      // blank first bar, and quietly broke the enclosures too.
      expect(scaleFor(Chord.parse('C6')), isNotEmpty);
      expect(_names([1, 2, 3, 5], 'C6'), ['C', 'D', 'E', 'G']);
    });

    test('a plain triad and a minor 6 too', () {
      expect(scaleFor(Chord.parse('C')), isNotEmpty);
      expect(scaleFor(Chord.parse('Cm')), isNotEmpty);
      expect(scaleFor(Chord.parse('Cm6')), contains('A'));
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
          home: NumberPatternsScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Picks [value] from a chip strip, dragging it along if the chip is
    /// off the side: with seven patterns and four progressions, some of
    /// them always are.
    Future<void> pick(
      WidgetTester tester,
      String value,
      String inSameRow,
    ) async {
      final chip = find.byKey(ValueKey('pick-$value'));
      await tester.dragUntilVisible(
        chip,
        find.byKey(ValueKey('pick-$inSameRow')),
        const Offset(-120, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('it writes the pattern over each chord of the changes', (
      tester,
    ) async {
      await open(tester);
      for (final chord in ['Dm7', 'G7', 'CΔ7']) {
        expect(
          find.byKey(ValueKey('over-$chord')),
          findsOneWidget,
          reason: chord,
        );
      }
      expect(find.text('no scale'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the key moves the chords', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('pick-F')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('over-Gm7')), findsOneWidget);
      expect(find.byKey(const ValueKey('over-C7')), findsOneWidget);
    });

    testWidgets('changing the progression changes the chords', (tester) async {
      await open(tester);
      await pick(tester, 'Turnaround', 'ii–V–I');
      expect(find.byKey(const ValueKey('over-C6')), findsOneWidget);
      expect(find.byKey(const ValueKey('over-Am7')), findsOneWidget);
      // The 6 chord is the one that used to come out blank.
      expect(find.text('no scale'), findsNothing);
    });

    testWidgets('changing the pattern says what it is for', (tester) async {
      await open(tester);
      await pick(tester, '7 5 3 1', '1 2 3 5');
      expect(find.textContaining('Arpeggio Down'), findsOneWidget);
    });

    testWidgets('playing without a sample bank is harmless', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('play-through')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('every chord can be played on its own', (tester) async {
      // For the bar you keep fumbling, rather than listening to the whole
      // progression to hear one of them.
      await open(tester);
      for (final chord in ['Dm7', 'G7', 'CΔ7']) {
        final button = find.byKey(ValueKey('play-$chord'));
        expect(button, findsOneWidget, reason: chord);
        // The staves sit low, under the reading; the controls are what
        // is pinned, not these.
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('hearing it is on the screen, not hidden in the bar', (
      tester,
    ) async {
      // It was an unlabelled icon in the app bar, which is where things
      // go to not be found.
      await open(tester);
      // On screen the moment it opens, without scrolling: they are
      // pinned under the reading rather than sitting after it.
      expect(find.text('Play It Through'), findsOneWidget);
      expect(find.text('Play Along'), findsOneWidget);
      expect(find.text('100 BPM'), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const ValueKey('loop-band'))).dy,
        lessThan(852),
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.play_circle_outline),
        ),
        findsNothing,
      );
    });

    testWidgets('the band loops, and stops, and only one at a time', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('loop-band')));
      await tester.pump();
      expect(find.text('Stop'), findsOneWidget);
      expect(find.textContaining('band is going round'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('loop-band')));
      await tester.pump();
      expect(find.text('Play Along'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tempo moves and holds its bounds', (tester) async {
      await open(tester);
      expect(find.text('100 BPM'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('faster')));
      await tester.pumpAndSettle();
      expect(find.text('105 BPM'), findsOneWidget);
      for (var i = 0; i < 40; i++) {
        await tester.tap(find.byKey(const ValueKey('slower')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('40 BPM'), findsOneWidget, reason: 'as slow as it goes');
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
      final card = find.byKey(const ValueKey('learn-number-patterns'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(NumberPatternsScreen), findsOneWidget);
    });
  });
}
