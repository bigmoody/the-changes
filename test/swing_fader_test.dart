// The swing fader in the mixer, for every groove rather than one.
//
// It used to be shown only for the swing feel, which was right when the
// value went nowhere else: a shuffle was pinned to the triplet and an
// even feel ignored it, so the slider would have been a control that did
// nothing. All six lean now, so all six have one.
//
// The thing most worth guarding is that the fader rests where the band
// actually plays. Reading the swing feel's answer for every feel showed
// a bossa sitting at "dotted" while the band played it even, which is a
// control lying about what you are hearing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_along/audio/practice_player.dart';
import 'package:play_along/music/swing.dart';
import 'package:play_along/music/tune.dart';
import 'package:play_along/music/tune_library.dart';
import 'package:play_along/screens/practice_screen.dart';
import 'package:play_along/settings/app_settings.dart';
import 'package:play_along/theme.dart';

/// Opens a tune and its mixer.
Future<void> openMixer(WidgetTester tester, String title) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.light),
      home: PracticeScreen(
        tune: standards.firstWhere((tune) => tune.title == title),
        player: PracticePlayer(),
        settings: AppSettings.inMemory(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Mixer'));
  await tester.pumpAndSettle();
}

Slider fader(WidgetTester tester) =>
    tester.widget<Slider>(find.byKey(const ValueKey('band-swing')));

void main() {
  group('the fader is there for every groove', () {
    testWidgets('a swing tune has one', (tester) async {
      await openMixer(tester, 'A Foggy Day');
      expect(find.byKey(const ValueKey('band-swing')), findsOneWidget);
    });

    testWidgets('and so does a bossa, which never used to', (tester) async {
      await openMixer(tester, 'Blue Bossa');
      expect(find.byKey(const ValueKey('band-swing')), findsOneWidget);
    });

    testWidgets('it rests where the band plays, not where swing does', (
      tester,
    ) async {
      // The bug this is here for: a bossa sat at the swing feel's own
      // answer, so the fader said "dotted" over a band playing even.
      await openMixer(tester, 'Blue Bossa');
      expect(fader(tester).value, straight);
      expect(find.textContaining('Even'), findsWidgets);
    });

    testWidgets('a swing tune rests on the tempo, and says so', (tester) async {
      await openMixer(tester, 'A Foggy Day');
      expect(fader(tester).value, greaterThan(straight));
      expect(find.textContaining('Follows the tempo'), findsOneWidget);
    });
  });

  group('putting it back', () {
    testWidgets('it is there before it is needed, and greyed', (tester) async {
      // Shown only once the fader had been moved, it was a button you
      // could not find by looking: you had to already have done the
      // thing you wanted undone.
      await openMixer(tester, 'Blue Bossa');
      final reset = find.byKey(const ValueKey('swing-follow-again'));
      expect(reset, findsOneWidget);
      expect(
        tester.widget<TextButton>(reset).onPressed,
        isNull,
        reason: 'nothing to undo yet',
      );
    });

    testWidgets('and it wakes up once the fader is moved', (tester) async {
      await openMixer(tester, 'Blue Bossa');
      await tester.drag(
        find.byKey(const ValueKey('band-swing')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      final reset = find.byKey(const ValueKey('swing-follow-again'));
      expect(tester.widget<TextButton>(reset).onPressed, isNotNull);
    });

    testWidgets('moved, it offers to go back, and does', (tester) async {
      await openMixer(tester, 'Blue Bossa');
      await tester.drag(
        find.byKey(const ValueKey('band-swing')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      expect(fader(tester).value, greaterThan(straight));

      final back = find.byKey(const ValueKey('swing-follow-again'));
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(fader(tester).value, straight);
      expect(
        tester.widget<TextButton>(back).onPressed,
        isNull,
        reason: 'nothing left to put back',
      );
    });

    testWidgets('it is called Reset, on an even groove', (tester) async {
      await openMixer(tester, 'Blue Bossa');
      await tester.drag(
        find.byKey(const ValueKey('band-swing')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('swing-follow-again')),
          matching: find.text('Reset'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and on a swinging one', (tester) async {
      // The same word either way. Where it goes back to differs by
      // groove and the line beside it says which; the button only has
      // to say that it undoes.
      await openMixer(tester, 'A Foggy Day');
      await tester.drag(
        find.byKey(const ValueKey('band-swing')),
        const Offset(-80, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('swing-follow-again')),
          matching: find.text('Reset'),
        ),
        findsOneWidget,
      );
    });
  });

  group('what it says', () {
    testWidgets('a funk tune is told its sixteenths are the ones leaning', (
      tester,
    ) async {
      final funk = standards.firstWhere(
        (tune) => tune.style.drums == Feel.funk,
      );
      await openMixer(tester, funk.title);
      await tester.drag(
        find.byKey(const ValueKey('band-swing')),
        const Offset(80, 0),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('on the sixteenths'), findsOneWidget);
    });
  });
}
