// Rhythm changes: whether the form is recognised from the chart rather
// than from somebody remembering to label it, and whether the screen
// says what the library actually holds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/backing_synth.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/rhythm_changes.dart';
import 'package:play_along/music/tritone_subs.dart' show isDominant;
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/learn_page.dart';
import 'package:play_along/screens/rhythm_changes_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

import 'support/fake_player.dart';

class _FakePlayer extends FakePlayer {
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

Tune _standard(String title) =>
    standards.firstWhere((tune) => tune.title == title);

void main() {
  group('finding the form', () {
    test('the app\'s own rhythm changes progression is one', () {
      final form = practiceProgressions.firstWhere(
        (tune) => tune.title.startsWith('Rhythm changes'),
      );
      expect(isRhythmChanges(form), isTrue);
      expect(form.form, 'AABA');
      expect(form.barCount, 32);
    });

    test('the bridge is four dominants, each a fourth above the last', () {
      final cycle = bridgeCycleOf(_standard('Oleo'))!;
      expect(cycle.map((c) => c.display), ['D7', 'G7', 'C7', 'F7']);
      expect(cycle.every(isDominant), isTrue);
      for (var i = 1; i < cycle.length; i++) {
        expect((cycle[i].root - cycle[i - 1].root + 12) % 12, upAFourth);
      }
    });

    test('the cycle walks home: the last one is the V of the key', () {
      // The fact that makes the other three make sense.
      for (final tune in tunesWithTheBridge(standards)) {
        final steps = cycleSteps(tune);
        expect(steps, hasLength(4), reason: tune.title);
        expect(steps.last.comesHome, isTrue, reason: tune.title);
        expect(
          steps.last.resolvesTo.display,
          tune.key,
          reason: '${tune.title} in ${tune.key}',
        );
      }
    });

    test('each step points at the chord it is the V of', () {
      final steps = cycleSteps(_standard('Oleo'));
      expect(steps.map((s) => s.chord.display), ['D7', 'G7', 'C7', 'F7']);
      expect(steps.map((s) => s.resolvesTo.display), ['G7', 'C7', 'F7', 'B♭']);
      expect(steps.take(3).every((s) => !s.comesHome), isTrue);
    });

    test('a blues is not rhythm changes, and neither is a ballad', () {
      for (final title in ["Now's the Time", 'Body and Soul', 'So What']) {
        expect(isRhythmChanges(_standard(title)), isFalse, reason: title);
        expect(hasTheBridge(_standard(title)), isFalse, reason: title);
      }
    });

    test(
      'it finds the form in every key it is written in, not just B flat',
      () {
        // Read off the chart, so transposing a tune cannot hide it.
        final keys = {for (final t in tunesWithTheBridge(standards)) t.key};
        expect(keys.length, greaterThan(2), reason: 'found $keys');
        expect(keys, contains('B♭'));
      },
    );

    test('transposing a rhythm changes tune leaves it rhythm changes', () {
      final oleo = _standard('Oleo');
      for (final steps in [1, 5, 7, 11]) {
        final moved = oleo.transposed(steps);
        expect(isRhythmChanges(moved), isTrue, reason: 'up $steps');
        expect(cycleSteps(moved).last.resolvesTo.display, moved.key);
      }
    });

    test('a bridge that moves faster than two bars is somebody else\'s', () {
      // Four dominants is the shape; four dominants a bar each is not
      // this bridge, and saying it is would teach the wrong eight bars.
      final notIt = Tune.fromChart(
        title: 'Not it',
        key: 'B♭',
        defaultTempo: 160,
        chart:
            '| [A] BbΔ7 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 '
            '| [A] BbΔ7 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 '
            '| [B] D7 | G7 | C7 | F7 | D7 | G7 | C7 | F7 '
            '| [A] BbΔ7 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 |',
      );
      expect(notIt.form, 'AABA');
      expect(hasTheBridge(notIt), isFalse);
    });

    test('a bridge of the right length but the wrong chords is not it', () {
      final minorBridge = Tune.fromChart(
        title: 'Not it either',
        key: 'B♭',
        defaultTempo: 160,
        chart:
            '| [A] BbΔ7 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 '
            '| [A] BbΔ7 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 '
            '| [B] Dm7 | Dm7 | Gm7 | Gm7 | Cm7 | Cm7 | Fm7 | Fm7 '
            '| [A] BbΔ7 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 | Bb6 |',
      );
      expect(hasTheBridge(minorBridge), isFalse, reason: 'those are not V7s');
    });
  });

  group('borrowing the bridge', () {
    test('a tune can have the bridge without being rhythm changes', () {
      // Scrapple from the Apple opens on the ii of Honeysuckle Rose and
      // then takes this middle eight. It is the best argument there is
      // for learning the bridge on its own, so the app has to be able to
      // tell the difference rather than lumping them together.
      final scrapple = _standard('Scrapple from the Apple');
      expect(hasTheBridge(scrapple), isTrue);
      expect(isRhythmChanges(scrapple), isFalse);
      expect(borrowsTheBridge(scrapple), isTrue);
    });

    test('the two groups do not overlap and cover everything found', () {
      final all = tunesWithTheBridge(standards);
      expect(all, isNotEmpty);
      for (final tune in all) {
        expect(
          isRhythmChanges(tune) != borrowsTheBridge(tune),
          isTrue,
          reason: '${tune.title} is one or the other, not both or neither',
        );
      }
    });

    test('the real ones open at home', () {
      for (final tune in tunesWithTheBridge(standards).where(isRhythmChanges)) {
        final opening = tune.bars.first.first.chord;
        expect(
          cycleSteps(tune).last.resolvesTo.root,
          opening.root,
          reason: '${tune.title} opens on ${opening.display} in ${tune.key}',
        );
      }
    });
  });

  group('the A section in numbers', () {
    test('it is written as four pairs of bars, covering all eight', () {
      expect(aSectionParts, hasLength(4));
      expect(aSectionParts.first.bars, startsWith('1'));
      expect(aSectionParts.last.bars, contains('8'));
    });

    test('the turnaround really is said to repeat', () {
      // The whole claim of that half of the screen: if the first two
      // entries did not share their shape there would be nothing to say.
      expect(aSectionParts[0].numerals, contains('ii'));
      expect(aSectionParts[0].numerals, contains('V'));
      expect(aSectionParts[1].numerals, contains('ii'));
      expect(aSectionParts[1].about.toLowerCase(), contains('same'));
    });

    test('every pair says what it is and why', () {
      for (final part in aSectionParts) {
        expect(part.numerals, isNotEmpty);
        expect(part.about.length, greaterThan(50), reason: part.bars);
      }
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
          home: RhythmChangesScreen(
            player: _FakePlayer(),
            settings: AppSettings.inMemory(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the bridge is on screen when it opens, before the A', (
      tester,
    ) async {
      // The bridge is the reason to be here. The A section is a
      // turnaround everybody already knows, so leading with it would
      // bury the point.
      await open(tester);
      expect(find.text('The Bridge'), findsOneWidget);
      final cycle = find.byKey(const ValueKey('the-cycle'));
      expect(cycle, findsOneWidget);
      expect(tester.getRect(cycle).bottom, lessThan(852));
      expect(
        tester.getRect(cycle).top,
        lessThan(tester.getRect(find.text('The A Section')).top),
      );
    });

    testWidgets('the chain is drawn, and it ends on the key', (tester) async {
      await open(tester);
      for (final chord in ['D7', 'G7', 'C7', 'F7', 'B♭']) {
        expect(find.text(chord), findsWidgets, reason: chord);
      }
    });

    /// Whether that button is offering to stop, asked of the button
    /// itself: the page is long and a ListView throws away what has
    /// scrolled off, so looking for the word "Stop" anywhere finds
    /// nothing once you have moved down the page.
    Finder stopping(String id) => find.descendant(
      of: find.byKey(ValueKey(id)),
      matching: find.byIcon(Icons.stop),
    );

    Future<void> press(WidgetTester tester, String id) async {
      final button = find.byKey(ValueKey(id));
      await tester.scrollUntilVisible(button, 100);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('each stretch can be played, and only one at a time', (
      tester,
    ) async {
      await open(tester);
      expect(stopping('play-bridge'), findsNothing);
      await press(tester, 'play-bridge');
      expect(stopping('play-bridge'), findsOneWidget);

      // Starting another stops the first: two stretches at once is a
      // mess, and the button that was playing has to say so.
      await press(tester, 'play-a-section');
      expect(stopping('play-a-section'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-bridge')),
        -100,
      );
      expect(stopping('play-bridge'), findsNothing);

      // And the same button again stops it.
      await press(tester, 'play-a-section');
      expect(stopping('play-a-section'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it counts the tunes rather than claiming a number', (
      tester,
    ) async {
      await open(tester);
      final count = tunesWithTheBridge(standards).length;
      expect(count, greaterThan(10), reason: 'worth a screen');
      final line = find.byKey(const ValueKey('tune-count'));
      await tester.scrollUntilVisible(line, 100);
      expect(
        find.textContaining('$count tunes in this app have that bridge'),
        findsOneWidget,
      );
    });

    testWidgets('it names the tune that only borrowed the bridge', (
      tester,
    ) async {
      await open(tester);
      final borrowed = find.byKey(const ValueKey('borrowed'));
      await tester.scrollUntilVisible(borrowed, 100);
      expect(borrowed, findsOneWidget);
      expect(
        find.textContaining('Scrapple from the Apple is the odd one out'),
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
      final card = find.byKey(const ValueKey('learn-rhythm-changes'));
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
      expect(find.byType(RhythmChangesScreen), findsOneWidget);
    });
  });
}
