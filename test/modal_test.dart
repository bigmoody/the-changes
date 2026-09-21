// Modal: whether "one chord for a long time" is measured off the charts
// rather than asserted, and whether the screen asks the question the
// chart actually leaves open.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/modal.dart';
import 'package:play_along/music/scales.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/modal_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

class _FakePlayer extends PracticePlayer {
  @override
  Future<void> start(
    BackingRequest request, {
    String? alongside,
    Duration leadIn = Duration.zero,
    int pickUpBeats = 0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void setVolume(Instrument instrument, double volume) {}
}

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

Mode _mode(String name) => modes.firstWhere((m) => m.name == name);

void main() {
  group('how long a chord lasts', () {
    test('it counts an unbroken run of one chord, in bars', () {
      expect(longestStay(_standard('So What')), 16);
      expect(longestStay(_standard('Impressions')), 16);
    });

    test('a bebop tune barely holds one at all', () {
      // The number that makes the rest of the screen worth reading.
      for (final title in ['Anthropology', 'Giant Steps', "Now's the Time"]) {
        expect(longestStay(_standard(title)), lessThan(4), reason: title);
        expect(isModal(_standard(title)), isFalse, reason: title);
      }
    });

    test('two chords in a bar breaks the run', () {
      // The question is how long you are left alone with one sound, and
      // a bar that moves is not leaving you alone.
      final broken = Tune.fromChart(
        title: 'Broken',
        key: 'D',
        defaultTempo: 120,
        chart: '| Dm7 | Dm7 | Dm7 G7 | Dm7 | Dm7 | Dm7 | Dm7 | Dm7 |',
      );
      expect(longestStay(broken), 5, reason: 'the run restarts after bar 3');
    });

    test('a tune that never repeats a chord stays at one', () {
      final moving = Tune.fromChart(
        title: 'Moving',
        key: 'C',
        defaultTempo: 120,
        chart: '| CΔ7 | Dm7 | Em7 | FΔ7 |',
      );
      expect(longestStay(moving), 1);
    });

    test('modal tunes come back longest first', () {
      final found = modalTunes(standards);
      expect(found, isNotEmpty);
      for (var i = 1; i < found.length; i++) {
        expect(
          longestStay(found[i]),
          lessThanOrEqualTo(longestStay(found[i - 1])),
          reason: '${found[i].title} after ${found[i - 1].title}',
        );
      }
      expect(longestStay(found.first), greaterThanOrEqualTo(16));
    });

    test('everything found really does hold a chord that long', () {
      for (final tune in modalTunes(standards)) {
        expect(
          longestStay(tune),
          greaterThanOrEqualTo(modalStay),
          reason: tune.title,
        );
      }
    });

    test('the famous ones are in there', () {
      final titles = {for (final t in modalTunes(standards)) t.title};
      for (final want in ['So What', 'Impressions', 'Milestones']) {
        expect(titles, contains(want));
      }
    });
  });

  group('the question the chart leaves open', () {
    test('one chord symbol is several modes', () {
      final written = modesWritten('m7');
      expect(written.length, greaterThan(1));
      expect(written.map((m) => m.name), containsAll(['Dorian', 'Aeolian']));
      // All of them really are written the same way, which is the point.
      for (final mode in written) {
        expect(mode.chord, 'm7', reason: mode.name);
      }
    });

    test('Dorian and Aeolian differ by exactly one note', () {
      final apart = differenceBetween(_mode('Dorian'), _mode('Aeolian'));
      expect(apart, ['6'], reason: 'the natural 6th, and nothing else');
    });

    test('and that note is the one the app marks as the mode\'s own', () {
      // The screen paints a note red and says it is what makes the mode
      // itself. That has to be the note that actually differs.
      expect(colourOf(_mode('Dorian')), contains('6'));
      expect(colourOf(_mode('Aeolian')), contains('b6'));
    });

    test('spelled out, it is one letter in seven', () {
      expect(_mode('Dorian').notesFrom('D'), [
        'D',
        'E',
        'F',
        'G',
        'A',
        'B',
        'C',
      ]);
      expect(_mode('Aeolian').notesFrom('D'), [
        'D',
        'E',
        'F',
        'G',
        'A',
        'B♭',
        'C',
      ]);
    });

    test('a degree is written the way it is spoken', () {
      // "The b6 in red" is not a sentence anybody would say out loud.
      expect(degreeLabel('6'), '6th');
      expect(degreeLabel('b6'), '♭6th');
      expect(degreeLabel('b2'), '♭2nd');
      expect(degreeLabel('#4'), '♯4th');
      expect(degreeLabel('1'), '1st');
      expect(degreeLabel('3'), '3rd');
    });

    test('every mode offered has something that marks it out', () {
      for (final mode in modesWritten('m7')) {
        expect(colourOf(mode), isNotEmpty, reason: mode.name);
        expect(mode.description.length, greaterThan(40), reason: mode.name);
      }
    });
  });

  group('what carries it instead', () {
    test('there are ideas, and each says what it is for', () {
      expect(modalIdeas.length, greaterThan(2));
      for (final idea in modalIdeas) {
        expect(idea.name, isNotEmpty);
        expect(idea.about.length, greaterThan(60), reason: idea.name);
      }
    });

    test('leaving space is one of them, because it is the hard one', () {
      expect(
        modalIdeas.map((i) => i.name.toLowerCase()).join(' '),
        contains('leaving it alone'),
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
          home: ModalScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the comparison is on screen when it opens', (tester) async {
      // Until you have seen sixteen bars against two, the rest of the
      // page sounds like fuss.
      await open(tester);
      final first = find.byKey(const ValueKey('stay-So What'));
      expect(first, findsOneWidget);
      expect(tester.getRect(first).bottom, lessThan(852));
      expect(find.byKey(const ValueKey('stay-Anthropology')), findsOneWidget);
    });

    testWidgets('it opens on Dorian, which is the modal minor', (tester) async {
      await open(tester);
      final notes = find.byKey(const ValueKey('mode-notes'));
      await tester.scrollUntilVisible(notes, 100);
      expect(find.text('B'), findsWidgets, reason: 'the natural 6th');
      expect(find.textContaining('what makes it Dorian'), findsOneWidget);
    });

    testWidgets('changing the mode changes the note and what it says', (
      tester,
    ) async {
      await open(tester);
      final aeolian = find.byKey(const ValueKey('pick-Aeolian'));
      await tester.scrollUntilVisible(aeolian, 100);
      await tester.tap(aeolian);
      await tester.pumpAndSettle();
      expect(find.text('B♭'), findsWidgets, reason: 'the flat 6th now');
      expect(find.textContaining('what makes it Aeolian'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hearing it plays over the chord, and says so', (tester) async {
      await open(tester);
      final button = find.byKey(const ValueKey('play-mode'));
      await tester.scrollUntilVisible(button, 100);
      expect(find.text('Hear It Over Dm7'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('it counts the tunes rather than claiming a number', (
      tester,
    ) async {
      await open(tester);
      final count = modalTunes(standards).length;
      final line = find.byKey(const ValueKey('modal-count'));
      await tester.scrollUntilVisible(line, 200);
      expect(
        find.textContaining('$count tunes in this app leave you'),
        findsOneWidget,
      );
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
      final card = find.byKey(const ValueKey('learn-modal'));
      await tester.scrollUntilVisible(card, 100);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(ModalScreen), findsOneWidget);
    });
  });
}
