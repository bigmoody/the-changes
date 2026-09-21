// The line written under each chord on the chart, to learn by.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/chord_aids.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

/// Every line, bar by bar, flattened into reading order.
List<String?> _lines(Tune tune, ChordAid aid) {
  final aids = aidsFor(tune, aid);
  return [for (var bar = 0; bar < tune.barCount; bar++) ...?aids[bar]];
}

void main() {
  group('what goes under the chords', () {
    test('nothing at all, unless it has been asked for', () {
      expect(aidsFor(_standard('Blue Bossa'), ChordAid.off), isEmpty);
    });

    test('the numbers read against the tune\'s own key', () {
      // Blue Bossa is in C minor: Cm6 is the i chord, Dø7 G7♭9 the ii–V.
      final roman = _lines(_standard('Blue Bossa'), ChordAid.roman);
      expect(roman.first, startsWith('i'));
      expect(roman, contains('V7♭9'));
    });

    test('and Nashville says the same thing in figures', () {
      final nashville = _lines(_standard('Blue Bossa'), ChordAid.nashville);
      expect(nashville.first, startsWith('1'));
      expect(
        nashville.every((line) => line != null && line.isNotEmpty),
        isTrue,
      );
    });

    test('the guide tones are two note names, in line order', () {
      final tones = _lines(_standard('Blue Bossa'), ChordAid.guideTones);
      for (final line in tones) {
        expect(line, isNotNull);
        expect(line!.split(' '), hasLength(2), reason: line);
      }
    });

    test('a note that is held reads the same twice running', () {
      // Autumn Leaves' Cm7 F7: the 7th of Cm7 is B♭, which is the 3rd of
      // F7; the line stands still while the chord changes under it.
      final tones = _lines(_standard('Autumn Leaves'), ChordAid.guideTones);
      final first = tones[0]!.split(' ');
      final second = tones[1]!.split(' ');
      expect(
        first.toSet().intersection(second.toSet()),
        isNotEmpty,
        reason: '$first then $second',
      );
    });

    test('nothing is ever marked with a dot or a tie', () {
      // Those read as musical marks they aren't.
      for (final aid in ChordAid.values) {
        for (final tune in standards.take(40)) {
          for (final line in _lines(tune, aid)) {
            expect(line ?? '', isNot(contains('·')), reason: tune.title);
            expect(line ?? '', isNot(contains('‿')), reason: tune.title);
          }
        }
      }
    });

    test('every tune in the book has a line for every chord', () {
      for (final aid in [
        ChordAid.roman,
        ChordAid.nashville,
        ChordAid.guideTones,
      ]) {
        for (final tune in [...standards, ...practiceProgressions]) {
          final lines = _lines(tune, aid);
          expect(
            lines,
            hasLength(tune.slots.length),
            reason: '${tune.title}, $aid',
          );
          for (final line in lines) {
            expect(line, isNotNull, reason: '${tune.title}, $aid');
            expect(line, isNotEmpty, reason: '${tune.title}, $aid');
          }
        }
      }
    });
  });

  group('on the chart', () {
    Future<void> open(WidgetTester tester, ChordAid aid) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final settings = AppSettings.inMemory();
      await settings.setChordAid(aid);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(aid),
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: _standard('Blue Bossa'),
            player: PracticePlayer(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('what the red letters are is said on the chart', (
      tester,
    ) async {
      // The complaint this guards against: you turn it on once, forget,
      // and are left reading "C F" under a Dm7 with nothing on screen
      // saying what that is.
      await open(tester, ChordAid.off);
      expect(find.byKey(const ValueKey('chord-aid')), findsNothing);

      await open(tester, ChordAid.guideTones);
      final chip = find.byKey(const ValueKey('chord-aid'));
      expect(chip, findsOneWidget);
      expect(find.text('3rd & 7th'), findsOneWidget);
      // And the whole of it is readable, not just the shorthand.
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: chip, matching: find.byType(Tooltip)),
            )
            .message,
        contains('guide tones'),
      );
    });

    testWidgets('the chip leads to where it is turned off', (tester) async {
      await open(tester, ChordAid.guideTones);
      await tester.tap(find.byKey(const ValueKey('chord-aid')));
      await tester.pumpAndSettle();
      expect(find.text('Under the Chords'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('aid-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet-done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chord-aid')), findsNothing);
    });

    testWidgets('off, the chart is only chords', (tester) async {
      await open(tester, ChordAid.off);
      expect(find.text('i6'), findsNothing);
      expect(find.text('iv7'), findsNothing);
    });

    testWidgets('on, the numerals are under the chords', (tester) async {
      await open(tester, ChordAid.roman);
      // Blue Bossa's iv chord, written under the Fm7 in bars 3 and 4.
      expect(find.text('iv7'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the whole tune still fits on one screen', (tester) async {
      for (final aid in ChordAid.values) {
        await open(tester, aid);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('chart')),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
          reason: '$aid: the chart should not need scrolling',
        );
      }
    });
  });
}
