// Somebody's own colours on the chart.
//
// The maths here is the part worth testing hardest: a colour that cannot
// be read is worse than no colour, and a colour whose hue has been quietly
// changed is worse than that, because the hue is the whole point.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';
import 'package:play_along/settings/chord_colours.dart';

const paper = Color(0xFFF7F4EE);
const darkPaper = Color(0xFF1C1B19);

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
}

void main() {
  group('keeping the colours', () {
    test('an empty map is the usual case', () {
      const colours = ChordColours();
      expect(colours.isEmpty, isTrue);
      expect(colours.of(2), isNull);
    });

    test('a colour is set, changed and cleared one root at a time', () {
      var colours = const ChordColours().set(2, const Color(0xFF3366CC));
      expect(colours.of(2), const Color(0xFF3366CC));
      colours = colours.set(7, const Color(0xFFCC3366));
      expect(colours.byPitchClass, hasLength(2));

      colours = colours.set(2, null);
      expect(colours.of(2), isNull);
      // And the other is untouched, which is the whole of the behaviour.
      expect(colours.of(7), const Color(0xFFCC3366));
    });

    test('a root above B is the same root again', () {
      // A chord's root comes through as a MIDI pitch class, but nothing
      // should break if it arrives unwrapped.
      final colours = const ChordColours().set(2, const Color(0xFF3366CC));
      expect(colours.of(14), const Color(0xFF3366CC));
    });

    test('they survive being written down and read back', () {
      final colours = const ChordColours()
          .set(0, const Color(0xFFAA1122))
          .set(11, const Color(0xFF11AA22));
      final read = ChordColours.fromJson(colours.toJson());
      expect(read.of(0), const Color(0xFFAA1122));
      expect(read.of(11), const Color(0xFF11AA22));
      expect(read.byPitchClass, hasLength(2));
    });

    test('nonsense in the saved file is dropped rather than thrown', () {
      // Somebody's whole mapping should not be lost to one bad entry.
      final read = ChordColours.fromJson({
        '0': 0xFFAA1122,
        'twelve': 0xFF000000,
        '99': 0xFF000000,
        '5': 'not a colour',
      });
      expect(read.byPitchClass.keys, [0]);
    });
  });

  group('reading it on the paper', () {
    test('a colour that already reads is left exactly alone', () {
      const deepBlue = Color(0xFF1A3FA0);
      expect(readableOn(deepBlue, paper), deepBlue);
    });

    test('a pale one is darkened until it can be read on paper', () {
      const paleYellow = Color(0xFFFFF4B0);
      final fixed = readableOn(paleYellow, paper);
      expect(contrast(fixed, paper), greaterThanOrEqualTo(3));
      // And it is still yellow: the hue is the thing somebody sees.
      expect(
        HSLColor.fromColor(fixed).hue,
        closeTo(HSLColor.fromColor(paleYellow).hue, 1),
      );
    });

    test('a dark one is lifted on the dark theme, hue intact', () {
      const deepPurple = Color(0xFF2A0A4A);
      final fixed = readableOn(deepPurple, darkPaper);
      expect(contrast(fixed, darkPaper), greaterThanOrEqualTo(3));
      expect(
        HSLColor.fromColor(fixed).hue,
        closeTo(HSLColor.fromColor(deepPurple).hue, 1),
      );
    });

    test('the same colour reads on both papers, moved only where needed', () {
      // The case this exists for: one colour, two backgrounds, and it has
      // to be legible on each without becoming a different colour.
      const midTeal = Color(0xFF0E7C7B);
      for (final background in [paper, darkPaper]) {
        final fixed = readableOn(midTeal, background);
        expect(
          contrast(fixed, background),
          greaterThanOrEqualTo(3),
          reason: 'unreadable on $background',
        );
        expect(
          HSLColor.fromColor(fixed).hue,
          closeTo(HSLColor.fromColor(midTeal).hue, 1),
        );
      }
    });

    test(
      'a grey that no lightness can save goes to ink rather than vanish',
      () {
        // Nothing in that hue reads against a mid grey, and invisible is
        // the one answer that is no use at all.
        const midGrey = Color(0xFF808080);
        final fixed = readableOn(midGrey, const Color(0xFF7F7F7F));
        expect(contrast(fixed, const Color(0xFF7F7F7F)), greaterThan(3));
      },
    );
  });

  group('the setting', () {
    test('is off for everyone who has not set one', () {
      final settings = AppSettings.inMemory();
      expect(settings.chordColours.isEmpty, isTrue);
      expect(settings.chordColourFor(0), isNull);
    });

    test('gives the colour once it is set', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(2, const Color(0xFF3366CC));
      expect(settings.chordColourFor(2), const Color(0xFF3366CC));
    });

    test(
      'turning them off keeps them, so nothing has to be typed twice',
      () async {
        final settings = AppSettings.inMemory();
        await settings.setChordColour(2, const Color(0xFF3366CC));
        await settings.setColourChords(false);
        expect(settings.chordColourFor(2), isNull);
        expect(settings.chordColours.of(2), const Color(0xFF3366CC));

        await settings.setColourChords(true);
        expect(settings.chordColourFor(2), const Color(0xFF3366CC));
      },
    );

    test('clearing takes the lot', () async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(2, const Color(0xFF3366CC));
      await settings.setChordColour(7, const Color(0xFFCC3366));
      await settings.clearChordColours();
      expect(settings.chordColours.isEmpty, isTrue);
    });
  });

  group('on the chart', () {
    /// The colour the chart draws a chord's lettering in.
    Future<Color> inkOf(
      WidgetTester tester,
      AppSettings settings,
      String chord,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 852) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          home: PracticeScreen(
            tune: standards.firstWhere((t) => t.title == 'Blue Bossa'),
            player: PracticePlayer(),
            settings: settings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(
        find
            .byWidgetPredicate(
              (w) => w is Text && w.data != null && w.data!.startsWith(chord),
            )
            .first,
      );
      return text.style!.color!;
    }

    testWidgets('a chord with no colour set is drawn in the usual ink', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      final ink = await inkOf(tester, settings, 'C');
      expect(ink, appTheme(Brightness.light).colorScheme.onSurface);
    });

    testWidgets('and in theirs once they have set one', (tester) async {
      // Blue Bossa starts on Cm7, so C is the one to colour.
      final settings = AppSettings.inMemory();
      await settings.setChordColour(0, const Color(0xFF1A3FA0));
      final ink = await inkOf(tester, settings, 'C');
      expect(ink, const Color(0xFF1A3FA0));
    });

    testWidgets('and back to the usual ink when they are turned off', (
      tester,
    ) async {
      final settings = AppSettings.inMemory();
      await settings.setChordColour(0, const Color(0xFF1A3FA0));
      await settings.setColourChords(false);
      final ink = await inkOf(tester, settings, 'C');
      expect(ink, appTheme(Brightness.light).colorScheme.onSurface);
    });
  });
}
